#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - MCP Module
# ============================================================================
# Model Context Protocol - Configuração de servidores MCP para AIs
# 
# Uso: source lib/mcp.sh
# Dependências: lib/core.sh, lib/file-ops.sh, lib/detection.sh, lib/templates.sh
# ============================================================================

# ============================================================================
source "${AIDEV_ROOT_DIR:-$(dirname $(dirname ${BASH_SOURCE[0]}))}/lib/templates.sh"

# ============================================================================
# Configuração de Servidores MCP
# ============================================================================

# Gera configuração MCP para Claude Code
# Uso: generate_mcp_config "claude-code" "/path/to/project"
generate_mcp_config() {
    local platform="$1"
    local project_path="${2:-.}"
    
    case "$platform" in
        "claude-code")
            generate_claude_mcp_config "$project_path"
            ;;
        "antigravity")
            # Gera ambos para máxima compatibilidade no ambiente Gemini
            generate_claude_mcp_config "$project_path"
            generate_antigravity_mcp_config "$project_path"
            ;;
        "gemini"|"opencode")
            generate_generic_mcp_config "$project_path" "$platform"
            ;;
        *)
            print_debug "MCP não suportado para: $platform"
            return 0
            ;;
    esac
}

# Extrai servidores MCP que nao fazem parte do template padrao
# Uso: custom=$(mcp_extract_custom_servers "/path/to/.mcp.json")
_mcp_extract_custom_servers() {
    local mcp_file="$1"
    [ ! -f "$mcp_file" ] && echo "{}" && return 0
    command -v jq >/dev/null 2>&1 || { echo "{}"; return 0; }
    local defaults_json='["context7","serena","basic-memory"]'
    jq --argjson defaults "$defaults_json" \
        '.mcpServers | to_entries | map(select(.key as $k | $defaults | index($k) | not)) | from_entries' \
        "$mcp_file" 2>/dev/null || echo "{}"
}

# Gera .mcp.json para Claude Code
generate_claude_mcp_config() {
    local project_path="$1"
    local mcp_file="$project_path/.mcp.json"

    # Detecta stack para personalização
    local stack
    stack=$(detect_stack "$project_path")

    local project_name
    project_name=$(detect_project_name "$project_path")

    # Captura servidores customizados ANTES de sobrescrever (protege em --force)
    local _custom_servers="{}"
    if [ -f "$mcp_file" ] && [ "${AIDEV_FORCE:-false}" = "true" ]; then
        _custom_servers=$(_mcp_extract_custom_servers "$mcp_file")
    fi

    if should_write_file "$mcp_file"; then
        # Normalização de path para portabilidade
        local display_path="$project_path"
        local abs_project_path=$(cd "$project_path" 2>/dev/null && pwd || echo "$project_path")
        local abs_pwd=$(pwd)
        if [ "$abs_project_path" = "$abs_pwd" ]; then
            display_path="."
        fi

        # Exporta variáveis para o template
        export CONTEXT7_API_KEY="${CONTEXT7_API_KEY:-}"
        export PROJECT_PATH="$display_path"
        export PROJECT_NAME="$project_name"
        export STACK="$stack"

        # Usa template se disponível, senão fallback para heredoc
        local template_file="$AIDEV_ROOT_DIR/templates/mcp/claude-code.json.tmpl"
        if [ -f "$template_file" ]; then
            process_template "$template_file" "$mcp_file"
        else
            # Fallback: gera diretamente
            local context7_key="${CONTEXT7_API_KEY:-}"
            cat > "$mcp_file" << EOF
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"],
      "env": {
        "CONTEXT7_API_KEY": "$context7_key"
      },
      "description": "Context7 server for documentation lookups"
    },
    "serena": {
      "command": "uvx",
      "args": ["serena", "--project=$display_path"],
      "description": "Serena server for intelligent code navigation"
    },
    "basic-memory": {
      "command": "uvx",
      "args": ["basic-memory", "mcp"],
      "description": "Persistent memory for cross-session knowledge"
    }
  },
  "projectConfig": {
    "name": "$project_name",
    "stack": "$stack",
    "version": "1.0.0"
  }
}
EOF
            increment_files
        fi
        print_success "Configuração MCP criada: $mcp_file"

        # Mescla servidores customizados de volta se havia customizacoes
        if [ "$_custom_servers" != "{}" ] && [ "$_custom_servers" != "null" ] && command -v jq >/dev/null 2>&1; then
            local _merged
            _merged=$(jq --argjson custom "$_custom_servers" '.mcpServers += $custom' "$mcp_file")
            if [ $? -eq 0 ] && [ -n "$_merged" ]; then
                echo "$_merged" > "$mcp_file"
                print_info "Servidores customizados preservados: $(echo "$_custom_servers" | jq -r 'keys | join(", ")')"
            fi
        fi
    fi
}

