#!/usr/bin/env bats

# Sprint 5 — Gaps TD-001: lessons_list pipefail e detect_stack project.md override
# Cobre: lessons list exit 0 com arquivo sem validation_result via CLI (5.1),
#        lessons list exibe seção APLICADAS via CLI (5.2),
#        detect_stack lê override de .devorq/rules/project.md (5.3)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ────────────────────────────────────────────
# 5.1: lessons list (via CLI com set -eEo pipefail ativo) não aborta
#      quando validation_result: está ausente em arquivo validado

@test "5.1: lessons list via CLI retorna exit 0 com arquivo legado sem validation_result" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/.devorq/state/lessons-validated"
    mkdir -p "$tmpdir/.devorq/state/lessons-pending"
    mkdir -p "$tmpdir/.devorq/state/lessons-applied"

    cat > "$tmpdir/.devorq/state/lessons-validated/LESSON-0001-01-01-2026-sem-campo.md" << 'EOF'
id: LESSON-0001-01-01-2026
title: Lição sem campo validation_result
domain: arquitetura
status: validated
EOF

    run bash -c "cd '$tmpdir' && bash '$DEVORQ_ROOT/bin/devorq' lessons list"
    rm -rf "$tmpdir"

    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────
# 5.2: lessons list via CLI exibe seção APLICADAS mesmo quando VALIDADAS
#      tem arquivo legado sem campo validation_result

@test "5.2: lessons list via CLI exibe secao APLICADAS apos VALIDADAS com arquivo legado" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/.devorq/state/lessons-validated"
    mkdir -p "$tmpdir/.devorq/state/lessons-pending"
    mkdir -p "$tmpdir/.devorq/state/lessons-applied"

    cat > "$tmpdir/.devorq/state/lessons-validated/LESSON-0001-01-01-2026-legada.md" << 'EOF'
id: LESSON-0001-01-01-2026
title: Lição legada
status: validated
EOF

    cat > "$tmpdir/.devorq/state/lessons-applied/LESSON-0002-02-02-2026-aplicada.md" << 'EOF'
id: LESSON-0002-02-02-2026
title: Lição aplicada
status: applied
EOF

    run bash -c "cd '$tmpdir' && bash '$DEVORQ_ROOT/bin/devorq' lessons list"
    rm -rf "$tmpdir"

    [ "$status" -eq 0 ]
    [[ "$output" == *"LIÇÕES APLICADAS"* ]]
    [[ "$output" == *"LESSON-0002-02-02-2026-aplicada"* ]]
}

# ────────────────────────────────────────────
# 5.3: detect_stack respeita override em .devorq/rules/project.md

@test "5.3: detect_stack retorna stack do project.md quando campo stack: presente" {
    source "$DEVORQ_ROOT/lib/detection.sh"

    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/.devorq/rules"

    cat > "$tmpdir/.devorq/rules/project.md" << 'EOF'
# Regras do Projeto
stack: bash-framework
EOF

    run detect_stack "$tmpdir"
    rm -rf "$tmpdir"

    [ "$status" -eq 0 ]
    [ "$output" = "bash-framework" ]
}
