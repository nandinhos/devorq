#!/usr/bin/env bash
# lib/commands/foundation.sh — DEVORQ Foundation Commands
#
# Comandos: foundation
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

foundation::help() {
    cat << 'EOF'
FOUNDATION COMMANDS:
  foundation                 Project Foundation
  foundation status          Mostra status dos 5 foundation docs
  foundation create [doc]   Wizard interativo
  foundation validate       Valida todos os 5 docs
  foundation migrate        Migra de SPEC.md
  foundation edit <doc>    Abre doc para edição
EOF
}

# ============================================================
# foundation
# ============================================================

devorq::cmd_foundation() {
    local action="${1:-status}"
    local foundation_root="${DEVORQ_ROOT}/skills/project-foundation"
    local scripts_dir="${foundation_root}/scripts"
    local foundation_dir="${PWD}/.devorq/state"

    # Setup cores para TTY
    local _GREEN='' _YELLOW='' _CYAN='' _RED='' _RESET=''
    if [ -t 1 ]; then
        _GREEN='\033[0;32m'
        _YELLOW='\033[0;33m'
        _CYAN='\033[0;36m'
        _RED='\033[0;31m'
        _RESET='\033[0m'
    fi

    case "$action" in
        status)
            devorq::info "Project Foundation Status"
            echo ""
            for doc in 5w2h premissas riscos requisitos restricoes; do
                local f="${foundation_dir}/${doc}.json"
                if [ -f "$f" ]; then
                    local size
                    size=$(wc -c < "$f" 2>/dev/null || echo "0")
                    if [ "$size" -gt 50 ]; then
                        echo "  ${_GREEN}[OK]${_RESET} ${doc}.json"
                    else
                        echo "  ${_YELLOW}[EMPTY]${_RESET} ${doc}.json"
                    fi
                else
                    echo "  ${_RED}[MISSING]${_RESET} ${doc}.json"
                fi
            done
            echo ""
            devorq::info "Execute: devorq foundation validate"
            ;;
        create)
            local doc_filter="${2:-all}"
            if [ ! -t 0 ] && [ ! -t 1 ]; then
                devorq::error "foundation create requer terminal interativo"
            fi
            if bash "${scripts_dir}/foundation-wizard.sh" "$doc_filter"; then
                devorq::success "Foundation docs criados"
            else
                devorq::fail "Erro ao criar foundation docs"
            fi
            ;;
        validate)
            if bash "${scripts_dir}/foundation-validate.sh" "$foundation_dir"; then
                exit 0
            else
                exit 1
            fi
            ;;
        migrate)
            if bash "${scripts_dir}/foundation-migrate.sh" 2>/dev/null; then
                devorq::success "Migracao concluida"
            else
                devorq::warn "Migracao com problemas - verifique os docs"
            fi
            ;;
        edit)
            local doc="${2:-}"
            if [ -z "$doc" ]; then
                devorq::error "Uso: devorq foundation edit <5w2h|premissas|riscos|requisitos|restricoes>"
            fi
            local valid_docs="5w2h premissas riscos requisitos restricoes"
            if ! echo "$valid_docs" | grep -qw "$doc"; then
                devorq::error "Doc invalido: '$doc' (validos: $valid_docs)"
            fi
            local f="${foundation_dir}/${doc}.json"
            if [ ! -f "$f" ]; then
                devorq::error "${doc}.json nao existe - use devorq foundation create"
            fi
            devorq::info "Editando ${doc}.json..."
            devorq::info "Para editar diretamente: $EDITOR $f"
            if command -v "${EDITOR:-nano}" &>/dev/null; then
                "${EDITOR:-nano}" "$f"
            else
                cat "$f"
            fi
            ;;
        *)
            devorq::info "DEVORQ Project Foundation"
            echo ""
            echo "USO: devorq foundation <comando>"
            echo ""
            echo "COMANDOS:"
            echo "  status              Mostra status dos 5 foundation docs"
            echo "  create [doc]        Wizard interativo (doc=all|5w2h|premissas|riscos|requisitos|restricoes)"
            echo "  validate            Valida todos os 5 docs (GATE-0.5)"
            echo "  migrate             Migra de SPEC.md existente"
            echo "  edit <doc>          Abre doc para edicao (5w2h|premissas|riscos|requisitos|restricoes)"
            echo ""
            echo "EXEMPLOS:"
            echo "  devorq foundation status"
            echo "  devorq foundation create"
            echo "  devorq foundation create 5w2h"
            echo "  devorq foundation validate"
            ;;
    esac
}
