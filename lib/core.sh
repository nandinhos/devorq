#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - Core Module
# ============================================================================
# Funções utilitárias de output e formatação
# 
# Uso: source lib/core.sh
# ============================================================================

# Lê a versão do SSOT (arquivo VERSION na raiz do projeto)
# Protege contra re-definição quando o módulo é sourced múltiplas vezes
if [ -z "${AIDEV_VERSION:-}" ]; then
    if [ -f "$AIDEV_ROOT_DIR/VERSION" ]; then
        AIDEV_VERSION=$(cat "$AIDEV_ROOT_DIR/VERSION" | tr -d '[:space:]')
    else
        AIDEV_VERSION="0.0.0-unknown"
    fi
    readonly AIDEV_VERSION
fi

# ============================================================================
# Cores e Formatação (Detecção de TTY)
# ============================================================================

# Definição base para manter compatibilidade com echo e printf
# Usamos strings ANSI-C ($'\e') para garantir o caractere ESC real
if [[ -z "${NO_COLOR:-}" ]] && { [[ -u /dev/stdout ]] || [[ -t 1 ]] || [[ "${AIDEV_FORCE_COLOR:-false}" == "true" ]]; }; then
    RED=$'\e[0;31m'
    GREEN=$'\e[0;32m'
    YELLOW=$'\e[1;33m'
    BLUE=$'\e[0;34m'
    CYAN=$'\e[0;36m'
    MAGENTA=$'\e[0;35m'
    BOLD=$'\e[1m'
    NC=$'\e[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    BOLD=''
    NC=''
fi

# ============================================================================
# Contadores (inicializados em cada operação)
# ============================================================================

AIDEV_FILES_CREATED=0
AIDEV_DIRS_CREATED=0

# ============================================================================
# Funções de Output
# ============================================================================

