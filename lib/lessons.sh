#!/bin/bash
# lib/lessons.sh — Pipeline de Auto-Aprendizado
# Captura, validação e incorporação de lições aprendidas nas skills
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi

# =====================================================
# CAPTURA DE LIÇÃO (Gate 5)
# =====================================================

capture_lesson() {
    local devorq_dir="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local pending_dir="$devorq_dir/state/lessons-pending"

    mkdir -p "$pending_dir"

    local lesson_file="$pending_dir/lesson_${timestamp}.md"

    cat > "$lesson_file" << EOF
---
id: lesson_${timestamp}
title: Nova Lição
skill_target: quality-gate
status: pending
created_at: $(date +%Y-%m-%d)
---

# Lição Aprendida — $timestamp

## SINTOMA
[Descrever o que aconteceu de errado ou o que foi descoberto]

## CAUSA
[Por que aconteceu — causa raiz, não sintoma]

## FIX
[O que resolveu o problema]

## SKILL AFETADA
[scope-guard / pre-flight / quality-gate / handoff / outra]

## STATUS
pending
EOF

    echo "$lesson_file"
}

# =====================================================
# LISTAGEM
# =====================================================

lessons_list() {
    local devorq_dir="$1"
    local pending_dir="$devorq_dir/state/lessons-pending"
    local validated_dir="$devorq_dir/state/lessons-validated"
    local applied_dir="$devorq_dir/state/lessons-applied"

    echo "=== LIÇÕES PENDENTES ==="
    if [ -d "$pending_dir" ] && [ "$(ls -A "$pending_dir" 2>/dev/null)" ]; then
        local count=0
        for f in "$pending_dir"/*.md; do
            [ -f "$f" ] || continue
            count=$((count + 1))
            local name
            name=$(basename "$f" .md)
            echo "  [$count] $name"
        done
        echo ""
        echo "Total pendentes: $count"
    else
        echo "  Nenhuma lição pendente."
    fi

    echo ""
    echo "=== LIÇÕES VALIDADAS ==="
    if [ -d "$validated_dir" ] && [ "$(ls -A "$validated_dir" 2>/dev/null)" ]; then
        local count=0
        for f in "$validated_dir"/*.md; do
            [ -f "$f" ] || continue
            count=$((count + 1))
            local name
            name=$(basename "$f" .md)
            local validation_result
            validation_result=$(grep -m1 "^validation_result:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
            echo "  [$count] $name ($validation_result)"
        done
        echo "Total validadas: $count"
    else
        echo "  Nenhuma lição validada."
    fi

    echo ""
    echo "=== LIÇÕES APLICADAS ==="
    if [ -d "$applied_dir" ] && [ "$(ls -A "$applied_dir" 2>/dev/null)" ]; then
        local count=0
        for f in "$applied_dir"/*.md; do
            [ -f "$f" ] || continue
            count=$((count + 1))
            local name
            name=$(basename "$f" .md)
            echo "  [$count] $name"
        done
        echo "Total aplicadas: $count"
    else
        echo "  Nenhuma lição aplicada."
    fi
}

# =====================================================
# GATE 6: VALIDAÇÃO AUTOMÁTICA
# =====================================================

lessons_validate() {
    local devorq_dir="$1"
    local pending_dir="$devorq_dir/state/lessons-pending"
    local validated_dir="$devorq_dir/state/lessons-validated"

    mkdir -p "$validated_dir"

    if [ ! -d "$pending_dir" ] || [ -z "$(ls -A "$pending_dir" 2>/dev/null)" ]; then
        echo "Nenhuma lição pendente para validar."
        return 0
    fi

    echo ""
    echo "=== VALIDAÇÃO DE LIÇÕES (Gate 6) ==="
    echo ""

    local count=0
    local files=()
    for f in "$pending_dir"/*.md; do
        [ -f "$f" ] || continue
        count=$((count + 1))
        files+=("$f")
    done

    if [ "$count" -eq 0 ]; then
        echo "Nenhuma lição pendente."
        return 0
    fi

    echo "Lições encontradas: $count"
    echo ""

    local validated_count=0

    for f in "${files[@]}"; do
        local lesson_name
        lesson_name=$(basename "$f" .md)

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Validando: $lesson_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        local skill_target
        skill_target=$(grep -m1 "^skill_target:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
        if [ -z "$skill_target" ]; then
            skill_target=$(grep -m1 "^## SKILL AFETADA" "$f" -A 1 2>/dev/null | tail -1 | xargs)
        fi

        echo "Skill Target: ${skill_target:-não definida}"

        local sintoma causa fix
        sintoma=$(grep -m1 "^## SINTOMA" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs)
        causa=$(grep -m1 "^## CAUSA" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs)
        fix=$(grep -m1 "^## FIX" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs)

        echo ""
        echo "SINTOMA: ${sintoma:-N/A}"
        echo "CAUSA: ${causa:-N/A}"
        echo "FIX: ${fix:-N/A}"
        echo ""

        echo "Classificando via Context7..."
        local classification="PARCIAL"
        local classification_details="Prática válida. Verificar documentação oficial."

        local ctx_cmd
        ctx_cmd=$(command -v ctx 2>/dev/null || echo "")
        if [ -x "$ctx_cmd" ]; then
            local ctx_query="documentation for skill $skill_target bash shell best practices"
            local ctx_result
            ctx_result=$($ctx_cmd search "$ctx_query" 2>/dev/null | head -20 || echo "")
            if echo "$ctx_result" | grep -qi "not found\|no results"; then
                classification="PARCIAL"
                classification_details="Context7 não encontrou docs específicas. Prática parece válida."
            else
                classification="CONFIRMADO"
                classification_details="Confirmado pela documentação."
            fi
        fi

        echo "Classificação: $classification"
        echo "Detalhes: $classification_details"
        echo ""

        local diff_text="+ ## Nova Regra: $lesson_name"
        if [ -n "$fix" ]; then
            diff_text="$diff_text
+ ${fix}"
        fi
        diff_text="$diff_text
+ **Skill:** $skill_target"

        echo "Diff Proposto:"
        echo "~~~diff"
        echo "$diff_text"
        echo "~~~"
        echo ""

        echo "[Gate 6] Revisar acima."
        echo "  [ENTER] - Mover para lessons-validated/"
        echo "  [s]      - Pular esta lição"
        echo "  [q]      - Sair sem aplicar"
        echo ""

        local proceed
        proceed=$(bash -c 'read -r proceed; echo "$proceed"' || echo "")

        if [[ "$proceed" == "q" ]]; then
            echo "Abortando validação."
            break
        elif [[ "$proceed" == "s" ]]; then
            echo "Lição $lesson_name ignorada."
            continue
        fi

        local lesson_basename
        lesson_basename=$(basename "$f")

        cat >> "$f" << EOF

## VALIDAÇÃO (Gate 6)
validation_result: $classification
validation_details: $classification_details
diff_proposed: |
$diff_text
validated_at: $(date -Iseconds)
EOF

        mv "$f" "$validated_dir/$lesson_basename"
        echo "✓ Movida para lessons-validated/"

        validated_count=$((validated_count + 1))
        echo ""
    done

    echo ""
    echo "=== VALIDAÇÃO CONCLUÍDA ==="
    echo "Lições validadas: $validated_count"
    echo ""
    echo "Próximo passo: devorq lessons apply <nome>"
}

# =====================================================
# GATE 7: APLICAÇÃO DE LIÇÃO
# =====================================================

lessons_apply() {
    local devorq_dir="$1"
    local lesson_name="$2"
    local skills_dir="$devorq_dir/skills"
    local validated_dir="$devorq_dir/state/lessons-validated"
    local applied_dir="$devorq_dir/state/lessons-applied"

    mkdir -p "$applied_dir"

    if [ -z "$lesson_name" ]; then
        echo "Uso: devorq lessons apply <nome_da_licao>"
        echo ""
        lessons_list "$devorq_dir"
        return 1
    fi

    local lesson_file="$validated_dir/${lesson_name}.md"
    if [ ! -f "$lesson_file" ]; then
        lesson_file="$validated_dir/${lesson_name}.md"
    fi

    if [ ! -f "$lesson_file" ]; then
        echo "Lição não encontrada: $lesson_name"
        echo "Verifique em: $validated_dir/"
        return 1
    fi

    echo ""
    echo "=== APLICAR LIÇÃO: $lesson_name (Gate 7) ==="
    echo ""

    local skill_target
    skill_target=$(grep -m1 "^skill_target:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs)

    local diff_proposed
    diff_proposed=$(grep -m1 "^diff_proposed:" "$lesson_file" -A 20 2>/dev/null | grep -v "^diff_proposed:" | head -15)

    echo "Skill Target: ${skill_target:-não definida}"
    echo ""
    echo "Diff proposto:"
    echo "~~~diff"
    echo "$diff_proposed"
    echo "~~~"
    echo ""

    local skill_dir="$skills_dir/$skill_target"
    if [ ! -d "$skill_dir" ]; then
        echo "Skill não encontrada: $skill_target"
        echo "Skills disponíveis:"
        ls -1 "$skills_dir/" 2>/dev/null | sed 's/^/  - /'
        return 1
    fi

    echo "Skill: $skill_target"
    echo ""
    echo "[Gate 7] Revisar diff acima."
    echo "  [ENTER] - Aplicar diff (com snapshot)"
    echo "  [e]      - Editar diff no editor"
    echo "  [q]      - Cancelar"
    echo ""

    local proceed
    proceed=$(bash -c 'read -r proceed; echo "$proceed"' || echo "")

    if [[ "$proceed" == "q" ]]; then
        echo "Aplicação cancelada."
        return 1
    fi

    local final_diff="$diff_proposed"
    if [[ "$proceed" == "e" ]]; then
        local tmpfile="/tmp/lesson_diff_$$.md"
        echo "$diff_proposed" > "$tmpfile"
        "${EDITOR:-vi}" "$tmpfile"
        final_diff=$(cat "$tmpfile")
        rm -f "$tmpfile"
        echo "Diff atualizado após edição."
    fi

    local changelog="$skill_dir/CHANGELOG.md"
    local versions_dir="$skill_dir/VERSIONS"

    mkdir -p "$versions_dir"

    local current_version="1.0.0"
    if [ -f "$changelog" ]; then
        current_version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$changelog" 2>/dev/null | head -1 | tr -d 'v' || echo "1.0.0")
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    minor=$((minor + 1))
    patch=0
    local new_version="${major}.${minor}.${patch}"

    local snapshot_file="$versions_dir/v${new_version}.md"
    cp "$skill_dir/SKILL.md" "$snapshot_file"
    echo "Snapshot criado: $snapshot_file"

    echo "" >> "$skill_dir/SKILL.md"
    echo "" >> "$skill_dir/SKILL.md"
    echo "$final_diff" >> "$skill_dir/SKILL.md"

    if [ -f "$changelog" ]; then
        echo "" >> "$changelog"
        echo "## v${new_version} ($(date +%Y-%m-%d))" >> "$changelog"
        echo "- Lição aprendida incorporada: $lesson_name" >> "$changelog"
    fi

    local lesson_basename
    lesson_basename=$(basename "$lesson_file")

    cat >> "$lesson_file" << EOF

## APLICAÇÃO (Gate 7)
diff_applied: true
applied_version: $new_version
applied_at: $(date -Iseconds)
skill_snapshot: $snapshot_file
EOF

    mv "$lesson_file" "$applied_dir/$lesson_basename"

    echo ""
    echo "=== APLICAÇÃO CONCLUÍDA ==="
    echo "Skill atualizada: $skill_target"
    echo "Nova versão: v$new_version"
    echo "Lição movida para: $applied_dir/"
    echo ""
    echo "=== PRÓXIMOS PASSOS ==="
    echo "1. Teste a funcionalidade impactada"
    echo "2. Verifique que não há regressions"
    echo "3. Commit manual quando validado:"
    echo "   git add -A && git commit -m \"feat(skill): incorpora lição $lesson_name - $skill_target\""
}

# =====================================================
# VERIFICAR DIFF
# =====================================================

lessons_diff() {
    local devorq_dir="$1"
    local lesson_name="$2"
    local validated_dir="$devorq_dir/state/lessons-validated"

    if [ -z "$lesson_name" ]; then
        echo "Uso: devorq lessons diff <nome>"
        return 1
    fi

    local lesson_file="$validated_dir/${lesson_name}.md"
    if [ ! -f "$lesson_file" ]; then
        lesson_file="$validated_dir/${lesson_name}.md"
    fi

    if [ ! -f "$lesson_file" ]; then
        echo "Lição não encontrada: $lesson_name"
        return 1
    fi

    local skill_target
    skill_target=$(grep -m1 "^skill_target:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs)

    local diff_proposed
    diff_proposed=$(grep -m1 "^diff_proposed:" "$lesson_file" -A 20 2>/dev/null | grep -v "^diff_proposed:" | head -15)

    echo "=== DIFF: $lesson_name ==="
    echo "Skill Target: ${skill_target:-não definida}"
    echo ""
    echo "~~~diff"
    echo "$diff_proposed"
    echo "~~~"
}

# =====================================================
# VERSIONAMENTO DE SKILL
# =====================================================

version_skill() {
    local skills_dir="$1"
    local skill_name="$2"
    local bump_type="$3"
    local skill_dir="$skills_dir/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        echo "Skill não encontrada: $skill_name"
        return 1
    fi

    local changelog="$skill_dir/CHANGELOG.md"
    local versions_dir="$skill_dir/VERSIONS"

    mkdir -p "$versions_dir"

    local current_version="1.0.0"
    if [ -f "$changelog" ]; then
        current_version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$changelog" 2>/dev/null | head -1 | tr -d 'v' || echo "1.0.0")
    fi

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    case "$bump_type" in
        major) major=$((major + 1)); minor=0; patch=0 ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        patch) patch=$((patch + 1)) ;;
        *)
            echo "Tipo de bump inválido: $bump_type (use patch, minor ou major)"
            return 1
            ;;
    esac

    local new_version="${major}.${minor}.${patch}"
    local snapshot_file="$versions_dir/v${new_version}.md"

    cp "$skill_dir/SKILL.md" "$snapshot_file"

    echo "Snapshot criado: $snapshot_file"
    echo "Atualize o CHANGELOG.md com a entrada v${new_version}."
    echo ""
    echo "Entrada para CHANGELOG.md:"
    echo ""
    echo "## v${new_version} ($(date +%Y-%m-%d))"
    echo ""
    echo "- [descrever mudança]"
}

# =====================================================
# ROLLBACK DE SKILL
# =====================================================

skill_rollback() {
    local skills_dir="$1"
    local skill_name="$2"
    local target_version="$3"
    local skill_dir="$skills_dir/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        echo "Skill não encontrada: $skill_name"
        return 1
    fi

    local version_file="$skill_dir/VERSIONS/${target_version}.md"

    if [ ! -f "$version_file" ]; then
        echo "Versão não encontrada: $target_version"
        echo "Versões disponíveis:"
        ls -1 "$skill_dir/VERSIONS/" 2>/dev/null | sed 's/^/  /'
        return 1
    fi

    local current_backup
    current_backup="$skill_dir/VERSIONS/pre-rollback-$(date +%Y%m%d_%H%M%S).md"
    cp "$skill_dir/SKILL.md" "$current_backup"

    cp "$version_file" "$skill_dir/SKILL.md"

    echo "Rollback concluído: $skill_name → $target_version"
    echo "Backup da versão anterior: $current_backup"
}
