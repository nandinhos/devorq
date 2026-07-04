#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/auto.sh — DEVORQ AUTO Mode
# Executa stories do prd.json via devorq flow

devorq::auto::usage() {
    cat <<'USAGE_EOF'
Usage: devorq auto [N|--all|--continue]

Modo AUTO (Híbrido): tracker de progresso para stories.
1. Mostra stories pendentes do prd.json
2. Você implementa manualmente
3. Usa --continue para marcar e commitar

Args:
  N          Numero de iterations (default: 1)
  --all      Executar todas as pendentes
  --continue Marque story atual como done + commit

Exemplos:
  devorq auto              # Mostra stories pendentes
  devorq auto 3            # Mostra 3 stories
  devorq auto --continue   # Marca story atual como done
USAGE_EOF
}

devorq::auto::die() {
    echo "[DEVORQ-AUTO] ERROR: $*" >&2
    exit 1
}

devorq::auto::info()    { echo "[DEVORQ-AUTO] $*"; }
devorq::auto::success() { echo "[DEVORQ-AUTO] OK $*"; }
devorq::auto::fail()    { echo "[DEVORQ-AUTO] FAIL $*"; }

devorq::auto::require_prd() {
    if [[ ! -f "$1/prd.json" ]]; then
        devorq::auto::die "prd.json nao encontrado em $1"
    fi
}

devorq::auto::generate_prd() {
    local project="$1"
    local prd="$project/prd.json"

    if [[ -f "$prd" ]]; then
        devorq::auto::info "Usando prd.json existente"
        return 0
    fi

    devorq::auto::info "Gerando prd.json do SPEC.md..."

    if [[ ! -f "$project/SPEC.md" ]]; then
        devorq::auto::die "SPEC.md nao encontrado em $project"
    fi

    if ! command -v jq >/dev/null 2>&1; then
        devorq::auto::die "jq required: apt install jq"
    fi

    local story_id=1
    local json_stories="[]"
    local current_title=""
    local current_desc=""
    local current_criteria="[]"
    local current_priority=100

    _save_story() {
        if [[ -z "$current_title" ]]; then return; fi
        json_stories=$(echo "$json_stories" | jq \
            --arg id "feat-$(printf '%03d' $story_id)" \
            --arg title "$current_title" \
            --arg desc "$current_desc" \
            --argjson pri "$current_priority" \
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
        current_criteria="[]"
    }

    _clean() {
        echo "$1" | sed 's/\*\*/''/g; s/__//g; s/`//g; s/^#* *//'
    }

    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ +GATE-[0-9]+:\ *(.+) ]]; then
            _save_story
            current_title="GATE: ${BASH_REMATCH[1]}"
            current_desc="Implementar gate bloqueante"
            current_priority=1
        elif [[ "$line" =~ ^##\ +([0-9]+\.)?\ *(.+) ]]; then
            _save_story
            current_title="${BASH_REMATCH[2]}"
            current_desc="Seção: $current_title"
            current_priority=50
        elif [[ "$line" =~ ^-\ \[.\]\ +(.*) ]]; then
            local criterion
            criterion="$(_clean "${BASH_REMATCH[1]}")"
            criterion="$(echo "$criterion" | sed 's/^ *//;s/ *$//')"
            if [[ -n "$criterion" ]]; then
                # --arg (nao concatenacao): aspa/$()/\ no SPEC nao corrompe o programa jq
                current_criteria=$(jq --arg c "$criterion" '. += [$c]' <<<"$current_criteria") || {
                    echo "[ERROR] auto: jq falhou ao adicionar criterio — abortando" >&2
                    return 1
                }
            fi
        fi
    done < "$project/SPEC.md"

    _save_story

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "{}" | jq \
        --arg project "$project" \
        --arg created "$timestamp" \
        --argjson stories "$json_stories" \
        '{
            project: $project,
            created: $created,
            stories: $stories
        }' > "$prd"

    local count
    count=$(jq '.stories | length' "$prd")
    devorq::auto::success "prd.json gerado: $count stories"
}

devorq::auto::next_story() {
    local prd="$1/prd.json"
    jq -c '.stories | sort_by(.priority // 999) | map(select((.passes != true) and (.status != "done" and .status != "complete"))) | .[0] // empty' "$prd" 2>/dev/null
}

devorq::auto::pending_count() {
    local prd="$1/prd.json"
    jq '.stories | map(select((.passes != true) and (.status != "done" and .status != "complete"))) | length' "$prd" 2>/dev/null
}

devorq::auto::total_count() {
    local prd="$1/prd.json"
    jq '.stories | length' "$prd" 2>/dev/null
}

devorq::auto::completed_count() {
    local prd="$1/prd.json"
    jq '.stories | map(select(.passes == true or .status == "done" or .status == "complete")) | length' "$prd" 2>/dev/null
}

