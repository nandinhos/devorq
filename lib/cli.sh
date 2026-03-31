#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - CLI Module
# ============================================================================
# Funções para parsing de argumentos e interface de linha de comando
# 
# Uso: source lib/cli.sh
# Dependências: lib/core.sh
# ============================================================================

# Variáveis de CLI (defaults)
CLI_INSTALL_PATH=""
CLI_MODE="full"
CLI_STACK="generic"
CLI_PRD_PATH=""
CLI_PLATFORM="auto"
CLI_LANGUAGE="pt-BR"
CLI_AUTO_DETECT=true
CLI_NO_MCP=false
CLI_NO_HOOKS=false
AIDEV_COMMAND=""
AIDEV_FORCE=false
AIDEV_DRY_RUN=false

# Sincroniza estado da sessão se disponível
# Deve ser chamado após parse_args
sync_session_state() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    if has_aidev_installed "$install_path"; then
        # Variáveis globais de progresso (lidas do estado)
        current_fase=$(get_state_value "current_fase" "1")
        current_sprint=$(get_state_value "current_sprint" "0")
        current_task=$(get_state_value "current_task" "Pendente")
        initialized_at=$(get_state_value "initialized_at" "$(date -Iseconds)")
        
        # Exporta para subprocessos se necessário
        export current_fase current_sprint current_task initialized_at
    fi
}

# ============================================================================
# Exibição de Ajuda
# ============================================================================

