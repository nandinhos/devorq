#!/bin/bash
# workflow-release.sh - Workflow completo de release
# Uso: aidev release [patch|minor|major]

AIDEV_ROOT="${AIDEV_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Detectar se AIDEV_ROOT aponta para .aidev ou para root
if [[ "$AIDEV_ROOT" == *".aidev" ]]; then
    PROJECT_ROOT="$(dirname "$AIDEV_ROOT")"
else
    PROJECT_ROOT="$AIDEV_ROOT"
fi
source "$AIDEV_ROOT/lib/activation-snapshot.sh"
source "$AIDEV_ROOT/lib/workflow-sync.sh"
source "$AIDEV_ROOT/lib/workflow-commit.sh"

# ============================================================================
# DETECTA VERSÃO ATUAL
# ============================================================================
get_current_version() {
    # Tentar ler de VERSION ou package.json
    if [ -f "$PROJECT_ROOT/VERSION" ]; then
        cat "$PROJECT_ROOT/VERSION"
    elif [ -f "$PROJECT_ROOT/package.json" ]; then
        jq -r '.version' "$PROJECT_ROOT/package.json" 2>/dev/null || echo "0.0.0"
    elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
        grep "^version" "$PROJECT_ROOT/pyproject.toml" | sed 's/version = "//' | sed 's/"//' | tr -d ' '
    else
        echo "0.0.0"
    fi
}

