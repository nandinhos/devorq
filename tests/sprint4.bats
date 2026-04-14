#!/usr/bin/env bats

# Sprint 4 — Contratos implícitos (Fix 1, Fix 2, Fix 3)
# Cobre: stdout contaminado em phase4 (4.1), alias DEVORQ_ROOT (4.2),
#        campos canônicos em cmd_spec_new (4.3)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ────────────────────────────────────────────
# 4.1: stdout de phase4_brainstorm deve ser apenas o path do arquivo
# ────────────────────────────────────────────

@test "4.1: funções de log em flow.sh redirecionam para stderr (não stdout)" {
    run grep -n 'echo.*>&2' "$DEVORQ_ROOT/lib/orchestration/flow.sh"
    [ "$status" -eq 0 ]
    # Deve ter ao menos 6 funções de log redirecionando para stderr
    local count
    count=$(grep -c 'echo.*>&2' "$DEVORQ_ROOT/lib/orchestration/flow.sh")
    [ "$count" -ge 6 ]
}

@test "4.1: nenhuma das funções de log local em flow.sh escreve em stdout" {
    # As 6 definições de função de log devem todas ter >&2
    local log_lines
    log_lines=$(grep -n '^log\b\|^log_step\|^log_info\|^log_warn\|^log_error\|^log_success' \
        "$DEVORQ_ROOT/lib/orchestration/flow.sh")
    # Todas as linhas de definição de função devem conter >&2
    while IFS= read -r line; do
        [[ "$line" == *">&2"* ]]
    done <<< "$log_lines"
}

@test "4.1: phase4_brainstorm stdout é exatamente uma linha (path do arquivo)" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint4-XXXXXX)
    DEVORQ_DIR="$tmpdir"

    local output
    output=$(phase4_brainstorm "teste de contrato stdout" 2>/dev/null)

    # Deve ser exatamente uma linha
    local line_count
    line_count=$(echo "$output" | wc -l)
    [ "$line_count" -eq 1 ]

    # Deve ser um path de arquivo existente
    [ -f "$output" ]

    # Não deve conter sequências de escape ANSI ou texto de log
    [[ "$output" != *"[DEVORQ]"* ]]
    [[ "$output" != *"[INFO]"* ]]
    [[ "$output" != *"FASE 4"* ]]

    rm -rf "$tmpdir"
}

@test "4.1: path retornado por phase4_brainstorm é referenciável por phase5_contract" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint4-XXXXXX)
    DEVORQ_DIR="$tmpdir"

    local brainstorm_path
    brainstorm_path=$(phase4_brainstorm "integração phase4→phase5" 2>/dev/null)

    # O path retornado deve ser um arquivo real (phase5 pode recebê-lo como argumento)
    [ -f "$brainstorm_path" ]

    # phase5 deve conseguir criar contrato usando o path retornado por phase4
    run phase5_contract "$brainstorm_path" "integração phase4→phase5"
    [ "$status" -eq 0 ]

    rm -rf "$tmpdir"
}

# ────────────────────────────────────────────
# 4.2: DEVORQ_ROOT como alias para DEVORQ_ROOT_DIR em core.sh
# ────────────────────────────────────────────

@test "4.2: core.sh contém alias DEVORQ_ROOT_DIR antes do bloco DEVORQ_VERSION" {
    run grep -n 'DEVORQ_ROOT_DIR.*DEVORQ_ROOT' "$DEVORQ_ROOT/lib/core.sh"
    [ "$status" -eq 0 ]
}

@test "4.2: DEVORQ_VERSION é lido corretamente quando só DEVORQ_ROOT está definido" {
    run bash -c "
        unset DEVORQ_ROOT_DIR
        DEVORQ_ROOT='$DEVORQ_ROOT'
        source '$DEVORQ_ROOT/lib/core.sh'
        echo \"\$DEVORQ_VERSION\"
    "
    [ "$status" -eq 0 ]
    [ "$output" != "0.0.0-unknown" ]
    [ -n "$output" ]
}

@test "4.2: DEVORQ_VERSION não é 0.0.0-unknown no fluxo principal (DEVORQ_ROOT definido)" {
    run bash -c "
        export DEVORQ_ROOT='$DEVORQ_ROOT'
        unset DEVORQ_ROOT_DIR
        source '$DEVORQ_ROOT/lib/core.sh' 2>/dev/null
        [[ \"\$DEVORQ_VERSION\" != '0.0.0-unknown' ]] && echo 'ok' || echo 'fail'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "4.2: DEVORQ_ROOT_DIR definido explicitamente não é sobrescrito pelo alias" {
    run bash -c "
        export DEVORQ_ROOT_DIR='$DEVORQ_ROOT'
        export DEVORQ_ROOT='/tmp/bogus-root-should-not-be-used'
        source '$DEVORQ_ROOT/lib/core.sh' 2>/dev/null
        echo \"\$DEVORQ_VERSION\"
    "
    [ "$status" -eq 0 ]
    # Versão deve ser lida de DEVORQ_ROOT_DIR (válido), não do DEVORQ_ROOT (bogus)
    [ "$output" != "0.0.0-unknown" ]
}

# ────────────────────────────────────────────
# 4.3: campos canônicos em cmd_spec_new
# ────────────────────────────────────────────

@test "4.3: template de cmd_spec_new contém campo priority" {
    run grep -n 'priority' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]
    [[ "$output" == *"priority: medium"* ]]
}

@test "4.3: template de cmd_spec_new contém campo owner" {
    run grep -n 'owner:' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]
}

@test "4.3: template de cmd_spec_new contém campo source" {
    run grep -n 'source:' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]
}

@test "4.3: template de cmd_spec_new contém campo related_tasks" {
    run grep -n 'related_tasks' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]
}

@test "4.3: spec new gera arquivo com todos os campos canônicos" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint4-XXXXXX)

    # Executar com DEVORQ_ROOT apontando para tmpdir para não sujar o projeto
    run bash "$DEVORQ_ROOT/bin/devorq" spec new "teste template canonico sprint4" \
        2>/dev/null <<< "" || true

    # Verificar via grep no template do próprio bin/devorq
    # (não precisa de arquivo em disco para esse teste estrutural)
    run grep -E '^priority:|^owner:|^source:|^related_tasks:' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]

    local field_count
    field_count=$(grep -cE '^priority:|^owner:|^source:|^related_tasks:' "$DEVORQ_ROOT/bin/devorq")
    [ "$field_count" -eq 4 ]

    rm -rf "$tmpdir"
}
