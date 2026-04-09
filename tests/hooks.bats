#!/usr/bin/env bats

# Testes funcionais: prepare-commit-msg hook
# Valida higiene de mensagens de commit (proibe emojis e Co-Authored-By)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_PATH="$DEVORQ_ROOT/.git/hooks/prepare-commit-msg"

setup() {
    # Criar arquivo temporário para mensagem de commit
    TMP_MSG=$(mktemp /tmp/commit-msg-XXXXXX)
    export TMP_MSG
}

teardown() {
    rm -f "$TMP_MSG"
}

# ============================================
# RED PHASE - Testes que devem falhar inicialmente
# ============================================

@test "Hook bloqueia commit com emoji 🚀" {
    echo "Funcionalidade: Adicionar novo recurso 🚀" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Emoji"* ]]
}

@test "Hook bloqueia commit com emoji ✅" {
    echo "Testes: Corrigir bug ✅" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
}

@test "Hook bloqueia commit com emoji 🤖" {
    echo "Auto: Atualizar dependências 🤖" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
}

@test "Hook bloqueia commit com Co-Authored-By" {
    cat > "$TMP_MSG" << 'EOF'
Funcionalidade: Adicionar nova feature

Co-Authored-By: Claude <claude@anthropic.com>
EOF
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
    [[ "$output" == *"Co-Authored-By"* ]]
}

@test "Hook permite commit sem emoji e sem co-autoria" {
    echo "Funcionalidade (Fase 1): Adicionar nova feature" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -eq 0 ]
}

@test "Hook permite commit template (merge) sem validacao" {
    echo "Merge branch 'main' into feature" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "merge" 2>&1
    [ "$status" -eq 0 ]
}

@test "Hook permite commit de template sem validacao" {
    echo "Padrão de commit" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "template" 2>&1
    [ "$status" -eq 0 ]
}

@test "Hook bloqueia múltiplos emojis na mesma mensagem" {
    echo "🚀 Funcionalidade: Adicionar ✨ feature nova 🎉" > "$TMP_MSG"
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
}

@test "Hook bloqueia Co-Authored-By em caixa baixa" {
    cat > "$TMP_MSG" << 'EOF'
Documentação: Atualizar README

co-authored-by: Claude <claude@anthropic.com>
EOF
    run bash "$HOOK_PATH" "$TMP_MSG" "" 2>&1
    [ "$status" -ne 0 ]
}
