#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - Module Loader
# ============================================================================
# Sistema de carregamento de módulos com verificação de dependências
# 
# Uso: source lib/loader.sh
# ============================================================================

# Diretório base do aidev (detectado automaticamente)
AIDEV_LIB_DIR="${AIDEV_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
AIDEV_ROOT_DIR="${AIDEV_ROOT_DIR:-$(dirname "$AIDEV_LIB_DIR")}"

# Módulos carregados
declare -a LOADED_MODULES=()

# ============================================================================
# Carregamento de Módulos
# ============================================================================

# Carrega um módulo pelo nome
# Uso: load_module "core"
load_module() {
    local module_name="$1"
    local module_path="$AIDEV_LIB_DIR/${module_name}.sh"
    
    # Verifica se já foi carregado
    if module_loaded "$module_name"; then
        return 0
    fi
    
    # Verifica se existe
    if [ ! -f "$module_path" ]; then
        echo "ERRO: Módulo não encontrado: $module_name" >&2
        echo "Caminho esperado: $module_path" >&2
        return 1
    fi
    
    # Carrega o módulo
    # shellcheck source=/dev/null
    source "$module_path"
    
    # Registra como carregado
    LOADED_MODULES+=("$module_name")
    
    return 0
}

# Verifica se módulo já foi carregado
# Uso: module_loaded "core" && echo "já carregado"
module_loaded() {
    local module_name="$1"
    local mod
    
    for mod in "${LOADED_MODULES[@]}"; do
        if [ "$mod" = "$module_name" ]; then
            return 0
        fi
    done
    
    return 1
}

# ============================================================================
# Carregamento com Dependências
# ============================================================================

# Carrega módulo e suas dependências
# Uso: load_module_with_deps "detection"
load_module_with_deps() {
    local module_name="$1"
    
    # Mapa de dependências
    case "$module_name" in
        "core")
            # Sem dependências
            ;;
        "file-ops")
            load_module "core"
            ;;
        "detection")
            load_module "core"
            ;;
        "cli")
            load_module "core"
            ;;
        "templates")
            load_module "core"
            load_module "file-ops"
            ;;
        "yaml-parser")
            load_module "core"
            ;;
        "config-merger")
            load_module "core"
            load_module "yaml-parser"
            ;;
        "mcp")
            load_module "core"
            load_module "file-ops"
            load_module "detection"
            ;;
        "orchestration")
            load_module "core"
            load_module "file-ops"
            load_module "detection"
            ;;
        "state")
            load_module "core"
            load_module "file-ops"
            load_module "detection"
            ;;
        "validation")
            load_module "core"
            load_module "file-ops"
            load_module "detection"
            ;;
        "memory")
            load_module "core"
            ;;
        "system")
            load_module "core"
            load_module "file-ops"
            ;;
        "release")
            load_module "core"
            ;;
        "sprint-manager")
            load_module "core"
            ;;
        "manifest")
            load_module "core"
            ;;
        "upgrade")
            load_module "core"
            load_module "manifest"
            ;;
        "llm-guard")
            load_module "core"
            load_module "file-ops"
            load_module "manifest"
            load_module "state"
            ;;
        "migration")
            load_module "core"
            load_module "state"
            ;;
        *)
            # Módulo desconhecido, tenta carregar core como dependência base
            load_module "core" 2>/dev/null || true
            ;;
    esac
    
    # Carrega o módulo em si
    load_module "$module_name"
}

# ============================================================================
# Carregamento em Lote
# ============================================================================

# Carrega múltiplos módulos
# Uso: load_modules "core" "file-ops" "detection"
load_modules() {
    local mod
    for mod in "$@"; do
        load_module "$mod" || return 1
    done
}

# Carrega todos os módulos essenciais
# Uso: load_essential_modules
load_essential_modules() {
    load_module "core"
    load_module "i18n"
    load_module "file-ops"
    load_module "detection"
    load_module "cli"
}

# Carrega todos os módulos disponíveis
# Uso: load_all_modules
load_all_modules() {
    local module_file
    
    for module_file in "$AIDEV_LIB_DIR"/*.sh; do
        if [ -f "$module_file" ] && [ "$(basename "$module_file")" != "loader.sh" ]; then
            local module_name
            module_name=$(basename "$module_file" .sh)
            load_module "$module_name" || true
        fi
    done
}

# ============================================================================
# Informações
# ============================================================================

# Lista módulos carregados
# Uso: list_loaded_modules
list_loaded_modules() {
    local mod
    for mod in "${LOADED_MODULES[@]}"; do
        echo "$mod"
    done
}

# Lista módulos disponíveis
# Uso: list_available_modules
list_available_modules() {
    local module_file
    
    for module_file in "$AIDEV_LIB_DIR"/*.sh; do
        if [ -f "$module_file" ]; then
            basename "$module_file" .sh
        fi
    done
}

# Conta módulos carregados
# Uso: count_loaded_modules
count_loaded_modules() {
    echo "${#LOADED_MODULES[@]}"
}

# ============================================================================
# Auto-carregamento do core (sempre necessário)
# ============================================================================

# Carrega core automaticamente se este script for sourcado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Este script deve ser sourced, não executado diretamente."
    echo "Uso: source lib/loader.sh"
    exit 1
fi

# Tenta carregar core e i18n se existirem
if [ -f "$AIDEV_LIB_DIR/core.sh" ] && ! module_loaded "core"; then
    # shellcheck source=/dev/null
    source "$AIDEV_LIB_DIR/core.sh"
    LOADED_MODULES+=("core")
fi

if [ -f "$AIDEV_LIB_DIR/i18n.sh" ] && ! module_loaded "i18n"; then
    # shellcheck source=/dev/null
    source "$AIDEV_LIB_DIR/i18n.sh"
    LOADED_MODULES+=("i18n")
fi
