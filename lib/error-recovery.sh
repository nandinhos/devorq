#!/bin/bash
# error-recovery.sh - Sistema de Recuperação Automática de Erros
# Sprint 6.2: Advanced Error Recovery
# Sugere correções automáticas baseadas na Knowledge Base
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "Erro: Este arquivo deve ser incluído (sourced), não executado diretamente." >&2; exit 1; }

# ============================================================================
# CONFIGURAÇÃO
# ============================================================================

# Diretório de KB de erros
readonly ERROR_KB_DIR="${ERROR_KB_DIR:-.devorq/memory/error-patterns}"

# Arquivo de log de erros
readonly ERROR_LOG_FILE="${ERROR_LOG_FILE:-.devorq/state/error-log.json}"

# ============================================================================
# BANCO DE PADRÕES DE ERRO (Embedded KB)
# ============================================================================

# Padrões de erro conhecidos e suas soluções
# Formato: "padrão_regex|descrição|solução|comando_fix"
declare -A ERROR_PATTERNS=(
    # Erros de permissão
    ["Permission denied"]='Permissão negada|Verifique se você tem permissão de escrita no diretório.|chmod 755 <diretório>'
    ["EACCES"]='Erro de acesso|Permissão negada para acessar arquivo ou diretório.|sudo chmod -R 755 .'
    
    # Erros de arquivo não encontrado
    ["No such file or directory"]='Arquivo ou diretório não encontrado|O caminho especificado não existe.|Verifique o caminho ou crie o diretório: mkdir -p <caminho>'
    ["ENOENT"]='Arquivo não encontrado|O sistema não encontrou o arquivo especificado.|Verifique se o arquivo existe: ls -la <arquivo>'
    
    # Erros de comando não encontrado
    ["command not found"]='Comando não encontrado|O comando não está instalado ou não está no PATH.|Instale o comando ou verifique o PATH.'
    ["not found"]='Comando ou arquivo não encontrado|Verifique se está instalado e no PATH.|which <comando> para verificar'
    
    # Erros de dependência
    ["No such module"]='Módulo não encontrado|Uma dependência está faltando.|aidev doctor --fix para reparar dependências'
    ["ModuleNotFoundError"]='Módulo Python não encontrado|Instale a dependência: pip install <módulo>'
    ["ImportError"]='Erro de importação|Biblioteca não encontrada.|Instale a biblioteca necessária.'
    
    # Erros de sintaxe
    ["syntax error"]='Erro de sintaxe|Há um erro de sintaxe no código.|Verifique a sintaxe do arquivo.'
    ["SyntaxError"]='Erro de sintaxe Python|Corrija a sintaxe do código Python.'
    ["parse error"]='Erro de parsing|O arquivo não pode ser parseado.|Verifique a estrutura do arquivo.'
    
    # Erros de execução
    ["Segmentation fault"]='Erro de segmentação|Acesso inválido à memória.|Verifique se há ponteiros nulos ou memória corrompida.'
    ["segfault"]='Segmentation fault|Erro grave de memória.|Reinicie o processo e verifique logs.'
    
    # Erros de rede
    ["Connection refused"]='Conexão recusada|O servidor não está aceitando conexões.|Verifique se o serviço está rodando.'
    ["Network is unreachable"]='Rede indisponível|Sem conexão de rede.|Verifique sua conexão de internet.'
    ["timeout"]='Timeout|A operação demorou muito tempo.|Verifique a conectividade ou aumente o timeout.'
    ["timed out"]='Tempo esgotado|A conexão excedeu o tempo limite.|Tente novamente ou verifique a rede.'
    
    # Erros de disk space
    ["No space left on device"]='Disco cheio|Não há espaço disponível no disco.|Libere espaço: aidev doctor --clean'
    ["ENOSPC"]='Sem espaço em disco|O disco está cheio.|Remova arquivos desnecessários.'
    
    # Erros de variáveis
    ["unbound variable"]='Variável não definida|Uma variável foi usada sem ser definida.|Defina a variável antes de usar.'
    ["parameter not set"]='Parâmetro não definido|Um parâmetro obrigatório não foi fornecido.|Passe todos os parâmetros necessários.'
    
    # Erros de AI Dev específicos
    ["AIDEV_GLOBAL_DIR"]='Configuração de diretório global|Problema com AIDEV_GLOBAL_DIR.|Exporte AIDEV_GLOBAL_DIR=$HOME/.aidev-superpowers'
    ["deploy_sync"]='Erro de sincronização|Falha na sincronização com instalação global.|Execute: aidev system sync'
    ["checkpoint"]='Erro de checkpoint|Falha ao criar checkpoint.|Verifique permissões em .devorq/state/'
    ["version"]='Erro de versão|Problema com versionamento.|Verifique o arquivo VERSION: cat VERSION'
    
    # Erros jq/json
    ["parse error: Invalid numeric literal"]='Erro de parsing JSON|JSON malformado.|Verifique a sintaxe do JSON.'
    ["jq: error"]='Erro no jq|Comando jq falhou.|Verifique se jq está instalado e JSON é válido.'
)