# Gera configuração MCP para Antigravity
generate_antigravity_mcp_config() {
    local project_path="$1"
    local config_dir="$project_path/.aidev/mcp"
    
    ensure_dir "$config_dir"
    
    local config_file="$config_dir/antigravity-config.json"
    
    local project_name
    project_name=$(detect_project_name "$project_path")
    
    local stack
    stack=$(detect_stack "$project_path")
    
    if should_write_file "$config_file"; then
        # Normalização de path para portabilidade
        local display_path="$project_path"
        if [ "$project_path" = "." ] || [ "$project_path" = "$(pwd)" ]; then
            display_path="."
        fi

        # Obtém API Key se disponível
        local context7_key="${CONTEXT7_API_KEY:-}"

        cat > "$config_file" << EOF
{
  "platform": "antigravity",
  "project": "$project_name",
  "stack": "$stack",
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server"],
      "description": "Analise semantica de codigo"
    },
    "basic-memory": {
      "command": "uvx",
      "args": ["basic-memory", "mcp"],
      "description": "Memoria persistente"
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"],
      "env": {
        "CONTEXT7_API_KEY": "$context7_key"
      },
      "description": "Documentacao de bibliotecas"
    }
  }
}
EOF
        increment_files
        print_success "Configuração MCP Antigravity: $config_file"
    fi
}

# Gera configuração genérica para outras plataformas
generate_generic_mcp_config() {
    local project_path="$1"
    local platform="$2"
    local config_dir="$project_path/.aidev/mcp"

    ensure_dir "$config_dir"

    local config_file="$config_dir/${platform}-config.json"

    if should_write_file "$config_file"; then
        # Normalização de path para portabilidade
        local display_path="$project_path"
        if [ "$project_path" = "." ] || [ "$project_path" = "$(pwd)" ]; then
            display_path="."
        fi

        local context7_key="${CONTEXT7_API_KEY:-}"
        cat > "$config_file" << EOF
{
  "platform": "$platform",
  "servers": {
    "context7": {
      "enabled": true,
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"],
      "env": {
        "CONTEXT7_API_KEY": "$context7_key"
      }
    },
    "serena": {
      "enabled": true,
      "command": "uvx",
      "args": ["serena", "--project=$display_path"]
    },
    "basic-memory": {
      "enabled": true,
      "command": "uvx",
      "args": ["basic-memory", "mcp"]
    }
  }
}
EOF
        increment_files
        print_success "Configuração MCP ($platform): $config_file"
    fi
}

# ============================================================================
# Servidores MCP Disponíveis
# ============================================================================

# Lista servidores MCP padrão
list_mcp_servers() {
    cat << 'EOF'
context7     - Documentação e exemplos de código
serena       - Navegação inteligente de código
filesystem   - Operações de sistema de arquivos
git          - Integração com Git
memory       - Memória persistente entre sessões
EOF
}

# Configura servidor MCP individual
configure_mcp_server() {
    local server_name="$1"
    local project_path="${2:-.}"
    local enabled="${3:-true}"
    
    local servers_file="$project_path/.aidev/mcp/servers.yaml"
    
    ensure_dir "$(dirname "$servers_file")"
    
    # Adiciona ou atualiza servidor
    if [ ! -f "$servers_file" ]; then
        echo "servers:" > "$servers_file"
    fi
    
    cat >> "$servers_file" << EOF
  $server_name:
    enabled: $enabled
    configured_at: $(date -Iseconds)
EOF
    
    print_info "Servidor MCP '$server_name' configurado"
}

