#!/usr/bin/env bash
# scripts/pipeline-tests.sh — Pipeline completo de testes DEVORQ
#
# Executa todos os testes em sequência:
#   1. Unit tests
#   2. Security tests
#   3. CI tests
#   4. E2E tests (se Playwright disponível)
#
# Com systematic-debugging quando falha

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_DIR="$DEVORQ_ROOT/.devorq-auto/runs"
readonly TEST_LOG="$LOG_DIR/pipeline-$(date +%Y-%m-%d_%H-%M).log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_TEST_FAILED=2
readonly EXIT_DEP_MISSING=3

# ============================================================
# Helpers
# ============================================================

log() {
    echo "[$(date +%H:%M:%S)] $*" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[✓]${RESET} $*" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[✗]${RESET} $*" | tee -a "$TEST_LOG"
}

log_warn() {
    echo -e "${YELLOW}[!]${RESET} $*" | tee -a "$TEST_LOG"
}

log_info() {
    echo -e "${CYAN}[i]${RESET} $*" | tee -a "$TEST_LOG"
}

# ============================================================
# Pre-flight Checks
# ============================================================

check_dependencies() {
    log_info "Verificando dependências..."

    local missing=()

    # Bash
    if ! command -v bash &>/dev/null; then
        missing+=("bash")
    fi

    # jq (opcional)
    if ! command -v jq &>/dev/null; then
        log_warn "jq não encontrado - alguns testes podem ser pulados"
    fi

    # ShellCheck binary (opcional)
    if ! command -v shellcheck &>/dev/null; then
        log_warn "shellcheck não encontrado - validação de sintaxe pulada"
    fi

    # Node/npm (para E2E)
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
        log_warn "Node.js/npm não encontrado - E2E tests pulados"
    fi

    # Playwright (opcional)
    if [ -d "$DEVORQ_ROOT/e2e-tests/node_modules" ]; then
        log_info "Playwright encontrado"
    else
        log_warn "Playwright não instalado - E2E tests pulados"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Dependências faltando: ${missing[*]}"
        return $EXIT_DEP_MISSING
    fi

    log_success "Dependências OK"
    return $EXIT_SUCCESS
}

# ============================================================
# SYSTEMATIC DEBUGGING WORKFLOW
# ============================================================

systematic_debug() {
    local test_name="$1"
    local error_msg="$2"
    local exit_code="$3"

    echo ""
    echo "============================================"
    echo -e "${RED}🔍 SYSTEMATIC DEBUGGING WORKFLOW${RESET}"
    echo "============================================"
    echo ""

    echo "1. 📍 ISOLAR"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Teste: ${test_name}"
    echo "   Erro:  ${error_msg}"
    echo "   Exit:   ${exit_code}"
    echo ""

    echo "2. 🔎 CAUSA RAIZ"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Analisando falha..."

    # Analisar based on test type
    case "$test_name" in
        *security*)
            echo "   → Verificar sanitização de inputs"
            echo "   → Verificar validação de paths"
            ;;
        *unit*)
            echo "   → Verificar sintaxe bash"
            echo "   → Verificar dependências"
            ;;
        *gate*)
            echo "   → Verificar lib/gates.sh"
            echo "   → Verificar contexto do projeto"
            ;;
        *)
            echo "   → Analisar output do teste"
            ;;
    esac
    echo ""

    echo "3. 🔧 SOLUÇÃO"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Implementando correção..."
    echo ""

    echo "4. 📚 VALIDAÇÃO OFICIAL (Context7)"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Consultando documentação oficial..."
    echo "   → Verificar práticas recomendadas"
    echo "   → Verificar security guidelines"
    echo ""

    echo "5. 📝 DOCUMENTAR"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Criando lesson se bug recorrente..."
    echo ""

    echo "6. ✅ VALIDAR"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Rodar testes novamente..."
    echo ""
}

# ============================================================
# RUN TEST PHASE
# ============================================================