# ============================================================================
# FUNÇÕES CORE
# ============================================================================

# Analisa um erro e retorna informações estruturadas
# Uso: error_recovery_analyze "$error_message" "$exit_code" "$command"
error_recovery_analyze() {
    local error_msg="$1"
    local exit_code="${2:-1}"
    local command="${3:-}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local pattern_found=""
    local description=""
    local solution=""
    local fix_command=""
    local confidence="low"
    
    # Procura por padrões conhecidos
    for pattern in "${!ERROR_PATTERNS[@]}"; do
        if echo "$error_msg" | grep -qi "$pattern"; then
            IFS='|' read -r pattern_desc pattern_solution pattern_fix <<< "${ERROR_PATTERNS[$pattern]}"
            pattern_found="$pattern"
            description="$pattern_desc"
            solution="$pattern_solution"
            fix_command="$pattern_fix"
            confidence="high"
            break
        fi
    done
    
    # Se não encontrou padrão específico, análise genérica
    if [ -z "$pattern_found" ]; then
        description="Erro não categorizado"
        solution="Análise manual necessária. Consulte os logs para mais detalhes."
        fix_command="aidev doctor"
        confidence="low"
        
        # Tenta identificar tipo geral
        if echo "$error_msg" | grep -qi "error\|erro"; then
            description="Erro genérico detectado"
        elif echo "$error_msg" | grep -qi "warning\|aviso"; then
            description="Aviso detectado"
            confidence="medium"
        fi
    fi
    
    # Retorna JSON com análise
    jq -n \
        --arg ts "$timestamp" \
        --arg exit "$exit_code" \
        --arg cmd "$command" \
        --arg msg "$error_msg" \
        --arg pattern "${pattern_found:-unknown}" \
        --arg desc "$description" \
        --arg sol "$solution" \
        --arg fix "$fix_command" \
        --arg conf "$confidence" \
        '{
            timestamp: $ts,
            exit_code: ($exit | tonumber),
            command: $cmd,
            error_message: $msg,
            pattern: $pattern,
            description: $desc,
            solution: $sol,
            suggested_fix: $fix,
            confidence: $conf,
            actionable: ($conf == "high")
        }'
}

# Registra erro no log para análise futura
error_recovery_log() {
    local analysis_json="$1"
    
    # Cria diretório se não existir
    mkdir -p "$(dirname "$ERROR_LOG_FILE")"
    
    # Inicializa arquivo se não existir
    if [ ! -f "$ERROR_LOG_FILE" ]; then
        echo '{"errors": []}' > "$ERROR_LOG_FILE"
    fi
    
    # Adiciona erro ao log
    jq ".errors += [$analysis_json]" "$ERROR_LOG_FILE" > "${ERROR_LOG_FILE}.tmp" && \
        mv "${ERROR_LOG_FILE}.tmp" "$ERROR_LOG_FILE"
}

# Sugere correções baseadas na análise
# Uso: error_recovery_suggest "$analysis_json"
error_recovery_suggest() {
    local analysis_json="$1"
    
    local description=$(echo "$analysis_json" | jq -r '.description')
    local solution=$(echo "$analysis_json" | jq -r '.solution')
    local fix_cmd=$(echo "$analysis_json" | jq -r '.suggested_fix')
    local confidence=$(echo "$analysis_json" | jq -r '.confidence')
    local actionable=$(echo "$analysis_json" | jq -r '.actionable')
    
    echo ""
    echo "💡 ANÁLISE DO ERRO:"
    echo ""
    echo "   Descrição: $description"
    echo ""
    echo "   Solução: $solution"
    echo ""
    
    if [ "$actionable" = "true" ]; then
        echo "   🛠️  COMANDO SUGERIDO:"
        echo "      $ $fix_cmd"
        echo ""
        echo "   Para executar automaticamente:"
        echo "      aidev doctor --recovery"
    else
        echo "   🔍 Diagnóstico necessário:"
        echo "      aidev doctor --verbose"
    fi
    
    echo ""
    echo "   (Confiança: $confidence)"
}

