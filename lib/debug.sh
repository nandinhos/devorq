#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/debug.sh — DEVORQ Systematic Debugging
#
# Implementa: Systematic Debugging Skill (4-phase root cause)
# Princípio: NENHUM fix sem investigação de causa raiz
#
# Funcionalidades:
#   debug::check  — Verificação passiva (GATE-7)
#   devorq debug  — Workflow interativo de debug sistemático
#
# Regra de Ouro: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST

set -euo pipefail

RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
debug::colors::init() {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
}
debug::colors::init

# ============================================================
# debug::fail / warn / info / pass — logging
# ============================================================

debug::fail() { echo -e "${RED}[FAIL]${RESET} $*" >&2; }
debug::warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
debug::info() { echo -e "${CYAN}[INFO]${RESET} $*"; }
debug::pass() { echo -e "${GREEN}[PASS]${RESET} $*"; }
debug::step() { echo -e "${BOLD}[PHASE $*]${RESET}"; }

# ============================================================
# debug::check — GATE-7 passive check
# ============================================================
# Called by GATE-7. Verifies no unresolved problems.
# Returns 0 if clean, 1 if problems detected.
# Does NOT attempt fixes — just identifies issues.

debug::check() {
    local ctx_file="${PWD}/.devorq/state/context.json"
    local problems=0

    debug::info "Systematic Debugging — verificando estado..."

    # Check 1: há contexto?
    if [ ! -f "$ctx_file" ]; then
        debug::pass "Nenhum projeto .devorq/ detectado"
        return 0
    fi

    # Check 2: hay errors registrados?
    if command -v jq &>/dev/null; then
        local errors
        errors=$(jq -r '.errors // [] | length' "$ctx_file" 2>/dev/null || echo "0")
        if [ "$errors" -gt 0 ]; then
            debug::warn "Projeto tem $errors erro(s) registrado(s) em context.json"
            problems=$((problems+1))
        fi
    fi

    # Check 3: recent test failures?
    local test_result="${PWD}/.devorq/state/last_test.json"
    if [ -f "$test_result" ]; then
        if command -v jq &>/dev/null; then
            local passed
            passed=$(jq -r '.passed // true' "$test_result" 2>/dev/null)
            if [ "$passed" = "false" ]; then
                debug::warn "Último teste falhou — use 'devorq debug' para investigar"
                problems=$((problems+1))
            fi
        fi
    fi

    # Check 4: gates pendentes em ciclo?
    if command -v jq &>/dev/null; then
        local stuck_gates
        stuck_gates=$(jq -r '.stuck_gates // [] | length' "$ctx_file" 2>/dev/null || echo "0")
        if [ "$stuck_gates" -gt 2 ]; then
            debug::warn "Gate(s) travado(s) detectado(s) — investigação necessária"
            problems=$((problems+1))
        fi
    fi

    if [ $problems -eq 0 ]; then
        debug::pass "Nenhum problema detectado — GATE-7 OK"
        return 0
    else
        debug::warn "$problems problema(s) encontrado(s)"
        debug::info "Execute 'devorq debug' para iniciar investigação sistemática"
        return 1
    fi
}

# ============================================================
# devorq debug — Workflow interativo (4 fases)
# ============================================================
# Wrapper CLI: `devorq debug [erro_msg]`
# Se erro_msg fornecido, pula Phase 1 e usa direto.

