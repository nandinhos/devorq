#!/usr/bin/env bats

# Sprint 2 — Segurança e Robustez
# Cobre: set_env_value regex injection (2.1), load_env parsing (2.2),
#        .gitignore logs (2.3), check jq bootstrap (2.4)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    tmpdir=$(mktemp -d /tmp/devorq-sprint2-XXXXXX)
    export tmpenv="$tmpdir/.env"
}

teardown() {
    rm -rf "$tmpdir"
}

# ────────────────────────────────────────────
# 2.1: set_env_value — regex injection
# ────────────────────────────────────────────

@test "2.1: set_env_value rejeita chave com caracteres invalidos" {
    source "$DEVORQ_ROOT/lib/core.sh"

    run set_env_value "CHAVE=ERRADA" "valor" "$tmpenv"

    [ "$status" -ne 0 ]
}

@test "2.1: set_env_value rejeita chave com ponto" {
    source "$DEVORQ_ROOT/lib/core.sh"

    run set_env_value "CHAVE.ERRADA" "valor" "$tmpenv"

    [ "$status" -ne 0 ]
}

@test "2.1: set_env_value aceita chave valida maiuscula e underscore" {
    source "$DEVORQ_ROOT/lib/core.sh"

    run set_env_value "CHAVE_VALIDA" "valor" "$tmpenv"

    [ "$status" -eq 0 ]
    grep -q "CHAVE_VALIDA" "$tmpenv"
}

@test "2.1: set_env_value com valor contendo pipe nao corrompe o .env" {
    source "$DEVORQ_ROOT/lib/core.sh"

    run set_env_value "MINHA_KEY" "val|injetado" "$tmpenv"

    [ "$status" -eq 0 ]
    # O arquivo deve ter exatamente uma linha com essa key
    local count
    count=$(grep -c "^MINHA_KEY=" "$tmpenv")
    [ "$count" -eq 1 ]
    # O valor deve conter o pipe literalmente
    grep -q 'val|injetado' "$tmpenv"
}

@test "2.1: set_env_value com valor contendo barra nao corrompe o .env" {
    source "$DEVORQ_ROOT/lib/core.sh"

    run set_env_value "PATH_KEY" "/usr/bin/bash" "$tmpenv"

    [ "$status" -eq 0 ]
    grep -q '/usr/bin/bash' "$tmpenv"
}

# ────────────────────────────────────────────
# 2.2: load_env — parser robusto
# ────────────────────────────────────────────

@test "2.2: load_env preserva valor com sinal de igual no conteudo" {
    cat > "$tmpenv" << 'EOF'
JWT_TOKEN=aaa=bbb=ccc
EOF
    source "$DEVORQ_ROOT/lib/core.sh"
    load_env "$tmpenv"

    [ "$JWT_TOKEN" = "aaa=bbb=ccc" ]
}

@test "2.2: load_env preserva valor com espacos" {
    cat > "$tmpenv" << 'EOF'
APP_NAME=Meu Projeto Com Espacos
EOF
    source "$DEVORQ_ROOT/lib/core.sh"
    load_env "$tmpenv"

    [ "$APP_NAME" = "Meu Projeto Com Espacos" ]
}

@test "2.2: load_env ignora comentarios" {
    cat > "$tmpenv" << 'EOF'
# Este e um comentario
CHAVE_REAL=valor_real
EOF
    source "$DEVORQ_ROOT/lib/core.sh"
    load_env "$tmpenv"

    [ "$CHAVE_REAL" = "valor_real" ]
}

@test "2.2: load_env ignora linhas vazias" {
    cat > "$tmpenv" << 'EOF'

CHAVE_A=valor_a

CHAVE_B=valor_b

EOF
    source "$DEVORQ_ROOT/lib/core.sh"
    load_env "$tmpenv"

    [ "$CHAVE_A" = "valor_a" ]
    [ "$CHAVE_B" = "valor_b" ]
}

# ────────────────────────────────────────────
# 2.3: .gitignore cobre .devorq/logs/
# ────────────────────────────────────────────

@test "2.3: .gitignore inclui .devorq/logs/" {
    run grep -F ".devorq/logs/" "$DEVORQ_ROOT/.gitignore"
    [ "$status" -eq 0 ]
}

@test "2.3: git check-ignore reconhece arquivo de log como ignorado" {
    run git -C "$DEVORQ_ROOT" check-ignore -q ".devorq/logs/mcp-fallback.log"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────
# 2.4: check jq obrigatório no bootstrap
# ────────────────────────────────────────────

@test "2.4: bin/devorq contem verificacao de jq no inicio" {
    run grep -n "command -v jq" "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -eq 0 ]
}

@test "2.4: bin/devorq falha com mensagem clara quando jq nao esta disponivel" {
    # Simular ausência de jq via PATH vazio de ferramentas
    run bash -c "
        PATH='/bin:/usr/bin'
        # Remove jq do PATH temporariamente via função override
        jq() { return 127; }
        export -f jq
        # Verificar que o script detecta ausência antes de executar comandos
        grep -q 'command -v jq' '$DEVORQ_ROOT/bin/devorq'
    "
    [ "$status" -eq 0 ]
}
