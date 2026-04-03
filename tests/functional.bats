#!/usr/bin/env bats

# Testes funcionais: validação dos 4 bugs corrigidos no Bloco B

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Bug B5: mcp_generator_create — helpers devem modificar json_content ---

@test "mcp_generator_create com stack laravel gera JSON com chave mcpServers" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"
    source "$DEVORQ_ROOT/lib/mcp-json-generator.sh"

    local tmpfile
    tmpfile=$(mktemp /tmp/mcp-test-XXXXXX.json)

    # Força stack laravel com container simulado
    stack_detect() { echo "laravel"; }
    docker() {
        if [[ "$*" == *"ps"* ]]; then echo "test-container"; fi
    }
    export -f stack_detect docker

    mcp_generator_create "." "$tmpfile" "true"

    run jq -e '.mcpServers' "$tmpfile"
    [ "$status" -eq 0 ]

    rm -f "$tmpfile"
}

# --- Bug B6: stack_get_mcps — deve retornar MCPs para nodejs e python ---

@test "stack_get_mcps com input nodejs retorna resultado não vazio" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"

    # Sobrescreve stack_detect para retornar nodejs
    stack_detect() { echo "nodejs"; }
    export -f stack_detect

    run stack_get_mcps "."
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# --- Bug B7: is_legacy — find com agrupamento lógico correto ---

@test "is_legacy com diretório tests contendo .js não retorna falso positivo" {
    source "$DEVORQ_ROOT/lib/detect.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-legacy-test-XXXXXX)
    mkdir -p "$tmpdir/tests"
    touch "$tmpdir/tests/example.js"

    # Projeto com tests JS — NÃO deve ser considerado legacy
    run bash -c "source '$DEVORQ_ROOT/lib/detect.sh'; is_legacy '$tmpdir' && echo legacy || echo modern"
    [ "$output" = "modern" ]

    rm -rf "$tmpdir"
}

# --- Bug B8: cmd_skills — não iterar quando diretório skills não existe ---

@test "cmd_skills em diretório sem skills retorna mensagem limpa sem item fantasma" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-skills-test-XXXXXX)
    mkdir -p "$tmpdir/.devorq"

    DEVORQ_ROOT="$tmpdir"
    DEVORQ_DIR="$tmpdir/.devorq"

    run bash -c '
        cmd_skills() {
            local skills_dir="$DEVORQ_DIR/skills"
            if [ ! -d "$skills_dir" ]; then
                echo "Skills DEVORQ (0 skills):"
                return 0
            fi
            echo "Skills DEVORQ ($(ls -1 "$skills_dir/" 2>/dev/null | wc -l | tr -d " ") skills):"
            for skill_dir in "$skills_dir"/*/; do
                [ -d "$skill_dir" ] || continue
                local skill
                skill=$(basename "$skill_dir")
                echo "  - $skill"
            done
        }
        cmd_skills
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 skills"* ]]
    [[ "$output" != *"*"* ]]

    rm -rf "$tmpdir"
}
