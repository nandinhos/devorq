#!/bin/bash
# workflow-commit.sh - Workflow automatizado de commit DEVORQ
# Uso: aidev commit "mensagem" [tipo]
# Uso: aidev cp "mensagem"  (commit + push)
[[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIDEV_ROOT="${AIDEV_ROOT:-$(cd "$_SCRIPT_DIR/.." && pwd)}"

# Detectar diretório do projeto
if [[ "$AIDEV_ROOT" == *".devorq" ]]; then
    PROJECT_ROOT="$(dirname "$AIDEV_ROOT")"
    cd "$PROJECT_ROOT"
else
    PROJECT_ROOT="$AIDEV_ROOT"
fi

source "$AIDEV_ROOT/lib/activation-snapshot.sh"
source "$AIDEV_ROOT/lib/workflow-sync.sh"

# ============================================================================
# DETECTA TIPO DE COMMIT (CATEGORIA)
# ============================================================================
detect_commit_type() {
    local message="$1"
    local message_lower=$(echo "$message" | tr '[:upper:]' '[:lower:]')
    
    # Mapeamento para Português (Padrão DEVORQ)
    if [[ "$message_lower" == *"corrige"* ]] || [[ "$message_lower" == *"bug"* ]] || [[ "$message_lower" == *"fix"* ]] || [[ "$message_lower" == *"débito"* ]]; then
        echo "Qualidade"
    elif [[ "$message_lower" == *"adiciona"* ]] || [[ "$message_lower" == *"nova"* ]] || [[ "$message_lower" == *"feature"* ]] || [[ "$message_lower" == *"feat"* ]]; then
        echo "Funcionalidade"
    elif [[ "$message_lower" == *"document"* ]] || [[ "$message_lower" == *"readme"* ]] || [[ "$message_lower" == *"docs"* ]]; then
        echo "Documentação"
    elif [[ "$message_lower" == *"refatora"* ]] || [[ "$message_lower" == *"refactor"* ]]; then
        echo "Refatoração"
    elif [[ "$message_lower" == *"test"* ]] || [[ "$message_lower" == *"bats"* ]]; then
        echo "Testes"
    elif [[ "$message_lower" == *"mcp"* ]]; then
        echo "MCP"
    elif [[ "$message_lower" == *"skill"* ]]; then
        echo "Skills"
    elif [[ "$message_lower" == *"norma"* ]] || [[ "$message_lower" == *"regra"* ]] || [[ "$message_lower" == *"governança"* ]]; then
        echo "Governança"
    else
        echo "Manutenção"
    fi
}

# ============================================================================
# DETECTA ESCOPO BASEADO EM ARQUIVOS ALTERADOS
# ============================================================================
detect_scope() {
    local files=$(git diff --name-only --cached 2>/dev/null || git diff --name-only 2>/dev/null)
    
    if [ -z "$files" ]; then
        echo "Geral"
        return
    fi
    
    # Detectar por padrões de arquivo
    if echo "$files" | grep -q "bin/"; then
        echo "CLI"
    elif echo "$files" | grep -q "lib/detect\|lib/detection"; then
        echo "Detecção"
    elif echo "$files" | grep -q "lib/"; then
        echo "Biblioteca"
    elif echo "$files" | grep -q "\.md$"; then
        echo "Documentação"
    elif echo "$files" | grep -q "test"; then
        echo "Testes"
    elif echo "$files" | grep -q "\.devorq/skills"; then
        echo "Skills"
    elif echo "$files" | grep -q "docs/specs"; then
        echo "Especificação"
    elif echo "$files" | grep -q "package\.json\|cargo\.toml\|requirements"; then
        echo "Dependências"
    else
        # Usar primeiro diretório capitalizado
        local first_file=$(echo "$files" | head -1)
        local scope=$(dirname "$first_file" | cut -d/ -f1)
        if [[ "$scope" == "." ]]; then
            echo "Raiz"
        else
            echo "${scope^}" # Capitalize first letter
        fi
    fi
}

# ============================================================================
# HIGIENIZA MENSAGEM (REMOVE EMOJIS E CO-AUTORIA)
# ============================================================================
sanitize_message() {
    local input="$1"
    # Remover emojis comuns (range básico) e caracteres especiais de status
    local clean=$(echo "$input" | tr -d '✅✓📦🚀💡⚠️⚡🛠️✨📝🔍🧪')
    # Remover linhas de Co-Authored-By
    clean=$(echo "$clean" | grep -v "Co-Authored-By")
    echo "$clean"
}

# ============================================================================
# EXECUTA COMMIT
# ============================================================================
cmd_commit() {
    local raw_message="$1"
    local force_type="$2"
    
    if [ -z "$raw_message" ]; then
        echo "Erro: Mensagem obrigatória"
        echo "Uso: aidev commit \"mensagem\" [tipo]"
        return 1
    fi
    
    echo "=== Workflow Commit DEVORQ ==="
    
    # Verificar se há alterações
    if [ -z "$(git status --porcelain)" ]; then
        echo "Nenhuma alteração para commit"
        return 1
    fi
    
    # Higienizar mensagem
    local message=$(sanitize_message "$raw_message")
    
    # Detectar componentes do padrão: Escopo (Fase): Descrição
    local category="${force_type:-$(detect_commit_type "$message")}"
    local scope=$(detect_scope)
    local fase="Fase 1" # Default para transição, pode ser expandido
    
    # Formatar mensagem no padrão canônico
    local formatted_msg="$category ($fase): $message"
    
    # Se o escopo detectado for diferente da categoria, podemos incluir no corpo ou como prefixo
    # No padrão solicitado: "Escopo (Fase): Descrição"
    # Vamos usar o 'scope' detectado como o 'Escopo' do título.
    formatted_msg="$scope ($fase): $message"
    
    echo "Categoria: $category"
    echo "Escopo: $scope"
    echo "Mensagem: $formatted_msg"
    
    # Stage all
    echo ""
    echo "Adicionando arquivos..."
    git add -A
    
    # Commit
    echo "Executando commit..."
    # Usamos --no-verify para evitar hooks que possam inserir co-autoria indesejada se existirem
    if git commit -m "$formatted_msg"; then
        echo "✓ Commit realizado: $(git rev-parse --short HEAD)"
        
        # Sincronizar snapshot após commit
        echo ""
        echo "Sincronizando snapshot..."
        generate_activation_snapshot 2>/dev/null || true
        
        echo "=== Commit concluído ==="
        return 0
    else
        echo "❌ Erro ao executar commit"
        return 1
    fi
}

# ============================================================================
# EXECUTA COMMIT + PUSH
# ============================================================================
cmd_commit_push() {
    local message="$1"
    local force_type="$2"
    
    echo "=== Workflow Commit + Push ==="
    
    # Executar commit primeiro
    cmd_commit "$message" "$force_type" || return 1
    
    echo ""
    echo "Executando push..."
    if git push; then
        echo "✓ Push realizado"
    else
        echo "❌ Erro ao fazer push"
        return 1
    fi
    
    echo "=== Commit + Push concluído ==="
    return 0
}

# ============================================================================
# VERIFICA STATUS PRÉ-COMMIT
# ============================================================================
cmd_status() {
    echo "=== Status Pré-Commit ==="
    
    local status=$(git status --porcelain 2>/dev/null)
    
    if [ -z "$status" ]; then
        echo "✓ Working tree limpo"
        return 0
    fi
    
    echo "Alterações detectadas:"
    echo "$status"
    echo ""
    
    # Suggestion
    local msg_hint="ajustes gerais"
    echo "💡 Sugestão de Formato: $(detect_scope) (Fase 1): $msg_hint"
    
    return 0
}
