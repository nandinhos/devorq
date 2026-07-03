#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/lessons/crud.sh - DEVORQ Lessons CRUD module
#
# Modulo responsavel por:
#   devorq::sanitize_input (helper compartilhado)
#   lessons::capture    - Salvar licao aprendida (CREATE)
#   lessons::list       - Listar licoes com filtro        (READ)
#   lessons::apply      - Marcar licao como aplicada      (UPDATE)
#   lessons::export     - Exportar licoes para JSON       (READ/external)
#   lessons::from_unify - Extrair licoes de UNIFY.md       (CREATE bulk)
#
# Originalmente em lib/lessons.sh (Story 3 - dogfooding).
# Mantem 100% das assinaturas publicas: nenhuma chamada externa precisa mudar.

set -euo pipefail

# sanitize_input — Remove caracteres perigosos de inputs
# ============================================================

devorq::sanitize_input() {
    local input="${1:-}"
    local max_len="${2:-200}"

    # Usa Python para sanitizacao confiavel
    if command -v python3 &>/dev/null; then
        python3 -c "
import sys
import re
dangerous = r'[;\x60\x24\x28\x29\x7b\x7d\x5b\x5d<>!\\\\]'
text = sys.argv[1][:int(sys.argv[2])]
print(re.sub(dangerous, ' ', text))
" "$input" "$max_len"
    else
        # Fallback sem python3: MESMO conjunto perigoso do caminho python3,
        # substituindo por espaco (antes o tr removia um subconjunto diferente,
        # deixando ( ) { } [ ] < > ! \ passarem — inconsistente). DQ-016
        printf '%s' "$input" | head -c "$max_len" | tr ';`$(){}[]<>!\\' ' '
    fi
}

# ============================================================

# Escapa uma string para uso seguro dentro de um literal JSON (fallback sem jq).
lessons::_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"      # barra invertida (primeiro)
    s="${s//\"/\\\"}"      # aspa dupla
    s="${s//$'\n'/\\n}"    # newline
    s="${s//$'\r'/\\r}"    # carriage return
    s="${s//$'\t'/\\t}"    # tab
    printf '%s' "$s"
}

lessons::capture() {
    # Validação de inputs
    if [[ -z "${1:-}" ]]; then
        echo "[ERROR] Title e obrigatorio" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Conteudo armazenado CRU: jq --arg (e _json_escape no fallback) ja produzem
    # JSON valido com qualquer caractere. Sanitizar aqui destruia codigo/comandos
    # nas licoes — justamente o conteudo mais valioso — sem ganho de seguranca
    # (o filename vem de ts/pid/random, nao do titulo). So limitamos o tamanho.
    local title problem solution
    title="${1:0:200}"
    problem="${2:0:2000}"
    solution="${3:0:5000}"

    local dir="${DEVORQ_LESSONS_DIR}/captured"
    mkdir -p "$dir"

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    # ID com entropia ($RANDOM) + checagem de unicidade — evita colisao/overwrite
    # quando varias licoes sao capturadas no mesmo segundo e processo (DQ-030).
    local id="lesson_${ts}_$$_${RANDOM}"
    local file="${dir}/${id}.json"
    while [ -e "$file" ]; do
        id="lesson_${ts}_$$_${RANDOM}"
        file="${dir}/${id}.json"
    done

    # Determinar stack do contexto
    local stack="${DEVORQ_STACK:-unknown}"
    local tags="${DEVORQ_TAGS:-}"

    # Serializar como JSON (fallback sem jq)
    if command -v jq &>/dev/null; then
        jq -n \
            --arg id "$id" \
            --arg title "$title" \
            --arg problem "$problem" \
            --arg solution "$solution" \
            --arg stack "$stack" \
            --arg tags "$tags" \
            --arg ts "$ts" \
            '{
                id: $id,
                title: $title,
                problem: $problem,
                solution: $solution,
                stack: $stack,
                tags: ($tags | if . == "" then [] else split(",") end),
                timestamp: $ts,
                validated: false,
                applied: false
            }' > "$file"
    else
        # Fallback sem jq: escapa cada campo para gerar JSON valido mesmo com
        # aspas/barras/newlines no conteudo (antes interpolava cru -> JSON quebrado, DQ-030)
        printf '%s\n' \
            "{" \
            "  \"id\": \"$(lessons::_json_escape "$id")\"," \
            "  \"title\": \"$(lessons::_json_escape "$title")\"," \
            "  \"problem\": \"$(lessons::_json_escape "$problem")\"," \
            "  \"solution\": \"$(lessons::_json_escape "$solution")\"," \
            "  \"stack\": \"$(lessons::_json_escape "$stack")\"," \
            "  \"tags\": [], " \
            "  \"timestamp\": \"$(lessons::_json_escape "$ts")\"," \
            "  \"validated\": false," \
            "  \"applied\": false" \
            "}" > "$file"
    fi

    # Sync com VPS se configurado
    lessons::sync_vps "$file" &>/dev/null || true

    echo -e "${GREEN}[✓]${RESET} Lição salva: ${id}"
    echo "   $title"
}

# ============================================================
# search
#   $1 = query string
# ============================================================


# ============================================================

