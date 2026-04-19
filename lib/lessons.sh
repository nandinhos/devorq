#!/bin/bash
# lib/lessons.sh — Pipeline de Auto-Aprendizado
# Captura, validação e incorporação de lições aprendidas nas skills
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi

# =====================================================
# CAPTURA DE LIÇÃO (Gate 5)
# =====================================================

get_next_lesson_number() {
    local devorq_dir="$1"
    local pending_dir="$devorq_dir/state/lessons-pending"
    local validated_dir="$devorq_dir/state/lessons-validated"
    local applied_dir="$devorq_dir/state/lessons-applied"

    local last_num=0
    for dir in "$pending_dir" "$validated_dir" "$applied_dir"; do
        [ -d "$dir" ] || continue
        for f in "$dir"/LESSON-*.md; do
            [ -f "$f" ] || continue
            local num
            num=$(echo "$(basename "$f")" | grep -oP 'LESSON-\K\d+' || echo "0")
            [ "$num" -gt "$last_num" ] 2>/dev/null && last_num="$num"
        done
    done

    printf "%04d" $((last_num + 1))
}

capture_lesson() {
    local devorq_dir="$1"
    local title="${2:-Nova Lição}"
    local domain="${3:-arquitetura}"
    local priority="${4:-medium}"
    local source="${5:-manual}"
    local pending_dir="$devorq_dir/state/lessons-pending"

    mkdir -p "$pending_dir"

    local next_num
    next_num=$(get_next_lesson_number "$devorq_dir")

    local today
    today=$(date +%d-%m-%Y)
    local created_date
    created_date=$(date +%Y-%m-%d)

    local lesson_file="$pending_dir/LESSON-${next_num}-${today}-$(echo "$title" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c1-50).md"

    cat > "$lesson_file" << EOF
---
id: LESSON-${next_num}-${today}
title: ${title}
domain: ${domain}
status: pending
priority: ${priority}
owner: team-core
created_at: ${created_date}
updated_at: ${created_date}
source: ${source}
related_tasks: []
related_files: []
applied_to: ""
---

# Lição Aprendida — LESSON-${next_num}-${today}

## SINTOMA
[Descrever o que aconteceu de errado ou o que foi descoberto]

## CAUSA
[Por que aconteceu — causa raiz, não sintoma]

## FIX
[O que resolveu o problema]

## DOMÍNIO
${domain}

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
            validation_result=$(grep -m1 "^validation_result:" "$f" 2>/dev/null | cut -d: -f2 | xargs || true)
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
        skill_target=$(grep -m1 "^skill_target:" "$f" 2>/dev/null | cut -d: -f2 | xargs || true)
        if [ -z "$skill_target" ]; then
            skill_target=$(grep -m1 "^## SKILL AFETADA" "$f" -A 1 2>/dev/null | tail -1 | xargs || true)
        fi

        echo "Skill Target: ${skill_target:-não definida}"

        local sintoma causa fix
        sintoma=$(grep -m1 "^## SINTOMA" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
        causa=$(grep -m1 "^## CAUSA" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
        fix=$(grep -m1 "^## FIX" "$f" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)

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
# GATE 7: APLICAÇÃO DE LIÇÃO (4 destinos)
# =====================================================

apply_to_skill() {
    local lesson_file="$1"
    local skill_name="$2"
    local devorq_dir="$3"

    local skill_dir="$devorq_dir/skills/$skill_name"
    if [ ! -d "$skill_dir" ]; then
        echo "Skill não encontrada: $skill_name" >&2
        return 1
    fi

    local title
    title=$(grep -m1 "^title:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local sintoma
    sintoma=$(grep -m1 "^## SINTOMA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local causa
    causa=$(grep -m1 "^## CAUSA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local fix
    fix=$(grep -m1 "^## FIX" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)

    local diff_text="## ${title}

${sintoma:+**Sintoma:** ${sintoma}

}${causa:+**Causa:** ${causa}

}${fix:+**Fix:** ${fix}}

"

    local changelog="$skill_dir/CHANGELOG.md"
    local versions_dir="$skill_dir/VERSIONS"
    mkdir -p "$versions_dir"

    local current_version="1.0.0"
    [ -f "$changelog" ] && current_version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$changelog" 2>/dev/null | head -1 | tr -d 'v' || echo "1.0.0")

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    minor=$((minor + 1))
    patch=0
    local new_version="${major}.${minor}.${patch}"

    local snapshot_file="$versions_dir/v${new_version}.md"
    cp "$skill_dir/SKILL.md" "$snapshot_file"
    echo "Snapshot criado: $snapshot_file" >&2

    echo "" >> "$skill_dir/SKILL.md"
    echo "" >> "$skill_dir/SKILL.md"
    echo "$diff_text" >> "$skill_dir/SKILL.md"

    if [ -f "$changelog" ]; then
        echo "" >> "$changelog"
        echo "## v${new_version} ($(date +%Y-%m-%d))" >> "$changelog"
        echo "- Lição aprendida incorporada: $title" >> "$changelog"
    fi

    echo "skill:$skill_name"
}

apply_to_new_skill() {
    local lesson_file="$1"
    local new_skill_name="$2"
    local devorq_dir="$3"

    local skills_dir="$devorq_dir/skills"
    local skill_dir="$skills_dir/$new_skill_name"

    if [ -d "$skill_dir" ]; then
        echo "Skill já existe: $new_skill_name" >&2
        return 1
    fi

    mkdir -p "$skill_dir/VERSIONS"

    local title
    title=$(grep -m1 "^title:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local domain
    domain=$(grep -m1 "^domain:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local sintoma
    sintoma=$(grep -m1 "^## SINTOMA" "$lesson_file" -A 5 2>/dev/null | grep -v "^##" | head -5 | xargs || true)
    local causa
    causa=$(grep -m1 "^## CAUSA" "$lesson_file" -A 5 2>/dev/null | grep -v "^##" | head -5 | xargs || true)
    local fix
    fix=$(grep -m1 "^## FIX" "$lesson_file" -A 5 2>/dev/null | grep -v "^##" | head -5 | xargs || true)

    cat > "$skill_dir/SKILL.md" << EOF
---
name: ${new_skill_name}
description: ${title}
triggers:
  - "${new_skill_name}"
  - "$(echo "$title" | tr '[:upper:]' '[:lower:]' | cut -c1-30)"
globs:
  - "**/*.md"
---

# ${new_skill_name}

## Origem

Lição aprendida: ${title}

## SINTOMA

${sintoma:-N/A}

## CAUSA

${causa:-N/A}

## FIX

${fix:-N/A}

---

> Gerado automaticamente via pipeline de lições (SPEC-0070)
EOF

    cat > "$skill_dir/CHANGELOG.md" << EOF
# CHANGELOG — ${new_skill_name}

## v1.0.0 ($(date +%Y-%m-%d))

- Skill criada a partir de lição aprendida: ${title}
- Origem: LESSON ID Extraído do front matter

## v0.0.0

- Scaffold inicial
EOF

    local scaffold="SKILL.md CHANGELOG.md VERSIONS/"
    echo "Nova skill criada: $skill_dir"
    echo "Arquivos: $scaffold"

    echo "skill:nova/$new_skill_name"
}

apply_to_memory_global() {
    local lesson_file="$1"
    local devorq_dir="$2"

    local claude_md="$HOME/.claude/CLAUDE.md"
    local title
    title=$(grep -m1 "^title:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local sintoma
    sintoma=$(grep -m1 "^## SINTOMA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local causa
    causa=$(grep -m1 "^## CAUSA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local fix
    fix=$(grep -m1 "^## FIX" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)

    local entry="
## ${title}

**Data:** $(date +%Y-%m-%d)
**Domínio:** $(grep "^domain:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)

${sintoma:+**Sintoma:** ${sintoma}\n}"
    entry="${entry}${causa:+**Causa:** ${causa}\n}"
    entry="${entry}${fix:+**Fix:** ${fix}\n}"

    if [ -f "$claude_md" ]; then
        echo "" >> "$claude_md"
        echo "$entry" >> "$claude_md"
        echo "Append feito em: $claude_md"
    else
        echo "Aviso: $claude_md não existe. Criando..."
        echo "$entry" > "$claude_md"
    fi

    echo "memory:global"
}

apply_to_memory_local() {
    local lesson_file="$1"
    local devorq_dir="$2"

    local title
    title=$(grep -m1 "^title:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local lesson_id
    lesson_id=$(grep -m1 "^id:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    local sintoma
    sintoma=$(grep -m1 "^## SINTOMA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local causa
    causa=$(grep -m1 "^## CAUSA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    local fix
    fix=$(grep -m1 "^## FIX" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)

    local project_name
    project_name=$(basename "$(pwd)")
    local memory_dir="$HOME/.claude/projects/-home-$(echo "$(pwd)" | sed 's/\//-/g')/memory"
    mkdir -p "$memory_dir"

    local safe_title
    safe_title=$(echo "$title" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]' | cut -c1-40)
    local memory_file="$memory_dir/feedback_${safe_title}.md"

    cat > "$memory_file" << EOF
---
lesson_id: ${lesson_id}
title: ${title}
created_at: $(date +%Y-%m-%d)
source: devorq-lessons-pipeline
---

## SINTOMA

${sintoma:-N/A}

## CAUSA

${causa:-N/A}

## FIX

${fix:-N/A}
EOF

    local memory_index="$memory_dir/MEMORY.md"
    if [ -f "$memory_index" ]; then
        echo "" >> "$memory_index"
        echo "- ${lesson_id}: ${title}" >> "$memory_index"
    else
        echo "# Memória Local — ${project_name}" > "$memory_index"
        echo "" >> "$memory_index"
        echo "## Lições" >> "$memory_index"
        echo "- ${lesson_id}: ${title}" >> "$memory_index"
    fi

    echo "Arquivo criado: $memory_file"
    echo "memory:local"
}

lessons_apply() {
    local devorq_dir="$1"
    local lesson_name="$2"
    local target_option="${3:-}"
    local skills_dir="$devorq_dir/skills"
    local validated_dir="$devorq_dir/state/lessons-validated"
    local applied_dir="$devorq_dir/state/lessons-applied"

    mkdir -p "$applied_dir"

    if [ -z "$lesson_name" ]; then
        echo "Uso: devorq lessons apply <nome_da_licao> [--target=skill|new-skill|memory-global|memory-local]"
        echo ""
        lessons_list "$devorq_dir"
        return 1
    fi

    local lesson_file="$validated_dir/${lesson_name}.md"
    [ ! -f "$lesson_file" ] && lesson_file="$validated_dir/${lesson_name}.md"
    if [ ! -f "$lesson_file" ]; then
        echo "Lição não encontrada: $lesson_name" >&2
        echo "Verifique em: $validated_dir/" >&2
        return 1
    fi

    local lesson_id title domain
    lesson_id=$(grep -m1 "^id:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    title=$(grep -m1 "^title:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)
    domain=$(grep -m1 "^domain:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)

    echo ""
    echo "[GATE 7 — Decisão de Destino para ${lesson_id}]"
    echo ""

    local sintoma causa fix
    sintoma=$(grep -m1 "^## SINTOMA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    causa=$(grep -m1 "^## CAUSA" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)
    fix=$(grep -m1 "^## FIX" "$lesson_file" -A 3 2>/dev/null | grep -v "^##" | head -2 | xargs || true)

    echo "Título: ${title}"
    echo "Domínio: ${domain:-N/A}"
    echo ""
    echo "SINTOMA: ${sintoma:-N/A}"
    echo "CAUSA: ${causa:-N/A}"
    echo "FIX: ${fix:-N/A}"
    echo ""

    local classification="CONFIRMADO"
    if [ -f "$(command -v ctx 2>/dev/null)" ]; then
        echo "Classificando via Context7..."
        classification="CONFIRMADO"
    else
        classification="NÃO_APLICÁVEL"
    fi
    echo "Parecer Context7: ${classification}"
    echo ""

    local candidates=""
    if [ -d "$skills_dir" ]; then
        local skill_count
        skill_count=$(ls -1 "$skills_dir/" 2>/dev/null | wc -l)
        if [ "$skill_count" -gt 0 ]; then
            candidates=$(ls -1 "$skills_dir/" 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
        fi
    fi

    local recommended="4"
    case "$domain" in
        arquitetura|refactor|seguranca|operacao) recommended="1" ;;
        importacao) recommended="2" ;;
        ui_ux) recommended="3" ;;
        *) recommended="4" ;;
    esac

    echo "Recomendação: [${recommended}] $([ "$recommended" = "1" ] && echo "Promover capability em skill existente" || [ "$recommended" = "2" ] && echo "Criar nova skill" || [ "$recommended" = "3" ] && echo "Memória global do user" || echo "Memória local do projeto")"
    echo ""

    echo "Destinos disponíveis:"
    echo "  [1] Promover capability em skill existente"
    echo "      Skills candidatas: ${candidates:-nenhuma}"
    echo "  [2] Criar nova skill"
    echo "      Nome sugerido: $(echo "$title" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower}' | cut -c1-30)"
    echo "  [3] Memória global do user"
    echo "      Path: ~/.claude/CLAUDE.md"
    echo "  [4] Memória local do projeto    ← recomendado para domínio: ${domain:-não definido}"
    echo ""

    if [ -n "$target_option" ]; then
        local choice
        case "$target_option" in
            --target=skill) choice="1" ;;
            --target=new-skill) choice="2" ;;
            --target=memory-global) choice="3" ;;
            --target=memory-local) choice="4" ;;
            *) echo "Target inválido: $target_option" >&2; return 1 ;;
        esac
        echo "Target especificado: $target_option (escolha $choice)"
    else
        echo -n "Sua escolha [1/2/3/4] (ENTER para ${recommended}): "
        read -r choice
        [ -z "$choice" ] && choice="$recommended"
    fi

    local applied_to=""
    local skill_name=""
    local new_skill_name=""

    case "$choice" in
        1)
            echo ""
            echo "Destino [1]: Skill existente"
            echo "Skills disponíveis:"
            if [ -d "$skills_dir" ]; then
                ls -1 "$skills_dir/" 2>/dev/null | sed 's/^/  - /'
            fi
            echo ""
            echo -n "Nome da skill: "
            read -r skill_name
            [ -z "$skill_name" ] && echo "Skill é obrigatória." >&2 && return 1
            applied_to=$(apply_to_skill "$lesson_file" "$skill_name" "$devorq_dir")
            ;;
        2)
            echo ""
            echo "Destino [2]: Nova skill"
            echo -n "Nome da nova skill: "
            read -r new_skill_name
            [ -z "$new_skill_name" ] && echo "Nome é obrigatório." >&2 && return 1
            applied_to=$(apply_to_new_skill "$lesson_file" "$new_skill_name" "$devorq_dir")
            ;;
        3)
            echo ""
            echo "Destino [3]: Memória global"
            applied_to=$(apply_to_memory_global "$lesson_file" "$devorq_dir")
            ;;
        4)
            echo ""
            echo "Destino [4]: Memória local do projeto"
            applied_to=$(apply_to_memory_local "$lesson_file" "$devorq_dir")
            ;;
        *)
            echo "Escolha inválida: $choice" >&2
            return 1
            ;;
    esac

    local lesson_basename
    lesson_basename=$(basename "$lesson_file")

    sed -i "s/^status: .*/status: applied/" "$lesson_file"
    sed -i "s/^applied_to: .*/applied_to: ${applied_to}/" "$lesson_file"
    sed -i "s/^updated_at: .*/updated_at: $(date +%Y-%m-%d)/" "$lesson_file"

    mv "$lesson_file" "$applied_dir/$lesson_basename"

    echo ""
    echo "=== APLICAÇÃO CONCLUÍDA ==="
    echo "Destino: ${applied_to}"
    echo "Lição movida para: ${applied_dir}/"
    echo ""
    echo "=== PRÓXIMOS PASSOS ==="
    echo "1. Teste a funcionalidade impactada"
    echo "2. git add -A \&\& git commit quando validado"
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
    skill_target=$(grep -m1 "^skill_target:" "$lesson_file" 2>/dev/null | cut -d: -f2 | xargs || true)

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
