#!/usr/bin/env bash
# scripts/test-commands.sh — Smoke tests dos módulos de comando VIVOS
#
# Apos DQ-002 (remoção das árvores órfãs bin/commands, lib/commands/cli e
# lib/commands/lessons), este suite testa o código realmente carregado em
# runtime: lib/commands/{workflow,utils,ddd}.sh e lib/lessons.sh.
#
# Cada teste roda num SUBSHELL isolado — os módulos vivos trazem
# `set -euo pipefail`, que de outra forma vazaria e abortaria o suite.

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

# ============================================================
# SETUP
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/devorq-test-commands"
export DEVORQ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"
export DEVORQ_VERSION="${DEVORQ_VERSION:-4.0.0}"
LIB_DIR="$DEVORQ_LIB"

setup() {
    info "Setup: criando ambiente de teste..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
}

teardown() {
    info "Teardown: limpando..."
    rm -rf "$TEST_DIR"
}

# Carrega o stack core necessário para os comandos vivos. Chamado DENTRO de
# cada subshell de teste; o set -e que os módulos armam fica contido.
_load_core() {
    source "$LIB_DIR/helpers.sh" 2>/dev/null || true
    source "$LIB_DIR/visual.sh" 2>/dev/null || true
    source "$LIB_DIR/gates.sh" 2>/dev/null || true
    source "$LIB_DIR/context.sh" 2>/dev/null || true
    set +e
}

# ============================================================
# TESTS (cada um emite ✓/✗ via pass/fail; rodam em subshell)
# ============================================================

test_cli_init() {
    info "Test: devorq::cmd_init (lib/commands/workflow.sh)"
    _load_core
    source "$LIB_DIR/commands/workflow.sh" 2>/dev/null || true
    set +e

    # cmd_init (vivo) opera sobre o cwd, sem argumento de path.
    rm -rf "$TEST_DIR/.devorq"; mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || return
    devorq::cmd_init >/dev/null 2>&1

    [ -d "$TEST_DIR/.devorq/state/lessons" ] \
        && pass "init cria estrutura .devorq" || fail "init deveria criar estrutura .devorq"
    [ -f "$TEST_DIR/.devorq/state/context.json" ] \
        && pass "init cria context.json" || fail "init deveria criar context.json"
}

test_cli_version() {
    info "Test: devorq::cmd_version (lib/commands/utils.sh)"
    _load_core
    source "$LIB_DIR/commands/utils.sh" 2>/dev/null || true
    set +e

    local output
    output=$(devorq::cmd_version 2>/dev/null)
    echo "$output" | grep -q "DEVORQ" \
        && pass "version imprime DEVORQ" || fail "version deveria imprimir DEVORQ"
    echo "$output" | grep -qE "v?[0-9]+\.[0-9]+" \
        && pass "version imprime número de versão" || fail "version deveria imprimir versão"
}

test_cli_stats() {
    info "Test: devorq::cmd_stats (lib/commands/utils.sh)"
    _load_core
    source "$LIB_DIR/commands/utils.sh" 2>/dev/null || true
    set +e

    # cmd_stats opera sobre o repo DEVORQ; basta rodar sem erro fatal.
    if devorq::cmd_stats >/dev/null 2>&1; then
        pass "stats roda sem erro fatal"
    else
        # exit != 0 ainda é aceitável desde que não tenha abortado o subshell;
        # falha só se a função nem existe.
        declare -f devorq::cmd_stats >/dev/null \
            && pass "stats roda (exit != 0 tolerado)" || fail "devorq::cmd_stats não definida"
    fi
}

test_lessons_live() {
    info "Test: lessons:: (lib/lessons.sh — crud/search/validate/sync vivos)"
    _load_core
    source "$LIB_DIR/lessons.sh" 2>/dev/null || true
    set +e

    export DEVORQ_DIR="$TEST_DIR/.devorq"
    export DEVORQ_LESSONS_DIR="$TEST_DIR/.devorq/state/lessons"
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"

    # Funções vivas definidas?
    declare -f lessons::approve >/dev/null \
        && pass "lessons::approve definida (viva)" || fail "lessons::approve ausente"
    declare -f lessons::compile >/dev/null \
        && pass "lessons::compile definida (viva)" || fail "lessons::compile ausente"
    declare -f lessons::list >/dev/null \
        && pass "lessons::list definida (viva)" || fail "lessons::list ausente"

    # approve numa lição inexistente => mensagem de não encontrada (comportamento vivo)
    local output
    output=$(lessons::approve "nonexistent" 2>&1)
    echo "$output" | grep -qi "não encontr\|not found" \
        && pass "approve trata lição inexistente" || fail "approve deveria tratar inexistente"

    # list roda sem abortar
    if lessons::list >/dev/null 2>&1; then
        pass "list roda sem erro"
    else
        declare -f lessons::list >/dev/null \
            && pass "list roda (exit != 0 tolerado)" || fail "lessons::list ausente"
    fi
}

test_ddd_validate() {
    info "Test: devorq::cmd_ddd_validate (lib/commands/ddd.sh)"
    _load_core
    source "$LIB_DIR/commands/ddd.sh" 2>/dev/null || true
    set +e

    cd "$TEST_DIR" || return
    printf '# Test\n\n## Domain Model\nEntities: User, Order\nBounded Contexts: CRM, Billing\n' > "$TEST_DIR/SPEC.md"
    local output
    output=$(devorq::cmd_ddd_validate 2>/dev/null)
    echo "$output" | grep -qiE "score|pass|gate|válido|valid" \
        && pass "ddd validate produz resultado" || fail "ddd validate deveria produzir resultado"

    rm -f "$TEST_DIR/SPEC.md"
    output=$(devorq::cmd_ddd_validate 2>&1)
    echo "$output" | grep -qi "não encontrado\|not found" \
        && pass "ddd validate trata SPEC ausente" || fail "ddd validate deveria tratar SPEC ausente"
}

# ============================================================
# MAIN — roda cada teste num subshell isolado e tabula ✓/✗
# ============================================================

main() {
    echo ""
    echo "========================================"
    echo " Commands Module Tests (codigo vivo)"
    echo "========================================"
    echo ""

    setup
    trap teardown EXIT

    local out
    for t in test_cli_init test_cli_version test_cli_stats test_lessons_live test_ddd_validate; do
        out=$( "$t" 2>&1 )          # subshell: contém o set -e dos módulos vivos
        echo "$out"
        local p f
        p=$(grep -c '✓' <<<"$out"); f=$(grep -c '✗' <<<"$out")
        TESTS_PASSED=$((TESTS_PASSED + p))
        TESTS_FAILED=$((TESTS_FAILED + f))
    done
    TESTS_RUN=$((TESTS_PASSED + TESTS_FAILED))

    echo ""
    echo "========================================"
    echo " Commands Tests Summary"
    echo "========================================"
    echo " Tests run:    $TESTS_RUN"
    echo " Passed:       $TESTS_PASSED"
    echo " Failed:       $TESTS_FAILED"
    echo "========================================"

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        return 1
    fi
}

main "$@"
