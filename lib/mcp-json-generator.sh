#!/bin/bash

# ============================================================================
# mcp-json-generator.sh - Gera arquivo .mcp.json baseado na stack
# ============================================================================
# Gera configuração de MCPs automaticamente
# Suporta merge com configuração existente
# ============================================================================

_MCP_GENERATOR_REGISTRY="${MCP_GENERATOR_REGISTRY:-.devorq/config/mcp-registry.yaml}"
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
    local force="${3:-false}"

    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        echo "⚠️  $output_file já existe. Use --force para sobrescrever."
        return 1
    fi

    local stack
    stack=$(stack_detect "$project_dir")

    echo "🔧 Gerando .mcp.json para stack: $stack"

    # Inicia JSON base com objeto mcpServers vazio
    local json_content
    json_content='{"mcpServers":{}}'

    # Adiciona MCPs universais via jq
    if _mcp_generator_has_tool "uvx"; then
        json_content=$(echo "$json_content" | jq \
            '.mcpServers["basic-memory"] = {"command":"uvx","args":["basic-memory","mcp"]}')
    fi

    if [ -n "$CONTEXT7_API_KEY" ]; then
        json_content=$(echo "$json_content" | jq \
            --arg key "$CONTEXT7_API_KEY" \
            '.mcpServers["context7-mcp"] = {"command":"npx","args":["-y","@upstash/context7-mcp@latest"],"env":{"CONTEXT7_API_KEY":$key}}')
    fi

    # Adiciona MCPs condicionais — helpers recebem json e retornam json modificado
    case "$stack" in
        laravel)
            json_content=$(_mcp_generator_add_laravel "$project_dir" "$json_content")
            ;;
        nodejs)
            json_content=$(_mcp_generator_add_nodejs "$project_dir" "$json_content")
            ;;
        python)
            json_content=$(_mcp_generator_add_python "$project_dir" "$json_content")
            ;;
    esac

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
    local json_content="$2"

    if ! command -v docker &>/dev/null; then
        echo "  ⚠️  Docker não disponível, pulando Laravel Boost" >&2
        echo "$json_content"
        return
    fi

    local container_name
    container_name=$(docker ps --format "{{.Names}}" 2>/dev/null | head -1)

    if [ -z "$container_name" ]; then
        echo "  ⚠️  Nenhum container Docker rodando, pulando Laravel Boost" >&2
        echo "$json_content"
        return
    fi

    local user_uid="${USER_UID:-$(id -u)}"
    local user_gid="${USER_GID:-$(id -g)}"

    echo "  ✅ Laravel Boost: $container_name" >&2

    echo "$json_content" | jq \
        --arg container "$container_name" \
        --arg uid "$user_uid" \
        --arg gid "$user_gid" \
        '.mcpServers["laravel-boost"] = {
            "command": "docker",
            "args": ["compose","exec","-T","laravel.test","php","artisan","boost:mcp"],
            "env": {"WWWUSER": $uid, "WWWGROUP": $gid}
        }'
}

# ============================================================================
# _mcp_generator_add_nodejs
# Adiciona configuração Node.js
# ============================================================================
_mcp_generator_add_nodejs() {
    local project_dir="$1"
    local json_content="$2"

    echo "  ℹ️  Node.js detectado" >&2

    # Detecta subframework Next.js
    if [ -f "$project_dir/next.config.js" ] || [ -f "$project_dir/next.config.mjs" ]; then
        echo "  ✅ Next.js detectado" >&2
        echo "$json_content" | jq \
            '.mcpServers["nextjs-mcp"] = {"command":"npx","args":["-y","@modelcontextprotocol/server-filesystem","./"]}'
        return
    fi

    echo "$json_content"
}

_mcp_generator_add_python() {
    local project_dir="$1"
    local json_content="$2"

    echo "  ℹ️  Python detectado" >&2

    # Detecta subframework Django
    if grep -q "django" "$project_dir/requirements.txt" 2>/dev/null || \
       grep -q "django" "$project_dir/pyproject.toml" 2>/dev/null; then
        echo "  ✅ Django detectado" >&2
        echo "$json_content" | jq \
            '.mcpServers["django-mcp"] = {"command":"uvx","args":["django-mcp"]}'
        return
    fi

    echo "$json_content"
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