# Executa recovery automático se possível
# Uso: error_recovery_auto "$analysis_json"
error_recovery_auto() {
    local analysis_json="$1"
    local actionable=$(echo "$analysis_json" | jq -r '.actionable')
    local fix_cmd=$(echo "$analysis_json" | jq -r '.suggested_fix')
    local pattern=$(echo "$analysis_json" | jq -r '.pattern')
    
    if [ "$actionable" != "true" ]; then
        echo "⚠️  Recovery automático não disponível para este erro."
        echo "   Execute 'aidev doctor' para diagnóstico manual."
        return 1
    fi
    
    echo "🤖 Tentando recovery automático..."
    echo "   Ação: $fix_cmd"
    echo ""
    
    case "$pattern" in
        "Permission denied"|"EACCES")
            echo "🔧 Corrigindo permissões..."
            chmod 755 . 2>/dev/null || sudo chmod 755 .
            echo "✅ Permissões corrigidas"
            ;;
        "No such file or directory"|"ENOENT")
            echo "🔧 Criando diretórios necessários..."
            mkdir -p .devorq/state .devorq/backups .devorq/logs
            echo "✅ Diretórios criados"
            ;;
        "command not found"|"not found")
            echo "❌ Comando não encontrado. Instalação manual necessária."
            return 1
            ;;
        "AIDEV_GLOBAL_DIR")
            echo "🔧 Configurando AIDEV_GLOBAL_DIR..."
            export AIDEV_GLOBAL_DIR="$HOME/.aidev-superpowers"
            echo "export AIDEV_GLOBAL_DIR=$HOME/.aidev-superpowers" >> ~/.bashrc
            echo "✅ Configuração adicionada ao .bashrc"
            ;;
        "deploy_sync")
            echo "🔧 Sincronizando instalação global..."
            aidev system sync --force 2>/dev/null || echo "⚠️  Sincronização manual necessária"
            ;;
        *)
            echo "⚠️  Recovery automático não implementado para: $pattern"
            echo "   Execute manualmente: $fix_cmd"
            return 1
            ;;
    esac
}

# Handler principal integrado com error_handler do aidev
# Uso: error_recovery_handler "$exit_code" "$line_no" "$command"
error_recovery_handler() {
    local exit_code="$1"
    local line_no="$2"
    local command="${3:-${BASH_COMMAND:-}}"
    local error_msg="${4:-}"
    
    # Se não recebeu mensagem de erro, tenta obter do contexto
    if [ -z "$error_msg" ]; then
        error_msg="Erro desconhecido (código: $exit_code)"
    fi
    
    # Analisa o erro
    local analysis=$(error_recovery_analyze "$error_msg" "$exit_code" "$command")
    
    # Registra para análise futura
    error_recovery_log "$analysis"
    
    # Mostra sugestões (para stderr, para não poluir stdout com texto)
    error_recovery_suggest "$analysis" >&2

    # Retorna análise JSON em stdout para uso posterior
    echo "$analysis"
}

# Mostra estatísticas de erros
error_recovery_stats() {
    if [ ! -f "$ERROR_LOG_FILE" ]; then
        echo "Nenhum erro registrado ainda."
        return 0
    fi
    
    echo "📊 ESTATÍSTICAS DE ERROS"
    echo ""
    
    local total=$(jq '.errors | length' "$ERROR_LOG_FILE")
    echo "   Total de erros registrados: $total"
    echo ""
    
    if [ "$total" -gt 0 ]; then
        echo "   Erros mais comuns:"
        jq -r '.errors | group_by(.pattern) | map({pattern: .[0].pattern, count: length}) | sort_by(.count) | reverse | .[0:5] | .[] | "      - \(.pattern): \(.count)x"' "$ERROR_LOG_FILE"
        
        echo ""
        echo "   Taxa de sucesso do recovery:"
        local high_conf=$(jq '[.errors[] | select(.confidence == "high")] | length' "$ERROR_LOG_FILE")
        echo "      Alta confiança: $high_conf/$total ($(echo "scale=1; $high_conf * 100 / $total" | bc)%)"
    fi
}

# Limpa log de erros
error_recovery_clear() {
    if [ -f "$ERROR_LOG_FILE" ]; then
        rm "$ERROR_LOG_FILE"
        echo "✅ Log de erros limpo."
    else
        echo "Nenhum log para limpar."
    fi
}

# ============================================================================
# CLI HANDLER
# ============================================================================

error_recovery_cli() {
    local subcommand="${1:-help}"
    
    case "$subcommand" in
        analyze|analyse)
            shift
            local error_msg="$*"
            if [ -z "$error_msg" ]; then
                echo "Uso: aidev error-recovery analyze '<mensagem de erro>'"
                return 1
            fi
            error_recovery_analyze "$error_msg" 1 "manual"
            ;;
        stats)
            error_recovery_stats
            ;;
        clear|clean)
            error_recovery_clear
            ;;
        test)
            # Simula um erro para teste
            echo "🧪 Simulando erro de teste..."
            error_recovery_handler 1 100 "teste" "Permission denied: arquivo.txt"
            ;;
        help|--help|-h)
            echo "Error Recovery - AI Dev Superpowers"
            echo ""
            echo "Uso: aidev error-recovery <comando>"
            echo ""
            echo "Comandos:"
            echo "  analyze '<msg>'   Analisa uma mensagem de erro"
            echo "  stats             Mostra estatísticas de erros"
            echo "  clear             Limpa log de erros"
            echo "  test              Testa sistema com erro simulado"
            echo "  help              Mostra esta ajuda"
            ;;
        *)
            echo "Comando desconhecido: $subcommand"
            error_recovery_cli help
            return 1
            ;;
    esac
}

# ============================================================================
# EXPORTAÇÃO
# ============================================================================

export -f error_recovery_analyze
export -f error_recovery_suggest
export -f error_recovery_auto
export -f error_recovery_handler
export -f error_recovery_stats
export -f error_recovery_clear
export -f error_recovery_cli