# Exibe ajuda completa do comando aidev
# Uso: show_help
show_help() {
    # Definição local de cores (prefixo C_ para evitar conflito com readonly globals)
    local C_CYAN="\033[0;36m"
    local C_YELLOW="\033[1;33m"
    local C_GREEN="\033[0;32m"
    local C_WHITE="\033[1;37m"
    local C_GREY="\033[0;90m"
    local C_NC="\033[0m"

    # Desabilita cores se não for terminal interativo
    if [ ! -t 1 ]; then
        C_CYAN=""; C_YELLOW=""; C_GREEN=""; C_WHITE=""; C_GREY=""; C_NC=""
    fi

    # Helper para imprimir linhas da tabela
    print_cmd() {
        printf "  ${C_GREEN}%-18s${C_NC} %s\n" "$1" "$2"
    }

    # ========================================================================
    # Correção de Alinhamento (ANSI-safe)
    # ------------------------------------------------------------------------
    local version="${AIDEV_VERSION}"
    local app_name="AI Dev Superpowers"
    
    # 1. Conteúdo limpo (sem cores) para cálculo de largura
    local clean_content="  ${app_name} v${version}"
    local content_len=${#clean_content}
    
    # 2. Largura fixa da tabela (baseada na borda de 64 chars)
    local inner_width=64
    
    # 3. Cálculo do padding (preenchimento à direita)
    local pad_len=$((inner_width - content_len))
    [[ $pad_len -lt 0 ]] && pad_len=0
    
    # 4. Conteúdo visual (com injeção de cores)
    local display_content="  ${C_YELLOW}${app_name}${C_NC} v${version}"

    # Top Border
    echo -e "${C_CYAN}╔════════════════════════════════════════════════════════════════╗${C_NC}"
    # Content Line
    # Usamos %b para interpretar os escapes de cor na string ($display_content)
    # Usamos %*s para injetar o padding de espaços calculado ($pad_len)
    printf "${C_CYAN}║${C_NC}%b%*s${C_CYAN}║${C_NC}\n" "${display_content}" "$pad_len" ""
    # Bottom Border
    echo -e "${C_CYAN}╚════════════════════════════════════════════════════════════════╝${C_NC}"
    echo -e "${C_WHITE}Sistema Unificado de Governança de IA para Desenvolvimento${C_NC}"
    echo ""

    echo -e "${C_YELLOW}Uso:${C_NC}"
    echo -e "  aidev <comando> [opções]"
    echo ""

    echo -e "${C_YELLOW}Comandos Principais:${C_NC}"
    print_cmd "init" "Inicializa AI Dev em um projeto"
    print_cmd "upgrade" "Atualiza instalação existente (projeto)"
    print_cmd "self-upgrade" "Atualiza instalação global do CLI"
    print_cmd "status" "Mostra status da instalação"
    print_cmd "doctor" "Diagnóstico da instalação"
    print_cmd "release" "Gerencia releases e versionamento"
    print_cmd "version" "Verifica versão e atualizações disponíveis"
    print_cmd "config" "Configurações (idioma, etc)"
    echo ""

    echo -e "${C_YELLOW}Fluxo de Trabalho (Agente):${C_NC}"
    print_cmd "new-feature" "Inicia fluxo de nova feature (brainstorming → TDD)"
    print_cmd "fix-bug" "Inicia fluxo de correção de bug (debugging sistemático)"
    print_cmd "refactor" "Inicia fluxo de refatoração (análise → plano → TDD)"
    print_cmd "suggest" "Analisa projeto e sugere próximo passo inteligente"
    echo ""

    echo -e "${C_YELLOW}Memória e Conhecimento:${C_NC}"
    print_cmd "lessons" "Gerencia base de conhecimento (KB)"
    print_cmd "snapshot" "Gera 'Context Passport' para migração entre IAs"
    print_cmd "metrics" "Visualiza telemetria e uso de skills"
    print_cmd "cache" "Gerencia cache de ativação (economia de tokens)"
    echo ""

    echo -e "${C_YELLOW}Modo Agente (LLM):${C_NC}"
    print_cmd "agent" "Gera prompt de ativação para copiar/colar"
    print_cmd "start" "Inicia sessão interativa com instruções"
    echo ""

    echo -e "${C_YELLOW}Customização:${C_NC}"
    print_cmd "add-skill" "Adiciona skill customizada"
    print_cmd "add-rule" "Adiciona regra customizada"
    print_cmd "add-agent" "Adiciona agente customizado"
    echo ""

    echo -e "${C_YELLOW}Manutenção:${C_NC}"
    print_cmd "patch" "Aplica patches de correção ao sistema"
    print_cmd "system" "Gerencia instalação global"
    echo ""

    echo -e "${C_YELLOW}Opções Globais:${C_NC}"
    printf "  ${C_CYAN}%-20s${C_NC} %s\n" "--install-in <path>" "Diretório alvo (default: .)"
    printf "  ${C_CYAN}%-20s${C_NC} %s\n" "--force" "Sobrescreve arquivos existentes"
    printf "  ${C_CYAN}%-20s${C_NC} %s\n" "--dry-run" "Simula execução sem alterações"
    printf "  ${C_CYAN}%-20s${C_NC} %s\n" "-h, --help" "Mostra esta ajuda"
    printf "  ${C_CYAN}%-20s${C_NC} %s\n" "-v, --version" "Mostra versão"
    echo ""

    echo -e "${C_GREY}Para ajuda específica de 'init':${C_NC}"
    echo "  aidev init --help"
    echo ""
    
    echo -e "${C_YELLOW}Documentação:${C_NC}"
    echo "  https://github.com/nandinhos/aidev-superpowers-v3"
    echo ""
}

# Exibe versão
# Uso: show_version
show_version() {
    echo "aidev v${AIDEV_VERSION}"
}

# ============================================================================
# Parsing de Argumentos
# ============================================================================

# Parse de argumentos da linha de comando
# Uso: parse_args "$@"
parse_args() {
    # Reset para defaults
    CLI_INSTALL_PATH=""
    CLI_MODE="full"
    CLI_STACK="generic"
    CLI_PRD_PATH=""
    CLI_PLATFORM="auto"
    CLI_LANGUAGE="pt-BR"
    CLI_LANGUAGE_SET=false
    CLI_AUTO_DETECT=true
    CLI_NO_MCP=false
    CLI_NO_HOOKS=false
    CLI_ONBOARDING=false
    AIDEV_COMMAND=""
    AIDEV_FORCE=false
    AIDEV_DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-in)
                CLI_INSTALL_PATH="$2"
                shift 2
                ;;
            --mode)
                CLI_MODE="$2"
                shift 2
                ;;
            --stack)
                CLI_STACK="$2"
                CLI_AUTO_DETECT=false
                shift 2
                ;;
            --prd)
                CLI_PRD_PATH="$2"
                shift 2
                ;;
            --platform)
                CLI_PLATFORM="$2"
                shift 2
                ;;
            --language)
                CLI_LANGUAGE="$2"
                CLI_LANGUAGE_SET=true
                shift 2
                ;;
            --detect)
                CLI_AUTO_DETECT=true
                shift
                ;;
            --force)
                AIDEV_FORCE=true
                shift
                ;;
            --dry-run)
                AIDEV_DRY_RUN=true
                shift
                ;;
            --no-mcp)
                CLI_NO_MCP=true
                shift
                ;;
            --no-hooks)
                CLI_NO_HOOKS=true
                shift
                ;;
            --onboarding)
                CLI_ONBOARDING=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -*)
                print_error "Opção desconhecida: $1"
                echo "Use 'aidev --help' para ver opções disponíveis"
                exit 1
                ;;
            *)
                # Argumento posicional (subcomando ou path)
                if [ -z "$AIDEV_COMMAND" ]; then
                    AIDEV_COMMAND="$1"
                elif [ -z "$CLI_INSTALL_PATH" ]; then
                    CLI_INSTALL_PATH="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Default install path
    if [ -z "$CLI_INSTALL_PATH" ]; then
        CLI_INSTALL_PATH="."
    fi
    export CLI_INSTALL_PATH
    
    # Sincroniza estado após determinar o path
    sync_session_state
}

