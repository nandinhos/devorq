#!/usr/bin/env bash
# lib/loop.sh - Core mínimo do Loop Engineering experimental.

devorq::loop::event() {
    local run_dir="$1" event="$2" status="$3" detail="${4:-}"
    jq -cn --arg event "$event" --arg status "$status" --arg detail "$detail" \
        '{timestamp:(now|todateiso8601),event:$event,status:$status,detail:$detail}' \
        >> "$run_dir/events.jsonl"
}

devorq::loop::write_contract() {
    local type="$1" target="$2" json="$3" tmp run_dir
    devorq::contracts::validate "$type" "$json" || return 1
    tmp=$(mktemp "${target}.tmp.XXXXXX") || return 1
    printf '%s\n' "$json" > "$tmp" && mv "$tmp" "$target" || return 1
    run_dir="$(dirname "$target")"
    printf '%s\n' "$json" >> "$run_dir/events.jsonl"
}

devorq::loop::terminal() {
    local run_dir="$1" status="$2" reason="$3" rc="$4" current
    current=$(cat "$run_dir/loop.json") || return 1
    current=$(jq -c --arg status "$status" --arg reason "$reason" \
        '.status=$status | .stop_reason=$reason' <<<"$current") || return 1
    devorq::loop::write_contract loop "$run_dir/loop.json" "$current" || return 1
    devorq::loop::event "$run_dir" "terminal" "$status" "$reason"
    printf 'LOOP IMPLEMENTATION %s: %s\n' "${status^^}" "$reason" >&2
    return "$rc"
}

devorq::loop::stop() {
    if devorq::loop::terminal "$@"; then
        return 0
    else
        return $?
    fi
}

devorq::loop::judge_implementation() {
    local run_dir="$1" execution="$2" verification="$3" evidence="$4"

    devorq::contracts::validate execution "$execution" || return 3
    devorq::contracts::validate verification "$verification" || return 3
    devorq::contracts::validate evidence "$evidence" || return 3
    jq -e '.status == "succeeded"' <<<"$execution" >/dev/null || return 1
    jq -e '.verdict == "passed"' <<<"$verification" >/dev/null || return 1
    jq -e '.result == "passed"' <<<"$evidence" >/dev/null || return 1
    devorq::loop::terminal "$run_dir" completed "evidencia_verificada_por_juiz" 0
}

