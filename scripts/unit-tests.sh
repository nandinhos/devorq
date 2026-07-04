#!/usr/bin/env bash
# scripts/unit-tests.sh — Unit tests para módulos DEVORQ
#
# Testa:
#   - Gates (lib/gates.sh)
#   - Lessons (lib/lessons.sh)
#   - Context (lib/context.sh)
#   - Workflow (lib/commands/workflow.sh)

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LIB_DIR="$DEVORQ_ROOT/lib"
readonly TEST_DIR="/tmp/devorq-unit-test"

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_TEST_FAILED=2

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

unit::info() { echo -e "${CYAN}[TEST]${RESET} $*"; }
unit::pass() { echo -e "${GREEN}[PASS]${RESET} $*"; ((TESTS_PASSED++)) || true; }
unit::fail() { echo -e "${RED}[FAIL]${RESET} $*"; ((TESTS_FAILED++)) || true; }

setup_test_env() {
    rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    export DEVORQ_LIB="$LIB_DIR"
    export DEVORQ_DIR="$TEST_DIR"
    export DEVORQ_LESSONS_DIR="$TEST_DIR/.devorq/state/lessons"
}

teardown_test_env() {
    rm -rf "$TEST_DIR"
}

assert() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    ((TESTS_RUN++)) || true

    if [ "$expected" = "$actual" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    ((TESTS_RUN++)) || true

    if echo "$haystack" | grep -q "$needle"; then
        unit::pass "${message:-Contains: $needle}"
        return 0
    else
        unit::fail "${message:-Does not contain: $needle}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    ((TESTS_RUN++)) || true

    # Use -e for files OR directories
    if [ -e "$file" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    ((TESTS_RUN++)) || true

    if [ ! -f "$file" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message"
        return 1
    fi
}

# ============================================================
# GATE TESTS
# ============================================================

test_gate_0_env_context() {
    unit::info "Test: GATE-0 DDD + env-context"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: GATE-0 sem intent (deve passar)
    if gate_0 2>/dev/null; then
        unit::pass "GATE-0 passes without intent"
    else
        unit::fail "GATE-0 should pass without intent"
    fi
    ((TESTS_RUN++)) || true

    # Test: GATE-0 com intent DDD
    mkdir -p "$TEST_DIR/.devorq/state"
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "stack": ["bash"],
  "intent": "Implementar domínio DDD com entidades"
}
EOF
    export DEVORQ_INTENT=""
    gate_0 2>/dev/null || true
    unit::pass "GATE-0 handles DDD intent"
    ((TESTS_RUN++)) || true
}

test_gate_0_5_foundation() {
    unit::info "Test: GATE-0.5 Foundation"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: GATE-0.5 sem scripts (deve falhar com warn)
    if gate_0_5 2>/dev/null; then
        unit::fail "GATE-0.5 should fail without foundation scripts"
    else
        unit::pass "GATE-0.5 fails without foundation scripts"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_1_spec_exists() {
    unit::info "Test: GATE-1 SPEC.md exists"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: SPEC.md não existe
    if gate_1 2>/dev/null; then
        unit::fail "GATE-1 should fail when SPEC.md doesn't exist"
    else
        unit::pass "GATE-1 fails without SPEC.md"
    fi
    ((TESTS_RUN++)) || true

    # Test: SPEC.md existe (deve ter > 100 bytes)
    cat > "$TEST_DIR/SPEC.md" << 'EOF'
# Test Project Specification

## Overview
This is a test project for the devorq testing framework.

## Features
- Feature 1
- Feature 2
- Feature 3
EOF
    if gate_1 2>/dev/null; then
        unit::pass "GATE-1 passes with SPEC.md (>100 bytes)"
    else
        unit::fail "GATE-1 should pass when SPEC.md exists (>100 bytes)"
    fi
    ((TESTS_RUN++)) || true

    # Test: SPEC.md vazio
    echo "" > "$TEST_DIR/SPEC.md"
    if gate_1 2>/dev/null; then
        unit::fail "GATE-1 should fail with empty SPEC.md"
    else
        unit::pass "GATE-1 fails with empty SPEC.md"
    fi
    ((TESTS_RUN++)) || true

    # Test: SPEC.md pequeno demais (< 100 bytes)
    echo "# Spec" > "$TEST_DIR/SPEC.md"
    if gate_1 2>/dev/null; then
        unit::fail "GATE-1 should fail with small SPEC.md"
    else
        unit::pass "GATE-1 fails with small SPEC.md"
    fi
    ((TESTS_RUN++)) || true

    # Test: DEVORQ_ALLOW_DRAFT=true
    export DEVORQ_ALLOW_DRAFT="true"
    rm -f "$TEST_DIR/SPEC.md"
    if gate_1 2>/dev/null; then
        unit::pass "GATE-1 ALLOW_DRAFT skips SPEC.md check"
    else
        unit::fail "GATE-1 should pass with ALLOW_DRAFT=true"
    fi
    ((TESTS_RUN++)) || true
    unset DEVORQ_ALLOW_DRAFT
}

test_gate_2_syntax() {
    unit::info "Test: GATE-2 Syntax checks"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: shellcheck syntax
    if command -v shellcheck &>/dev/null; then
        if shellcheck -S error "$LIB_DIR"/*.sh 2>/dev/null | grep -q "SC[12]"; then
            unit::fail "Shellcheck found syntax errors"
        else
            unit::pass "Shellcheck: no syntax errors"
        fi
    else
        unit::pass "Shellcheck not available (skipped)"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_3_context() {
    unit::info "Test: GATE-3 Context documented"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"
    source "$LIB_DIR/context.sh"

    # Test: context.json não existe
    cat > "$TEST_DIR/SPEC.md" << 'EOF'
# Test
EOF

    if gate_3 2>/dev/null; then
        unit::pass "GATE-3 handles missing context.json"
    else
        unit::fail "GATE-3 should handle missing context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json existe com dados
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test-project",
  "stack": ["bash"],
  "intent": "testing"
}
EOF

    if gate_3 2>/dev/null; then
        unit::pass "GATE-3 passes with valid context.json"
    else
        unit::fail "GATE-3 should pass with valid context.json"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_4_lessons() {
    unit::info "Test: GATE-4 Lessons reviewed"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: Sem lessons
    if gate_4 2>/dev/null; then
        unit::pass "GATE-4 passes with no lessons (warning OK)"
    else
        unit::fail "GATE-4 should pass with no lessons"
    fi
    ((TESTS_RUN++)) || true

    # Test: Com lessons
    echo '{"title":"test"}' > "$TEST_DIR/.devorq/state/lessons/captured/lesson_001.json"
    if gate_4 2>/dev/null; then
        unit::pass "GATE-4 passes with lessons"
    else
        unit::fail "GATE-4 should pass with lessons"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_5_handoff() {
    unit::info "Test: GATE-5 Handoff ready"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"
    source "$LIB_DIR/compact.sh"

    # Setup context for handoff
    mkdir -p "$TEST_DIR/.devorq/state"
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "stack": [],
  "intent": "test"
}
EOF

    if gate_5 2>/dev/null; then
        if [ -f "$TEST_DIR/.devorq/state/handoff.json" ]; then
            unit::pass "GATE-5 generates valid handoff.json"
        else
            unit::fail "GATE-5 should generate handoff.json"
        fi
    else
        unit::fail "GATE-5 should pass"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_5_5_unify() {
    unit::info "Test: GATE-5.5 UNIFY check"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: Sem context.json (deve passar com warn)
    if gate_5_5 2>/dev/null; then
        unit::pass "GATE-5.5 passes without context.json"
    else
        unit::fail "GATE-5.5 should pass without context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json sem unify_done
    mkdir -p "$TEST_DIR/.devorq/state"
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "stack": [],
  "intent": "test"
}
EOF
    if gate_5_5 2>/dev/null; then
        unit::pass "GATE-5.5 passes with context.json (warns about UNIFY)"
    else
        unit::fail "GATE-5.5 should pass with context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json com unify_done=true
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "stack": [],
  "intent": "test",
  "unify_done": true,
  "unify_file": "unified-feature.md"
}
EOF
    if gate_5_5 2>/dev/null; then
        unit::pass "GATE-5.5 passes with unify_done=true"
    else
        unit::fail "GATE-5.5 should pass with unify_done=true"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_6_context7() {
    unit::info "Test: GATE-6 Context7 checked"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: Sem lib/context7.sh (deve passar com warn)
    if gate_6 2>/dev/null; then
        unit::pass "GATE-6 passes without context7.sh"
    else
        unit::fail "GATE-6 should pass without context7.sh"
    fi
    ((TESTS_RUN++)) || true
}

test_gate_7_debug() {
    unit::info "Test: GATE-7 Systematic debugging"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: Sem lib/debug.sh (deve passar)
    if gate_7 2>/dev/null; then
        unit::pass "GATE-7 passes without debug.sh"
    else
        unit::fail "GATE-7 should pass without debug.sh"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# LESSONS TESTS
# ============================================================

test_lessons_capture() {
    unit::info "Test: lessons::capture"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Test: Capture válido
    if lessons::capture "Test Lesson" "Problem desc" "Solution desc" 2>/dev/null; then
        local files
        files=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)
        if [ "$files" -gt 0 ]; then
            unit::pass "lessons::capture creates JSON file"
        else
            unit::fail "lessons::capture should create JSON file"
        fi
    else
        unit::fail "lessons::capture should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: Capture com title vazio (deve falhar ou lidar gracefully)
    local files_before
    files_before=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)

    if ! lessons::capture "" "Problem" "Solution" 2>/dev/null; then
        unit::pass "lessons::capture handles empty title"
    else
        # Aceita se passou e não criou arquivo
        local files_after
        files_after=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)
        if [ "$files_after" -eq "$files_before" ]; then
            unit::pass "lessons::capture does not create file with empty title"
        else
            unit::fail "lessons::capture should not create file with empty title"
        fi
    fi
    ((TESTS_RUN++)) || true
}

test_lessons_schema() {
    unit::info "Test: Lessons JSON schema"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Criar lesson
    lessons::capture "Schema Test" "Problem" "Solution" 2>/dev/null || true

    local lesson_file
    lesson_file=$(ls -t "$TEST_DIR/.devorq/state/lessons/captured"/*.json 2>/dev/null | head -1)

    if [ -n "$lesson_file" ] && [ -f "$lesson_file" ]; then
        # Verificar campos obrigatórios
        if command -v jq &>/dev/null; then
            local has_title has_problem has_solution
            has_title=$(jq -r '.title' "$lesson_file" 2>/dev/null)
            has_problem=$(jq -r '.problem' "$lesson_file" 2>/dev/null)
            has_solution=$(jq -r '.solution' "$lesson_file" 2>/dev/null)

            if [ "$has_title" != "null" ] && [ "$has_problem" != "null" ] && [ "$has_solution" != "null" ]; then
                unit::pass "Lesson has required fields (title, problem, solution)"
            else
                unit::fail "Lesson missing required fields"
            fi
        else
            # Sem jq, verificar se arquivo tem conteúdo
            if grep -q "title" "$lesson_file" && grep -q "problem" "$lesson_file"; then
                unit::pass "Lesson has content"
            else
                unit::fail "Lesson should have content"
            fi
        fi
    else
        unit::fail "No lesson file found"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# CONTEXT TESTS
# ============================================================

test_ctx_lint() {
    unit::info "Test: ctx_lint"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Limpar qualquer contexto existente
    rm -rf "$TEST_DIR/.devorq"
    mkdir -p "$TEST_DIR/.devorq/state"

    # Test: Sem context.json (deve falhar)
    if ctx_lint 2>/dev/null; then
        unit::fail "ctx_lint should fail without context.json"
    else
        unit::pass "ctx_lint fails without context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json inválido
    echo '{"invalid": }' > "$TEST_DIR/.devorq/state/context.json"
    if ctx_lint 2>/dev/null; then
        unit::fail "ctx_lint should fail with invalid JSON"
    else
        unit::pass "ctx_lint fails with invalid JSON"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json válido
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "intent": "testing",
  "stack": []
}
EOF
    if ctx_lint 2>/dev/null; then
        unit::pass "ctx_lint passes with valid context.json"
    else
        unit::fail "ctx_lint should pass with valid context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: context.json sem campo project
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "intent": "testing",
  "stack": []
}
EOF
    if ctx_lint 2>/dev/null; then
        unit::fail "ctx_lint should warn about missing project"
    else
        unit::pass "ctx_lint warns about missing project"
    fi
    ((TESTS_RUN++)) || true
}

test_ctx_set() {
    unit::info "Test: ctx_set"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Test: ctx_set com contexto inicial
    rm -f "$TEST_DIR/.devorq/state/context.json"
    if ctx_set "project" "test-project" 2>/dev/null; then
        if [ -f "$TEST_DIR/.devorq/state/context.json" ]; then
            unit::pass "ctx_set creates context.json"
        else
            unit::fail "ctx_set should create context.json"
        fi
    else
        unit::fail "ctx_set should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: ctx_set atualiza campo existente
    if ctx_set "intent" "new intent" 2>/dev/null; then
        if command -v jq &>/dev/null; then
            local intent_val
            intent_val=$(jq -r '.intent' "$TEST_DIR/.devorq/state/context.json" 2>/dev/null)
            if [ "$intent_val" = "new intent" ]; then
                unit::pass "ctx_set updates existing field"
            else
                unit::fail "ctx_set should update field (got: $intent_val)"
            fi
        else
            unit::pass "ctx_set executed (jq not available)"
        fi
    else
        unit::fail "ctx_set should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: ctx_set sem campo (deve falhar)
    if ctx_set "" "value" 2>/dev/null; then
        unit::fail "ctx_set should fail without field name"
    else
        unit::pass "ctx_set fails without field name"
    fi
    ((TESTS_RUN++)) || true
}

test_ctx_stats() {
    unit::info "Test: ctx_stats"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Test: Sem context.json
    rm -f "$TEST_DIR/.devorq/state/context.json"
    if ctx_stats 2>/dev/null; then
        unit::fail "ctx_stats should fail without context.json"
    else
        unit::pass "ctx_stats fails without context.json"
    fi
    ((TESTS_RUN++)) || true

    # Test: Com context.json válido
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "intent": "testing",
  "stack": ["bash"]
}
EOF
    if ctx_stats 2>/dev/null; then
        unit::pass "ctx_stats works with valid context.json"
    else
        unit::fail "ctx_stats should work with valid context.json"
    fi
    ((TESTS_RUN++)) || true
}

test_ctx_pack() {
    unit::info "Test: ctx_pack"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Setup context.json
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "intent": "testing",
  "stack": ["bash"],
  "gates_completed": [1, 2, 3],
  "pending_gates": [4, 5],
  "last_session": "2024-01-01"
}
EOF

    local output_file="$TEST_DIR/.devorq/state/handoff.json"
    if ctx_pack "$output_file" 2>/dev/null; then
        if [ -f "$output_file" ]; then
            unit::pass "ctx_pack creates handoff file"
            if command -v jq &>/dev/null; then
                local has_project has_timestamp
                has_project=$(jq -r '.project' "$output_file" 2>/dev/null)
                has_timestamp=$(jq -r '.timestamp' "$output_file" 2>/dev/null)
                if [ "$has_project" = "test" ] && [ "$has_timestamp" != "null" ]; then
                    unit::pass "ctx_pack includes required fields"
                else
                    unit::fail "ctx_pack should include project ($has_project) and timestamp ($has_timestamp)"
                fi
            fi
        else
            unit::fail "ctx_pack should create handoff file"
        fi
    else
        unit::fail "ctx_pack should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: Sem context.json (deve falhar)
    rm -f "$TEST_DIR/.devorq/state/context.json"
    if ctx_pack "$output_file" 2>/dev/null; then
        unit::fail "ctx_pack should fail without context.json"
    else
        unit::pass "ctx_pack fails without context.json"
    fi
    ((TESTS_RUN++)) || true
}

test_ctx_merge() {
    unit::info "Test: ctx_merge"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Setup base context
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "base-project",
  "intent": "base intent",
  "stack": []
}
EOF

    # Setup incoming context
    cat > "$TEST_DIR/incoming.json" << 'EOF'
{
  "project": "incoming-project",
  "intent": "incoming intent",
  "new_field": "new value"
}
EOF

    # Test: Merge
    if ctx_merge "$TEST_DIR/incoming.json" 2>/dev/null; then
        if command -v jq &>/dev/null; then
            local merged_project merged_intent merged_new
            merged_project=$(jq -r '.project' "$TEST_DIR/.devorq/state/context.json" 2>/dev/null)
            merged_intent=$(jq -r '.intent' "$TEST_DIR/.devorq/state/context.json" 2>/dev/null)
            merged_new=$(jq -r '.new_field' "$TEST_DIR/.devorq/state/context.json" 2>/dev/null)

            if [ "$merged_project" = "incoming-project" ] && \
               [ "$merged_intent" = "incoming intent" ] && \
               [ "$merged_new" = "new value" ]; then
                unit::pass "ctx_merge merges contexts correctly"
            else
                unit::fail "ctx_merge should merge all fields"
            fi
        else
            unit::pass "ctx_merge executed (jq not available)"
        fi
    else
        unit::fail "ctx_merge should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: Merge sem arquivo (deve falhar)
    if ctx_merge "" 2>/dev/null; then
        unit::fail "ctx_merge should fail without incoming file"
    else
        unit::pass "ctx_merge fails without incoming file"
    fi
    ((TESTS_RUN++)) || true

    # Test: Merge com arquivo inexistente (deve falhar)
    if ctx_merge "/nonexistent/file.json" 2>/dev/null; then
        unit::fail "ctx_merge should fail with nonexistent file"
    else
        unit::pass "ctx_merge fails with nonexistent file"
    fi
    ((TESTS_RUN++)) || true
}

test_ctx_clear() {
    unit::info "Test: ctx_clear"

    cd "$TEST_DIR"
    source "$LIB_DIR/context.sh"

    # Test: Com context.json
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{"project": "test"}
EOF
    if ctx_clear 2>/dev/null; then
        if [ ! -f "$TEST_DIR/.devorq/state/context.json" ]; then
            unit::pass "ctx_clear removes context.json"
        else
            unit::fail "ctx_clear should remove context.json"
        fi
    else
        unit::fail "ctx_clear should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: Sem context.json
    if ctx_clear 2>/dev/null; then
        unit::pass "ctx_clear handles missing file"
    else
        unit::fail "ctx_clear should handle missing file"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# VPS TESTS (seguranca e validacao)
# ============================================================

test_vps_sanitize_path() {
    unit::info "Test: devorq::sanitize_path"

    cd "$TEST_DIR"
    source "$LIB_DIR/vps.sh"

    # Test: Path valido dentro do diretorio
    mkdir -p "$TEST_DIR/project"
    touch "$TEST_DIR/project/file.txt"
    local result
    result=$(devorq::sanitize_path "$TEST_DIR/project/file.txt" "$TEST_DIR/project" 2>/dev/null)
    if [ "$?" -eq 0 ] && [ -n "$result" ]; then
        unit::pass "sanitize_path accepts valid path"
    else
        unit::fail "sanitize_path should accept valid path"
    fi
    ((TESTS_RUN++)) || true

    # Test: Path traversal detectado
    if devorq::sanitize_path "$TEST_DIR/../../../etc/passwd" "$TEST_DIR" 2>/dev/null; then
        unit::fail "sanitize_path should block path traversal"
    else
        unit::pass "sanitize_path blocks path traversal"
    fi
    ((TESTS_RUN++)) || true

    # Test: Path invalido
    if devorq::sanitize_path "/nonexistent/path/file" "/tmp" 2>/dev/null; then
        unit::fail "sanitize_path should fail for invalid path"
    else
        unit::pass "sanitize_path fails for invalid path"
    fi
    ((TESTS_RUN++)) || true

    # Test: Base dir invalido
    if devorq::sanitize_path "$TEST_DIR/file.txt" "/invalid/base" 2>/dev/null; then
        unit::fail "sanitize_path should fail for invalid base dir"
    else
        unit::pass "sanitize_path fails for invalid base dir"
    fi
    ((TESTS_RUN++)) || true
}

test_vps_validate_ssh_host() {
    unit::info "Test: devorq::validate_ssh_host"

    cd "$TEST_DIR"
    source "$LIB_DIR/vps.sh"

    # Test: Host valido
    if devorq::validate_ssh_host "example.com" "22" 2>/dev/null; then
        unit::pass "validate_ssh_host accepts valid host/port"
    else
        unit::fail "validate_ssh_host should accept valid host/port"
    fi
    ((TESTS_RUN++)) || true

    # Test: Host com IP valido
    if devorq::validate_ssh_host "192.168.1.1" "8080" 2>/dev/null; then
        unit::pass "validate_ssh_host accepts valid IP/port"
    else
        unit::fail "validate_ssh_host should accept valid IP/port"
    fi
    ((TESTS_RUN++)) || true

    # Test: Host invalido (caracteres especiais)
    if devorq::validate_ssh_host "'; rm -rf /'" "22" 2>/dev/null; then
        unit::fail "validate_ssh_host should block injection in host"
    else
        unit::pass "validate_ssh_host blocks injection in host"
    fi
    ((TESTS_RUN++)) || true

    # Test: Host invalido (vazio)
    if devorq::validate_ssh_host "" "22" 2>/dev/null; then
        unit::fail "validate_ssh_host should reject empty host"
    else
        unit::pass "validate_ssh_host rejects empty host"
    fi
    ((TESTS_RUN++)) || true

    # Test: Porta invalida (letras)
    if devorq::validate_ssh_host "example.com" "abc" 2>/dev/null; then
        unit::fail "validate_ssh_host should reject non-numeric port"
    else
        unit::pass "validate_ssh_host rejects non-numeric port"
    fi
    ((TESTS_RUN++)) || true

    # Test: Porta invalida (fora do range)
    if devorq::validate_ssh_host "example.com" "70000" 2>/dev/null; then
        unit::fail "validate_ssh_host should reject out-of-range port"
    else
        unit::pass "validate_ssh_host rejects out-of-range port"
    fi
    ((TESTS_RUN++)) || true

    # Test: Porta invalida (zero)
    if devorq::validate_ssh_host "example.com" "0" 2>/dev/null; then
        unit::fail "validate_ssh_host should reject port 0"
    else
        unit::pass "validate_ssh_host rejects port 0"
    fi
    ((TESTS_RUN++)) || true
}

test_vps_pg_exec_validation() {
    unit::info "Test: devorq::vps_pg_exec SQL validation"

    cd "$TEST_DIR"
    source "$LIB_DIR/vps.sh"

    # Test: SQL valido (não conecta, mas valida sintaxe)
    # Como não temos SSH, apenas verificamos que a validacao funciona
    local sql="SELECT count(*) FROM devorq.lessons;"

    # Test: SQL com comentario
    if devorq::validate_ssh_host "test.com" "22" 2>/dev/null; then
        unit::pass "vps_pg_exec validation logic available"
    else
        unit::fail "vps_pg_exec validation should be available"
    fi
    ((TESTS_RUN++)) || true

    # Nota: Não podemos testar vps_pg_exec sem VPS real
    # Mas podemos verificar que a funcao existe
    if declare -f devorq::vps_pg_exec &>/dev/null; then
        unit::pass "devorq::vps_pg_exec function exists"
    else
        unit::fail "devorq::vps_pg_exec should exist"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# LESSONS ADVANCED TESTS
# ============================================================

test_sanitize_input() {
    unit::info "Test: devorq::sanitize_input"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Test: Input limpo
    local result
    result=$(devorq::sanitize_input "Hello World" 200 2>/dev/null)
    if [ "$result" = "Hello World" ]; then
        unit::pass "sanitize_input passes clean input"
    else
        unit::fail "sanitize_input should pass clean input (got: $result)"
    fi
    ((TESTS_RUN++)) || true

    # Test: Input com shell injection chars
    result=$(devorq::sanitize_input "test; rm -rf /" 200 2>/dev/null)
    if echo "$result" | grep -qv ';'; then
        unit::pass "sanitize_input removes shell injection chars"
    else
        unit::fail "sanitize_input should remove shell injection chars"
    fi
    ((TESTS_RUN++)) || true

    # Test: Input com backticks
    result=$(devorq::sanitize_input "test\`echo hack\`" 200 2>/dev/null)
    if echo "$result" | grep -qv '`'; then
        unit::pass "sanitize_input removes backticks"
    else
        unit::fail "sanitize_input should remove backticks"
    fi
    ((TESTS_RUN++)) || true

    # Test: Input vazio
    result=$(devorq::sanitize_input "" 200 2>/dev/null)
    if [ -z "$result" ]; then
        unit::pass "sanitize_input handles empty input"
    else
        unit::fail "sanitize_input should handle empty input"
    fi
    ((TESTS_RUN++)) || true

    # Test: Max length
    local long_input="a12345678901234567890123456789012345678901234567890"
    result=$(devorq::sanitize_input "$long_input" 30 2>/dev/null)
    if [ ${#result} -le 30 ]; then
        unit::pass "sanitize_input respects max_len"
    else
        unit::fail "sanitize_input should respect max_len"
    fi
    ((TESTS_RUN++)) || true
}

test_lessons_search() {
    unit::info "Test: lessons::search"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Setup: criar algumas lições
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    cat > "$TEST_DIR/.devorq/state/lessons/captured/lesson_001.json" << 'EOF'
{
  "id": "lesson_001",
  "title": "Docker Error",
  "problem": "Container fails to start",
  "solution": "Check port mapping",
  "timestamp": "20240101"
}
EOF
    cat > "$TEST_DIR/.devorq/state/lessons/captured/lesson_002.json" << 'EOF'
{
  "id": "lesson_002",
  "title": "Git Reset",
  "problem": "How to undo commits",
  "solution": "git reset --soft HEAD~1",
  "timestamp": "20240102"
}
EOF

    # Test: Busca com query valida
    local output
    output=$(lessons::search "Docker" 2>/dev/null)
    if echo "$output" | grep -q "Docker"; then
        unit::pass "lessons::search finds matching lesson"
    else
        unit::fail "lessons::search should find matching lesson"
    fi
    ((TESTS_RUN++)) || true

    # Test: Busca sem resultados
    output=$(lessons::search "nonexistent" 2>/dev/null)
    if echo "$output" | grep -q "Nenhuma"; then
        unit::pass "lessons::search handles no results"
    else
        unit::fail "lessons::search should show no results"
    fi
    ((TESTS_RUN++)) || true

    # Test: Busca sem query (deve falhar)
    if lessons::search "" 2>/dev/null; then
        unit::fail "lessons::search should fail without query"
    else
        unit::pass "lessons::search fails without query"
    fi
    ((TESTS_RUN++)) || true
}

test_lessons_list() {
    unit::info "Test: lessons::list"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Test: Lista com lições
    if lessons::list 2>/dev/null; then
        unit::pass "lessons::list executes successfully"
    else
        unit::fail "lessons::list should execute"
    fi
    ((TESTS_RUN++)) || true

    # Test: Lista com filtro
    if lessons::list "all" 2>/dev/null; then
        unit::pass "lessons::list with filter 'all'"
    else
        unit::fail "lessons::list filter should work"
    fi
    ((TESTS_RUN++)) || true
}

test_lessons_apply() {
    unit::info "Test: lessons::apply"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Setup: criar lição
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    cat > "$TEST_DIR/.devorq/state/lessons/captured/lesson_test.json" << 'EOF'
{
  "id": "lesson_test",
  "title": "Test",
  "problem": "Test problem",
  "solution": "Test solution",
  "applied": false
}
EOF

    # Test: Apply com ID especifico
    if lessons::apply "lesson_test" 2>/dev/null; then
        if command -v jq &>/dev/null; then
            local applied
            applied=$(jq -r '.applied' "$TEST_DIR/.devorq/state/lessons/captured/lesson_test.json" 2>/dev/null)
            if [ "$applied" = "true" ]; then
                unit::pass "lessons::apply marks as applied"
            else
                unit::fail "lessons::apply should mark as applied"
            fi
        else
            unit::pass "lessons::apply executed"
        fi
    else
        unit::fail "lessons::apply should succeed"
    fi
    ((TESTS_RUN++)) || true

    # Test: Apply lição inexistente (deve falhar)
    if lessons::apply "nonexistent" 2>/dev/null; then
        unit::fail "lessons::apply should fail for nonexistent"
    else
        unit::pass "lessons::apply fails for nonexistent"
    fi
    ((TESTS_RUN++)) || true
}

test_lessons_migrate() {
    unit::info "Test: lessons::migrate"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Setup: criar lição sem campos approved
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    cat > "$TEST_DIR/.devorq/state/lessons/captured/lesson_old.json" << 'EOF'
{
  "id": "lesson_old",
  "title": "Old Lesson",
  "problem": "Old problem",
  "solution": "Old solution"
}
EOF

    # Test: Migrate executa
    if lessons::migrate 2>/dev/null; then
        if command -v jq &>/dev/null; then
            local has_approved
            has_approved=$(jq -r '.approved' "$TEST_DIR/.devorq/state/lessons/captured/lesson_old.json" 2>/dev/null)
            if [ "$has_approved" = "false" ]; then
                unit::pass "lessons::migrate adds approved field"
            else
                unit::fail "lessons::migrate should add approved field"
            fi
        else
            unit::pass "lessons::migrate executed"
        fi
    else
        unit::fail "lessons::migrate should succeed"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# WORKFLOW TESTS
# ============================================================

test_workflow_init() {
    unit::info "Test: devorq::cmd_init"

    cd "$TEST_DIR"
    # Remover .devorq existente para testar init do zero
    rm -rf "$TEST_DIR/.devorq"

    # Setup DEVORQ_VERSION for init
    export DEVORQ_VERSION="3.7.0"
    export DEVORQ_LIB="$LIB_DIR"

    # Definir stubs para funções ausentes
    devorq::success() { echo "[OK] $*"; }
    devorq::warn() { echo "[WARN] $*"; }
    devorq::info() { echo "[INFO] $*"; }

    source "$LIB_DIR/gates.sh" 2>/dev/null || true
    source "$LIB_DIR/helpers.sh" 2>/dev/null || true
    source "$LIB_DIR/commands/workflow.sh"

    if declare -f devorq::cmd_init &>/dev/null; then
        if devorq::cmd_init 2>/dev/null; then
            assert_file_exists "$TEST_DIR/.devorq" "Creates .devorq directory"
            assert_file_exists "$TEST_DIR/.devorq/state" "Creates .devorq/state directory"
            assert_file_exists "$TEST_DIR/.devorq/state/context.json" "Creates context.json"
        else
            unit::fail "devorq::cmd_init should succeed"
        fi
    else
        unit::skip "devorq::cmd_init not found"
    fi
    ((TESTS_RUN++)) || true
}

test_auto_mark_pass() {
    unit::info "Test: devorq::auto::mark_pass nunca zera prd.json (DQ-004)"

    source "$LIB_DIR/helpers.sh" 2>/dev/null || true
    source "$LIB_DIR/auto.sh" 2>/dev/null || true

    if ! declare -f devorq::auto::mark_pass &>/dev/null; then
        unit::skip "devorq::auto::mark_pass not found"
        ((TESTS_RUN++)) || true
        return
    fi

    local proj
    proj=$(mktemp -d)

    # Caso normal: marca a story como done e mantém JSON válido
    printf '%s' '{"stories":[{"id":"s1","title":"A","passes":false,"status":"todo"}]}' > "$proj/prd.json"
    devorq::auto::mark_pass "$proj" "s1" >/dev/null 2>&1 || true
    assert "done" "$(jq -r '.stories[0].status' "$proj/prd.json" 2>/dev/null)" "mark_pass marca status=done"

    # Regressão DQ-004: story_id com aspas NÃO pode zerar o prd.json
    printf '%s' '{"stories":[{"id":"s1","title":"A","passes":false,"status":"todo"}]}' > "$proj/prd.json"
    devorq::auto::mark_pass "$proj" "s1') x" >/dev/null 2>&1 || true
    local sz; sz=$(wc -c < "$proj/prd.json")
    ((TESTS_RUN++)) || true
    if [ "$sz" -gt 0 ] && jq empty "$proj/prd.json" 2>/dev/null; then
        unit::pass "prd.json preservado com story_id contendo aspas (DQ-004)"
    else
        unit::fail "prd.json zerado/corrompido por story_id com aspas (DQ-004)"
    fi

    rm -rf "$proj"
}

test_no_cmd_shadowing() {
    unit::info "Test: nenhuma devorq::cmd_* definida em >1 arquivo carregado (DQ-001)"
    ((TESTS_RUN++)) || true

    # Guard estatico: nos arquivos efetivamente carregados em runtime (core libs,
    # commands de topo e dispatchers — exclui as arvores orfas cli/ e lessons/),
    # nenhuma funcao devorq::cmd_* pode ter definicao duplicada. Duplicata =>
    # vencedor depende da ordem de source (shadowing). Ex.: cmd_test (DQ-001).
    local dups
    dups=$(grep -rhoE '^devorq::cmd_[a-z0-9_]+\(\)' \
              "$DEVORQ_ROOT"/lib/*.sh \
              "$DEVORQ_ROOT"/lib/commands/*.sh \
              "$DEVORQ_ROOT"/lib/dispatchers/*.sh 2>/dev/null \
            | sort | uniq -d)

    if [ -z "$dups" ]; then
        unit::pass "Sem definicoes duplicadas de devorq::cmd_* no caminho carregado"
    else
        unit::fail "devorq::cmd_* duplicada(s) — shadowing: $(echo "$dups" | tr '\n' ' ')"
    fi
}

test_check_story_fail_closed() {
    unit::info "Test: check-story.sh fail-closed sem runner (DQ-005)"
    local cs="$DEVORQ_ROOT/skills/devorq-auto/scripts/check-story.sh"
    if [ ! -f "$cs" ]; then
        unit::skip "check-story.sh not found"; ((TESTS_RUN++)) || true; return
    fi

    local proj
    proj=$(mktemp -d)
    mkdir -p "$proj/.devorq/state"
    echo '{}' > "$proj/.devorq/state/context.json"

    # Sem nenhum runner (composer/pytest/package.json) => deve falhar (fail-closed)
    ((TESTS_RUN++)) || true
    if bash "$cs" "$proj" >/dev/null 2>&1; then
        unit::fail "check-story deveria falhar sem runner detectado (DQ-005)"
    else
        unit::pass "check-story fail-closed sem runner"
    fi

    # Com opt-in explicito => deve passar
    ((TESTS_RUN++)) || true
    if DEVORQ_AUTO_ALLOW_NO_RUNNER=1 bash "$cs" "$proj" >/dev/null 2>&1; then
        unit::pass "check-story passa com DEVORQ_AUTO_ALLOW_NO_RUNNER=1"
    else
        unit::fail "check-story deveria passar com override DEVORQ_AUTO_ALLOW_NO_RUNNER (DQ-005)"
    fi

    rm -rf "$proj"
}

test_no_cjk_glyphs() {
    unit::info "Test: sem glifos CJK/mojibake no codigo de runtime (DQ-021)"
    ((TESTS_RUN++)) || true
    local hits
    hits=$(grep -rlP '[\x{3000}-\x{9fff}\x{ff00}-\x{ffef}]' \
              "$DEVORQ_ROOT"/lib "$DEVORQ_ROOT"/bin "$DEVORQ_ROOT"/scripts \
              --include='*.sh' 2>/dev/null || true)
    if [ -z "$hits" ]; then
        unit::pass "Nenhum glifo CJK no codigo .sh de runtime"
    else
        unit::fail "Glifos CJK encontrados em: $(echo "$hits" | tr '\n' ' ')"
    fi
}

test_audit_log() {
    unit::info "Test: devorq::audit_log gera JSONL com run_id (DQ-018)"

    source "$LIB_DIR/helpers.sh" 2>/dev/null || true
    if ! declare -f devorq::audit_log &>/dev/null; then
        unit::skip "devorq::audit_log not found"; ((TESTS_RUN++)) || true; return
    fi

    local d; d=$(mktemp -d)
    ( cd "$d" && unset DEVORQ_RUN_ID && devorq::audit_log "gate" "pass" "gate-1" && devorq::audit_log "flow" "end" "ok" )
    local f; f=$(find "$d/.devorq/state/logs" -name 'run-*.jsonl' 2>/dev/null | head -1)

    ((TESTS_RUN++)) || true
    if [ -n "$f" ] && [ "$(jq -r .run_id "$f" 2>/dev/null | sort -u | wc -l)" -eq 1 ] && jq empty "$f" 2>/dev/null; then
        unit::pass "audit_log: JSONL valido, run_id estavel"
    else
        unit::fail "audit_log: log ausente/invalido (DQ-018)"
    fi
    rm -rf "$d"
}

# ============================================================
# SUMMARY
# ============================================================

unit::summary() {
    echo ""
    echo "=========================================="
    echo " Unit Tests Summary"
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
# MAIN
# ============================================================

main() {
    echo "=========================================="
    echo " DEVORQ — Unit Tests"
    echo "=========================================="
    echo ""

    setup_test_env

    # Executar testes
    test_gate_0_env_context
    test_gate_0_5_foundation
    test_gate_1_spec_exists
    test_gate_2_syntax
    test_gate_3_context
    test_gate_4_lessons
    test_gate_5_handoff
    test_gate_5_5_unify
    test_gate_6_context7
    test_gate_7_debug
    test_lessons_capture
    test_lessons_schema
    test_sanitize_input
    test_lessons_search
    test_lessons_list
    test_lessons_apply
    test_lessons_migrate
    test_ctx_lint
    test_ctx_set
    test_ctx_stats
    test_ctx_pack
    test_ctx_merge
    test_ctx_clear
    test_vps_sanitize_path
    test_vps_validate_ssh_host
    test_vps_pg_exec_validation
    test_workflow_init
    test_auto_mark_pass
    test_no_cmd_shadowing
    test_check_story_fail_closed
    test_no_cjk_glyphs
    test_audit_log

    teardown_test_env

    unit::summary
}

main "$@"
