#!/usr/bin/env bats

# Testes: estrutura e conteúdo das novas skills e regras

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Skill /spec ---

@test "skill spec/SKILL.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md" ]
}

@test "skill spec/SKILL.md contém trigger 'spec'" {
    grep -q "\"spec\"" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/SKILL.md documenta saída em docs/specs/" {
    grep -q "docs/specs/" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/SKILL.md menciona gate de aprovação" {
    grep -qi "aprovação\|gate\|aprovar" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/CHANGELOG.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/CHANGELOG.md" ]
}

@test "skill spec/VERSIONS/v1.0.0.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/VERSIONS/v1.0.0.md" ]
}

# --- Skill /break ---

@test "skill break/SKILL.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md" ]
}

@test "skill break/SKILL.md contém trigger 'break'" {
    grep -q "\"break\"" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/SKILL.md menciona protótipo antes de comportamento" {
    grep -qi "protótipo\|prototype" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/SKILL.md documenta saída em .devorq/state/tasklist/" {
    grep -q "tasklist" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/CHANGELOG.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/CHANGELOG.md" ]
}

@test "skill break/VERSIONS/v1.0.0.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/VERSIONS/v1.0.0.md" ]
}

# --- constraint-loader: reuse search ---

@test "constraint-loader menciona busca de código reutilizável" {
    grep -qi "reutiliz\|reuso\|reuse" "$DEVORQ_ROOT/.devorq/skills/constraint-loader/SKILL.md"
}

@test "constraint-loader tem Step 0 antes do Step 1" {
    grep -q "Step 0" "$DEVORQ_ROOT/.devorq/skills/constraint-loader/SKILL.md"
}

# --- Regra thin client ---

@test "laravel-tall.md contém regra Thin Client" {
    grep -qi "thin client\|fat server" "$DEVORQ_ROOT/.devorq/rules/stack/laravel-tall.md"
}

@test "laravel-tall.md proíbe lógica de negócio no frontend" {
    grep -qi "NUNCA.*lógica\|lógica.*frontend\|negócio.*frontend" "$DEVORQ_ROOT/.devorq/rules/stack/laravel-tall.md"
}

# --- prompts/claude.md atualizado ---

@test "prompts/claude.md menciona /spec" {
    grep -q "/spec" "$DEVORQ_ROOT/prompts/claude.md"
}

@test "prompts/claude.md menciona /break" {
    grep -q "/break" "$DEVORQ_ROOT/prompts/claude.md"
}
