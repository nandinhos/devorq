#!/usr/bin/env bash
# scripts/ci-test.sh — DEVORQ CI Test Suite
# Run locally or in GitHub Actions
# Exit codes: 0 = all pass, 1 = any failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVORQ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CI_STATE_BACKUP_DIR=""
CI_STATE_ORIGINAL=""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; TESTS_PASSED=$((TESTS_PASSED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; TESTS_FAILED=$((TESTS_FAILED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

cleanup() {
    # PASSO 1: limpa APENAS artefatos criados durante o teste
    # (skills geradas pelo lessons::compile, lessons de teste capturadas)
    rm -rf "$DEVORQ_ROOT/skills/learned-lesson"
    rm -rf "$DEVORQ_ROOT/skills/.index.md"
    # Limpa lessons de teste (capturadas durante o teste, no .devorq ATUAL,
    # antes de restaurar o backup)
    if [ -d "$DEVORQ_ROOT/.devorq/state/lessons/captured" ]; then
        rm -f "$DEVORQ_ROOT/.devorq/state/lessons/captured/"*.json 2>/dev/null || true
    fi

    # PASSO 2: restaura estado original em diretório temporário único.
    # Nunca usa .devorq.bak dentro do repositório: um run interrompido não pode
    # parecer deleção em massa do estado rastreado.
    if [ -n "$CI_STATE_ORIGINAL" ] && [ -d "$CI_STATE_ORIGINAL" ]; then
        rm -rf "$DEVORQ_ROOT/.devorq"
        mv "$CI_STATE_ORIGINAL" "$DEVORQ_ROOT/.devorq"
    fi
    [ -z "$CI_STATE_BACKUP_DIR" ] || rmdir "$CI_STATE_BACKUP_DIR" 2>/dev/null || true
}

# Setup
trap cleanup EXIT
mkdir -p "$DEVORQ_ROOT/.devorq/state/lessons/captured"

# Backup estado atual fora do worktree, inclusive se a suite for interrompida.
CI_STATE_BACKUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/devorq-ci-state.XXXXXX")"
CI_STATE_ORIGINAL="$CI_STATE_BACKUP_DIR/original"
[ -d "$DEVORQ_ROOT/.devorq" ] && mv "$DEVORQ_ROOT/.devorq" "$CI_STATE_ORIGINAL"
mkdir -p "$DEVORQ_ROOT/.devorq/state/lessons/captured"

export DEVORQ_DIR="$DEVORQ_ROOT"
export DEVORQ_ROOT="$DEVORQ_ROOT"
export DEVORQ_LESSONS_DIR="$DEVORQ_ROOT/.devorq/state/lessons"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"
export PATH="$DEVORQ_ROOT/bin:$PATH"
export LESSONS_AUTO=true

cd "$DEVORQ_ROOT"

echo ""
echo "========================================"
echo " DEVORQ — CI Test Suite"
echo "========================================"
echo ""

# ============================================================
# FASE 1: Sintaxe
# ============================================================
info "═══ FASE 1: Sintaxe ═══"

check_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        pass "syntax: $file"
        return 0
    else
        fail "syntax: $file"
        return 1
    fi
}

check_syntax "$DEVORQ_ROOT/bin/devorq" || true
for f in "$DEVORQ_LIB"/*.sh; do
    check_syntax "$f" || true
done

echo ""

# ============================================================
# FASE 2: Estrutura
# ============================================================
info "═══ FASE 2: Estrutura ═══"

[ -f "$DEVORQ_LIB/lessons.sh" ] && pass "lib/lessons.sh existe" || fail "lib/lessons.sh existe"
[ -f "$DEVORQ_LIB/gates.sh" ] && pass "lib/gates.sh existe" || fail "lib/gates.sh existe"
[ -f "$DEVORQ_LIB/context7.sh" ] && pass "lib/context7.sh existe" || fail "lib/context7.sh existe"
[ -f "$DEVORQ_LIB/compact.sh" ] && pass "lib/compact.sh existe" || fail "lib/compact.sh existe"
[ -f "$DEVORQ_ROOT/bin/devorq" ] && pass "bin/devorq existe" || fail "bin/devorq existe"

# Skills
[ -d "$DEVORQ_ROOT/skills/scope-guard" ] && pass "skills/scope-guard existe" || fail "skills/scope-guard existe"
[ -d "$DEVORQ_ROOT/skills/env-context" ] && pass "skills/env-context existe" || fail "skills/env-context existe"
[ -d "$DEVORQ_ROOT/skills/ddd-deep-domain" ] && pass "skills/ddd-deep-domain existe" || fail "skills/ddd-deep-domain existe"
[ -d "$DEVORQ_ROOT/skills/devorq-auto" ] && pass "skills/devorq-auto existe" || fail "skills/devorq-auto existe"
[ -d "$DEVORQ_ROOT/skills/devorq-mode" ] && pass "skills/devorq-mode existe" || fail "skills/devorq-mode existe"
[ -d "$DEVORQ_ROOT/skills/devorq-code-review" ] && pass "skills/devorq-code-review existe" || fail "skills/devorq-code-review existe"

echo ""

# ============================================================
# FASE 3: Lessons Loop (capture → validate → approve → compile)
# ============================================================
info "═══ FASE 3: Lessons Loop ═══"

# Carrega lessons.sh
source "$DEVORQ_LIB/lessons.sh"

# 3a: capture
LESSON_ID=""
capture_result=$(lessons::capture "CI Test: file permission" "Permission denied ao criar arquivo" "Usar chmod corretamente" 2>&1) || true
if echo "$capture_result" | grep -q "Lição salva"; then
    pass "lessons::capture"
    LESSON_ID=$(ls "$DEVORQ_LESSONS_DIR/captured/"*.json 2>/dev/null | head -1 | sed 's/.*\///; s/\.json$//')
else
    fail "lessons::capture — output: $capture_result"
fi

# 3b: migrate
migrate_result=$(lessons::migrate 2>&1) || true
if echo "$migrate_result" | grep -q "Lições migradas"; then
    pass "lessons::migrate"
else
    warn "lessons::migrate — output: $migrate_result"
fi

# 3c: validate em AUTO SEM Context7 — marca skipped, NAO auto-valida (DQ-013)
validate_result=$(LESSONS_AUTO=true lessons::validate 2>&1) || true
if echo "$validate_result" | grep -qiE "skipped|não-verificad|validação manual|Validadas: [1-9]|Context7 (não configurado|indisponível)"; then
    pass "lessons::validate (skipped sem Context7 / validado com Context7)"
else
    fail "lessons::validate — output: $validate_result"
fi

# 3d: approve
if [ -n "$LESSON_ID" ]; then
    approve_result=$(lessons::approve "$LESSON_ID" "" "true" 2>&1) || true
    if echo "$approve_result" | grep -qi "aprovada\|já aprovada\|already"; then
        pass "lessons::approve"
    else
        fail "lessons::approve — output: $approve_result"
    fi
fi

# 3e: compile
compile_result=$(lessons::compile "" "" "false" 2>&1) || true
if echo "$compile_result" | grep -q "Skill compilada"; then
    pass "lessons::compile"
else
    fail "lessons::compile — output: $compile_result"
fi

# 3f: skill gerada
if [ -f "$DEVORQ_ROOT/skills/learned-lesson/SKILL.md" ]; then
    pass "skill SKILL.md gerada"
else
    fail "skill SKILL.md gerada"
fi

# 3g: compile dry-run
compile_dry=$(lessons::compile "" "" "true" 2>&1) || true
if echo "$compile_dry" | grep -q "DRY RUN"; then
    pass "lessons::compile --dry-run"
else
    fail "lessons::compile --dry-run — output: $compile_dry"
fi

echo ""

# ============================================================
# FASE 4: CLI commands
# ============================================================
info "═══ FASE 4: CLI Commands ═══"

# verify-dispatch (bin/devorq → lib/commands/*)
if bash "$DEVORQ_ROOT/scripts/verify-dispatch.sh" >/dev/null 2>&1; then
    pass "verify-dispatch.sh"
else
    fail "verify-dispatch.sh"
fi

# devorq test
cli_test=$(bin/devorq test 2>&1) || true
if echo "$cli_test" | grep -q "OK\|Estrutura OK"; then
    pass "devorq test"
else
    fail "devorq test — output: $cli_test"
fi

# devorq lessons list
cli_list=$(bin/devorq lessons list 2>&1) || true
if echo "$cli_list" | grep -q "LESSONS\|Total"; then
    pass "devorq lessons list"
else
    fail "devorq lessons list — output: $cli_list"
fi

# devorq lessons list approved
cli_list_appr=$(bin/devorq lessons list approved 2>&1) || true
if echo "$cli_list_appr" | grep -q "LESSONS\|★"; then
    pass "devorq lessons list approved"
else
    fail "devorq lessons list approved — output: $cli_list_appr"
fi

# devorq lessons approve --help
cli_approve_help=$(bin/devorq lessons approve --help 2>&1) || true
if echo "$cli_approve_help" | grep -q "Uso:"; then
    pass "devorq lessons approve --help"
else
    fail "devorq lessons approve --help — output: $cli_approve_help"
fi

# devorq lessons compile --help
cli_compile_help=$(bin/devorq lessons compile --help 2>&1) || true
if echo "$cli_compile_help" | grep -q "Uso:"; then
    pass "devorq lessons compile --help"
else
    fail "devorq lessons compile --help — output: $cli_compile_help"
fi

# devorq ddd validate
cli_ddd=$(bin/devorq ddd validate 2>&1) || true
if echo "$cli_ddd" | grep -q "GATE-0\|Score\|PASS\|FAIL"; then
    pass "devorq ddd validate"
else
    fail "devorq ddd validate — output: $cli_ddd"
fi

# devorq rules export (smoke)
export_tmp=$(mktemp -d)
mkdir -p "$export_tmp/.devorq"
(
    cd "$export_tmp"
    for target in cursor claude agents; do
        export_out=$("$DEVORQ_ROOT/bin/devorq" rules export "$target" 2>&1) || true
        case "$target" in
            cursor)
                [ -f ".cursor/rules/devorq-discipline.mdc" ] && pass "devorq rules export cursor" || fail "devorq rules export cursor — $export_out"
                ;;
            claude)
                [ -f "CLAUDE.md" ] && pass "devorq rules export claude" || fail "devorq rules export claude — $export_out"
                ;;
            agents)
                [ -f "AGENTS.md" ] && pass "devorq rules export agents" || fail "devorq rules export agents — $export_out"
                ;;
        esac
    done
)
rm -rf "$export_tmp"

# devorq scope lite
scope_out=$(bin/devorq scope lite "testar export agnostico" 2>&1) || true
if echo "$scope_out" | grep -qiE "FAZER|NÃO FAZER|VERIFICAR|NAO FAZER"; then
    pass "devorq scope lite"
else
    fail "devorq scope lite — output: $scope_out"
fi

# validate-rules (coauthor + agnostic checks)
if bash "$DEVORQ_ROOT/scripts/validate-rules.sh" >/dev/null 2>&1; then
    pass "validate-rules.sh"
else
    fail "validate-rules.sh (coauthor ou estrutura agnóstica)"
fi

echo ""

# ============================================================
# FASE 5.5: Version sync (story-004)
info "═══ FASE 5.5: Version Sync ═══"

if bash "$DEVORQ_ROOT/scripts/sync-version.sh" --check >/dev/null 2>&1; then
    pass "sync-version.sh --check"
else
    fail "sync-version.sh --check (drift detectado - rode --fix)"
fi

echo ""

# FASE 5: Skills scripts
# ============================================================
info "═══ FASE 5: Skills Scripts ═══"

# env-detect.sh
env_detect=$("$DEVORQ_ROOT/skills/env-context/scripts/env-detect.sh" 2>&1) || true
if echo "$env_detect" | grep -q "DEVORQ ENVIRONMENT CONTEXT\|Stack:\|Runtime:"; then
    pass "env-detect.sh"
else
    fail "env-detect.sh — output: $env_detect"
fi

# ddd-validate-spec.sh
ddd_val=$("$DEVORQ_ROOT/skills/ddd-deep-domain/scripts/ddd-validate-spec.sh" "$DEVORQ_ROOT/SPEC.md" 2>&1) || true
if echo "$ddd_val" | grep -q "GATE-0\|Score\|PASS\|FAIL"; then
    pass "ddd-validate-spec.sh"
else
    fail "ddd-validate-spec.sh — output: $ddd_val"
fi

# Contratos de segurança terminal (AUTO e code review)
if bash "$DEVORQ_ROOT/tests/auto/test-loop-terminal-safety.sh" all >/dev/null 2>&1; then
    pass "AUTO: seguranca terminal"
else
    fail "AUTO: seguranca terminal"
fi

if bash "$DEVORQ_ROOT/tests/review/test-review-contract.sh" all >/dev/null 2>&1; then
    pass "code-review: contrato fail-closed"
else
    fail "code-review: contrato fail-closed"
fi

if bash "$DEVORQ_ROOT/tests/contracts/test-contracts.sh" all >/dev/null 2>&1 \
    && bash "$DEVORQ_ROOT/tests/contracts/test-prd-legacy-compatibility.sh" all >/dev/null 2>&1; then
    pass "Loop Engineering: contratos e migracao PRD"
else
    fail "Loop Engineering: contratos e migracao PRD"
fi

if bash "$DEVORQ_ROOT/tests/loop/test-loop-implementation.sh" all >/dev/null 2>&1; then
    pass "Loop Engineering: implementation experimental"
else
    fail "Loop Engineering: implementation experimental"
fi

echo ""


# ============================================================
# FASE 5.6: E2E (story-001 e2e revival)
# Suite Playwright em e2e-tests/. Bloqueante por padrao.
# Para diagnostico local temporario, defina DEVORQ_E2E_STRICT=0.
# ============================================================
info "═══ FASE 5.6: E2E (Playwright) ═══"

E2E_DIR="$DEVORQ_ROOT/e2e-tests"
E2E_REPORT_DIR="$E2E_DIR/playwright-report"

e2e_skip_reason=""
if [ ! -d "$E2E_DIR" ]; then
    e2e_skip_reason="e2e-tests/ nao existe"
elif ! command -v node >/dev/null 2>&1; then
    e2e_skip_reason="node nao instalado"
elif ! command -v npx >/dev/null 2>&1; then
    e2e_skip_reason="npx nao instalado"
fi

if [ -n "$e2e_skip_reason" ]; then
    warn "E2E skipped: $e2e_skip_reason"
    echo ""
else
    # Instala deps se necessario
    if [ ! -d "$E2E_DIR/node_modules" ]; then
        info "Instalando dependencias E2E (primeira execucao)..."
        (cd "$E2E_DIR" && npm install --no-fund --no-audit --silent) >/dev/null 2>&1 || {
            warn "npm install falhou em e2e-tests/"
        }
    fi

    # Roda a suite Playwright (com timeout de 5 min para evitar travas)
    e2e_output=$(cd "$E2E_DIR" && unset NODE_OPTIONS && timeout 300 npx playwright test --reporter=line 2>&1) || e2e_rv=$?
    e2e_rv=${e2e_rv:-0}

    e2e_passed=$(echo "$e2e_output" | grep -oE "[0-9]+ passed" | head -1 | grep -oE "[0-9]+" || echo "0")
    e2e_failed=$(echo "$e2e_output" | grep -oE "[0-9]+ failed" | head -1 | grep -oE "[0-9]+" || echo "0")
    e2e_total=$(( ${e2e_passed:-0} + ${e2e_failed:-0} ))

    if [ "$e2e_failed" -eq 0 ] && [ "$e2e_passed" -gt 0 ]; then
        pass "e2e: ${e2e_passed}/${e2e_total} passed"
    elif [ "$e2e_rv" -ne 0 ] && [ -z "$e2e_passed" ]; then
        warn "e2e: suite nao executou (exit $e2e_rv) - verifique logs em $E2E_REPORT_DIR"
    else
        if [ "${DEVORQ_E2E_STRICT:-1}" = "0" ]; then
            warn "e2e: ${e2e_passed}/${e2e_total} passed (${e2e_failed} failed) - nao bloqueante no dev"
        else
            fail "e2e: ${e2e_passed}/${e2e_total} passed (${e2e_failed} failed) - STRICT mode"
        fi
    fi

    if [ -d "$E2E_REPORT_DIR" ]; then
        info "Relatorio HTML: $E2E_REPORT_DIR/index.html"
    fi
fi

echo ""

# ============================================================
# RESUMO
# ============================================================
echo "========================================"
echo " CI Results: $TESTS_PASSED/$TESTS_RUN passed"
if [ "$TESTS_FAILED" -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $TESTS_FAILED test(s)"
    echo ""
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    echo ""
    exit 0
fi
