#!/usr/bin/env bash
# lib/commands/utils.sh — DEVORQ Utils Commands
#
# Comandos: version, upgrade, uninstall, build, stats
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

utils::help() {
    cat << 'EOF'
UTILS COMMANDS:
  version                   Mostrar versão
  upgrade                  Atualizar DEVORQ
  uninstall               Desinstalar DEVORQ
  build                   Self-build (test + gates)
  stats                   Estatísticas
EOF
}

# ============================================================
# version
# ============================================================

devorq::cmd_version() {
    echo "DEVORQ v${DEVORQ_VERSION}"
}

# ============================================================
# upgrade
# ============================================================

devorq::cmd_upgrade() {
    devorq::info "Atualizando DEVORQ..."
    local current_version
    current_version=$(cat "${DEVORQ_ROOT}/.devorq/version" 2>/dev/null || echo "desconhecida")
    devorq::info "Versão atual: $current_version"

    if [ -d "${DEVORQ_ROOT}/.git" ]; then
        git -C "${DEVORQ_ROOT}" pull || devorq::error "Git pull falhou"
        local new_version
        new_version=$(cat "${DEVORQ_ROOT}/.devorq/version" 2>/dev/null || echo "desconhecida")
        devorq::success "Atualizado: $current_version -> $new_version"

        # Re-roda build para confirmar integridade
        devorq::info "Executando devorq build para validar..."
        devorq::cmd_build
    else
        devorq::error "Não é um clone git — use install.sh"
    fi
}

# ============================================================
# uninstall
# ============================================================

devorq::cmd_uninstall() {
    devorq::warn "Isto vai REMOVER TODO o diretorio ${DEVORQ_ROOT} (inclusive .devorq/)."
    if [[ ! -t 0 ]]; then
        devorq::error "uninstall requer confirmacao interativa (rode num terminal)"
        return 1
    fi
    echo -n "Digite 'yes' para confirmar: "
    local confirm
    read -r confirm
    if [[ "$confirm" != "yes" ]]; then
        devorq::info "Cancelado — nada removido."
        return 0
    fi

    rm -rf "${DEVORQ_ROOT}"
    devorq::success "Removido de ${DEVORQ_ROOT}"
    devorq::info "Execute 'rm -f ~/bin/devorq' para remover o symlink"
}

# ============================================================
# build
# ============================================================

devorq::cmd_build() {
    devorq::info "═══ DEVORQ Self-Build ═══"
    devorq::info "Executando teste + gates 1-7 no repositório DEVORQ..."
    echo ""

    # Self-build sempre opera no repo DEVORQ, não no projeto atual
    local original_pwd="$PWD"
    cd "${DEVORQ_ROOT}"

    # Carregar módulos necessários
    source "${DEVORQ_LIB}/commands/test.sh"
    source "${DEVORQ_LIB}/commands/workflow.sh"

    # Etapa 1: checagem de estrutura (sintaxe) — função renomeada (DQ-001)
    devorq::info "── Etapa 1: checagem de estrutura ──"
    if ! devorq::cmd_structure_check; then
        devorq::warn "checagem de estrutura falhou"
    fi
    echo ""

    # Etapa 2: gates de codigo (1-7). GATE-0/0.5 (foundation) sao pulados de
    # proposito no self-build; reportamos a contagem REAL — nao um "7/7" fixo
    # que escondia o subset (DQ-028).
    local failed=0 total=0
    for gate in 1 2 3 4 5 6 7; do
        total=$((total + 1))
        devorq::info "── Etapa 2: Gate $gate ──"
        if ! devorq::cmd_gate "$gate"; then
            echo "[FAIL] Gate $gate falhou" >&2
            failed=$((failed+1))
        fi
    done

    cd "$original_pwd"

    echo ""
    devorq::info "═══ Resultado ═══"
    if [ $failed -eq 0 ]; then
        devorq::success "Build OK — ${total}/${total} gates de codigo (1-7) verdes"
        devorq::info "Sistema pronto para self-building"
        return 0
    else
        echo "[ERROR] $failed de $total gate(s) de codigo falhou(aram)" >&2
        return 1
    fi
}

# ============================================================
# stats
# ============================================================

devorq::cmd_stats() {
    # Stats sempre opera no repo DEVORQ (como build)
    local original_pwd="$PWD"
    cd "${DEVORQ_ROOT}"

    source "${DEVORQ_LIB}/stats.sh" 2>/dev/null || true
    if declare -f stats::summary &>/dev/null; then
        stats::summary
    else
        devorq::warn "lib/stats.sh não disponível"
    fi

    cd "$original_pwd"
}
