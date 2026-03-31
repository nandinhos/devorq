#!/bin/bash

# ============================================================================
# stack-detector.sh - Detecção automática de stack do projeto
# ============================================================================
# Detecta qual stack o projeto utiliza (Laravel, Node, Python, etc)
# Usado para ativar MCPs condicionais automaticamente
# ============================================================================

_STACK_DETECTOR_REGISTRY="${_STACK_DETECTOR_REGISTRY:-.aidev/config/mcp-registry.yaml}"

# ============================================================================
# stack_detect
# Detecta a stack principal do projeto
# Retorna: laravel, nodejs, python, rust, go, php, generic
# ============================================================================
stack_detect() {
    local project_dir="${1:-.}"
    local detected="generic"
    
    # Laravel (verifica primeiro - mais específico)
    if _stack_check_laravel "$project_dir"; then
        detected="laravel"
    # Node.js
    elif [ -f "$project_dir/package.json" ]; then
        detected="nodejs"
    # Python
    elif [ -f "$project_dir/requirements.txt" ] || [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/poetry.lock" ]; then
        detected="python"
    # Rust
    elif [ -f "$project_dir/Cargo.toml" ]; then
        detected="rust"
    # Go
    elif [ -f "$project_dir/go.mod" ]; then
        detected="go"
    # PHP genérico (sem framework)
    elif [ -f "$project_dir/composer.json" ]; then
        detected="php"
    fi
    
    echo "$detected"
}

# ============================================================================
# _stack_check_laravel
# Verifica se é um projeto Laravel
# ============================================================================
_stack_check_laravel() {
    local project_dir="$1"
    
    # Verifica composer.json com Laravel
    if [ -f "$project_dir/composer.json" ]; then
        if grep -q "laravel/framework" "$project_dir/composer.json" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Verifica arquivo artisan
    if [ -f "$project_dir/artisan" ]; then
        return 0
    fi
    
    return 1
}

# ============================================================================
# stack_detect_all
# Detecta todas as stacks presentes no projeto (retorna array)
# ============================================================================
stack_detect_all() {
    local project_dir="${1:-.}"
    local stacks=()
    
    # Verifica cada stack possível
    if _stack_check_laravel "$project_dir"; then
        stacks+=("laravel")
    fi
    
    if [ -f "$project_dir/package.json" ]; then
        stacks+=("nodejs")
        
        # Verifica frameworks específicos de Node
        if [ -f "$project_dir/next.config.js" ] || [ -f "$project_dir/next.config.mjs" ]; then
            stacks+=("nextjs")
        fi
        if [ -f "$project_dir/nuxt.config.ts" ] || [ -f "$project_dir/nuxt.config.js" ]; then
            stacks+=("nuxt")
        fi
    fi
    
    if [ -f "$project_dir/requirements.txt" ] || [ -f "$project_dir/pyproject.toml" ]; then
        stacks+=("python")
        
        # Verifica frameworks Python
        if grep -q "django" "$project_dir/requirements.txt" 2>/dev/null; then
            stacks+=("django")
        fi
        if grep -q "flask" "$project_dir/requirements.txt" 2>/dev/null; then
            stacks+=("flask")
        fi
    fi
    
    if [ -f "$project_dir/Cargo.toml" ]; then
        stacks+=("rust")
    fi
    
    if [ -f "$project_dir/go.mod" ]; then
        stacks+=("go")
    fi
    
    if [ -f "$project_dir/composer.json" ]; then
        if ! _stack_check_laravel "$project_dir"; then
            stacks+=("php")
        fi
    fi
    
    # Retorna como string separada por vírgula
    if [ ${#stacks[@]} -eq 0 ]; then
        echo "generic"
    else
        echo "${stacks[*]}"
    fi
}

# ============================================================================
# stack_get_mcps
# Retorna lista de MCPs condicionais para a stack detectada
# ============================================================================
stack_get_mcps() {
    local project_dir="${1:-.}"
    local stack
    stack=$(stack_detect "$project_dir")
    local mcps=()
    
    case "$stack" in
        laravel)
            mcps+=("laravel-boost")
            ;;
        django)
            mcps+=("django-mcp")
            ;;
        nextjs)
            mcps+=("nextjs-mcp")
            ;;
        # Adicionar mais conforme necessário
    esac
    
    if [ ${#mcps[@]} -eq 0 ]; then
        echo ""
    else
        echo "${mcps[*]}"
    fi
}

# ============================================================================
# stack_show
# Exibe informações sobre a stack detectada
# ============================================================================
stack_show() {
    local project_dir="${1:-.}"
    
    echo "🔍 Detectando stack do projeto..."
    echo ""
    
    local stack
    stack=$(stack_detect "$project_dir")
    echo "  Stack principal: $stack"
    
    local all_stacks
    all_stacks=$(stack_detect_all "$project_dir")
    echo "  Stacks detectadas: $all_stacks"
    
    local mcps
    mcps=$(stack_get_mcps "$project_dir")
    if [ -n "$mcps" ]; then
        echo "  MCPs condicionais: $mcps"
    else
        echo "  MCPs condicionais: nenhum"
    fi
    
    # Docker check para Laravel
    if [ "$stack" = "laravel" ]; then
        echo ""
        echo "  Docker:"
        if command -v docker &>/dev/null; then
            local container_count
            container_count=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
            if [ "$container_count" -gt 0 ]; then
                echo "    ✅ $container_count container(s) rodando"
                docker ps --format "    - {{.Names}} ({{.Image}})" 2>/dev/null | head -5
            else
                echo "    ⚠️  Nenhum container rodando"
            fi
        else
            echo "    ❌ Docker não disponível"
        fi
    fi
}

# ============================================================================
# stack_to_json
# Retorna JSON com informações da stack
# ============================================================================
stack_to_json() {
    local project_dir="${1:-.}"
    
    local stack
    stack=$(stack_detect "$project_dir")
    
    local all_stacks
    all_stacks=$(stack_detect_all "$project_dir")
    
    local mcps
    mcps=$(stack_get_mcps "$project_dir")
    
    # Converte espaços para vírgulas
    all_stacks=$(echo "$all_stacks" | tr ' ' ',')
    mcps=$(echo "$mcps" | tr ' ' ',')
    
    jq -n \
        --arg stack "$stack" \
        --arg stacks "$all_stacks" \
        --arg mcps "$mcps" \
        '{
            primary: $stack,
            detected: ($stacks | split(",")),
            conditional_mcps: ($mcps | split(",") | map(select(length > 0)))
        }'
}

# Export for external use
export -f stack_detect
export -f stack_detect_all
export -f stack_get_mcps
export -f stack_show
export -f stack_to_json