devorq::debug() {
    local error_msg="${1:-}"

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  DEVORQ Systematic Debugging Workflow${RESET}"
    echo -e "${BOLD}  Regra: SEM causa raiz = SEM fix${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo ""

    local phase=1
    local root_cause=""
    local fix_attempts=0

    # --- PHASE 1: Root Cause Investigation ---
    if [ -z "$error_msg" ]; then
        debug::step "1 — Investigação de Causa Raiz"
        echo ""
        echo "Colete informações sobre o problema:"
        echo "  1. Qual é a mensagem de erro exata?"
        echo "  2. Quais são os passos para reproduzir?"
        echo "  3. Quando começou a falhar? (última mudança)"
        echo ""
        echo -n "Cole a mensagem de erro (ou Enter se já tiver): "
        read -r error_msg
    fi

    if [ -n "$error_msg" ]; then
        echo ""
        debug::info "Erro reportado: $error_msg"

        # Tenta detectar tipo de erro
        local error_type="unknown"
        case "$error_msg" in
            *"syntax error"*)      error_type="syntax" ;;
            *"command not found"*) error_type="missing_dep" ;;
            *"permission denied"*) error_type="permission" ;;
            *"not found"*)         error_type="missing_file" ;;
            *"failed"*)            error_type="failure" ;;
            *"error"*)             error_type="generic_error" ;;
        esac
        debug::info "Tipo de erro detectado: $error_type"

        # Checklist Phase 1
        echo ""
        echo "── Phase 1 Checklist ──"
        echo "  [ ] Mensagem de erro lida com atenção? $([ -n "$error_msg" ] && echo '✓' || echo '○')"
        echo "  [ ] Erro reproduzido com sucesso?      ○"
        echo "  [ ] Mudanças recentes identificadas?   ○"
        echo "  [ ] Sistema com múltiplos componentes? ○"
        echo ""
    fi

    echo -n "Pressione Enter quando Phase 1 estiver completa (ou 'skip' para pular): "
    read -r p1_ready
    if [ "$p1_ready" = "skip" ]; then
        debug::warn "Phase 1 pulada — risco de fix sem causa raiz"
    fi

    # --- PHASE 2: Pattern Analysis ---
    debug::step "2 — Análise de Padrão"
    echo ""
    echo "Antes de propor fixes, identifique o padrão:"
    echo "  1. Existe código similar que funciona? Onde?"
    echo "  2. O que é diferente entre o que funciona e o que não?"
    echo "  3. Quais dependências/configs estão envolvidas?"
    echo ""

    echo -n "Pressione Enter quando Phase 2 estiver completa: "
    read -r p2_ready

    # --- PHASE 3: Hypothesis ---
    debug::step "3 — Hipótese"
    echo ""
    echo "Formule uma hipótese clara:"
    echo "  'Eu acho que X é a causa porque Y'"
    echo ""
    echo -n "Sua hipótese: "
    read -r hypothesis
    if [ -z "$hypothesis" ]; then
        debug::fail "Hipótese vazia — não prossiga sem entender o problema"
        return 1
    fi
    debug::info "Hipótese: $hypothesis"

    # Rule of 3 check
    echo ""
    echo "── Validação da Hipótese ──"
    echo -n "A hipótese explica TODO o comportamento? (s/n): "
    read -r validates
    if [ "$validates" != "s" ] && [ "$validates" != "S" ]; then
        debug::warn "Hipótese incompleta — retorne à Phase 1"
        return 1
    fi

    # --- PHASE 4: Implementation ---
    debug::step "4 — Implementação do Fix"
    echo ""
    echo "Agora sim, faça o menor fix possível para testar a hipótese."
    echo "Regra: 1 variável por vez. Sem 'while I'm here'."
    echo ""

    # Rule of 3: if 3+ failed attempts already, question architecture
    if [ $fix_attempts -ge 3 ]; then
        debug::fail "3+ tentativas de fix falharam"
        debug::warn "PADRÃO ARQUITETURAL DETECTADO — não continue tentando fixes"
        debug::info "Questione: a arquitetura atual é a escolha certa?"
        debug::info "Discuta com usuário antes de continuar."
        return 1
    fi

    echo -n "Fix implementado e testado? (s/n): "
    read -r fixed
    if [ "$fixed" = "s" ] || [ "$fixed" = "S" ]; then
        debug::pass "Fix implementado com sucesso!"
        debug::info "Registre a lição aprendida:"
        debug::info "  devorq lessons capture '<título>' '<problema>' '<solução>'"
        return 0
    fi

    debug::warn "Fix não funcionou — tente nova hipótese"
    debug::info "Retorne à Phase 3 com nova teoria"
    return 1
}

# ============================================================
# debug::trace — Trace utilitário para Phase 1
# ============================================================
# Uso: debug::trace <função|variável> <escopo>
# Exemplo: debug::trace "minha_fução" "src/main.sh"

debug::trace() {
    local target="${1:-}"
    local scope="${2:-.}"

    if [ -z "$target" ]; then
        echo "[ERROR] Uso: debug::trace <função|variável> [escopo]"
        return 1
    fi

    echo "── Trace: $target em $scope ──"

    # Find function definitions
    if declare -f "$target" &>/dev/null; then
        echo "[FOUND] Função '$target' definida:"
        declare -f "$target"
    else
        echo "[SEARCH] Buscando '$target' em $scope..."
        grep -rn --include="*.sh" "$target" "$scope" 2>/dev/null || \
            echo "[NOT FOUND] '$target' não encontrado em $scope"
    fi
}

# ============================================================
# debug::recent_changes — Phase 1 helper
# ============================================================
# Mostra mudanças recentes no git

debug::recent_changes() {
    if [ -d ".git" ]; then
        echo "── Mudanças Recentes (git log) ──"
        git log --oneline -10 2>/dev/null || echo "git não disponível"
        echo ""
        echo "── Uncommitted Changes ──"
        git diff --stat 2>/dev/null || echo "sem changes"
    else
        echo "[INFO] Não é um repositório git"
    fi
}