# ============================================================================
# Validação MCP
# ============================================================================

# Verifica se MCP está configurado
has_mcp_config() {
    local project_path="${1:-.}"
    
    # Claude Code
    [ -f "$project_path/.mcp.json" ] && return 0
    
    # Gemini/outros
    [ -d "$project_path/.aidev/mcp" ] && return 0
    
    return 1
}

# Valida configuração MCP
validate_mcp_config() {
    local project_path="${1:-.}"
    local errors=0
    
    print_section "Verificando MCP"
    
    if [ -f "$project_path/.mcp.json" ]; then
        # Valida JSON
        if command -v jq &> /dev/null; then
            if jq . "$project_path/.mcp.json" > /dev/null 2>&1; then
                print_success ".mcp.json válido"
            else
                print_error ".mcp.json JSON inválido"
                ((errors++)) || true
            fi
        else
            print_info ".mcp.json existe (jq não disponível para validação)"
        fi
    else
        print_warning ".mcp.json não encontrado"
    fi
    
    return $errors
}

# ============================================================================
# MCP Engine Setup
# ============================================================================

# Configura MCP Engine completo
setup_mcp_engine() {
    local project_path="${1:-.}"
    local platform="${2:-auto}"
    
    # Auto-detecta plataforma se necessário
    if [ "$platform" = "auto" ]; then
        platform=$(detect_platform)
    fi
    
    print_step "Configurando MCP Engine para $platform..."
    
    # Gera config principal
    generate_mcp_config "$platform" "$project_path"
    
    # Cria estrutura de diretórios MCP
    ensure_dir "$project_path/.aidev/mcp/servers"
    ensure_dir "$project_path/.aidev/mcp/memory"
    
    # Gera arquivos auxiliares
    generate_mcp_readme "$project_path"
    
    print_success "MCP Engine configurado!"
}

# Gera README explicativo para MCP
generate_mcp_readme() {
    local project_path="$1"
    local readme_file="$project_path/.aidev/mcp/README.md"
    
    if should_write_file "$readme_file"; then
        cat > "$readme_file" << 'EOF'
# MCP - Model Context Protocol

Este diretório contém a configuração do MCP para este projeto.

## Servidores Configurados

### context7
Acesso a documentação e exemplos de código atualizados.

### serena
Navegação inteligente de código com análise semântica.

## Estrutura

```
mcp/
├── servers/     # Configs de servidores individuais
├── memory/      # Memória persistente
└── README.md    # Este arquivo
```

## Uso

Os servidores MCP são carregados automaticamente pelo AI quando você inicia uma sessão.

## Configuração

Edite `.mcp.json` na raiz do projeto para customizar servidores.
EOF
        increment_files
    fi
}

# ============================================================================
# Comandos de Gerenciamento
# ============================================================================

# Status do MCP
mcp_status() {
    local project_path="${1:-.}"
    
    print_section "Status do MCP"
    
    if has_mcp_config "$project_path"; then
        print_success "MCP configurado"
        
        if [ -f "$project_path/.mcp.json" ]; then
            echo "  Plataforma: Claude Code"
            echo "  Config: .mcp.json"
            
            if command -v jq &> /dev/null; then
                local servers
                servers=$(jq -r '.mcpServers | keys[]' "$project_path/.mcp.json" 2>/dev/null | tr '\n' ', ')
                echo "  Servidores: ${servers%,}"
            fi
        fi
    else
        print_warning "MCP não configurado"
        print_info "Use 'aidev init' ou 'aidev mcp setup' para configurar"
    fi
}