lessons::apply() {
    local id="${1:-}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    _apply_file() {
        local f="$1"
        if command -v jq &>/dev/null; then
            jq '.applied = true' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        else
            sed 's/"applied": false/"applied": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        fi
        echo -e "${GREEN}[✓]${RESET} $(basename "$f" .json) marcada como aplicada"
    }

    if [ -z "$id" ]; then
        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue
            _apply_file "$f"
        done
    else
        local file="${dir}/${id}.json"
        [ ! -f "$file" ] && echo "Lição não encontrada: $id" && return 1
        _apply_file "$file"
    fi
}

# ============================================================
# sync_vps — Sincroniza lição com VPS HUB (background)
# ============================================================


# ============================================================

lessons::list() {
    local filter="${1:-all}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    [ ! -d "$dir" ] && echo "[INFO] Nenhuma lição capturada." && return 0

    local count=0
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        ((count++)) || true
    done

    echo -e "${CYAN}[LESSONS]${RESET} Total: $count | Filtro: $filter"
    echo ""

    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue

        local id title validated approved compiled_at skill_name
        id=$(basename "$f" .json)
        if command -v jq &>/dev/null; then
            title=$(jq -r '.title' "$f")
            validated=$(jq -r '.validated' "$f")
            approved=$(jq -r '.approved' "$f")
            compiled_at=$(jq -r '.compiled_at // "—" ' "$f")
            skill_name=$(jq -r '.skill_name // .skill_path // "—" ' "$f")
        fi

        # Filtro: pending = validada mas nao aprovada
        case "$filter" in
            pending)
                [[ "$validated" != "true" ]] && continue
                [[ "$approved" = "true" ]] && continue
                ;;
            validated)
                [[ "$validated" != "true" ]] && continue
                [[ "$approved" = "true" ]] && continue
                ;;
            approved)
                [[ "$approved" != "true" ]] && continue
                ;;
            compiled)
                [[ "$compiled_at" = "—" ]] || [[ "$compiled_at" = "null" ]] && continue
                ;;
        esac

        # Status badges
        local val_mark="[ ]"
        [[ "$validated" = "true" ]] && val_mark="${GREEN}[✓]${RESET}"
        local appr_mark="[ ]"
        [[ "$approved" = "true" ]] && appr_mark="${GREEN}[★]${RESET}"

        echo -e "  $val_mark $appr_mark ${id}"
        echo -e "       ${title}"
        if [[ "$approved" = "true" ]]; then
            echo -e "       ${CYAN}→ $skill_name${RESET}"
        fi
        echo ""
    done
}

# ============================================================
# export — Exporta todas as lições para JSON
# ============================================================


# ============================================================

lessons::export() {
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local output="${1:-/dev/stdout}"

    if [ ! -d "$dir" ]; then
        echo "[]"
        return 0
    fi

    local first=true
    echo "["
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        if $first; then
            first=false
        else
            echo ","
        fi
        jq '.' "$f"
    done
    echo "]"
}

# ============================================================
# lessons::from_unify
#   Extrai lições do UNIFY.md e captura automaticamente
#   $1 = caminho para UNIFY.md
# ============================================================


# ============================================================

lessons::from_unify() {
    local unify_file="$1"

    if [ ! -f "$unify_file" ]; then
        echo "[WARN] UNIFY file não encontrado: $unify_file"
        return 1
    fi

    # Extrair lições da seção "Lições Aprendidas"
    local in_lessons=false
    local lesson_num=0

    while IFS= read -r line; do
        # Detectar início da seção
        if echo "$line" | grep -q "## Lições Aprendidas"; then
            in_lessons=true
            continue
        fi

        # Detectar fim da seção (próxima heading)
        if [ "$in_lessons" = "true" ] && echo "$line" | grep -qE "^## "; then
            break
        fi

        # Processar linhas de lição
        if [ "$in_lessons" = "true" ] && echo "$line" | grep -qE "^[0-9]+\."; then
            lesson_num=$((lesson_num + 1))

            # Extrair o texto após o número
            local lesson_text
            lesson_text=$(echo "$line" | sed 's/^[0-9]*\. *//')

            # Parse: "**problema** — solução"
            local problem solution
            if echo "$lesson_text" | grep -q "—"; then
                problem=$(echo "$lesson_text" | cut -d'—' -f1 | sed 's/\*\*/"/g' | sed 's/\*\*/"/g')
                solution=$(echo "$lesson_text" | cut -d'—' -f2- | sed 's/\*\*/"/g' | sed 's/\*\*/"/g')
            else
                problem="$lesson_text"
                solution="Verificar contexto na UNIFY.md"
            fi

            local title="UNIFY-$lesson_num: $(echo "$problem" | cut -c1-50)"

            if declare -f lessons::capture &>/dev/null; then
                echo "[INFO] Capturando lição: $title"
                lessons::capture "$title" "$problem" "$solution" 2>/dev/null || true
            fi
        fi
    done < "$unify_file"

    if [ "$lesson_num" -eq 0 ]; then
        echo "[INFO] Nenhuma lição encontrada em $unify_file"
    else
        echo "[OK] $lesson_num lição(ões) capturada(s) de $unify_file"
    fi

    return 0
}

# ============================================================
# LESSONS::HELP — Ajuda para comandos de lições
# ============================================================
