#!/usr/bin/env bats

# Sprint 1 — Testes comportamentais para débitos 1, 2, 3, 5
# Cobre: heredoc literal, stdout/stderr separation, mcp-health-check path

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ────────────────────────────────────────────
# Achado 1: heredoc literal em phase5_contract
# ────────────────────────────────────────────

@test "1.1: phase5_contract gera arquivo sem executar crases como comandos" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint1-XXXXXX)
    DEVORQ_DIR="$tmpdir"

    # Se heredoc não for literal, `caminho/arquivo1.php` seria executado
    # e geraria erro ou saída inesperada. O arquivo deve conter a string literal.
    run phase5_contract "brainstorm.md" "teste de heredoc"

    [ "$status" -eq 0 ]

    # O arquivo de contrato deve ter sido criado
    local contract_file
    contract_file=$(ls "$tmpdir/state/contracts/"ct_*.md 2>/dev/null | head -1)
    [ -n "$contract_file" ]

    # Deve conter a string literal com backticks — NÃO executou como comando
    grep -q '`caminho/arquivo1.php`' "$contract_file"

    rm -rf "$tmpdir"
}

@test "1.1: contrato gerado contém variavel user_intent interpolada corretamente" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint1-XXXXXX)
    DEVORQ_DIR="$tmpdir"

    run phase5_contract "brainstorm.md" "minha tarefa especifica"

    local contract_file
    contract_file=$(ls "$tmpdir/state/contracts/"ct_*.md 2>/dev/null | head -1)
    [ -n "$contract_file" ]

    # Variável deve ser interpolada
    grep -q 'minha tarefa especifica' "$contract_file"

    rm -rf "$tmpdir"
}

# ────────────────────────────────────────────
# Achado 2: stdout/stderr em phase1_detection
# ────────────────────────────────────────────

@test "1.2: phase1_detection retorna apenas payload estruturado no stdout" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint1-XXXXXX)
    DEVORQ_DIR="$tmpdir"
    DEVORQ_ROOT="$DEVORQ_ROOT"

    # Captura apenas stdout
    local context
    context=$(phase1_detection 2>/dev/null)

    # Deve ser exatamente uma linha no formato stack:tipo:llm:runtime:db
    local line_count
    line_count=$(echo "$context" | grep -c ".")
    [ "$line_count" -eq 1 ]

    # Deve ter exatamente 4 separadores ':'
    local colon_count
    colon_count=$(echo "$context" | tr -cd ':' | wc -c)
    [ "$colon_count" -eq 4 ]

    rm -rf "$tmpdir"
}

@test "1.2: cut -d: -f1 em saida de phase1_detection extrai stack sem texto de log" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-sprint1-XXXXXX)
    DEVORQ_DIR="$tmpdir"

    local context
    context=$(phase1_detection 2>/dev/null)

    local stack
    stack=$(echo "$context" | cut -d: -f1)

    # Stack não pode conter espaços ou texto de log
    [[ "$stack" != *" "* ]]
    [[ "$stack" != *"["* ]]
    [ -n "$stack" ]

    rm -rf "$tmpdir"
}

# ────────────────────────────────────────────
# Achado 5: path incorreto em mcp-health-check
# ────────────────────────────────────────────

@test "1.3: mcp_health_all nao falha silenciosamente quando stack-detector nao existe no path errado" {
    # Verifica que o arquivo usa path correto (lib/ e nao .devorq/lib/)
    run grep -n '\.devorq/lib/stack-detector' "$DEVORQ_ROOT/lib/mcp-health-check.sh"

    # Não deve existir a referência ao path incorreto
    [ "$status" -ne 0 ]
}

@test "1.3: mcp-health-check usa path derivado de DEVORQ_ROOT para stack-detector" {
    # O arquivo deve referenciar lib/stack-detector via variável ou path absoluto correto
    run grep -E 'DEVORQ_ROOT.*stack-detector|stack-detector\.sh.*DEVORQ' "$DEVORQ_ROOT/lib/mcp-health-check.sh"
    [ "$status" -eq 0 ]
}
