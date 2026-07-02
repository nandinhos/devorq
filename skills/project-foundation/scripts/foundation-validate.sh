#!/usr/bin/env bash
# skills/project-foundation/scripts/foundation-validate.sh
#
# Valida os 5 foundation docs — usado por GATE-0.5
# Retorna 0 se todos válidos, 1 se algum falta ou inválido, 2 se JSON malformado
#
# Uso: foundation-validate.sh <foundation_dir>

set -euo pipefail

FOUNDATION_DIR="${1:-.devorq/state}"

# Cores
RED='' GREEN='' YELLOW='' CYAN='' RESET=''
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
fi

# Status tracking
declare -a PASSED=()
declare -a FAILED=()
declare -a WARNINGS=()
EXIT_CODE=0

log()   { echo "[DEVORQ] $*"; }
pass()  { PASSED+=("$*"); }
fail()  { FAILED+=("$*"); EXIT_CODE=1; }
warn()  { WARNINGS+=("$*"); }
info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }

# Validar JSON bem formado
validate_json() {
    local file="$1"
    if ! command -v jq &>/dev/null; then
        # Fallback: tentar ler como JSON com bash
        if grep -q '^[[:space:]]*{' "$file" 2>/dev/null; then
            return 0
        fi
        return 1
    fi
    jq empty "$file" 2>/dev/null
    return $?
}

