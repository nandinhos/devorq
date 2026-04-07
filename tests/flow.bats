#!/usr/bin/env bats

# Testes comportamentais de ponta-a-ponta: fluxo flow e handoff
# Subtarefa 1.5 — Sprint 1

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    tmpdir=$(mktemp -d /tmp/devorq-flow-test-XXXXXX)
    # Simular estrutura mínima de projeto DEVORQ
    mkdir -p "$tmpdir/.devorq/state/contracts"
    mkdir -p "$tmpdir/.devorq/state/handoffs"
    mkdir -p "$tmpdir/.devorq/state/checkpoints"
    export DEVORQ_DIR="$tmpdir/.devorq"
    export DEVORQ_ROOT_TEST="$tmpdir"
}

teardown() {
    rm -rf "$tmpdir"
}

# ────────────────────────────────────────────
# Testes de fluxo: phase5_contract
# ────────────────────────────────────────────

@test "flow: phase5_contract cria arquivo de contrato em state/contracts/" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"
    # Sobrescrever DEVORQ_DIR após source (source redefine a variável)
    DEVORQ_DIR="$tmpdir/.devorq"

    run phase5_contract "brainstorm.md" "implementar login"

    [ "$status" -eq 0 ]
    [ -n "$(ls "$tmpdir/.devorq/state/contracts/"ct_*.md 2>/dev/null)" ]
}

@test "flow: phase5_contract retorna path do arquivo criado no stdout" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"
    export DEVORQ_DIR="$tmpdir/.devorq"

    local output_path
    # última linha do stdout é o path limpo do arquivo
    output_path=$(phase5_contract "brainstorm.md" "nova feature" 2>/dev/null | tail -1)

    [ -n "$output_path" ]
    [ -f "$output_path" ]
}

@test "flow: phase5_contract nao gera erro ao processar crases no conteudo" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    # Deve executar sem erro (exit 0) mesmo com backticks no template
    run bash -c "
        DEVORQ_DIR='$tmpdir/.devorq'
        source '$DEVORQ_ROOT/lib/orchestration/flow.sh'
        phase5_contract 'brainstorm.md' 'teste' 2>/dev/null
    "
    [ "$status" -eq 0 ]
}

@test "flow: phase1_detection stdout tem exatamente 5 campos separados por :" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local context
    context=$(phase1_detection 2>/dev/null)

    # 5 campos = 4 separadores
    local count
    count=$(echo "$context" | awk -F: '{print NF}')
    [ "$count" -eq 5 ]
}

@test "flow: phase1_detection nao emite texto de log no stdout" {
    source "$DEVORQ_ROOT/lib/orchestration/flow.sh"

    local context
    context=$(phase1_detection 2>/dev/null)

    # Não deve conter textos típicos de log
    [[ "$context" != *"FASE 1"* ]]
    [[ "$context" != *"[INFO]"* ]]
    [[ "$context" != *"Stack:"* ]]
}

# ────────────────────────────────────────────
# Testes de handoff: generate e update
# ────────────────────────────────────────────

@test "handoff: generate_handoff cria arquivo handoff_*.md em state/handoffs/" {
    source "$DEVORQ_ROOT/lib/handoff.sh"

    run generate_handoff "$tmpdir/.devorq" "$DEVORQ_ROOT"

    [ "$status" -eq 0 ]
    [ -n "$(ls "$tmpdir/.devorq/state/handoffs/"handoff_*.md 2>/dev/null)" ]
}

@test "handoff: generate_handoff cria arquivo com secoes obrigatorias" {
    source "$DEVORQ_ROOT/lib/handoff.sh"

    generate_handoff "$tmpdir/.devorq" "$DEVORQ_ROOT" 2>/dev/null

    local handoff_file
    handoff_file=$(ls -t "$tmpdir/.devorq/state/handoffs/"handoff_*.md 2>/dev/null | head -1)

    [ -n "$handoff_file" ]
    grep -q "Status:" "$handoff_file"
}

@test "handoff: handoff_update_status atualiza o campo Status no arquivo" {
    source "$DEVORQ_ROOT/lib/handoff.sh"

    # Criar handoff de teste
    local handoff_file="$tmpdir/.devorq/state/handoffs/handoff_test.md"
    echo "# Handoff" > "$handoff_file"
    echo "Status: pendente" >> "$handoff_file"

    run handoff_update_status "$tmpdir/.devorq" "em_andamento"

    [ "$status" -eq 0 ]
    grep -q "Status: em_andamento" "$handoff_file"
}

@test "handoff: handoff_update_status retorna erro quando nao ha handoff ativo" {
    source "$DEVORQ_ROOT/lib/handoff.sh"

    run handoff_update_status "$tmpdir/.devorq" "concluido"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Nenhum handoff"* ]]
}
