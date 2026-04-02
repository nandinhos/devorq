#!/usr/bin/env bats

# Testes: todos os módulos lib/ devem ser sourceable sem qualquer erro em stderr

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export CLI_INSTALL_PATH="$DEVORQ_ROOT"
}

# Helper: source um arquivo e verifica ausência de erros
source_clean() {
    local files="$1"
    run bash -c "cd '$DEVORQ_ROOT' && $files 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"No such file"* ]]
    [[ "$output" != *"not found"* ]]
    [[ "$output" != *"command not found"* ]]
}

@test "lib/core.sh: sem erros ao fazer source" {
    source_clean "source lib/core.sh"
}

@test "lib/orchestration.sh: sem erros ao fazer source" {
    source_clean "source lib/core.sh && source lib/orchestration.sh"
}

@test "lib/state.sh: sem erros ao fazer source" {
    source_clean "source lib/core.sh && source lib/state.sh"
}

@test "lib/detect.sh: sem erros ao fazer source" {
    source_clean "source lib/detect.sh"
}

@test "lib/mcp-fallback.sh: sem erros ao fazer source" {
    source_clean "source lib/mcp-fallback.sh"
}

@test "lib/checkpoint-manager.sh: sem erros ao fazer source" {
    source_clean "source lib/core.sh && source lib/checkpoint-manager.sh"
}

@test "lib/error-recovery.sh: sem erros ao fazer source" {
    source_clean "source lib/core.sh && source lib/error-recovery.sh"
}

@test "lib/lessons.sh: sem erros ao fazer source" {
    source_clean "source lib/lessons.sh"
}

@test "lib/handoff.sh: sem erros ao fazer source" {
    source_clean "source lib/handoff.sh"
}