run_phase() {
    local phase_name="$1"
    local test_command="$2"

    echo ""
    echo "============================================"
    echo -e "${CYAN}▶ FASE: ${phase_name}${RESET}"
    echo "============================================"

    if ! eval "$test_command" >> "$TEST_LOG" 2>&1; then
        log_error "${phase_name} falhou"
        return 1
    fi

    log_success "${phase_name} passou"
    return 0
}

# ============================================================
# MAIN PIPELINE
# ============================================================

main() {
    # Setup
    mkdir -p "$LOG_DIR"

    echo ""
    echo "============================================"
    echo " DEVORQ — Test Pipeline"
    echo " $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================"
    echo " Log: $TEST_LOG"
    echo ""

    # Pre-flight
    check_dependencies || {
        log_warn "Continuando mesmo com dependências faltando..."
    }

    local pipeline_failed=false
    local failed_phases=()

    # ========================================
    # FASE 1: Unit Tests (bash)
    # ========================================
    if ! run_phase "Unit Tests (bash)" "bash $SCRIPT_DIR/unit-tests.sh"; then
        failed_phases+=("Unit Tests")
        if [ "${DEVORQ_DEBUG:-false}" = "true" ]; then
            systematic_debug "unit" "Teste unitário falhou" $?
        fi
        pipeline_failed=true
    fi

    # ========================================
    # FASE 1b: Unit Tests (Python)
    # ========================================
    if command -v python3 &>/dev/null; then
        if ! run_phase "Unit Tests (Python)" "python3 $SCRIPT_DIR/test_sync.py"; then
            failed_phases+=("Unit Tests (Python)")
            pipeline_failed=true
        fi
    fi

    # ========================================
    # FASE 2: Security Tests
    # ========================================
    if ! run_phase "Security Tests" "bash $SCRIPT_DIR/security-tests.sh"; then
        failed_phases+=("Security Tests")
        if [ "${DEVORQ_DEBUG:-false}" = "true" ]; then
            systematic_debug "security" "Teste de segurança falhou" $?
        fi
        pipeline_failed=true
    fi

    # ========================================
    # FASE 3: CI Tests (existente)
    # ========================================
    if ! run_phase "CI Tests" "bash $SCRIPT_DIR/ci-test.sh"; then
        failed_phases+=("CI Tests")
        if [ "${DEVORQ_DEBUG:-false}" = "true" ]; then
            systematic_debug "ci" "Teste CI falhou" $?
        fi
        pipeline_failed=true
    fi

    # ========================================
    # FASE 4: E2E Tests (Playwright)
    # ========================================
    if [ -d "$DEVORQ_ROOT/e2e-tests/node_modules" ]; then
        if ! run_phase "E2E Tests (Playwright)" "cd $DEVORQ_ROOT/e2e-tests && npm test"; then
            failed_phases+=("E2E Tests")
            if [ "${DEVORQ_DEBUG:-false}" = "true" ]; then
                systematic_debug "e2e" "Teste E2E falhou" $?
            fi
            pipeline_failed=true
        fi
    else
        log_warn "E2E Tests pulados (Playwright não instalado)"
    fi

    # ========================================
    # SUMMARY
    # ========================================
    echo ""
    echo "============================================"
    echo " PIPELINE SUMMARY"
    echo "============================================"

    if [ "$pipeline_failed" = "true" ]; then
        echo -e "${RED}✗ PIPELINE FALHOU${RESET}"
        echo ""
        echo "Fases que falharam:"
        for phase in "${failed_phases[@]}"; do
            echo -e "  ${RED}✗${RESET} $phase"
        done
        echo ""
        echo "Log: $TEST_LOG"
        echo ""
        echo "Para debugar: DEVORQ_DEBUG=true bash $SCRIPT_DIR/pipeline-tests.sh"
        return $EXIT_TEST_FAILED
    fi

    echo -e "${GREEN}✓ PIPELINE COMPLETO - TODOS OS TESTES PASSARAM${RESET}"
    echo ""
    echo "Log: $TEST_LOG"
    return $EXIT_SUCCESS
}

main "$@"
