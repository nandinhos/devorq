#!/bin/bash

# ============================================================================
# mcp-fallback.sh - Sistema de Fallback e Resiliência para MCPs
# ============================================================================
# Princípio: MCPs são enhancement, não dependência
# Se MCP não responde → fallback automático sem erro
# ============================================================================

_MCP_FALLBACK_STATE_FILE="${MCP_FALLBACK_STATE_FILE:-.aidev/state/mcp-fallback-status.json}"
_MCP_MAX_RETRIES=3
_MCP_RETRY_DELAY=1

# ============================================================================
# Funções Auxiliares (devem vir primeiro)
# ============================================================================

_mcp_fallback_log() {
    local level="$1"
    local mcp_name="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "[$timestamp] [$level] mcp-fallback: $mcp_name - $message" >&2
    
    mkdir -p .aidev/logs 2>/dev/null || true
    echo "[$timestamp] [$level] mcp-fallback: $mcp_name - $message" >> .aidev/logs/mcp-fallback.log 2>/dev/null || true
}

_mcp_fallback_update_status() {
    local mcp_name="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p .aidev/state 2>/dev/null || true
    
    local temp_file
    temp_file=$(mktemp)
    
    if [ -f "$_MCP_FALLBACK_STATE_FILE" ]; then
        jq --arg name "$mcp_name" \
           --arg status "$status" \
           --arg msg "$message" \
           --arg ts "$timestamp" \
           '.mcps[$name] = {"status": $status, "message": $msg, "last_check": $ts}' \
           "$_MCP_FALLBACK_STATE_FILE" > "$temp_file" && mv "$temp_file" "$_MCP_FALLBACK_STATE_FILE"
    else
        echo "{\"updated_at\": \"$timestamp\", \"mcps\": {\"$mcp_name\": {\"status\": \"$status\", \"message\": \"$message\", \"last_check\": \"$timestamp\"}}}" > "$temp_file"
        mv "$temp_file" "$_MCP_FALLBACK_STATE_FILE"
    fi
}

# ============================================================================
# mcp_fallback_check <mcp-name>
# Verifica se MCP está instalado e responde
# Faz retry 3x antes de marcar como down
# Retorna: 0 (ok), 1 (down - fallback ativado)
# ============================================================================
mcp_fallback_check() {
    local mcp_name="$1"
    local retries=0
    local result=1
    
    [ -z "$mcp_name" ] && { echo "ERROR: mcp_name required" >&2; return 1; }
    
    while [ $retries -lt $_MCP_MAX_RETRIES ]; do
        case "$mcp_name" in
            basic-memory)
                command -v basic-memory &>/dev/null && result=0
                ;;
            context7|context7-mcp)
                # Verifica se tem chave de API configurada OU ripgrep disponível
                if [ -n "$CONTEXT7_API_KEY" ]; then
                    result=0
                elif command -v ripgrep &>/dev/null; then
                    result=0
                fi
                ;;
            serena)
                # Verifica se está rodando ou comando disponível
                pgrep -f "serena.*mcp" &>/dev/null && result=0
                ;;
            laravel-boost)
                command -v docker &>/dev/null && result=0
                ;;
            *)
                result=0
                ;;
        esac
        
        if [ $result -eq 0 ]; then
            _mcp_fallback_log "INFO" "$mcp_name" "OK after $((retries + 1)) attempt(s)"
            _mcp_fallback_update_status "$mcp_name" "connected" "OK"
            return 0
        fi
        
        retries=$((retries + 1))
        [ $retries -lt $_MCP_MAX_RETRIES ] && sleep $_MCP_RETRY_DELAY
    done
    
    _mcp_fallback_log "WARN" "$mcp_name" "FALLBACK ATIVADO após $_MCP_MAX_RETRIES tentativas"
    _mcp_fallback_update_status "$mcp_name" "fallback" "Ativado automaticamente"
    return 1
}

# ============================================================================
# mcp_fallback_check_all
# Verifica todos os MCPs configurados
# ============================================================================
mcp_fallback_check_all() {
    local mcp_list=("basic-memory" "context7" "serena" "laravel-boost")
    local failed=0
    local checked=0
    
    for mcp in "${mcp_list[@]}"; do
        checked=$((checked + 1))
        if ! mcp_fallback_check "$mcp"; then
            failed=$((failed + 1))
        fi
    done
    
    echo "MCPs verificados: $checked | Ativos: $((checked - failed)) | Fallback: $failed"
    
    [ $failed -gt 0 ] && return 1
    return 0
}