# ============================================================================
# INCREMENTA VERSÃO SEMVER
# ============================================================================
increment_version() {
    local current="$1"
    local type="${2:-patch}"
    
    # Parse versão (x.y.z)
    local major=$(echo "$current" | cut -d. -f1)
    local minor=$(echo "$current" | cut -d. -f2)
    local patch=$(echo "$current" | cut -d. -f3)
    
    case "$type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Tipo inválido: $type (use: patch, minor, major)"
            return 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# ============================================================================
# GERA CHANGELOG AUTOMÁTICO
# ============================================================================
generate_changelog() {
    local current_tag="$1"
    local new_version="$2"
    
    echo "=== Changelog $new_version ===" 
    echo ""
    
    # Commits desde a última tag
    local commits=$(git log --oneline "$current_tag"..HEAD 2>/dev/null || git log --oneline -20)
    
    if [ -z "$commits" ]; then
        echo "Nenhum commit desde $current_tag"
        return
    fi
    
    # Agrupar por tipo
    echo "## Mudanças"
    echo ""
    
    local feats=$(echo "$commits" | grep "^.*feat" | sed 's/^[^ ]* //')
    local fixes=$(echo "$commits" | grep "^.*fix" | sed 's/^[^ ]* //')
    local others=$(echo "$commits" | grep -v "^.*feat" | grep -v "^.*fix" | sed 's/^[^ ]* //')
    
    if [ -n "$feats" ]; then
        echo "### Features"
        echo "$feats" | sed 's/^/- /'
        echo ""
    fi
    
    if [ -n "$fixes" ]; then
        echo "### Bug Fixes"
        echo "$fixes" | sed 's/^/- /'
        echo ""
    fi
    
    if [ -n "$others" ]; then
        echo "### Other"
        echo "$others" | sed 's/^/- /'
        echo ""
    fi
}

# ============================================================================
# CRIA RELEASE NO GITHUB
# ============================================================================
create_github_release() {
    local version="$1"
    local changelog="$2"
    
    if ! command -v gh &>/dev/null; then
        echo "⚠️  gh CLI não disponível, pulando criação de release no GitHub"
        return 0
    fi
    
    # Verificar auth
    if ! gh auth status &>/dev/null; then
        echo "⚠️  gh não autenticado, pulando release no GitHub"
        return 0
    fi
    
    echo "📦 Criando GitHub Release v$version..."
    
    # Criar release
    local release_url
    release_url=$(gh release create "v$version" \
        --title "Release v$version" \
        --notes "$changelog" 2>&1) || {
        echo "⚠️  Release pode já existir ou erro: $release_url"
        return 1
    }
    
    echo "✅ GitHub Release criado: $release_url"
    return 0
}

# ============================================================================
# WORKFLOW RELEASE COMPLETO
# ============================================================================
cmd_release() {
    local release_type="${1:-patch}"
    
    echo "=== Workflow Release ($release_type) ==="
    echo ""
    
    # 1. Verificar se há alterações pendentes
    echo "1. Verificando alterações..."
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "⚠️  Há alterações não commitadas!"
        echo "   Execute 'aidev commit' primeiro ou use --force"
        read -p "Continuar mesmo assim? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Cancelado"
            return 1
        fi
    fi
    
    # 2. Obter versão atual
    echo "2. Obtendo versão atual..."
    local current_version=$(get_current_version)
    echo "   Versão atual: $current_version"
    
    # 3. Calcular nova versão
    echo "3. Calculando nova versão..."
    local new_version=$(increment_version "$current_version" "$release_type")
    echo "   Nova versão: $new_version"
    
    # 4. Gerar changelog
    echo "4. Gerando changelog..."
    local current_tag="v$current_version"
    local changelog=$(generate_changelog "$current_tag" "$new_version")
    echo "$changelog"
    
    # 5. Atualizar versão em arquivos
    echo "5. Atualizando versão..."
    if [ -f "$PROJECT_ROOT/VERSION" ]; then
        echo "$new_version" > "$PROJECT_ROOT/VERSION"
        git add "$PROJECT_ROOT/VERSION"
    fi
    
    # 6. Commit de release
    echo "6. Criando commit de release..."
    local commit_msg="release($release_type): bump versão para v$new_version"
    git add -A
    git commit -m "$commit_msg" || {
        echo "⚠️  Nada para commitar, forçando..."
    }
    echo "   ✅ Commit: $commit_msg"
    
    # 7. Criar tag
    echo "7. Criando tag v$new_version..."
    git tag -a "v$new_version" -m "Release v$new_version"
    echo "   ✅ Tag criada"
    
    # 8. Push
    echo "8. Enviando para remote..."
    if git push; then
        echo "   ✅ Push OK"
    else
        echo "   ⚠️  Push falhou, continuando..."
    fi
    
    # 9. Push tags
    if git push --tags; then
        echo "   ✅ Tags enviadas"
    else
        echo "   ⚠️  Push de tags falhou"
    fi
    
    # 10. GitHub Release
    echo "10. Criando GitHub Release..."
    create_github_release "$new_version" "$changelog"
    
    # 11. Sincronizar snapshot
    echo "11. Sincronizando snapshot..."
    generate_activation_snapshot
    
    echo ""
    echo "=== Release v$new_version CONCLUÍDO ==="
    echo ""
    echo "Resumo:"
    echo "  - Versão: $current_version → $new_version"
    echo "  - Tipo: $release_type"
    echo "  - Tag: v$new_version"
    echo "  - Branch: $(git branch --show-current)"
}

# ============================================================================
# VERIFICA PRÉ-RELEASE
# ============================================================================
cmd_pre_release_check() {
    echo "=== Pré-Release Check ==="
    
    # Verificar versão
    local version=$(get_current_version)
    echo "✅ Versão atual: $version"
    
    # Verificar tag
    local tag_exists=$(git tag -l "v$version" 2>/dev/null)
    if [ -n "$tag_exists" ]; then
        echo "⚠️  Tag v$version já existe"
    else
        echo "✅ Tag v$version não existe"
    fi
    
    # Verificar git status
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        echo "✅ Working tree limpo"
    else
        echo "⚠️  Há alterações pendentes"
    fi
    
    # Verificar gh
    if command -v gh &>/dev/null; then
        if gh auth status &>/dev/null; then
            echo "✅ gh autenticado"
        else
            echo "⚠️  gh não autenticado"
        fi
    else
        echo "⚠️  gh não disponível"
    fi
    
    # Próximos passos
    echo ""
    echo "Próximos passos:"
    echo "  aidev release patch   # patch release (x.y.z+1)"
    echo "  aidev release minor  # minor release (x.y+1.0)"
    echo "  aidev release major  # major release (x+1.0.0)"
}

# Executar se chamado diretamente
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    case "${1:-check}" in
        patch|minor|major)
            cmd_release "$1"
            ;;
        check|status)
            cmd_pre_release_check
            ;;
        *)
            echo "Workflow Release - Uso:"
            echo "  $0 patch   - Release patch (x.y.z+1)"
            echo "  $0 minor   - Release minor (x.y+1.0)"
            echo "  $0 major   - Release major (x+1.0.0)"
            echo "  $0 check   - Verificar status pré-release"
            ;;
    esac
fi