# Validar 5w2h.json — todos os 7 campos com description não-vazio
validate_5w2h() {
    local file="${FOUNDATION_DIR}/5w2h.json"

    if [ ! -f "$file" ]; then
        fail "5w2h.json não existe"
        return
    fi

    if ! validate_json "$file"; then
        fail "5w2h.json — JSON malformado"
        return
    fi

    if command -v jq &>/dev/null; then
        local empty_fields=$(jq -r '
            [.what.description, .why.description, .who.description, .when.description,
             .where.description, .how.description, .how_much.description]
            | map(select(. == null or . == "")) | length
        ' "$file" 2>/dev/null || echo "7")

        if [ "$empty_fields" -gt 0 ]; then
            fail "5w2h.json — ${empty_fields} campo(s) sem description"
        else
            pass "5w2h.json — todos os 7 campos preenchidos"
        fi
    else
        # Fallback sem jq
        local content=$(cat "$file")
        if echo "$content" | grep -q '"description"[[:space:]]*:[[:space:]]*""'; then
            fail "5w2h.json — campo(s) sem description"
        else
            pass "5w2h.json — todos os campos preenchidos (jq unavailable, basic check)"
        fi
    fi
}

# Validar premissas.json — pelo menos 1 item
validate_premissas() {
    local file="${FOUNDATION_DIR}/premissas.json"

    if [ ! -f "$file" ]; then
        fail "premissas.json não existe"
        return
    fi

    if ! validate_json "$file"; then
        fail "premissas.json — JSON malformado"
        return
    fi

    if command -v jq &>/dev/null; then
        local count=$(jq '.premissas | length' "$file" 2>/dev/null || echo "0")
        if [ "$count" -lt 1 ]; then
            fail "premissas.json — sem premissas (precisa pelo menos 1)"
        else
            pass "premissas.json — ${count} premissa(s)"
        fi
    else
        local content=$(cat "$file")
        if echo "$content" | grep -q '"premissas"\s*:\s*\[\s*\]'; then
            fail "premissas.json — array vazio"
        else
            pass "premissas.json — premissas presentes (jq unavailable)"
        fi
    fi
}

# Validar riscos.json — pelo menos 1 item com severity E mitigation
validate_riscos() {
    local file="${FOUNDATION_DIR}/riscos.json"

    if [ ! -f "$file" ]; then
        fail "riscos.json não existe"
        return
    fi

    if ! validate_json "$file"; then
        fail "riscos.json — JSON malformado"
        return
    fi

    if command -v jq &>/dev/null; then
        local count=$(jq '.riscos | length' "$file" 2>/dev/null || echo "0")
        if [ "$count" -lt 1 ]; then
            fail "riscos.json — sem riscos (precisa pelo menos 1)"
            return
        fi

        local without_severity=$(jq '[.riscos[] | select(.severity == null or .severity == "")] | length' "$file" 2>/dev/null || echo "0")
        local without_mitigation=$(jq '[.riscos[] | select(.mitigation == null or .mitigation == "")] | length' "$file" 2>/dev/null || echo "0")

        if [ "$without_severity" -gt 0 ] || [ "$without_mitigation" -gt 0 ]; then
            fail "riscos.json — ${count} risco(s) mas $([ "$without_severity" -gt 0 ] && echo "${without_severity} sem severity" || echo "0 sem severity"), $([ "$without_mitigation" -gt 0 ] && echo "${without_mitigation} sem mitigation" || echo "0 sem mitigation")"
        else
            pass "riscos.json — ${count} risco(s) com severity e mitigation"
        fi
    else
        local content=$(cat "$file")
        if echo "$content" | grep -q '"riscos"\s*:\s*\[\s*\]'; then
            fail "riscos.json — array vazio"
        else
            pass "riscos.json — riscos presentes (jq unavailable)"
        fi
    fi
}

# Validar requisitos.json — pelo menos 1 item com acceptance_criteria
validate_requisitos() {
    local file="${FOUNDATION_DIR}/requisitos.json"

    if [ ! -f "$file" ]; then
        fail "requisitos.json não existe"
        return
    fi

    if ! validate_json "$file"; then
        fail "requisitos.json — JSON malformado"
        return
    fi

    if command -v jq &>/dev/null; then
        local count=$(jq '.requisitos | length' "$file" 2>/dev/null || echo "0")
        if [ "$count" -lt 1 ]; then
            fail "requisitos.json — sem requisitos (precisa pelo menos 1)"
            return
        fi

        local without_criteria=$(jq '[.requisitos[] | select((.acceptance_criteria // []) | length == 0)] | length' "$file" 2>/dev/null || echo "0")

        if [ "$without_criteria" -gt 0 ]; then
            fail "requisitos.json — ${without_criteria} requisito(s) sem acceptance_criteria"
        else
            pass "requisitos.json — ${count} requisito(s) com acceptance_criteria"
        fi
    else
        local content=$(cat "$file")
        if echo "$content" | grep -q '"requisitos"\s*:\s*\[\s*\]'; then
            fail "requisitos.json — array vazio"
        else
            pass "requisitos.json — requisitos presentes (jq unavailable)"
        fi
    fi
}

# Validar restricoes.json — pelo menos 1 item
validate_restricoes() {
    local file="${FOUNDATION_DIR}/restricoes.json"

    if [ ! -f "$file" ]; then
        fail "restricoes.json não existe"
        return
    fi

    if ! validate_json "$file"; then
        fail "restricoes.json — JSON malformado"
        return
    fi

    if command -v jq &>/dev/null; then
        local count=$(jq '.restricoes | length' "$file" 2>/dev/null || echo "0")
        if [ "$count" -lt 1 ]; then
            fail "restricoes.json — sem restrições (precisa pelo menos 1)"
        else
            pass "restricoes.json — ${count} restrição(ões)"
        fi
    else
        local content=$(cat "$file")
        if echo "$content" | grep -q '"restricoes"\s*:\s*\[\s*\]'; then
            fail "restricoes.json — array vazio"
        else
            pass "restricoes.json — restrições presentes (jq unavailable)"
        fi
    fi
}

# Main
main() {
    echo ""
    info "GATE-0.5: Project Foundation Validation"
    echo "========================================="
    echo ""

    validate_5w2h
    validate_premissas
    validate_riscos
    validate_requisitos
    validate_restricoes

    echo ""
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        for w in "${WARNINGS[@]}"; do
            warn "$w"
        done
        echo ""
    fi

    if [ ${#FAILED[@]} -gt 0 ]; then
        for f in "${FAILED[@]}"; do
            echo -e "${RED}[FAIL]${RESET} $f"
        done
        echo ""
        info "GATE-0.5: FALHOU"
        info "Execute: devorq foundation create"
        exit 1
    else
        echo ""
        for p in "${PASSED[@]}"; do
            echo -e "${GREEN}[PASS]${RESET} $p"
        done
        echo ""
        info "GATE-0.5: APROVADO — Todos os foundation docs válidos"
        exit 0
    fi
}

main "$@"
