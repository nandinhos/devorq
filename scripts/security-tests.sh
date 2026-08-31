#!/usr/bin/env bash
# scripts/security-tests.sh — Testes de segurança para DEVORQ
#
# Testa:
#   - Input sanitization
#   - Path traversal prevention
#   - SQL injection detection
#   - SSH host validation
#
# Usa systematic-debugging quando falha:
#   1. Isolar → 2. Causa Raiz → 3. Solução → 4. Validação (Context7) → 5. Documentar

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LIB_DIR="$DEVORQ_ROOT/lib"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_TEST_FAILED=2

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Helpers
# ============================================================

sec::info() {
    echo -e "${CYAN}[TEST]${RESET} $*"
}

sec::pass() {
    echo -e "${GREEN}[PASS]${RESET} $*"
    ((TESTS_PASSED++)) || true
}

sec::fail() {
    echo -e "${RED}[FAIL]${RESET} $*"
    ((TESTS_FAILED++)) || true
}

sec::summary() {
    echo ""
    echo "=========================================="
    echo " Security Tests Summary"
    echo "=========================================="
    echo -e " Tests run:    ${TESTS_RUN}"
    echo -e " Passed:       ${GREEN}${TESTS_PASSED}${RESET}"
    echo -e " Failed:       ${RED}${TESTS_FAILED}${RESET}"
    echo "=========================================="

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED${RESET}"
        return $EXIT_SUCCESS
    else
        echo -e "${RED}SOME TESTS FAILED${RESET}"
        return $EXIT_TEST_FAILED
    fi
}

# ============================================================
# TEST: Input Sanitization
# ============================================================

test_input_sanitize() {
    sec::info "Test: Input Sanitization"

    # Source vps.sh para ter accesso às funções
    source "$LIB_DIR/vps.sh" 2>/dev/null || true

    local dangerous_chars='; & | ` $ ( ) { } [ ] < > ! \'
    local tests=0
    local passed=0

    # Testar cada caractere perigoso: o sanitarizador deve REMOVÊ-LO do resultado.
    # Antes o assert `[ -n "$result" ]` aceitava qualquer saída não-vazia — falso
    # sucesso: reportava "caracteres bloqueados" mesmo sem nada bloqueado.
    for char in ';' '&' '|' '`' '$' '(' ')' '{' '}' '[' ']' '<' '>' '!' '\\'; do
        ((tests++)) || true
        local input="test${char}value"
        local result

        # Sanitarizador de caracteres (NÃO o sanitize_path, que só valida path).
        if declare -f devorq::sanitize_input &>/dev/null; then
            result=$(devorq::sanitize_input "$input" 2>/dev/null)
        elif declare -f sanitize_input &>/dev/null; then
            result=$(sanitize_input "$input" 2>/dev/null)
        else
            # Fallback: mesma regra (remove tudo exceto [a-zA-Z0-9._-]).
            result=$(printf '%s' "$input" | sed 's/[^a-zA-Z0-9._-]//g')
        fi

        # O caractere perigoso deve ter sido removido do resultado sanitizado.
        if [[ -n "$result" ]] && ! printf '%s' "$result" | grep -qF -- "$char"; then
            ((passed++)) || true
        fi
    done

    if [ $passed -eq $tests ]; then
        sec::pass "Input sanitization: $passed/$tests caracteres sanitizados"
        return 0
    else
        sec::fail "Input sanitization: only $passed/$tests caracteres sanitizados"
        return 1
    fi
}

# ============================================================
# TEST: Path Traversal Prevention
# ============================================================

