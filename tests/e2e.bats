#!/usr/bin/env bats

# DEVORQ - Suíte de Testes E2E
# Valida o funcionamento da CLI de ponta a ponta

setup() {
    # Definir diretório raiz do projeto (onde o código original está)
    DEVORQ_REAL_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    
    # Criar sandbox temporário para os testes
    TEST_SANDBOX=$(mktemp -d /tmp/devorq-e2e-XXXXXX)
    
    # Simular instalação do devorq no sandbox
    mkdir -p "$TEST_SANDBOX/bin" "$TEST_SANDBOX/lib"
    cp "$DEVORQ_REAL_ROOT/bin/devorq" "$TEST_SANDBOX/bin/"
    cp -r "$DEVORQ_REAL_ROOT/lib/"* "$TEST_SANDBOX/lib/"
    chmod +x "$TEST_SANDBOX/bin/devorq"
    
    # Definir DEVORQ_ROOT como o sandbox para os testes
    DEVORQ_ROOT="$TEST_SANDBOX"
    
    cd "$TEST_SANDBOX" || exit 1
}

teardown() {
    # Limpar sandbox
    rm -rf "$TEST_SANDBOX"
}

# --- Cenário 1: Inicialização ---

@test "E2E: 'devorq init' cria estrutura básica de diretórios e arquivos de estado" {
    run "$DEVORQ_ROOT/bin/devorq" init
    
    [ "$status" -eq 0 ]
    [ -d ".devorq" ]
    [ -d ".devorq/state" ]
    [ -f ".devorq/state/session.json" ]
}

# --- Cenário 2: Fluxo de Orquestração ---

@test "E2E: 'devorq flow' gera artefatos de brainstorm, contrato e spec em sequência" {
    # Inicializar primeiro
    "$DEVORQ_ROOT/bin/devorq" init >/dev/null
    
    # Executar flow
    run "$DEVORQ_ROOT/bin/devorq" flow "implementar autenticação jwt"
    
    [ "$status" -eq 0 ]
    
    # Verificar se as pastas de artefatos foram criadas
    [ -d ".devorq/state/brainstorms" ]
    [ -d ".devorq/state/contracts" ]
    [ -d ".devorq/state/specs" ]
    
    # Verificar se os arquivos existem (pelo menos um em cada)
    [ "$(ls -1 ".devorq/state/brainstorms/"br_*.md 2>/dev/null | wc -l)" -gt 0 ]
    [ "$(ls -1 ".devorq/state/contracts/"ct_*.md 2>/dev/null | wc -l)" -gt 0 ]
    [ "$(ls -1 ".devorq/state/specs/"sp_*.md 2>/dev/null | wc -l)" -gt 0 ]
}

# --- Cenário 3: Handoff ---

@test "E2E: 'devorq handoff generate' produz arquivo de handoff válido" {
    "$DEVORQ_ROOT/bin/devorq" init >/dev/null
    
    # Rodar sem run primeiro para depurar se houver falha de carregar comando
    echo "Rodando handoff generate..." >&2
    run "$DEVORQ_ROOT/bin/devorq" handoff generate
    
    echo "Status: $status" >&2
    echo "Output: $output" >&2
    
    [ "$status" -eq 0 ]
    [ "$(ls -1 ".devorq/state/handoffs/"handoff_*.md 2>/dev/null | wc -l)" -gt 0 ]
    
    # A saída deve conter o caminho do arquivo
    [[ "$output" == *".devorq/state/handoffs/handoff_"* ]]
}

# --- Cenário 4: Skills ---

@test "E2E: 'devorq skills' lista skills disponíveis quando o diretório existe" {
    # Simular diretório de skills
    mkdir -p ".devorq/skills/test-skill"
    touch ".devorq/skills/test-skill/SKILL.md"
    
    run "$DEVORQ_ROOT/bin/devorq" skills
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-skill"* ]]
}

# --- Cenário 5: Regressão e Proteção (Bug 127) ---

@test "E2E: Bibliotecas não podem ser executadas diretamente" {
    # Tentar executar core.sh diretamente via bash
    run bash "$DEVORQ_ROOT/lib/core.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERRO: Este módulo deve ser carregado via 'source', não executado"* ]]
}

@test "E2E: Carregamento de funções em subshells robusto (Bug 127)" {
    # Inicializar
    "$DEVORQ_ROOT/bin/devorq" init >/dev/null
    
    # Criar um script que faz source e chama funções em subshell
    cat <<EOF > test_subshell.sh
#!/bin/bash
source "$DEVORQ_ROOT/lib/core.sh"
# Chamar função em subshell
RESULT=\$(print_info "teste subshell" 2>&1)
echo "\$RESULT"
EOF
    chmod +x test_subshell.sh
    
    run ./test_subshell.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"teste subshell"* ]]
}