# Exibe header do script
# Uso: print_header "Título Opcional"
print_header() {
    local title="${1:-AI Dev Superpowers}"
    local version="${AIDEV_VERSION}"
    
    # 1. Conteúdo limpo (sem cores)
    local clean_content="  ${title} v${version}"
    local content_len=${#clean_content}
    
    # 2. Largura interna (borda a borda = 64)
    local inner_width=64
    
    # 3. Padding
    local pad_len=$((inner_width - content_len))
    [[ $pad_len -lt 0 ]] && pad_len=0
    
    # 4. Display content (com cores)
    local display_content="  ${YELLOW}${title}${NC} v${version}"

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC}%b%*s${CYAN}║${NC}\n" "${display_content}" "$pad_len" ""
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Exibe etapa de progresso
# Uso: print_step "Descrição da etapa"
print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

# Exibe mensagem de sucesso
# Uso: print_success "Operação concluída"
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Exibe informação
# Uso: print_info "Informação adicional"
print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Exibe aviso
# Uso: print_warning "Algo precisa de atenção"
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Exibe erro (envia para stderr)
# Uso: print_error "Algo deu errado"
print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# Exibe modo de operação
# Uso: print_mode "new" "Criando novo projeto"
print_mode() {
    local mode="$1"
    local description="${2:-}"
    echo -e "${MAGENTA}◆${NC} Modo: ${BOLD}${mode}${NC} ${description}"
}

# Exibe sumário final de operação
# Uso: print_summary "modo" "stack"
print_summary() {
    local mode="${1:-full}"
    local stack="${2:-generic}"
    
    # Header do Summary
    local title="Operação Concluída com Sucesso!"
    local clean_title="  ${title}" # Espaços antes
    local inner_width=64
    local pad_len=$((inner_width - ${#clean_title}))
    [[ $pad_len -lt 0 ]] && pad_len=0
    local display_title="  ${GREEN}${title}${NC}"

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║${NC}%b%*s${CYAN}║${NC}\n" "${display_title}" "$pad_len" ""
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}║${NC}  Diretórios criados: %-42s${CYAN}║${NC}\n" "$AIDEV_DIRS_CREATED"
    printf "${CYAN}║${NC}  Arquivos criados:   %-42s${CYAN}║${NC}\n" "$AIDEV_FILES_CREATED"
    printf "${CYAN}║${NC}  Modo:               %-42s${CYAN}║${NC}\n" "$mode"
    printf "${CYAN}║${NC}  Stack:              %-42s${CYAN}║${NC}\n" "$stack"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Exibe separador visual
# Uso: print_separator
print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
}

# Exibe seção com título
# Uso: print_section "Nome da Seção"
print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}▸ $1${NC}"
    echo ""
}

# Desenha uma barra de progresso horizontal
# Uso: print_progress <percentual> [largura] [estilo]
print_progress() {
    local percent="${1:-0}"
    local width="${2:-30}"
    local style="${3:-full}"
    
    # Garante que percent seja numérico entre 0 e 100
    percent=${percent%.*}
    [[ $percent -lt 0 ]] && percent=0
    [[ $percent -gt 100 ]] && percent=100
    
    local filled=$(( (percent * width) / 100 ))
    local empty=$(( width - filled ))
    
    local bar_char=$( [ "$style" = "full" ] && echo "█" || echo "=" )
    local empty_char=$( [ "$style" = "full" ] && echo "░" || echo " " )
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="$bar_char"; done
    for ((i=0; i<empty; i++)); do bar+="$empty_char"; done
    
    local color=$GREEN
    if [ $percent -lt 40 ]; then color=$RED
    elif [ $percent -lt 80 ]; then color=$YELLOW
    fi
    
    echo -e "[${color}${bar}${NC}] ${percent}%"
}

# ============================================================================
# Funções de Debug (opcional)
# ============================================================================

# Exibe mensagem de debug (somente se AIDEV_DEBUG=true)
# Uso: print_debug "Mensagem de debug"
print_debug() {
    if [ "${AIDEV_DEBUG:-false}" = "true" ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $1" >&2
    fi
}

# ============================================================================
# Reset de contadores
# ============================================================================

# Reseta contadores para nova operação
# Uso: reset_counters
reset_counters() {
    AIDEV_FILES_CREATED=0
    AIDEV_DIRS_CREATED=0
}

# Incrementa contador de arquivos
# Uso: increment_files
increment_files() {
    ((AIDEV_FILES_CREATED++)) || true
}

# Incrementa contador de diretórios
# Uso: increment_dirs
increment_dirs() {
    ((AIDEV_DIRS_CREATED++)) || true
}

# Resolve caminhos dinamicamente (expande $HOME, ~, etc)
# Uso: resolved=$(resolve_path "$path")
resolve_path() {
    local path="$1"
    
    # Substitui ~ pelo HOME atual
    if [[ "$path" == "~"* ]]; then
        path="${path/#\~/$HOME}"
    fi
    
    # Substitui literal $HOME pelo valor da variável
    path="${path/\$HOME/$HOME}"
    
    echo "$path"
}

# ============================================================================
# Persistência de Estado (Sessão)
# ============================================================================

# Define um valor no estado persistente (JSON)
# Uso: set_state_value "key" "value"
set_state_value() {
    local key="$1"
    local value="$2"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local state_file="$install_path/.aidev/state/session.json"
    
    mkdir -p "$(dirname "$state_file")"
    
    # Inicializa arquivo se não existir
    if [ ! -f "$state_file" ]; then
        echo "{}" > "$state_file"
    fi
    
    # Atualiza via jq ou fallback
    if command -v jq >/dev/null 2>&1; then
        local tmp_file
        tmp_file=$(mktemp)
        jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$state_file" > "$tmp_file" && mv "$tmp_file" "$state_file"
    else
        # Fallback via sed/grep para casos ultra-mínimos (apenas para strings simples)
        # ALERTA: Não suporta arrays ou objetos complexos, apenas pares chave-valor simples
        local tmp_file=$(mktemp)
        if grep -q "\"$key\":" "$state_file"; then
            # Atualiza existente
            sed "s/\"$key\": \".*\"/\"$key\": \"$value\"/" "$state_file" > "$tmp_file"
        else
            # Adiciona novo (antes do último })
            sed "s/}$/  \"$key\": \"$value\",\n}/" "$state_file" > "$tmp_file"
            # Limpa vírgula extra se for o caso
            sed -i 's/,\n}/\n}/g' "$tmp_file"
        fi
        mv "$tmp_file" "$state_file"
        print_warning "JQ não encontrado. Usando fallback básico para persistência."
    fi
    
    print_debug "Estado atualizado: $key=$value"
}

# Obtém um valor do estado persistente (JSON)
# Uso: value=$(get_state_value "key" ["default"])
get_state_value() {
    local key="$1"
    local default="${2:-}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local state_file="$install_path/.aidev/state/session.json"
    
    if [ ! -f "$state_file" ]; then
        echo "$default"
        return 0
    fi
    
    local value=""
    if command -v jq >/dev/null 2>&1; then
        value=$(jq -r --arg key "$key" '.[$key] // empty' "$state_file" 2>/dev/null || echo "")
    fi
    
    # Se JQ falhou ou não retornou nada, tenta o fallback
    if [ -z "$value" ]; then
        # Fallback simples via grep/sed
        value=$(grep "\"$key\":" "$state_file" | sed "s/.*\"$key\": \"\(.*\)\".*/\1/" | head -n 1 || echo "")
    fi
    
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# ============================================================================
# Gestão de Segredos (.env)
# ============================================================================

# Carrega variáveis de um arquivo .env se ele existir
# Uso: load_env ["path/to/.env"]
load_env() {
    local env_file="${1:-${CLI_INSTALL_PATH:-.}/.env}"
    
    if [ -f "$env_file" ]; then
        print_debug "Carregando variáveis de $env_file"
        # Lê linha por linha ignorando comentários e exportando
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Remove whitespace
            key=$(echo "$key" | xargs)
            # Ignora linhas vazias ou comentários
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            
            # Remove aspas do valor se existirem
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            export "$key"="$value"
        done < "$env_file"
    fi
}

# Define ou atualiza uma variável no arquivo .env
# Uso: set_env_value "KEY" "VALUE" ["path/to/.env"]
set_env_value() {
    local key="$1"
    local value="$2"
    local env_file="${3:-${CLI_INSTALL_PATH:-.}/.env}"
    
    mkdir -p "$(dirname "$env_file")"
    [ ! -f "$env_file" ] && touch "$env_file"
    
    if grep -q "^$key=" "$env_file"; then
        # Atualiza existente
        sed -i "s|^$key=.*|$key=\"$value\"|" "$env_file"
    else
        # Adiciona novo
        echo "$key=\"$value\"" >> "$env_file"
    fi
    
    # Exporta para a sessão atual também
    export "$key"="$value"
    print_debug "Variável $key definida em $env_file"
}