#!/usr/bin/env bats

# Post-commit hook — captura de lição após SPEC movida para implemented/
# Testes em 2 grupos: funções internas (via source) + fluxo interativo (stdin mockado)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK="$DEVORQ_ROOT/.devorq/hooks/post-commit"

# ────────────────────────────────────────────
# Grupo 1 — Existência e source guard
# ────────────────────────────────────────────

@test "post-commit hook existe" {
    [ -f "$HOOK" ]
}

@test "post-commit hook é executável" {
    [ -x "$HOOK" ]
}

@test "post-commit hook carrega via source sem executar lógica principal" {
    run bash -c "source '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "post-commit hook passa shellcheck sem erros de severity error" {
    run shellcheck --severity=error "$HOOK"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────
# Grupo 2 — Funções internas (via source)
# ────────────────────────────────────────────

setup() {
    export BATS_TMPDIR
    export FAKE_DEVORQ_DIR="$BATS_TEST_TMPDIR/devorq_dir"
    mkdir -p "$FAKE_DEVORQ_DIR/state/lessons-pending"
    # Carregar funções do hook sem executar main
    # shellcheck source=/dev/null
    source "$HOOK"
}

@test "create_spec_lesson_skeleton cria arquivo em lessons-pending" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    [ -f "$out" ]
}

@test "create_spec_lesson_skeleton define source: spec-completion" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    grep -q "^source: spec-completion$" "$out"
}

@test "create_spec_lesson_skeleton inclui campo spec_origin com ID da SPEC" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    grep -q "^spec_origin: SPEC-0071-16-04-2026$" "$out"
}

@test "create_spec_lesson_skeleton define status: pending" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    grep -q "^status: pending$" "$out"
}

@test "create_spec_lesson_skeleton inclui campo applied_to vazio" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    grep -q "^applied_to: \"\"$" "$out"
}

@test "create_spec_lesson_skeleton usa template de spec-completion (seção O QUE FOI IMPLEMENTADO)" {
    local out
    out=$(create_spec_lesson_skeleton "$FAKE_DEVORQ_DIR" "SPEC-0071-16-04-2026" "Título Teste" "arquitetura")
    grep -q "O QUE FOI IMPLEMENTADO" "$out"
}

@test "detect_spec_implemented retorna vazio quando nenhuma SPEC foi movida" {
    run detect_spec_implemented "non-existent-diff-output"
    [ -z "$output" ]
}

@test "detect_spec_implemented extrai ID da SPEC de linha de diff simulada" {
    local fake_diff="A	docs/specs/implemented/SPEC-0071-16-04-2026-hook-post-commit.md"
    run detect_spec_implemented "$fake_diff"
    [[ "$output" == *"SPEC-0071-16-04-2026"* ]]
}

# ────────────────────────────────────────────
# Grupo 3 — Fluxo interativo (stdin mockado)
# ────────────────────────────────────────────

@test "resposta N: nenhum arquivo criado em lessons-pending" {
    local pending_dir="$BATS_TEST_TMPDIR/n_test/state/lessons-pending"
    mkdir -p "$pending_dir"
    # Hook não será chamado via git, então testamos a função ask_capture_lesson diretamente
    run bash -c "
        source '$HOOK'
        echo 'N' | ask_capture_lesson '$BATS_TEST_TMPDIR/n_test' 'SPEC-0071-16-04-2026' 'Título' 'arquitetura'
    "
    local count
    count=$(ls "$pending_dir" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -eq 0 ]
}

@test "resposta S+D: arquivo criado em lessons-pending, sem Gate 6" {
    local pending_dir="$BATS_TEST_TMPDIR/sd_test/state/lessons-pending"
    mkdir -p "$pending_dir"
    run bash -c "
        source '$HOOK'
        printf 'S\nD\n' | ask_capture_lesson '$BATS_TEST_TMPDIR/sd_test' 'SPEC-0071-16-04-2026' 'Título' 'arquitetura'
    "
    local count
    count=$(ls "$pending_dir" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -eq 1 ]
}

# ────────────────────────────────────────────
# Grupo 4 — Guards de ambiente
# ────────────────────────────────────────────

@test "ambiente não-interativo: hook sai com exit 0 sem criar arquivos" {
    local pending_dir="$BATS_TEST_TMPDIR/nonint/state/lessons-pending"
    mkdir -p "$pending_dir"
    # Executar sem terminal (bats por padrão não tem tty)
    run bash "$HOOK"
    [ "$status" -eq 0 ]
    local count
    count=$(ls "$pending_dir" 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -eq 0 ]
}
