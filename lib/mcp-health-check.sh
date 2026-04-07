#!/bin/bash

# ============================================================================
# mcp-health-check.sh - Verificação de saúde dos MCPs
# ============================================================================
# Health check completo que verifica se MCPs estão respondendo
# Não apenas se o comando existe, mas se realmente funcionam
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "Erro: Este arquivo deve ser incluído (sourced), não executado diretamente." >&2; exit 1; }
# ============================================================================

_MCP_HEALTH_TIMEOUT=5
_MCP_HEALTH_REGISTRY="${MCP_HEALTH_REGISTRY:-.devorq/config/mcp-registry.yaml}"

# ============================================================================
# mcp_health_check
# Verifica saúde de um MCP específico
# Retorna: 0 (ok), 1 (falhou), 2 (aviso)
# ============================================================================
mcp_health_check() {
    local mcp_name="$1"
    local verbose="${2:-false}"
    local result=0
    
    case "$mcp_name" in
        basic-memory)
            _mcp_health_basic_memory "$verbose" || result=$?
            ;;
        context7|context7-mcp)
            _mcp_health_context7 "$verbose" || result=$?
            ;;
        serena)
            _mcp_health_serena "$verbose" || result=$?
            ;;
        laravel-boost)
            _mcp_health_laravel "$verbose" || result=$?
            ;;
        *)
            if [ "$verbose" = "true" ]; then
                echo "  ❓ MCP desconhecido: $mcp_name"
            fi
            return 1
            ;;
    esac
    
    return ${result:-0}
}

# ============================================================================
# _mcp_health_basic_memory
# Basic Memory é local-first, não precisa de API key
# ============================================================================
_mcp_health_basic_memory() {
    local verbose="$1"
    
    # Verifica se comando existe
    if ! command -v basic-memory &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ❌ basic-memory: comando não encontrado"
        return 1
    fi
    
    # Basic Memory é local-first, não precisa de API key
    # Tenta verificar se está funcionando
    if timeout $_MCP_HEALTH_TIMEOUT basic-memory --version &>/dev/null 2>&1; then
        [ "$verbose" = "true" ] && echo "  ✅ basic-memory: OK (local-first)"
        return 0
    fi
    
    [ "$verbose" = "true" ] && echo "  ⚠️  basic-memory: não está respondendo"
    return 2
}

# ============================================================================
# _mcp_health_context7
# ============================================================================
_mcp_health_context7() {
    local verbose="$1"
    
    # Verifica se tem API key
    if [ -z "$CONTEXT7_API_KEY" ]; then
        [ "$verbose" = "true" ] && echo "  ❌ context7: API key não configurada"
        return 1
    fi
    
    # Verifica se npx existe
    if ! command -v npx &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ❌ context7: npx não encontrado"
        return 1
    fi
    
    # Verifica ripgrep como fallback
    if command -v ripgrep &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ✅ context7: OK (fallback ripgrep disponível)"
        return 0
    fi
    
    [ "$verbose" = "true" ] && echo "  ⚠️  context7: sem fallback"
    return 2
}

# ============================================================================
# _mcp_health_serena
# ============================================================================
_mcp_health_serena() {
    local verbose="$1"
    
    # Verifica se está rodando
    if pgrep -f "serena.*mcp" &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ✅ serena: OK (em execução)"
        return 0
    fi
    
    # Verifica se comando existe
    if command -v serena &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ⚠️  serena: instalado mas não está rodando"
        echo "     Execute: uvx --from git+https://github.com/oraios/serena serena start-mcp-server &"
        return 2
    fi
    
    # Fallback
    if command -v find &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ⚠️  serena: usando fallback (find)"
        return 2
    fi
    
    [ "$verbose" = "true" ] && echo "  ❌ serena: não disponível"
    return 1
}

