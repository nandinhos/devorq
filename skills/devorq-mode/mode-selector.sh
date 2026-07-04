#!/usr/bin/env bash
# devorq-mode/scripts/mode-selector.sh
# Detecção automática ou manual do modo de implementação DEVORQ
#
# Uso:
#   devorq-mode/mode-selector.sh [auto|classic|<intent>]
#
# Se nenhum argumento: detecta automaticamente via keywords
# e exibe menu se ambiguo

set -euo pipefail

MODE="${1:-}"
PROJECT_ROOT="${2:-$(pwd)}"

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

info()   { echo "[DEVORQ-MODE] $*"; }
warn()   { echo "[DEVORQ-MODE] WARN: $*"; }
error()  { echo "[DEVORQ-MODE] ERROR: $*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────
# Detecção de modo via keywords
# ──────────────────────────────────────────────────────────────

_is_auto() {
    [[ "${MODE,,}" =~ (auto|autonomous|ralph|story.by.story|modo.auto|autom.tico|story.by.story|story-by-story) ]]
}

_is_classic() {
    [[ "${MODE,,}" =~ (classic|manual|tradicional|direto|modo.classic|cl.ssico|implementar.direto) ]]
}

# ──────────────────────────────────────────────────────────────
# Validação do projeto
# ──────────────────────────────────────────────────────────────

validate_project() {
    local spec="${PROJECT_ROOT}/SPEC.md"
    local devorq_dir="${PROJECT_ROOT}/.devorq"

    if [ ! -f "$spec" ]; then
        error "SPEC.md não encontrado em ${PROJECT_ROOT}"
    fi

    if [ ! -d "$devorq_dir" ]; then
        warn ".devorq/ não encontrado — executando devorq init..."
        devorq init 2>/dev/null || true
    fi

    return 0
}

# ──────────────────────────────────────────────────────────────
# Mostrar status do projeto
# ──────────────────────────────────────────────────────────────

show_project_status() {
    local ctx_file="${PROJECT_ROOT}/.devorq/state/context.json"

    echo ""
    echo "═══════════════════════════════════════"
    echo "⚡ DEVORQ — Mode Selector"
    echo "═══════════════════════════════════════"

    # Project name
    local project_name="${PROJECT_ROOT##*/}"
    if [ -f "$ctx_file" ]; then
        project_name=$(jq -r '.project // empty' "$ctx_file" 2>/dev/null || echo "${PROJECT_ROOT##*/}")
    fi
    echo " Project: $project_name"

    # Intent
    local intent=""
    if [ -f "$ctx_file" ]; then
        intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
    fi
    if [ -n "$intent" ]; then
        echo " Intent:  ${intent:0:60}..."
    else
        echo " Intent:  (não definido — use devorq context set intent)"
    fi

    # Stack
    local stack=""
    if [ -f "$ctx_file" ]; then
        stack=$(jq -r '.stack | join(", ") // ""' "$ctx_file" 2>/dev/null || echo "")
    fi
    if [ -n "$stack" ]; then
        echo " Stack:   [$stack]"
    fi

    # Stories (se AUTO)
    if [ -f "${PROJECT_ROOT}/prd.json" ]; then
        local total pending
        total=$(jq '.stories | length' "${PROJECT_ROOT}/prd.json" 2>/dev/null || echo "0")
        pending=$(jq '[.stories[] | select((.passes != true) and (.status != "done" and .status != "complete"))] | length' "${PROJECT_ROOT}/prd.json" 2>/dev/null || echo "0")
        echo " Stories: $pending pendentes / $total total"
    fi

    echo "───────────────────────────────────────"
}

# ──────────────────────────────────────────────────────────────
# Main logic
# ──────────────────────────────────────────────────────────────

main() {
    # Se argumento fornecido, detectar modo
    if [ -n "$MODE" ]; then
        validate_project

        if _is_auto; then
            # Checar se intent contém DDD keywords
            local ctx_file="${PROJECT_ROOT}/.devorq/state/context.json"
            local intent=""
            if [ -f "$ctx_file" ]; then
                intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
            fi
            if echo "$intent" | grep -qiE "domínio|ddd|modelagem|entidade|contexto|bounded|invariante"; then
                warn "DDD detectado no intent + modo AUTO"
                info "Sugestão: considere usar CLASSIC ou rodar: devorq ddd explore"
            fi
            echo "MODE=AUTO"
            return 0
        elif _is_classic; then
            echo "MODE=CLASSIC"
            return 0
        fi

        # Modo não reconhecido → perguntar
        warn "Modo '$MODE' não reconhecido"
    fi

    # Sem argumento → mostrar menu (chamado via Hermes Agent)
    show_project_status

    echo ""
    echo "⚡ Modo de implementação:"
    echo ""
    echo "  [1] 🤖 AUTO — story por story"
    echo "      delegate_task, contexto limpo por iteracao,"
    echo "      commit por story, mais robusto"
    echo ""
    echo "  [2] 📝 CLASSIC — gates 1-7 direto"
    echo "      implementacao direta, rapido,"
    echo "      ideal para tasks pequenas"
    echo ""
    echo "  [3] 🚀 AUTO [N] stories"
    echo "      auto com limite especifico"
    echo ""

    # Não exit aqui — Hermes Agent faz a pergunta real
    echo "MODE=ASK"
}

main "$@"