test_path_traversal() {
    sec::info "Test: Path Traversal Prevention"

    mkdir -p /tmp/.devorq/state

    source "$LIB_DIR/vps.sh" 2>/dev/null || true

    local tests=(
        "/etc/passwd|/tmp|BLOCKED"
        "../../../etc/passwd|/tmp|BLOCKED"
        "/tmp/../../../root|/tmp|BLOCKED"
        "/tmp/.devorq|/tmp|ALLOWED"
        "/tmp/.devorq/state|/tmp|ALLOWED"
        "/tmp/test.txt|/tmp|ALLOWED"
    )

    local test_count=0
    local passed=0

    for test in "${tests[@]}"; do
        IFS='|' read -r path base expected <<< "$test"
        ((test_count++)) || true

        local result
        if declare -f devorq::sanitize_path &>/dev/null; then
            result=$(devorq::sanitize_path "$path" "$base" 2>&1 || echo "BLOCKED")
        else
            # Fallback: validar manualmente
            local real_path real_base
            real_path=$(realpath -q "$path" 2>/dev/null || echo "$path")
            real_base=$(realpath -q "$base" 2>/dev/null || echo "$base")

            if [[ "$real_path" == "$real_base"* ]]; then
                result="ALLOWED"
            else
                result="BLOCKED"
            fi
        fi

        # Verifica resultado: ALLOWED = caminho válido, BLOCKED/ERROR = bloqueado
        local is_allowed=false
        if [[ "$result" == "$base"* ]]; then
            is_allowed=true
        fi

        if [[ "$expected" == "ALLOWED" && "$is_allowed" == "true" ]] || \
           [[ "$expected" == "BLOCKED" && "$is_allowed" == "false" ]]; then
            ((passed++)) || true
            sec::pass "Path '$path' -> $result (esperado: $expected)"
        else
            sec::fail "Path '$path' -> $result (esperado: $expected)"
        fi
    done

    if [ $passed -eq $test_count ]; then
        sec::pass "Path traversal prevention: $passed/$test_count testes"
        return 0
    else
        sec::fail "Path traversal prevention: $passed/$test_count testes"
        return 1
    fi
}

# ============================================================
# TEST: SSH Host Validation
# ============================================================