# ============================================================================
# _mcp_health_laravel
# Verifica stack primeiro - se não é Laravel, retorna sem erro
# ============================================================================
_mcp_health_laravel() {
    local verbose="$1"
    
    # Detecta stack do projeto
    local stack="generic"
    if type stack_detect &>/dev/null; then
        stack=$(stack_detect "." 2>/dev/null || echo "generic")
    fi
    
    # Se não é projeto Laravel, não é aplicável
    if [ "$stack" != "laravel" ]; then
        [ "$verbose" = "true" ] && echo "  ℹ️  laravel-boost: não aplicável (stack: $stack)"
        return 0  # Não é erro, simplesmente não se aplica
    fi
    
    # A partir daqui, é projeto Laravel - verifica configuração
    
    # Verifica Docker
    if ! command -v docker &>/dev/null; then
        [ "$verbose" = "true" ] && echo "  ❌ laravel-boost: Ops! Seu projeto tem Laravel mas Docker não está disponível"
        [ "$verbose" = "true" ] && echo "     💡 Execute: docker-compose up -d"
        return 1
    fi
    
    # Verifica se container está rodando
    local container_count
    container_count=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    
    if [ "$container_count" -eq 0 ]; then
        [ "$verbose" = "true" ] && echo "  ❌ laravel-boost: Ops! Seu projeto tem Laravel mas nenhum container está rodando"
        [ "$verbose" = "true" ] && echo "     💡 Execute: docker-compose up -d"
        return 1
    fi
    
    # Verifica se PHP artisan funciona
    if command -v php &>/dev/null && php artisan &>/dev/null 2>&1; then
        [ "$verbose" = "true" ] && echo "  ✅ laravel-boost: OK ($container_count container(s))"
        return 0
    fi
    
    [ "$verbose" = "true" ] && echo "  ⚠️  laravel-boost: containers rodando mas PHP indisponível"
    return 2
}

# ============================================================================
# mcp_health_all
# Verifica todos os MCPs e exibe relatório
# ============================================================================
mcp_health_all() {
    local verbose="${1:-true}"
    local total=0
    local ok=0
    local warn=0
    local fail=0
    
    # Detecta stack primeiro (para saber se Laravel é aplicável)
    local current_stack="generic"
    local _stack_detector
    _stack_detector="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/stack-detector.sh"
    # Fallback para DEVORQ_ROOT se disponível
    if [ -f "${DEVORQ_ROOT:-}/lib/stack-detector.sh" ]; then
        _stack_detector="${DEVORQ_ROOT}/lib/stack-detector.sh"
    fi
    if [ -f "$_stack_detector" ]; then
        # shellcheck source=/dev/null
        source "$_stack_detector"
        current_stack=$(stack_detect "." 2>/dev/null || echo "generic")
    fi
    
    echo "🔍 Health Check dos MCPs"
    echo "========================"
    echo "Stack detectada: $current_stack"
    echo ""
    
    for mcp in basic-memory context7 serena laravel-boost; do
        # Pula laravel-boost se não é projeto Laravel
        if [ "$mcp" = "laravel-boost" ] && [ "$current_stack" != "laravel" ]; then
            continue
        fi
        
        total=$((total + 1))
        
        mcp_health_check "$mcp" "$verbose"
        local result=$?
        
        case $result in
            0) ok=$((ok + 1)) ;;
            2) warn=$((warn + 1)) ;;
            1) fail=$((fail + 1)) ;;
        esac
    done
    
    echo ""
    echo "========================"
    echo "Total: $total | OK: $ok | Aviso: $warn | Falha: $fail"
    
    if [ $fail -gt 0 ]; then
        return 1
    elif [ $warn -gt 0 ]; then
        return 2
    fi
    return 0
}

# ============================================================================
# mcp_health_suggest
# Sugere correções para MCPs com problema
# ============================================================================
mcp_health_suggest() {
    echo "💡 Sugestões para resolver problemas:"
    echo ""
    
    # Context7
    if [ -z "$CONTEXT7_API_KEY" ]; then
        echo "  context7:"
        echo "    1. Obtenha chave em: https://upstash.com/"
        echo "    2. Execute: aidev mcp keys"
        echo "    3. Adicione ao ~/.bashrc: export CONTEXT7_API_KEY=\"sua-chave\""
        echo ""
    fi
    
    # Serena
    if ! pgrep -f "serena.*mcp" &>/dev/null; then
        echo "  serena:"
        echo "    1. Inicie o servidor: uvx --from git+https://github.com/oraios/serena serena start-mcp-server &"
        echo "    2. O fallback usa 'find . -name' que funciona sem configuração"
        echo ""
    fi
    
    # Laravel Boost
    if ! command -v docker &>/dev/null; then
        echo "  laravel-boost:"
        echo "    1. Instale o Docker"
        echo "    2. Inicie seus containers: docker-compose up -d"
        echo ""
    fi
}

# Export
export -f mcp_health_check
export -f mcp_health_all
export -f mcp_health_suggest