# ============================================================================
# mcp_fallback_get_fallback_command <mcp-name>
# Retorna o comando de fallback para o MCP
# ============================================================================
mcp_fallback_get_fallback_command() {
    local mcp_name="$1"
    
    case "$mcp_name" in
        basic-memory)
            echo "cat .aidev/memory/kb/"
            ;;
        context7|context7-mcp)
            echo "rg --hidden"
            ;;
        serena)
            echo "find . -name"
            ;;
        laravel-boost)
            echo "php artisan"
            ;;
        *)
            echo "echo 'No fallback available'"
            ;;
    esac
}

# ============================================================================
# mcp_fallback_log <level> <mcp-name> <message>
# Log de eventos de fallback
# ============================================================================
mcp_fallback_log() {
    local level="$1"
    local mcp_name="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "[$timestamp] [$level] mcp-fallback: $mcp_name - $message" >&2
    
    # Also log to file
    mkdir -p .aidev/logs
    echo "[$timestamp] [$level] mcp-fallback: $mcp_name - $message" >> .aidev/logs/mcp-fallback.log
}

# ============================================================================
# mcp_fallback_update_status <mcp-name> <status> <message>
# Atualiza estado do MCP no arquivo JSON
# ============================================================================
mcp_fallback_update_status() {
    local mcp_name="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p .aidev/state
    
    # Create or update JSON
    local temp_file
    temp_file=$(mktemp)
    
    if [ -f "$_MCP_FALLBACK_STATE_FILE" ]; then
        # Update existing
        jq --arg name "$mcp_name" \
           --arg status "$status" \
           --arg msg "$message" \
           --arg ts "$timestamp" \
           '.mcps[$name] = {"status": $status, "message": $msg, "last_check": $ts}' \
           "$_MCP_FALLBACK_STATE_FILE" > "$temp_file" && mv "$temp_file" "$_MCP_FALLBACK_STATE_FILE"
    else
        # Create new
        echo "{\"updated_at\": \"$timestamp\", \"mcps\": {\"$mcp_name\": {\"status\": \"$status\", \"message\": \"$message\", \"last_check\": \"$timestamp\"}}}" > "$temp_file"
        mv "$temp_file" "$_MCP_FALLBACK_STATE_FILE"
    fi
}

# ============================================================================
# mcp_fallback_get_status <mcp-name>
# Retorna status atual do MCP
# ============================================================================
mcp_fallback_get_status() {
    local mcp_name="$1"
    
    if [ -f "$_MCP_FALLBACK_STATE_FILE" ]; then
        jq -r ".mcps.\"$mcp_name\".status // \"unknown\"" "$_MCP_FALLBACK_STATE_FILE"
    else
        echo "unknown"
    fi
}

# ============================================================================
# mcp_fallback_hook_sprint_done
# Hook para executar após 'aidev done'
# Verifica todos os MCPs e ativa fallback se necessário
# ============================================================================
mcp_fallback_hook_sprint_done() {
    echo ""
    echo "🔍 Verificando status dos MCPs..."
    mcp_fallback_check_all
    local result=$?
    
    if [ $result -ne 0 ]; then
        echo "⚠️  Alguns MCPs estão em modo fallback. Funcionalidade preservada."
    fi
    
    return 0
}

# ============================================================================
# mcp_fallback_hook_ckpt_create
# Hook para executar antes de criar checkpoint
# ============================================================================
mcp_fallback_hook_ckpt_create() {
    # Quick check - just log status
    for mcp in basic-memory context7 serena laravel-boost; do
        local status
        status=$(mcp_fallback_get_status "$mcp")
        if [ "$status" = "fallback" ]; then
            _mcp_fallback_log "INFO" "$mcp" "Checkpoint created with fallback active"
        fi
    done
    return 0
}

# Export for external use
export -f mcp_fallback_check
export -f mcp_fallback_check_all
export -f mcp_fallback_get_status
export -f mcp_fallback_get_fallback_command
export -f mcp_fallback_hook_sprint_done
export -f mcp_fallback_hook_ckpt_create
