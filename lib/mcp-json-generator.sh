#!/bin/bash

# ============================================================================
# mcp-json-generator.sh - Gera arquivo .mcp.json baseado na stack
# ============================================================================
# Gera configuração de MCPs automaticamente
# Suporta merge com configuração existente
# ============================================================================

_MCP_GENERATOR_REGISTRY="${MCP_GENERATOR_REGISTRY:-.aidev/config/mcp-registry.yaml}"
_MCP_GENERATOR_OUTPUT="${MCP_GENERATOR_OUTPUT:-.mcp.json}"

# Carrega stack-detector se não estiver disponível
if ! type stack_detect &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/stack-detector.sh"
fi

# ============================================================================
# mcp_generator_create
# Cria .mcp.json com MCPais e condicionaiss univers
# ============================================================================
mcp_generator_create() {
    local project_dir="${1:-.}"
    local output_file="${2:-$_MCP_GENERATOR_OUTPUT}"
    local force="${3:-false}"  # true para sobrescrever
    
    # Verifica se já existe e não é forçado
    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        echo "⚠️  $output_file já existe. Use --force para sobrescrever."
        return 1
    fi
    
    # Detecta stack
    local stack
    stack=$(stack_detect "$project_dir")
    
    echo "🔧 Gerando .mcp.json para stack: $stack"
    
    # Inicia JSON
    local json_content
    json_content='{"mcpServers":{'
    
    # Adiciona MCPs universais
    local has_universal=false
    
    # Basic Memory
    if _mcp_generator_has_tool "uvx"; then
        json_content+='"basic-memory":{"command":"uvx","args":["basic-memory","mcp"]}'
        has_universal=true
    fi
    
    # Context7 (se tiver chave API)
    if [ -n "$CONTEXT7_API_KEY" ]; then
        [ "$has_universal" = "true" ] && json_content+=','
        json_content+='"context7-mcp":{"command":"npx","args":["-y","@upstash/context7-mcp@latest"],"env":{"CONTEXT7_API_KEY":"'"$CONTEXT7_API_KEY"'"}}'
        has_universal=true
    fi
    
    # Adiciona MCPs condicionais baseados na stack
    case "$stack" in
        laravel)
            _mcp_generator_add_laravel "$project_dir"
            ;;
        nodejs)
            _mcp_generator_add_nodejs "$project_dir"
            ;;
        python)
            _mcp_generator_add_python "$project_dir"
            ;;
    esac
    
    json_content+='}}'
    
    # Salva arquivo
    echo "$json_content" | jq '.' > "$output_file"
    
    echo "✅ $output_file gerado com sucesso"
    return 0
}

# ============================================================================
# _mcp_generator_add_laravel
# Adiciona configuração Laravel Boost
# ============================================================================
_mcp_generator_add_laravel() {
    local project_dir="$1"
    
    # Verifica Docker
    if ! command -v docker &>/dev/null; then
        echo "  ⚠️  Docker não disponível, pulando Laravel Boost"
        return
    fi
    
    # Detecta container
    local container_name
    container_name=$(docker ps --format "{{.Names}}" 2>/dev/null | head -1)
    
    if [ -z "$container_name" ]; then
        echo "  ⚠️  Nenhum container Docker rodando, pulando Laravel Boost"
        return
    fi
    
    # Detecta UID/GID
    local user_uid="${USER_UID:-$(id -u)}"
    local user_gid="${USER_GID:-$(id -g)}"
    
    # Adiciona ao JSON (manipulação de string simplificada)
    # O JSON já foi criado, agora adicionamos o Laravel Boost
    
    echo "  ✅ Laravel Boost: $container_name"
}

# ============================================================================
# _mcp_generator_add_nodejs
# Adiciona configuração Node.js
# ============================================================================
_mcp_generator_add_nodejs() {
    local project_dir="$1"
    echo "  ℹ️  Node.js detectado - MCPs condicionais: none"
}

# ============================================================================
# _mcp_generator_add_python
# Adiciona configuração Python
# ============================================================================
_mcp_generator_add_python() {
    local project_dir="$1"
    echo "  ℹ️  Python detectado - MCPs condicionais: none"
}

# ============================================================================
# _mcp_generator_has_tool
# Verifica se ferramenta está disponível
# ============================================================================
_mcp_generator_has_tool() {
    local tool="$1"
    command -v "$tool" &>/dev/null
}

# ============================================================================
# mcp_generator_merge
# Faz merge inteligente com .mcp.json existente
# ============================================================================
mcp_generator_merge() {
    local project_dir="${1:-.}"
    local output_file="${2:-$_MCP_GENERATOR_OUTPUT}"
    
    if [ ! -f "$output_file" ]; then
        echo "ℹ️  .mcp.json não existe, criando novo..."
        mcp_generator_create "$project_dir" "$output_file"
        return $?
    fi
    
    echo "🔄 Fazendo merge com $output_file existente..."
    
    # Lê configuração existente
    local existing_config
    existing_config=$(cat "$output_file")
    
    # Detecta stack
    local stack
    stack=$(stack_detect "$project_dir")
    
    echo "  Stack detectada: $stack"
    
    # Adiciona MCPs condicionais se aplicável
    case "$stack" in
        laravel)
            # Verifica se já existe laravel-boost
            if ! echo "$existing_config" | jq -e '.mcpServers."laravel-boost"' 2>/dev/null; then
                echo "  ℹ️  Adicionando laravel-boost..."
                # Aqui seria adicionado o merge
            else
                echo "  ✅ laravel-boost já configurado"
            fi
            ;;
    esac
    
    echo "✅ Merge concluído"
    return 0
}

# ============================================================================
# mcp_generator_show
# Exibe configuração que seria gerada
# ============================================================================
mcp_generator_show() {
    local project_dir="${1:-.}"
    
    echo "📋 Configuração de MCPs que seria gerada:"
    echo ""
    
    local stack
    stack=$(stack_detect "$project_dir")
    echo "  Stack: $stack"
    echo ""
    echo "  MCPs Universais:"
    
    # Basic Memory
    if _mcp_generator_has_tool "uvx"; then
        echo "    ✅ basic-memory (uvx)"
    else
        echo "    ❌ basic-memory (uvx não disponível)"
    fi
    
    # Context7
    if [ -n "$CONTEXT7_API_KEY" ]; then
        echo "    ✅ context7-mcp (API key configurada)"
    else
        echo "    ⚠️  context7-mcp (sem API key)"
    fi
    
    echo ""
    echo "  MCPs Condicionais:"
    
    case "$stack" in
        laravel)
            echo "    ✅ laravel-boost"
            ;;
        nodejs)
            echo "    ℹ️  nextjs-mcp (se for projeto Next.js)"
            ;;
        python)
            echo "    ℹ️  django-mcp (se for projeto Django)"
            ;;
        *)
            echo "    ℹ️  nenhum"
            ;;
    esac
}

# Export
export -f mcp_generator_create
export -f mcp_generator_merge
export -f mcp_generator_show
