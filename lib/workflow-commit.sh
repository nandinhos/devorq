#!/bin/bash
# workflow-commit.sh - Workflow automatizado de commit
# Uso: aidev commit "mensagem" [tipo]
# Uso: aidev cp "mensagem"  (commit + push)

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIDEV_ROOT="${AIDEV_ROOT:-$(cd "$_SCRIPT_DIR/.." && pwd)}"

# Detectar diretório do projeto
if [[ "$AIDEV_ROOT" == *".aidev" ]]; then
    PROJECT_ROOT="$(dirname "$AIDEV_ROOT")"
    cd "$PROJECT_ROOT"
else
    PROJECT_ROOT="$AIDEV_ROOT"
fi

source "$AIDEV_ROOT/lib/activation-snapshot.sh"
source "$AIDEV_ROOT/lib/workflow-sync.sh"

# ============================================================================
# DETECTA TIPO DE COMMIT AUTOMATICAMENTE
# ============================================================================
detect_commit_type() {
    local message="$1"
    local message_lower=$(echo "$message" | tr '[:upper:]' '[:lower:]')
    
    # Verificar padrões na mensagem
    if [[ "$message_lower" == *"corrige"* ]] || [[ "$message_lower" == *"bug"* ]] || [[ "$message_lower" == *"fix"* ]]; then
        echo "fix"
    elif [[ "$message_lower" == *"adiciona"* ]] || [[ "$message_lower" == *"nova"* ]] || [[ "$message_lower" == *"feature"* ]]; then
        echo "feat"
    elif [[ "$message_lower" == *"document"* ]] || [[ "$message_lower" == *"readme"* ]]; then
        echo "docs"
    elif [[ "$message_lower" == *"refatora"* ]] || [[ "$message_lower" == *"refactor"* ]]; then
        echo "refactor"
    elif [[ "$message_lower" == *"test"* ]]; then
        echo "test"
    else
        echo "chore"
    fi
}

# ============================================================================
# DETECTA ESCOPO BASEADO EM ARQUIVOS ALTERADOS
# ============================================================================
detect_scope() {
    local files=$(git diff --name-only --cached 2>/dev/null || git diff --name-only 2>/dev/null)
    
    if [ -z "$files" ]; then
        echo "general"
        return
    fi
    
    # Detectar por padrões de arquivo
    if echo "$files" | grep -q "bin/"; then
        echo "bin"
    elif echo "$files" | grep -q "lib/"; then
        echo "lib"
    elif echo "$files" | grep -q "\.md$"; then
        echo "docs"
    elif echo "$files" | grep -q "test"; then
        echo "tests"
    elif echo "$files" | grep -q "package\.json\|cargo\.toml\|requirements"; then
        echo "deps"
    else
        # Usar primeiro diretório
        local first_file=$(echo "$files" | head -1)
        local scope=$(dirname "$first_file" | tr '/' '-' | sed 's/^-//')
        echo "${scope:-general}"
    fi
}

# ============================================================================
# EXECUTA COMMIT
# ============================================================================
cmd_commit() {
    local message="$1"
    local force_type="$2"
    
    if [ -z "$message" ]; then
        echo "Erro: Mensagem obrigatória"
        echo "Uso: aidev commit \"mensagem\" [tipo]"
        return 1
    fi
    
    echo "=== Workflow Commit ==="
    
    # Verificar se há alterações (incluindo arquivos não rastreados)
    local has_changes=0
    if [ -n "$(git status --porcelain)" ]; then
        has_changes=1
    else
        has_changes=0
    fi
    
    if [ $has_changes -eq 0 ]; then
        echo "Nenhuma alteração para commit"
        return 1
    fi
    
    # Detectar tipo
    local commit_type="${force_type:-$(detect_commit_type "$message")}"
    local scope=$(detect_scope)
    
    # Formatar mensagem no padrão conventional commits
    local formatted_msg="$commit_type($scope): $message"
    
    echo "Tipo: $commit_type"
    echo "Escopo: $scope"
    echo "Mensagem: $formatted_msg"
    
    # Stage all
    echo ""
    echo "📦 Adicionando arquivos..."
    git add -A 2>/dev/null || git add .
    
    # Commit
    echo "💾 Executando commit..."
    if git commit -m "$formatted_msg"; then
        echo "✅ Commit realizado: $(git rev-parse --short HEAD)"
        
        # Sincronizar snapshot após commit
        echo ""
        echo "🔄 Sincronizando snapshot..."
        generate_activation_snapshot
        
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
    
    # Verificar auth
    echo ""
    echo "🔐 Verificando autenticação..."
    if ! command -v gh &>/dev/null; then
        echo "⚠️  gh CLI não encontrado, executando git push..."
        if git push; then
            echo "✅ Push realizado"
        else
            echo "❌ Erro ao fazer push"
            return 1
        fi
    else
        # Verificar status de auth
        if gh auth status &>/dev/null; then
            echo "✅ gh auth OK"
            echo "📤 Executando push..."
            if git push; then
                echo "✅ Push realizado"
            else
                echo "❌ Erro ao fazer push"
                return 1
            fi
        else
            echo "⚠️  gh não autenticado, tentando git push..."
            if git push; then
                echo "✅ Push realizado"
            else
                echo "❌ Erro ao fazer push"
                return 1
            fi
        fi
    fi
    
    # Sincronizar novamente após push
    echo ""
    echo "🔄 Sincronizando snapshot final..."
    generate_activation_snapshot
    
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
        echo "✅ Working tree limpo"
        return 0
    fi
    
    echo "Alterações detectadas:"
    echo "$status"
    echo ""
    
    # Contar por tipo
    local staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
    local modified=$(echo "$status" | grep "^.M" | wc -l)
    local untracked=$(echo "$status" | grep "^??" | wc -l)
    
    echo "Arquivos: $((staged + modified + untracked)) total"
    echo "  - Preparados: $staged"
    echo "  - Modificados: $modified"
    echo "  - Não rastreados: $untracked"
    
    # Suggestion
    echo ""
    local suggested_type=$(detect_commit_type "alteração")
    echo "💡 Tipo sugerido: $suggested_type"
    echo "💡 Escopo sugerido: $(detect_scope)"
    
    return 0
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    case "${1:-}" in
        commit|c)
            shift
            cmd_commit "$@"
            ;;
        push|cp)
            shift
            cmd_commit_push "$@"
            ;;
        status|s)
            cmd_status
            ;;
        *)
            echo "Workflow Commit - Uso:"
            echo "  $0 commit \"mensagem\"      - Executa commit"
            echo "  $0 push \"mensagem\"        - Commit + Push"
            echo "  $0 status                  - Verifica status"
            ;;
    esac
fi
