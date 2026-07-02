#!/usr/bin/env bash
#===========================================================
# devorq-auto — prd-from-spec.sh v1.0.1
# Converte SPEC.md em prd.json com stories atomicas.
# Usa: bash, jq
#
# BUGFIX v1.0.1: regex H2/H3 corrigida — H3 e agora
# detectada ANTES do checklist item, evitando que
# headers virassem criteria.
#===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
devorq_auto::usage() {
    cat <<EOF
Usage: prd-from-spec.sh <PROJECT_ROOT> [--force]

Converte SPEC.md em prd.json com stories atomicas.
Cada GATE ou US vira uma story independente.

Args:
  PROJECT_ROOT   Diretorio do projeto (obrigatorio)
  --force        Sobrescreve prd.json existente

Exit codes:
  0  prd.json gerado com sucesso
  1  Erro (spec nao encontrada, jq ausente, etc)
EOF
}

devorq_auto::die() {
    echo "ERROR: $*" >&2
    exit 1
}

devorq_auto::require_command() {
    command -v "$1" >/dev/null 2>&1 \
        || devorq_auto::die "jq required: apt install jq || brew install jq"
}

#-----------------------------------------------------------
# Parser de SPEC.md -> stories JSON
#-----------------------------------------------------------
devorq_auto::parse_spec() {
    local spec_file="$1"
    local project_name
    project_name=$(basename "$(dirname "$spec_file")")

    local story_id=1
    local priority=1
    local json_stories="[]"

    local current_title=""
    local current_desc=""
    local current_criteria="[]"

    # Helpers internos
    _save_story() {
        [[ -z "$current_title" ]] && return
        json_stories=$(echo "$json_stories" | jq \
            --arg id "feat-$(printf '%03d' $story_id)" \
            --arg title "$current_title" \
            --arg desc "$current_desc" \
            --argjson pri "$priority" \
            --argjson crits "$current_criteria" \
            '. += [{
                id: $id,
                title: $title,
                description: $desc,
                acceptanceCriteria: $crits,
                priority: $pri,
                passes: false
            }]')
        story_id=$((story_id + 1))
        priority=$((priority + 1))
        current_criteria="[]"
    }

    _clean() {
        # Remove markdown: **bold**, __underline__, `code`, #headings
        echo "$1" | sed 's/\*\*/''/g; s/__//g; s/`//g; s/^#* *//'
    }

    while IFS= read -r line; do
        # IMPORTANTE: H3 (###) PRIMEIRO do que H2 (##)
        # porque H2 content pode comecar com ### tambem

        # H3: ### US-XXX: Titulo
        if [[ "$line" =~ ^###\ [A-Z]+-[0-9]+:\ *(.*) ]]; then
            _save_story
            current_title="$(_clean "${BASH_REMATCH[1]}")"
            current_desc="User story: $current_title"
        # H2: ## GATE-X: Titulo  ou  ## Titulo
        elif [[ "$line" =~ ^##\ +([A-Za-z].*) ]]; then
            _save_story
            current_title="$(_clean "${BASH_REMATCH[1]}")"
            current_desc="Implementar: $current_title"
        # Checklist item: - [ ] ou - [x]  (NAO comeca com ###)
        elif [[ "$line" =~ ^-\ \[.\]\ +(.*) ]]; then
            local criterion
            criterion="$(_clean "${BASH_REMATCH[1]}")"
            criterion="$(echo "$criterion" | sed 's/^ *//;s/ *$//')"
            if [[ -n "$criterion" ]]; then
                # --arg (nao concatenacao): aspa/$()/\ no SPEC nao corrompe o programa jq
                current_criteria=$(jq --arg c "$criterion" '. += [$c]' <<<"$current_criteria") || {
                    echo "[ERROR] prd-from-spec: jq falhou ao adicionar criterio — abortando" >&2
                    return 1
                }
            fi
        fi
    done < "$spec_file"

    # Ultima story
    _save_story

    # Monta prd.json final
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{}" | jq \
        --arg project "$project_name" \
        --arg created "$timestamp" \
        --argjson stories "$json_stories" \
        '{
            project: $project,
            created: $created,
            stories: $stories
        }'
}

#-----------------------------------------------------------
# Main
#-----------------------------------------------------------
main() {
    local project_root=""
    local force=false

    [[ $# -lt 1 ]] && { devorq_auto::usage; exit 1; }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force=true; shift ;;
            -h|--help) devorq_auto::usage; exit 0 ;;
            *) project_root="$1"; shift ;;
        esac
    done

    [[ -z "$project_root" ]] && devorq_auto::die "PROJECT_ROOT obrigatorio"
    [[ ! -d "$project_root" ]] && devorq_auto::die "Diretorio nao existe: $project_root"

    local spec_file="$project_root/SPEC.md"
    [[ ! -f "$spec_file" ]] && devorq_auto::die "SPEC.md nao encontrado em: $spec_file"

    devorq_auto::require_command jq

    local prd_file="$project_root/prd.json"
    if [[ -f "$prd_file" && "$force" == false ]]; then
        echo "AVISO: prd.json ja existe. Use --force para sobrescrever." >&2
        exit 1
    fi

    devorq_auto::parse_spec "$spec_file" > "$prd_file"

    local count
    count=$(jq '.stories | length' "$prd_file")
    echo "✅ prd.json gerado: $count stories em $prd_file"
}

main "$@"