devorq::auto::mark_pass() {
    local prd="$1/prd.json"
    local story_id="$2"
    local tmp
    tmp=$(mktemp)

    if command -v python3 >/dev/null 2>&1; then
        # Valores passados via ambiente (nunca interpolados no source) para
        # evitar quebra/injeção quando story_id/path contêm aspas (DQ-004).
        DEVORQ_PRD="$prd" DEVORQ_STORY_ID="$story_id" DEVORQ_TMP="$tmp" python3 -c '
import json, os
prd = os.environ["DEVORQ_PRD"]
story_id = os.environ["DEVORQ_STORY_ID"]
tmp = os.environ["DEVORQ_TMP"]
with open(prd) as f:
    data = json.load(f)
for s in data["stories"]:
    if s.get("id") == story_id:
        s["passes"] = True
        s["status"] = "done"
        break
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
' 2>/dev/null
    else
        # Fallback sem python3: escreve a transformação no tmp, NUNCA edita o prd in-place.
        sed "s/\"id\": \"$story_id\", \"passes\": false/\"id\": \"$story_id\", \"passes\": true/g" "$prd" > "$tmp" 2>/dev/null || true
    fi

    # Só promove se o tmp for não-vazio E (quando jq existir) JSON válido.
    # Garante que prd.json jamais é zerado por falha de parsing/sem-python3 (DQ-004).
    local valid=0
    if [[ -s "$tmp" ]]; then
        if command -v jq >/dev/null 2>&1; then
            jq empty "$tmp" >/dev/null 2>&1 && valid=1
        else
            valid=1
        fi
    fi

    if [[ "$valid" == "1" ]]; then
        mv "$tmp" "$prd"
    else
        rm -f "$tmp"
        echo "[ERROR] mark_pass: falha ao atualizar story '$story_id'; prd.json preservado intacto" >&2
        return 1
    fi
}

devorq::auto::show_status() {
    local project="$1"
    devorq::auto::require_prd "$project"

    local total pending completed
    total=$(devorq::auto::total_count "$project")
    pending=$(devorq::auto::pending_count "$project")
    completed=$(devorq::auto::completed_count "$project")

    echo ""
    echo "prd.json: $total stories ($completed done, $pending pending)"
    echo "-----------------------------------------------------------"

    if command -v jq >/dev/null 2>&1; then
        jq -r '.stories | sort_by(.priority // 999) | .[] | "[", (.priority // 0), "] ", .title, " [", (.passes // false), "]" ' "$project/prd.json" 2>/dev/null
    fi
}

devorq::auto::show_story() {
    local story_json="$1"
    local id title desc priority

    id=$(echo "$story_json" | jq -r '.id')
    title=$(echo "$story_json" | jq -r '.title')
    desc=$(echo "$story_json" | jq -r '.description')
    priority=$(echo "$story_json" | jq -r '.priority')

    echo ""
    echo "Story: $id - $title"
    echo "   Priority: $priority"
    echo "   Desc: $desc"
    echo "   Criteria:"
    echo "$story_json" | jq -r '(.acceptanceCriteria // .acceptance_criteria // [])[] | "     - \(.)"' 2>/dev/null || true
}

devorq::auto::ensure_branch() {
    local project="$1"
    # Estado de branch unificado com o loop canonico (.devorq-auto/), em vez do
    # antigo .devorq/auto/ — os modos guided e ralph compartilham o mesmo arquivo. DQ-003
    local branch_file="$project/.devorq-auto/.last-branch"

    mkdir -p "$project/.devorq-auto"

    if [[ -f "$branch_file" ]]; then
        local existing_branch
        existing_branch=$(cat "$branch_file")
        if git -C "$project" rev-parse --verify "$existing_branch" >/dev/null 2>&1; then
            git -C "$project" checkout "$existing_branch" 2>/dev/null && return 0
        fi
    fi

    local new_branch="devorq-auto/$(date +%Y%m%d-%H%M%S)"
    git -C "$project" checkout -b "$new_branch" 2>/dev/null || true
    echo "$new_branch" > "$branch_file"
}

devorq::auto::git_commit() {
    local project="$1"
    local story_id="$2"
    local story_title="$3"

    if git -C "$project" diff --cached --quiet && git -C "$project" diff --quiet; then
        devorq::auto::info "Nenhum change para commitar"
        return 0
    fi

    git -C "$project" add -A
    # story_id (ex: sec-001) nao e escopo valido; vai na descricao. Formato tipo(escopo).
    git -C "$project" commit -m "feat(core): ${story_title} (${story_id})" --no-verify 2>/dev/null || true
}

devorq::auto::execute_flow() {
    local story_title="$1"
    devorq::auto::info "Story: $story_title"
    devorq::auto::info "Implemente manualmente, depois rode 'devorq auto --continue'"
    devorq::auto::info "para marcar como done e commitar."
    echo "Press Enter quando implementar:"
    read -r _ < /dev/stdin
    return 0
}

devorq::auto::verify() {
    local project="$1"
    devorq::auto::info "Verificando via devorq build..."
    if devorq build 2>&1; then
        return 0
    else
        echo "devorq build falhou. Corrija e tente novamente."
        return 1
    fi
}