# Adiciona servidor ao MCP
# Adiciona servidor ao MCP
mcp_add_server() {
    local server_name="$1"
    local command="$2"
    local args="$3"
    local project_path="${4:-.}"
    
    if [ -z "$server_name" ] || [ -z "$command" ]; then
        print_error "Nome do servidor e comando são obrigatórios"
        print_info "Uso: aidev mcp add <nome> --command <cmd> [--args <args>]"
        return 1
    fi
    
    local mcp_file="$project_path/.mcp.json"
    
    if [ ! -f "$mcp_file" ]; then
        print_warning ".mcp.json não encontrado. Criando novo..."
        echo '{ "mcpServers": {} }' > "$mcp_file"
    fi
    
    print_step "Adicionando servidor '$server_name'..."
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file=$(mktemp)
        
        # Constrói o objeto do servidor
        # Tratamento básico de args como array JSON se possível, ou string simples splitada
        # Aqui assumimos que args vem como string única que será quebrada por espaços pelo jq se necessário
        # Mas para segurança, vamos tentar passar como array se o usuário fornecer JSON, senão string split
        
        local jq_script
        if [ -n "$args" ]; then
            # Se args parecer um array JSON (começa com [), usa raw, senão split por espaço
            if [[ "$args" == \[* ]]; then
                 jq --arg name "$server_name" \
                    --arg cmd "$command" \
                    --argjson args_arr "$args" \
                    '.mcpServers[$name] = { "command": $cmd, "args": $args_arr }' \
                    "$mcp_file" > "$tmp_file"
            else
                 # Split por espaço é arriscado para args com espaço, mas é o baseline bash
                 # Melhor abordagem: usuário passa args como string única e nós transformamos em array de 1 elemento ou split
                 # Vamos usar split(" ") simples para compatibilidade shell básica
                 jq --arg name "$server_name" \
                    --arg cmd "$command" \
                    --arg args_str "$args" \
                    '.mcpServers[$name] = { "command": $cmd, "args": ($args_str | split(" ")) }' \
                    "$mcp_file" > "$tmp_file"
            fi
        else
            jq --arg name "$server_name" \
               --arg cmd "$command" \
               '.mcpServers[$name] = { "command": $cmd, "args": [] }' \
               "$mcp_file" > "$tmp_file"
        fi
        
        if [ $? -eq 0 ]; then
            mv "$tmp_file" "$mcp_file"
            print_success "Servidor '$server_name' adicionado com sucesso!"
        else
            print_error "Falha ao atualizar .mcp.json"
            rm "$tmp_file"
            return 1
        fi
    else
        print_error "jq não encontrado. Instale jq para gerenciar MCP."
        return 1
    fi
}

# Remove servidor do MCP
mcp_remove_server() {
    local server_name="$1"
    local project_path="${2:-.}"
    
    if [ -z "$server_name" ]; then
        print_error "Nome do servidor é obrigatório"
        return 1
    fi
    
    local mcp_file="$project_path/.mcp.json"
    
    if [ ! -f "$mcp_file" ]; then
        print_error ".mcp.json não encontrado"
        return 1
    fi
    
    print_step "Removendo servidor '$server_name'..."
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file=$(mktemp)
        
        jq --arg name "$server_name" 'del(.mcpServers[$name])' "$mcp_file" > "$tmp_file"
        
        if [ $? -eq 0 ]; then
            mv "$tmp_file" "$mcp_file"
            print_success "Servidor '$server_name' removido."
        else
            print_error "Falha ao atualizar .mcp.json"
            rm "$tmp_file"
            return 1
        fi
    else
        print_error "jq não encontrado."
        return 1
    fi
}

# Lista servidores configurados
mcp_list_servers() {
    local project_path="${1:-.}"
    local mcp_file="$project_path/.mcp.json"
    
    if [ ! -f "$mcp_file" ]; then
        print_warning ".mcp.json não encontrado"
        return 1
    fi
    
    print_section "Servidores MCP Configurados"
    
    if command -v jq >/dev/null 2>&1; then
        # Extrai chaves e formata
        local count
        count=$(jq '.mcpServers | length' "$mcp_file")
        
        if [ "$count" -gt 0 ]; then
            jq -r '.mcpServers | to_entries[] | "• \(.key) -> \(.value.command) \(.value.args | join(" "))"' "$mcp_file"
            echo ""
            echo "Total: $count servidores"
        else
            echo "Nenhum servidor configurado."
        fi
    else
        grep "mcpServers" -A 20 "$mcp_file"
    fi
}