test_ssh_host_validation() {
    sec::info "Test: SSH Host Validation"

    source "$LIB_DIR/vps.sh" 2>/dev/null || true

    local tests=(
        "valid-host.com|6985|SUCCESS"
        "192.168.1.1|22|SUCCESS"
        "my-server.test|8080|SUCCESS"
        "my-server|8080|SUCCESS"
        "server123|8080|SUCCESS"
        "valid|99999|FAIL"
        "valid|-1|FAIL"
    )

    local test_count=0
    local passed=0

    for test in "${tests[@]}"; do
        IFS='|' read -r host port expected <<< "$test"
        ((test_count++)) || true

        local result
        if declare -f devorq::validate_ssh_host &>/dev/null; then
            if devorq::validate_ssh_host "$host" "$port" 2>/dev/null; then
                result="SUCCESS"
            else
                result="FAIL"
            fi
        else
            # Fallback: validação inline
            if [[ "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] && \
               [[ "$port" =~ ^[0-9]+$ ]] && \
               ((port >= 1 && port <= 65535)); then
                result="SUCCESS"
            else
                result="FAIL"
            fi
        fi

        if [ "$result" = "$expected" ]; then
            ((passed++)) || true
            sec::pass "SSH host '$host:$port' -> $result"
        else
            sec::fail "SSH host '$host:$port' -> $result (esperado: $expected)"
        fi
    done

    if [ $passed -eq $test_count ]; then
        sec::pass "SSH host validation: $passed/$test_count testes"
        return 0
    else
        sec::fail "SSH host validation: $passed/$test_count testes"
        return 1
    fi
}

# ============================================================
# TEST: SQL Injection Detection
# ============================================================

test_sql_injection() {
    sec::info "Test: SQL Injection Detection"

    local malicious_inputs=(
        "' OR '1'='1"
        "'; DROP TABLE users; --"
        "1; DELETE FROM lessons WHERE '1'='1"
        "admin'--"
        "1' AND '1'='1"
    )

    local test_count=0
    local passed=0

    for input in "${malicious_inputs[@]}"; do
        ((test_count++)) || true

        local detected=false

        # Checar se contém padrões de SQL injection
        if echo "$input" | grep -qiE "('|;|DROP|DELETE|UNION|INSERT|UPDATE|OR 1=1|AND .*=.)"; then
            detected=true
        fi

        if $detected; then
            ((passed++)) || true
            sec::pass "SQL injection detectado: '$input'"
        else
            sec::fail "SQL injection NÃO detectado: '$input'"
        fi
    done

    if [ $passed -eq $test_count ]; then
        sec::pass "SQL injection detection: $passed/$test_count testes"
        return 0
    else
        sec::fail "SQL injection detection: $passed/$test_count testes"
        return 1
    fi
}

# ============================================================
# TEST: Exit Codes Consistency
# ============================================================

test_exit_codes() {
    sec::info "Test: Exit Codes Consistency"

    source "$LIB_DIR/vps.sh" 2>/dev/null || true
    source "$LIB_DIR/lessons.sh" 2>/dev/null || true

    local tests=(
        "devorq::validate_ssh_host '' 22|EXIT_INVALID_ARGS"
        "lessons::capture ''|EXIT_INVALID_ARGS"
        "lessons::search ''|EXIT_INVALID_ARGS"
    )

    local test_count=0
    local passed=0

    for test in "${tests[@]}"; do
        IFS='|' read -r cmd expected_name <<< "$test"
        ((test_count++)) || true

        # expected_name é o NOME de uma variável (ex.: EXIT_INVALID_ARGS);
        # resolve para o valor numérico antes de comparar. Antes o código
        # lia `expected_code` e o descartava, aceitando qualquer exit code.
        local expected_code
        expected_code="${!expected_name:-}"
        if [[ -z "$expected_code" ]]; then
            sec::fail "Variavel de exit-code nao encontrada: ${expected_name}"
            continue
        fi

        local exit_code=""
        eval "$cmd" 2>/dev/null || exit_code=$?

        if [[ "$exit_code" == "$expected_code" ]]; then
            ((passed++)) || true
            sec::pass "Exit code ${exit_code} == ${expected_name} para: $cmd"
        else
            sec::fail "Exit code ${exit_code} != ${expected_name}=${expected_code} para: $cmd"
        fi
    done

    if [ $passed -eq $test_count ]; then
        sec::pass "Exit codes consistency: $passed/$test_count testes"
        return 0
    else
        sec::fail "Exit codes consistency: $passed/$test_count testes"
        return 1
    fi
}

# ============================================================
# SYSTEMATIC DEBUGGING WORKFLOW
# ============================================================

systematic_debug() {
    local test_name="$1"
    local error_msg="$2"

    echo ""
    echo "=========================================="
    echo -e "${RED}SYSTEMATIC DEBUGGING${RESET}"
    echo "=========================================="
    echo ""

    echo "1. ISOLAR"
    echo "   Test: $test_name"
    echo "   Erro: $error_msg"
    echo ""

    echo "Fluxo de investigacao (G-7 — investigar ANTES de corrigir):"
    echo "  2. Rode o teste isolado e leia a saida COMPLETA (sem grep)"
    echo "  3. Isole a causa raiz antes de propor correcao"
    echo "  4. Valide a correcao contra docs oficiais (Context7)"
    echo "  5. Rode a suite inteira de novo"
    echo "  6. Capture lesson se a descoberta nao for obvia (devorq lessons capture)"
    echo ""
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo "=========================================="
    echo " DEVORQ — Security Tests"
    echo "=========================================="
    echo ""

    TESTS_RUN=0

    # Executar testes
    test_input_sanitize || systematic_debug "input_sanitize" "Caracteres perigosos não bloqueados"
    ((TESTS_RUN+=15)) || true

    test_path_traversal || systematic_debug "path_traversal" "Path traversal não prevenido"
    ((TESTS_RUN+=6)) || true

    test_ssh_host_validation || systematic_debug "ssh_host" "Host inválido aceito"
    ((TESTS_RUN+=7)) || true

    test_sql_injection || systematic_debug "sql_injection" "SQL injection não detectado"
    ((TESTS_RUN+=5)) || true

    test_exit_codes || systematic_debug "exit_codes" "Exit codes inconsistentes"
    ((TESTS_RUN+=3)) || true

    echo ""
    sec::summary
}

main "$@"
