#!/usr/bin/env bats

# Testes: todos os módulos lib/ e skills devem usar .devorq/ e nunca .aidev/

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Helper: arquivo não deve conter referência ao path legado .aidev (ignorando .aidev-superpowers que é path global)
no_aidev_refs() {
    local file="$1"
    # Exclui .aidev-superpowers (diretório de instalação global, conceito diferente)
    run grep -cE '\.aidev[^-]|\.aidev$' "$file"
    [ "$output" -eq 0 ]
}

# --- lib/ ---

@test "lib/state.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/state.sh"
}

@test "lib/orchestration.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/orchestration.sh"
}

@test "lib/mcp-fallback.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/mcp-fallback.sh"
}

@test "lib/mcp.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/mcp.sh"
}

@test "lib/core.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/core.sh"
}

@test "lib/checkpoint-manager.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/checkpoint-manager.sh"
}

@test "lib/detection.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/detection.sh"
}

@test "lib/error-recovery.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/error-recovery.sh"
}

@test "lib/feature-lifecycle.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/feature-lifecycle.sh"
}

@test "lib/mcp-health-check.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/mcp-health-check.sh"
}

@test "lib/mcp-json-generator.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/mcp-json-generator.sh"
}

@test "lib/stack-detector.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/stack-detector.sh"
}

@test "lib/workflow-commit.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/workflow-commit.sh"
}

@test "lib/workflow-release.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/workflow-release.sh"
}

@test "lib/workflow-sync.sh: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/lib/workflow-sync.sh"
}

# --- .devorq/skills/ ---

@test "skill brainstorming/SKILL.md: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/.devorq/skills/brainstorming/SKILL.md"
}

@test "skill learned-lesson/SKILL.md: não referencia .aidev/" {
    no_aidev_refs "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
}
