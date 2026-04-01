#!/bin/bash
# lib/lessons.sh — Pipeline de Auto-Aprendizado
# Captura, validação e incorporação de lições aprendidas nas skills

# =====================================================
# CAPTURA DE LIÇÃO
# =====================================================

capture_lesson() {
    local devorq_dir="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local pending_dir="$devorq_dir/state/lessons-pending"

    mkdir -p "$pending_dir"

    local lesson_file="$pending_dir/lesson_${timestamp}.md"

    cat > "$lesson_file" << EOF
# Lição Aprendida — $timestamp

## SINTOMA
[Descrever o que aconteceu de errado ou o que foi descoberto]

## CAUSA
[Por que aconteceu — causa raiz, não sintoma]

## FIX
[O que resolveu o problema]

## SKILL AFETADA
[Qual skill deveria prevenir isso: scope-guard / pre-flight / quality-gate / integrity-guardian / outra]

## STATUS
pending

## CAPTURADO EM
$(date -Iseconds)
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
            echo "  [$count] $name"
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
# VALIDAÇÃO VIA CONTEXT7 (Gate 6)
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

    echo "=== VALIDAÇÃO DE LIÇÕES ==="
    echo ""
    echo "Lições encontradas:"

    local count=0
    local files=()
    for f in "$pending_dir"/*.md; do
        [ -f "$f" ] || continue
        count=$((count + 1))
        files+=("$f")
        echo "  [$count] $(basename "$f" .md)"
    done

    echo ""
    echo "Para validar, apresente estas lições ao LLM disponível com a seguinte instrução:"
    echo ""
    echo "---"
    echo "Usando MCP Context7, valide cada lição abaixo contra a documentação oficial."
    echo "Para cada lição, retorne:"
    echo "  CONFIRMADO  — documentação oficial confirma a prática"
    echo "  PARCIAL     — prática válida mas não documentada oficialmente"
    echo "  INCORRETO   — contraria documentação oficial (explicar por quê)"
    echo ""
    echo "Lições para validar:"
    for f in "${files[@]}"; do
        echo ""
        echo "### $(basename "$f" .md)"
        cat "$f"
        echo ""
    done
    echo "---"
    echo ""

    # Gate 6
    echo "[Gate 6] Após receber o relatório de validação do LLM, confirmar para mover para validadas."
    echo "         Use: devorq lessons apply <nome_da_licao>"
}

# =====================================================
# APLICAÇÃO DE LIÇÃO (Gate 7)
# =====================================================

lessons_apply() {
    local devorq_dir="$1"
    local lesson_name="$2"
    local skills_dir="$devorq_dir/skills"
    local pending_dir="$devorq_dir/state/lessons-pending"
    local validated_dir="$devorq_dir/state/lessons-validated"
    local applied_dir="$devorq_dir/state/lessons-applied"

    mkdir -p "$validated_dir" "$applied_dir"

    if [ -z "$lesson_name" ]; then
        echo "Uso: devorq lessons apply <nome_da_licao>"
        echo ""
        lessons_list "$devorq_dir"
        return 1
    fi

    # Encontrar arquivo da lição
    local lesson_file=""
    if [ -f "$pending_dir/${lesson_name}.md" ]; then
        lesson_file="$pending_dir/${lesson_name}.md"
    elif [ -f "$validated_dir/${lesson_name}.md" ]; then
        lesson_file="$validated_dir/${lesson_name}.md"
    else
        echo "Lição não encontrada: $lesson_name"
        return 1
    fi

    echo "=== APLICAR LIÇÃO: $lesson_name ==="
    echo ""
    cat "$lesson_file"
    echo ""

    # Gate 7
    echo "[Gate 7] Qual skill deve ser atualizada com esta lição?"
    echo "         Skills disponíveis:"
    ls -1 "$skills_dir/" 2>/dev/null | sed 's/^/           - /'
    echo ""
    echo "         Após identificar a skill e o diff, use:"
    echo "         devorq skill version <nome_skill> minor"
    echo "         para criar nova versão e atualizar o SKILL.md."
    echo ""

    # Mover para aplicadas
    mv "$lesson_file" "$applied_dir/" 2>/dev/null || true
    echo "Lição movida para aplicadas: $applied_dir/$(basename "$lesson_file")"
}

# =====================================================
# VERSIONAMENTO DE SKILL
# =====================================================

version_skill() {
    local skills_dir="$1"
    local skill_name="$2"
    local bump_type="$3"  # patch | minor | major
    local skill_dir="$skills_dir/$skill_name"

    if [ ! -d "$skill_dir" ]; then
        echo "Skill não encontrada: $skill_name"
        return 1
    fi

    local changelog="$skill_dir/CHANGELOG.md"
    local versions_dir="$skill_dir/VERSIONS"

    mkdir -p "$versions_dir"

    # Detectar versão atual
    local current_version="1.0.0"
    if [ -f "$changelog" ]; then
        current_version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$changelog" | head -1 | tr -d 'v')
    fi

    # Calcular nova versão
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

    # Criar snapshot imutável
    cp "$skill_dir/SKILL.md" "$snapshot_file"

    echo "Snapshot criado: $snapshot_file"
    echo "Atualize o CHANGELOG.md com a entrada v${new_version} e edite o SKILL.md conforme necessário."
    echo ""
    echo "Entrada para CHANGELOG.md:"
    echo ""
    echo "## v${new_version} ($(date +%Y-%m-%d))"
    echo ""
    echo "- [descrever mudança incorporada da lição]"
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

    # Backup da versão atual antes de reverter
    local current_backup="$skill_dir/VERSIONS/pre-rollback-$(date +%Y%m%d_%H%M%S).md"
    cp "$skill_dir/SKILL.md" "$current_backup"

    # Restaurar versão alvo
    cp "$version_file" "$skill_dir/SKILL.md"

    echo "Rollback concluído: $skill_name → $target_version"
    echo "Backup da versão anterior: $current_backup"
}