devorq::loop::worktree_signature() {
    local project="$1" path
    {
        git -C "$project" diff --binary HEAD 2>/dev/null || true
        git -C "$project" diff --cached --binary 2>/dev/null || true
        while IFS= read -r -d '' path; do
            case "$path" in .devorq|.devorq/*|.devorq-auto|.devorq-auto/*) continue ;; esac
            printf 'untracked:%s:' "$path"
            git -C "$project" hash-object --no-filters -- "$path" 2>/dev/null || true
        done < <(git -C "$project" ls-files --others --exclude-standard -z)
    }
}

devorq::loop::changed_paths() {
    local project="$1" path
    {
        git -C "$project" diff --name-only -z
        git -C "$project" diff --cached --name-only -z
        git -C "$project" ls-files --others --exclude-standard -z
    } | while IFS= read -r -d '' path; do
        case "$path" in .devorq|.devorq/*|.devorq-auto|.devorq-auto/*) continue ;; esac
        printf '%s\0' "$path"
    done
}

devorq::loop::enforce_allowed_files() {
    local project="$1" story="$2" path allowed
    allowed=$(jq -c '.allowed_files // []' <<<"$story") || return 1
    jq -e 'length > 0' <<<"$allowed" >/dev/null || {
        echo "[loop] Story sem allowed_files; escopo de escrita nao pode ser atestado" >&2
        return 1
    }

    while IFS= read -r -d '' path; do
        jq -e --arg path "$path" 'index($path) != null' <<<"$allowed" >/dev/null || {
            echo "[loop] Alteracao fora de allowed_files: $path" >&2
            return 1
        }
    done < <(devorq::loop::changed_paths "$project")
}

devorq::loop::enforce_limits() {
    local project="$1" max_files="$2" max_lines="$3" path lines=0
    local -a paths=()
    mapfile -d '' paths < <(devorq::loop::changed_paths "$project")
    [[ ${#paths[@]} -le "$max_files" ]] || {
        echo "[loop] limite de arquivos excedido: ${#paths[@]}/$max_files" >&2
        return 1
    }
    for path in "${paths[@]}"; do
        [[ -f "$project/$path" ]] || continue
        lines=$((lines + $(wc -l < "$project/$path")))
    done
    [[ "$lines" -le "$max_lines" ]] || {
        echo "[loop] limite de linhas excedido: $lines/$max_lines" >&2
        return 1
    }
}

devorq::loop::run_implementation() {
    local project="$1" prd="$2" story_id="$3" run_id="$4"
    local experimental="$5"
    local run_dir story_envelope story loop execution verification evidence
    local executor verifier executor_id verifier_id risk before after verifier_rc judge_rc
    local profiles_file profile max_files max_lines

    [[ "$experimental" == "1" ]] || { echo "[loop] requer --experimental" >&2; return 2; }
    command -v jq >/dev/null 2>&1 || { echo "[loop] jq obrigatorio" >&2; return 3; }
    command -v flock >/dev/null 2>&1 || { echo "[loop] flock obrigatorio para lock seguro" >&2; return 3; }
    [[ -f "$prd" ]] || { echo "[loop] PRD ausente: $prd" >&2; return 3; }
    git -C "$project" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || { echo "[loop] repositorio Git obrigatorio" >&2; return 3; }
    [[ -z "$(git -C "$project" status --porcelain --untracked-files=all -- ':!.devorq' ':!.devorq-auto' ':!progress.txt')" ]] \
        || { echo "[loop] worktree ou index sujo; loop bloqueado" >&2; return 3; }

    run_dir="$project/.devorq/state/runs/$run_id"
    [[ ! -e "$run_dir" ]] || { echo "[loop] run_id ja existe: $run_id" >&2; return 3; }
    mkdir -p "$project/.devorq/state" || return 3
    mkdir -p "$run_dir/evidence" || return 3
    exec 9>"$project/.devorq/state/loop-engineering.lock"
    flock -n 9 || { echo "[loop] outro writer ja possui o worktree" >&2; return 3; }

    story_envelope="$run_dir/story-envelope.json"
    "$DEVORQ_ROOT/scripts/migrate-prd-v1.sh" --input "$prd" --story "$story_id" --output "$story_envelope" \
        || { rm -rf "$run_dir"; echo "[loop] migracao de story bloqueada" >&2; return 3; }
    story=$(jq -c '.story' "$story_envelope") || return 3
    devorq::contracts::validate story "$story" || return 3

    profiles_file="${DEVORQ_LOOP_PROFILES_FILE:-$DEVORQ_ROOT/config/loop-profiles.json}"
    profile=$(jq -ce '.profiles.implementation' "$profiles_file" 2>/dev/null) \
        || { echo "[loop] perfil implementation invalido ou ausente" >&2; return 3; }
    max_files=$(jq -r '.limits.max_files_changed' <<<"$profile")
    max_lines=$(jq -r '.limits.max_lines_changed' <<<"$profile")
    [[ "$max_files" =~ ^[1-9][0-9]*$ && "$max_lines" =~ ^[1-9][0-9]*$ ]] \
        || { echo "[loop] limites de profile invalidos" >&2; return 3; }

    loop=$(jq -cn --arg run "$run_id" --arg objective "$(jq -r '.objective' <<<"$story")" \
        '{schema_version:"devorq.loop/v1",document_type:"loop",run_id:$run,id:("loop-"+$run),profile:"implementation",objective:$objective,status:"planning"}')
    devorq::loop::write_contract loop "$run_dir/loop.json" "$loop" || return 3
    devorq::loop::event "$run_dir" "planned" "planning" "story=$story_id"

    risk=$(jq -r '.risk // "low"' <<<"$story")
    executor="${DEVORQ_DELEGATE_FN:-}"
    verifier="${DEVORQ_LOOP_VERIFIER_FN:-$DEVORQ_ROOT/skills/devorq-auto/scripts/check-story.sh}"
    executor_id="${DEVORQ_LOOP_EXECUTOR_ID:-delegate}"
    verifier_id="${DEVORQ_LOOP_VERIFIER_ID:-check-story}"
    if [[ -z "$executor" || ! -x "$verifier" ]]; then
        devorq::loop::stop "$run_dir" blocked "executor_ou_verifier_indisponivel" 3 || return $?
    fi
    if [[ "$risk" == "high" || "$risk" == "critical" ]]; then
        if [[ "$executor_id" == "$verifier_id" ]]; then
            devorq::loop::stop "$run_dir" blocked "verificador_independente_obrigatorio" 4 || return $?
        fi
    fi
    if [[ "$risk" == "critical" ]]; then
        devorq::loop::stop "$run_dir" requires_owner_decision "risco_critico_exige_owner" 4 || return $?
    fi

    loop=$(jq -c '.status="running"' "$run_dir/loop.json")
    devorq::loop::write_contract loop "$run_dir/loop.json" "$loop" || return 3
    devorq::loop::event "$run_dir" "dispatch" "running" "executor=$executor_id"
    before=$(devorq::loop::worktree_signature "$project")
    if "$executor" "$story" "$project"; then
        execution=$(jq -cn --arg run "$run_id" --arg story "$story_id" --arg actor "$executor_id" \
            '{schema_version:"devorq.execution/v1",document_type:"execution",run_id:$run,id:("execution-"+$run+"-1"),story_id:$story,attempt:1,actor:$actor,status:"succeeded",exit_code:0}')
    else
        execution=$(jq -cn --arg run "$run_id" --arg story "$story_id" --arg actor "$executor_id" \
            '{schema_version:"devorq.execution/v1",document_type:"execution",run_id:$run,id:("execution-"+$run+"-1"),story_id:$story,attempt:1,actor:$actor,status:"failed",exit_code:1}')
        devorq::loop::write_contract execution "$run_dir/execution.json" "$execution" || return 3
        devorq::loop::stop "$run_dir" failed "executor_falhou" 1 || return $?
    fi
    devorq::loop::write_contract execution "$run_dir/execution.json" "$execution" || return 3
    after=$(devorq::loop::worktree_signature "$project")
    if [[ "$before" == "$after" ]]; then
        devorq::loop::stop "$run_dir" failed "executor_sem_diff" 1 || return $?
    fi
    if ! devorq::loop::enforce_allowed_files "$project" "$story"; then
        devorq::loop::stop "$run_dir" failed "alteracao_fora_do_escopo" 1 || return $?
    fi
    if ! devorq::loop::enforce_limits "$project" "$max_files" "$max_lines"; then
        devorq::loop::stop "$run_dir" failed "limite_de_mudanca_excedido" 1 || return $?
    fi

    if DEVORQ_LOOP_STORY_JSON="$story" "$verifier" "$project"; then verifier_rc=0; else verifier_rc=1; fi
    printf 'verifier=%s\nexit_code=%s\n' "$verifier_id" "$verifier_rc" > "$run_dir/evidence/verification.txt"
    evidence=$(jq -cn --arg run "$run_id" --arg path ".devorq/state/runs/$run_id/evidence/verification.txt" \
        --arg sha "$(sha256sum "$run_dir/evidence/verification.txt" | awk '{print $1}')" --arg result "$([[ "$verifier_rc" -eq 0 ]] && echo passed || echo failed)" \
        '{schema_version:"devorq.evidence/v1",document_type:"evidence",run_id:$run,id:("evidence-"+$run+"-verification"),evidence_type:"verifier_exit",path:$path,sha256:$sha,result:$result}')
    devorq::loop::write_contract evidence "$run_dir/evidence.json" "$evidence" || return 3
    verification=$(jq -cn --arg run "$run_id" --arg story "$story_id" --arg verifier "$verifier_id" --arg verdict "$([[ "$verifier_rc" -eq 0 ]] && echo passed || echo failed)" \
        '{schema_version:"devorq.verification/v1",document_type:"verification",run_id:$run,id:("verification-"+$run+"-1"),story_id:$story,verifier:$verifier,checks:["verifier_exit"],verdict:$verdict}')
    devorq::loop::write_contract verification "$run_dir/verification.json" "$verification" || return 3
    if [[ "$verifier_rc" -ne 0 ]]; then
        devorq::loop::stop "$run_dir" failed "verificacao_falhou" 1 || return $?
    fi

    if devorq::loop::judge_implementation "$run_dir" "$execution" "$verification" "$evidence"; then
        return 0
    fi
    judge_rc=$?
    if [[ "$judge_rc" -eq 1 ]]; then
        devorq::loop::stop "$run_dir" failed "juiz_recusou_evidencia" 1 || return $?
    fi
    devorq::loop::stop "$run_dir" blocked "evidencia_ou_contrato_invalido" 3 || return $?
}