devorq::auto::run() {
    local iterations="${1:-1}"
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    cd "$project_root"

    devorq::auto::info "Modo AUTO - DEVORQ"
    devorq::auto::info "Projeto: $project_root"

    devorq::auto::generate_prd "$project_root"
    devorq::auto::require_prd "$project_root"

    local pending
    pending=$(devorq::auto::pending_count "$project_root")

    if [[ $pending -eq 0 ]]; then
        devorq::auto::success "Todas as stories ja passaram."
        return 0
    fi

    echo ""
    echo "============================================"
    echo "AUTO MODE - $pending stories pendentes"
    echo "============================================"

    devorq::auto::ensure_branch "$project_root"
    devorq::auto::show_status "$project_root"

    local loop=0
    while [[ $loop -lt $iterations ]]; do
        loop=$((loop + 1))

        local story_json
        story_json=$(devorq::auto::next_story "$project_root")

        if [[ -z "$story_json" || "$story_json" == "null" ]]; then
            devorq::auto::success "Todas stories processadas."
            break
        fi

        local story_id story_title
        story_id=$(echo "$story_json" | jq -r '.id')
        story_title=$(echo "$story_json" | jq -r '.title')

        devorq::auto::info "Iteration $loop/$iterations - Story: $story_id"
        devorq::auto::show_story "$story_json"

        if devorq::auto::execute_flow "$story_title"; then
            # Executa devorq build + verificação visual (Playwright ou manual)
            if devorq::verify::run "auto" "" "false"; then
                devorq::auto::success "Verificação visual passou"
                devorq::info ""
                devorq::info "Próximo passo — commit manual:"
                devorq::info "  devorq commit --story $story_id"
                devorq::info ""
                devorq::info "Após commitar, execute: devorq auto --continue"
                devorq::auto::success "Story aguardando commit: $story_id"

                local done total
                done=$(devorq::auto::completed_count "$project_root")
                total=$(devorq::auto::total_count "$project_root")
                devorq::auto::info "Progress: $done/$total stories"
            else
                devorq::auto::fail "Verificação visual falhou"
                echo "Press Enter para continuar (investigar erro) ou Ctrl+C para abortar"
                read -r _ < /dev/stdin
            fi
        else
            devorq::auto::fail "devorq flow failed"
            echo "Press Enter to continue or Ctrl+C to abort"
            read -r _ < /dev/stdin
        fi

        echo ""
    done

    local done total
    done=$(devorq::auto::completed_count "$project_root")
    total=$(devorq::auto::total_count "$project_root")
    pending=$(devorq::auto::pending_count "$project_root")

    echo ""
    echo "============================================"
    echo "AUTO MODE COMPLETE"
    echo "============================================"
    echo "$done stories done, $pending pending"
    echo "status: $project_root/prd.json"
    echo "============================================"
}

devorq::cmd_auto_guided() {
    local iterations=1
    local mode="interactive"

    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        devorq::auto::usage
        return 0
    fi

    if [[ "${1:-}" == "--continue" || "${1:-}" == "-c" ]]; then
        mode="continue"
    elif [[ "${1:-}" == "--all" ]]; then
        iterations=999
    elif [[ -n "${1:-}" && "${1:-}" =~ ^[0-9]+$ ]]; then
        iterations="${1:-1}"
    fi

    if [[ "$mode" == "continue" ]]; then
        devorq::auto::run_continue
    else
        devorq::auto::run "$iterations"
    fi
}

devorq::auto::run_continue() {
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"
    cd "$project_root"

    devorq::auto::require_prd "$project_root"

    local story_json
    story_json=$(devorq::auto::next_story "$project_root")

    if [[ -z "$story_json" || "$story_json" == "null" ]]; then
        devorq::auto::success "Todas stories processadas."
        return 0
    fi

    local story_id story_title
    story_id=$(echo "$story_json" | jq -r '.id')
    story_title=$(echo "$story_json" | jq -r '.title')

    devorq::auto::info "Marcando como done: $story_id - $story_title"

    # Executa devorq build + verificação visual
    if devorq::verify::run "auto" "$story_id" "false"; then
        devorq::auto::success "Verificação visual passou"

        devorq::info ""
        devorq::info "Story pronta para commit manual:"
        devorq::info "  devorq commit --story $story_id"
        devorq::info ""
        echo -n "Confirmar commit automático (ou Ctrl+C para manual)? [Y/n]: "
        local confirm
        read -r confirm
        confirm="${confirm:-Y}"

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            devorq::commit::from_story "$project_root" "$story_id"
        fi

        # Guarda contra set -e: se mark_pass falhar (prd preservado), nao
        # claim "completa" — propaga o erro (DQ-004/revisao).
        if ! devorq::auto::mark_pass "$project_root" "$story_id"; then
            devorq::auto::fail "Falha ao atualizar prd.json para $story_id (preservado)"
            return 1
        fi
        devorq::auto::success "Story completa: $story_id"

        local done total pending
        done=$(devorq::auto::completed_count "$project_root")
        total=$(devorq::auto::total_count "$project_root")
        pending=$(devorq::auto::pending_count "$project_root")
        devorq::auto::info "Progress: $done/$total stories ($pending pending)"
    else
        devorq::auto::fail "Verificação visual falhou"
        devorq::info "Após corrigir, execute: devorq auto --continue"
        return 1
    fi
}