# ============================================================================
# Validação de Argumentos
# ============================================================================

# Valida argumentos após parsing
# Uso: validate_args
validate_args() {
    local errors=0
    
    # Validar modo
    if [[ ! "$CLI_MODE" =~ ^(new|refactor|minimal|full)$ ]]; then
        print_error "Modo inválido: $CLI_MODE"
        echo "Modos válidos: new, refactor, minimal, full"
        ((errors++)) || true
    fi
    
    # Validar PRD para modo new
    if [ "$CLI_MODE" = "new" ] && [ -z "$CLI_PRD_PATH" ]; then
        print_error "--mode new requer --prd <path>"
        ((errors++)) || true
    fi
    
    # Validar PRD existe
    if [ -n "$CLI_PRD_PATH" ] && [ ! -f "$CLI_PRD_PATH" ]; then
        print_error "PRD não encontrado: $CLI_PRD_PATH"
        ((errors++)) || true
    fi
    
    # Validar stack
    local valid_stacks="laravel|filament|livewire|node|react|nextjs|vue|express|python|django|fastapi|flask|ruby|rails|go|rust|php|generic"
    if [[ ! "$CLI_STACK" =~ ^($valid_stacks)$ ]]; then
        print_error "Stack inválida: $CLI_STACK"
        echo "Stacks válidas: laravel, filament, livewire, node, react, nextjs, python, generic, etc."
        ((errors++)) || true
    fi
    
    # Validar plataforma
    local valid_platforms="auto|antigravity|claude-code|gemini|opencode|codex|rovo|aider|cursor|continue|generic"
    if [[ ! "$CLI_PLATFORM" =~ ^($valid_platforms)$ ]]; then
        print_error "Plataforma inválida: $CLI_PLATFORM"
        ((errors++)) || true
    fi
    
    # Validar idioma
    if [[ ! "$CLI_LANGUAGE" =~ ^(pt-BR|en)$ ]]; then
        print_error "Idioma inválido: $CLI_LANGUAGE"
        echo "Idiomas válidos: pt-BR, en"
        ((errors++)) || true
    fi
    
    if [ $errors -gt 0 ]; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# Confirmação Interativa
# ============================================================================

# Solicita confirmação do usuário
# Uso: confirm "Deseja continuar?" && echo "sim"
confirm() {
    local message="${1:-Deseja continuar?}"
    local default="${2:-n}"
    
    local prompt
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    read -r -p "$message $prompt " response
    
    case "$response" in
        [yY][eE][sS]|[yY]|[sS][iI][mM]|[sS])
            return 0
            ;;
        [nN][oO]|[nN]|[nN][ãÃ][oO])
            return 1
            ;;
        "")
            if [ "$default" = "y" ]; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# Exibição de Status
# ============================================================================

# Exibe resumo de configuração antes de executar
# Uso: show_config_summary
show_config_summary() {
    print_section "Configuração"
    
    echo "  Diretório:     $CLI_INSTALL_PATH"
    echo "  Modo:          $CLI_MODE"
    echo "  Stack:         $CLI_STACK"
    echo "  Plataforma:    $CLI_PLATFORM"
    echo "  Idioma:        $CLI_LANGUAGE"
    echo "  Auto-detectar: $CLI_AUTO_DETECT"
    echo "  MCP Engine:    $([ "$CLI_NO_MCP" = true ] && echo "Desabilitado" || echo "Habilitado")"
    echo "  Hooks:         $([ "$CLI_NO_HOOKS" = true ] && echo "Desabilitado" || echo "Habilitado")"
    echo "  Force:         $AIDEV_FORCE"
    echo "  Dry-run:       $AIDEV_DRY_RUN"
    
    if [ -n "$CLI_PRD_PATH" ]; then
        echo "  PRD:           $CLI_PRD_PATH"
    fi
    
    echo ""
}
