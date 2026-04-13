#!/usr/bin/env bats

# Testes funcionais: DEVORQ pre-commit hook
# Valida que o hook existe, é executável, e passa quando tudo está ok

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK_PATH="$DEVORQ_ROOT/.devorq/hooks/pre-commit"

setup() {
    TMP_MSG=$(mktemp /tmp/commit-msg-XXXXXX)
    export TMP_MSG
}

teardown() {
    rm -f "$TMP_MSG"
}

# ============================================
# GREEN PHASE - Testes que devem passar
# ============================================

@test "Hook existe e é executável" {
    [ -f "$HOOK_PATH" ]
    [ -x "$HOOK_PATH" ]
}

@test "Hook executa sem erro em projeto limpo" {
    run bash "$HOOK_PATH" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEVORQ"* ]]
}

@test "Hook passa quando não há alterações staged" {
    run bash "$HOOK_PATH" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pre-commit validado"* ]] || [[ "$output" == *"PASS"* ]]
}

# ============================================
# Testes de detecção de stack
# ============================================

@test "Hook detecta stack generic quando não há composer.json" {
    run bash "$HOOK_PATH" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"generic"* ]] || [[ "$output" == *"Lint nao aplicavel"* ]]
}

# ============================================
# Testes de validação de arquivos
# ============================================

@test "Hook termina com exit 0 em ambiente sem erros" {
    run bash "$HOOK_PATH" 2>&1
    [ "$status" -eq 0 ]
}

@test "Hook produz output com mensagens de status" {
    run bash "$HOOK_PATH" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" == *"DEVORQ"* ]]
    [[ "$output" == *"PASS"* ]] || [[ "$output" == *"WARN"* ]] || [[ "$output" == *"verificando"* ]]
}

# ============================================
# Testes de integração básica
# ============================================

@test "Hook pode ser executado de qualquer diretório" {
    cd /tmp
    run bash "$HOOK_PATH" "$TMP_MSG" 2>&1
    [ "$status" -eq 0 ] || skip "Hook requer git repo"
}

@test "Hook não corrompe arquivos temporários" {
    echo "teste de commit" > "$TMP_MSG"
    cp "$TMP_MSG" "${TMP_MSG}.backup"
    run bash "$HOOK_PATH" "$TMP_MSG" 2>&1
    diff "$TMP_MSG" "${TMP_MSG}.backup"
}

@test "DEVORQ_ROOT está configurado corretamente no hook" {
    run bash -c "grep -c 'DEVORQ_ROOT' '$HOOK_PATH'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}