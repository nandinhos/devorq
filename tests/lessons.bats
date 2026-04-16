#!/usr/bin/env bats

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

load "$DEVORQ_ROOT/lib/lessons.sh"

@test "lib/lessons.sh carrega sem erro" {
    [ -f "$DEVORQ_ROOT/lib/lessons.sh" ]
}

@test "capture_lesson gera ID no formato LESSON-NNNN-DD-MM-YYYY" {
    local output
    output=$(capture_lesson "$DEVORQ_ROOT" "Teste de título" "refactor" "medium" "manual")
    local lesson_id
    lesson_id=$(grep -m1 "^id:" "$output" 2>/dev/null | cut -d: -f2 | xargs)
    rm -f "$output"
    [[ "$lesson_id" =~ ^LESSON-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]
}

@test "capture_lesson usa front matter canônico de 12 campos" {
    local output
    output=$(capture_lesson "$DEVORQ_ROOT" "Teste front matter" "operacao" "high" "session-audit")
    local count
    count=$(grep -c "^id:\|^title:\|^domain:\|^status:\|^priority:\|^owner:\|^created_at:\|^updated_at:\|^source:\|^related_tasks:\|^related_files:\|^applied_to:" "$output" 2>/dev/null || echo "0")
    rm -f "$output"
    [ "$count" -eq 12 ]
}

@test "capture_lesson define applied_to como string vazia" {
    local output
    output=$(capture_lesson "$DEVORQ_ROOT" "Teste applied_to" "seguranca" "critical" "code-review")
    grep -q "^applied_to: \"\"$" "$output"
    rm -f "$output"
}

@test "get_next_lesson_number retorna número sequencial" {
    local num
    num=$(get_next_lesson_number "$DEVORQ_ROOT")
    [[ "$num" =~ ^[0-9]{4}$ ]]
}

@test "lessons_apply detecta target inválido" {
    run lessons_apply "$DEVORQ_DIR" "LESSON-9999-99-99-9999" "--target=invalid" 2>&1
    [ "$status" -ne 0 ]
}

@test "skill learned-lesson/SKILL.md documenta 4 destinos do Gate 7" {
    grep -q "Promover capability em skill existente" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "Criar nova skill" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "Memória global do user" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "Memória local do projeto" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
}

@test "skill learned-lesson/SKILL.md usa front matter canônico" {
    grep -q "^id: LESSON-" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^title:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^domain:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^status:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^priority:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^owner:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^created_at:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^updated_at:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^source:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^related_tasks:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^related_files:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
    grep -q "^applied_to:" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/SKILL.md"
}

@test "skill quality-gate/SKILL.md contém Etapa 9" {
    grep -q "Etapa 9" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
}

@test "skill quality-gate/SKILL.md contém Etapa 10" {
    grep -q "Etapa 10" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
}

@test "skill quality-gate/SKILL.md contém diálogo de validação manual" {
    grep -q "N/A" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
    grep -q "BUG:" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
}

@test "skill quality-gate/SKILL.md contém preview do commit" {
    grep -q "Aprovado" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
    grep -q "E:" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
    grep -q "^  R" "$DEVORQ_ROOT/.devorq/skills/quality-gate/SKILL.md"
}

@test "skill learned-lesson/CHANGELOG.md registra v2.1.0" {
    grep -q "v2.1.0" "$DEVORQ_ROOT/.devorq/skills/learned-lesson/CHANGELOG.md"
}

@test "skill quality-gate/CHANGELOG.md registra v1.3.0" {
    grep -q "v1.3.0" "$DEVORQ_ROOT/.devorq/skills/quality-gate/CHANGELOG.md"
}
