#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLI="$REPO_ROOT/bin/devorq"
TESTDIR="$(mktemp -d -t devorq-loop-implementation-XXXXXX)"
FAILURES=0
RUN_RC=0
RUN_OUTPUT=""

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "$1 nao encontrado" >&2
        exit 2
    }
}

new_project() {
    local name="$1"
    local story_id="$2"
    local risk="$3"
    local project
    project="$(mktemp -d "$TESTDIR/${name}-XXXXXX")"

    git -C "$project" init -q -b main
    git -C "$project" config user.email "test@devorq"
    git -C "$project" config user.name "devorq-test"
    jq -n --arg id "$story_id" --arg risk "$risk" '
        {
          project: "loop-implementation-fixture",
          stories: [
            {
              schema_version: "devorq.story/v1",
              document_type: "story",
              run_id: "fixture",
              id: $id,
              title: "Aplicar alteracao permitida",
              objective: "Aplicar alteracao permitida",
              description: "Fixture hermetica do loop implementation.",
              acceptance_criteria: ["Arquivo permitido existe"],
              allowed_files: ["allowed.txt"],
              priority: 1,
              risk: $risk,
              status: "pending"
            }
          ]
        }
    ' > "$project/prd.json"
    printf '# fixture\n' > "$project/README.md"
    git -C "$project" add README.md prd.json
    git -C "$project" commit -q -m "test(loop): fixture"
    printf '%s\n' "$project"
}

write_stubs() {
    local delegate_mode="$1"
    local delegate="$TESTDIR/delegate-${delegate_mode}.sh"
    local verifier="$TESTDIR/verifier-ok.sh"

    case "$delegate_mode" in
        allowed)
            cat > "$delegate" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${DEVORQ_LOOP_EXECUTOR_ID:?}" > "${DEVORQ_LOOP_DELEGATE_MARKER:?}"
printf 'mudanca permitida\n' > "$2/allowed.txt"
SH
            ;;
        outside)
            cat > "$delegate" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${DEVORQ_LOOP_EXECUTOR_ID:?}" > "${DEVORQ_LOOP_DELEGATE_MARKER:?}"
printf 'mudanca fora do escopo\n' > "$2/forbidden.txt"
SH
            ;;
        *)
            echo "delegate mode invalido: $delegate_mode" >&2
            exit 2
            ;;
    esac

    cat > "$verifier" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${DEVORQ_LOOP_VERIFIER_ID:?}" > "${DEVORQ_LOOP_VERIFIER_MARKER:?}"
exit 0
SH
    chmod +x "$delegate" "$verifier"
    printf '%s\n%s\n' "$delegate" "$verifier"
}

run_loop() {
    local project="$1"
    local story_id="$2"
    local run_id="$3"
    local experimental="$4"
    local delegate="$5"
    local verifier="$6"
    local executor_id="$7"
    local verifier_id="$8"
    local marker="$9"
    local verifier_marker="${10}"
    local -a args=(loop implementation --prd prd.json --story "$story_id" --run-id "$run_id")

    if [[ "$experimental" == "true" ]]; then
        args=(loop implementation --experimental --prd prd.json --story "$story_id" --run-id "$run_id")
    fi

    RUN_OUTPUT="$TESTDIR/run-${run_id}.log"
    set +e
    (
        cd "$project"
        env \
            DEVORQ_DELEGATE_FN="$delegate" \
            DEVORQ_LOOP_VERIFIER_FN="$verifier" \
            DEVORQ_LOOP_EXECUTOR_ID="$executor_id" \
            DEVORQ_LOOP_VERIFIER_ID="$verifier_id" \
            DEVORQ_LOOP_DELEGATE_MARKER="$marker" \
            DEVORQ_LOOP_VERIFIER_MARKER="$verifier_marker" \
            "$CLI" "${args[@]}"
    ) > "$RUN_OUTPUT" 2>&1
    RUN_RC=$?
    set -e
}

record_for() {
    local state_dir="$1"
    local type="$2"
    jq -c --arg type "$type" 'select(.document_type == $type)' "$state_dir/events.jsonl" | tail -n 1
}

validate_record() {
    local state_dir="$1"
    local type="$2"
    local expected_run_id="$3"
    local record
    record="$(record_for "$state_dir" "$type")"
    [[ -n "$record" ]] || return 1
    jq -e --arg run_id "$expected_run_id" '.run_id == $run_id' >/dev/null <<<"$record" || return 1
    devorq::contracts::validate "$type" "$record"
}

loop_not_completed() {
    local state_dir="$1"
    local record
    [[ -f "$state_dir/events.jsonl" ]] || return 0
    record="$(record_for "$state_dir" loop || true)"
    [[ -z "$record" ]] || jq -e '.status != "completed"' >/dev/null <<<"$record"
}

test_experimental_flag_required() {
    local project stubs delegate verifier marker verifier_marker run_id
    project="$(new_project experimental-required implementation-001 low)"
    stubs="$(write_stubs allowed)"
    delegate="$(sed -n '1p' <<<"$stubs")"
    verifier="$(sed -n '2p' <<<"$stubs")"
    marker="$TESTDIR/experimental-delegate.marker"
    verifier_marker="$TESTDIR/experimental-verifier.marker"
    run_id="implementation-no-experimental"
    run_loop "$project" implementation-001 "$run_id" false "$delegate" "$verifier" executor-low verifier-low "$marker" "$verifier_marker"

    if [[ "$RUN_RC" -eq 0 ]]; then
        fail "loop implementation sem --experimental retornou sucesso"
    else
        pass "loop implementation sem --experimental bloqueia"
    fi
    if [[ -e "$marker" || -e "$verifier_marker" ]]; then
        fail "loop implementation sem --experimental fez dispatch"
    else
        pass "loop implementation sem --experimental nao faz dispatch"
    fi
}

test_low_risk_persists_valid_records() {
    local project stubs delegate verifier marker verifier_marker run_id state_dir evidence evidence_path expected_hash
    project="$(new_project low-risk implementation-002 low)"
    stubs="$(write_stubs allowed)"
    delegate="$(sed -n '1p' <<<"$stubs")"
    verifier="$(sed -n '2p' <<<"$stubs")"
    marker="$TESTDIR/low-delegate.marker"
    verifier_marker="$TESTDIR/low-verifier.marker"
    run_id="implementation-low-risk"
    state_dir="$project/.devorq/state/runs/$run_id"
    run_loop "$project" implementation-002 "$run_id" true "$delegate" "$verifier" executor-low verifier-low "$marker" "$verifier_marker"

    if [[ "$RUN_RC" -eq 0 && -f "$project/allowed.txt" && -f "$marker" && -f "$verifier_marker" ]]; then
        pass "low-risk despacha executor e verifier e retorna sucesso"
    else
        fail "low-risk deveria concluir com executor e verifier"
        return
    fi
    if [[ ! -f "$state_dir/events.jsonl" ]]; then
        fail "low-risk nao persistiu events.jsonl"
        return
    fi
    if validate_record "$state_dir" loop "$run_id" && validate_record "$state_dir" execution "$run_id" && validate_record "$state_dir" verification "$run_id" && validate_record "$state_dir" evidence "$run_id"; then
        pass "low-risk persiste loop/execution/verification/evidence v1 validos"
    else
        fail "low-risk nao persistiu contratos v1 validos"
        return
    fi
    if ! jq -e '.status == "completed"' <<<"$(record_for "$state_dir" loop)" >/dev/null; then
        fail "low-risk nao marcou loop completed"
    fi
    evidence="$(record_for "$state_dir" evidence)"
    evidence_path="$(jq -r '.path' <<<"$evidence")"
    if [[ "$evidence_path" != /* ]]; then
        evidence_path="$project/$evidence_path"
    fi
    expected_hash="$(jq -r '.sha256' <<<"$evidence")"
    if [[ -f "$evidence_path" && "$(sha256sum "$evidence_path" | awk '{print $1}')" == "$expected_hash" ]]; then
        pass "evidence aponta para artefato imutavel com hash valido"
    else
        fail "evidence nao aponta para artefato com hash correspondente"
    fi
}

test_allowed_files_blocks_outside_change() {
    local project stubs delegate verifier marker verifier_marker run_id state_dir
    project="$(new_project outside-change implementation-003 low)"
    stubs="$(write_stubs outside)"
    delegate="$(sed -n '1p' <<<"$stubs")"
    verifier="$(sed -n '2p' <<<"$stubs")"
    marker="$TESTDIR/outside-delegate.marker"
    verifier_marker="$TESTDIR/outside-verifier.marker"
    run_id="implementation-outside-change"
    state_dir="$project/.devorq/state/runs/$run_id"
    run_loop "$project" implementation-003 "$run_id" true "$delegate" "$verifier" executor-low verifier-low "$marker" "$verifier_marker"

    if [[ "$RUN_RC" -eq 0 ]]; then
        fail "alteracao fora de allowed_files retornou sucesso"
    else
        pass "alteracao fora de allowed_files bloqueia"
    fi
    if loop_not_completed "$state_dir"; then
        pass "alteracao fora de allowed_files nao marca completed"
    else
        fail "alteracao fora de allowed_files marcou completed"
    fi
}

test_dirty_worktree_blocks_before_dispatch() {
    local project stubs delegate verifier marker verifier_marker run_id
    project="$(new_project dirty-worktree implementation-004 low)"
    stubs="$(write_stubs allowed)"
    delegate="$(sed -n '1p' <<<"$stubs")"
    verifier="$(sed -n '2p' <<<"$stubs")"
    marker="$TESTDIR/dirty-delegate.marker"
    verifier_marker="$TESTDIR/dirty-verifier.marker"
    run_id="implementation-dirty-worktree"
    printf 'mudanca preexistente\n' > "$project/unrelated.txt"
    run_loop "$project" implementation-004 "$run_id" true "$delegate" "$verifier" executor-low verifier-low "$marker" "$verifier_marker"

    if [[ "$RUN_RC" -eq 0 ]]; then
        fail "worktree dirty retornou sucesso"
    else
        pass "worktree dirty bloqueia"
    fi
    if [[ -e "$marker" || -e "$verifier_marker" ]]; then
        fail "worktree dirty fez dispatch"
    else
        pass "worktree dirty bloqueia antes do dispatch"
    fi
}

test_high_risk_requires_distinct_identities() {
    local project stubs delegate verifier marker verifier_marker run_id
    project="$(new_project high-risk implementation-005 high)"
    stubs="$(write_stubs allowed)"
    delegate="$(sed -n '1p' <<<"$stubs")"
    verifier="$(sed -n '2p' <<<"$stubs")"
    marker="$TESTDIR/high-delegate.marker"
    verifier_marker="$TESTDIR/high-verifier.marker"
    run_id="implementation-high-risk"
    run_loop "$project" implementation-005 "$run_id" true "$delegate" "$verifier" shared-identity shared-identity "$marker" "$verifier_marker"

    if [[ "$RUN_RC" -eq 0 ]]; then
        fail "high-risk aceitou executor e verifier com mesma identidade"
    else
        pass "high-risk exige executor e verifier distintos"
    fi
    if [[ -e "$marker" || -e "$verifier_marker" ]]; then
        fail "high-risk com identidades iguais fez dispatch"
    else
        pass "high-risk com identidades iguais bloqueia antes do dispatch"
    fi
}

run_case() {
    local scenario="$1"
    "$scenario"
}

main() {
    local scenario="${1:-all}"
    require git
    require jq
    require sha256sum
    [[ -x "$CLI" ]] || { echo "CLI nao executavel: $CLI" >&2; exit 2; }
    source "$REPO_ROOT/lib/contracts.sh"

    case "$scenario" in
        experimental) run_case test_experimental_flag_required ;;
        low_risk) run_case test_low_risk_persists_valid_records ;;
        allowed_files) run_case test_allowed_files_blocks_outside_change ;;
        dirty_worktree) run_case test_dirty_worktree_blocks_before_dispatch ;;
        high_risk) run_case test_high_risk_requires_distinct_identities ;;
        all)
            run_case test_experimental_flag_required
            run_case test_low_risk_persists_valid_records
            run_case test_allowed_files_blocks_outside_change
            run_case test_dirty_worktree_blocks_before_dispatch
            run_case test_high_risk_requires_distinct_identities
            ;;
        *)
            echo "Uso: $0 [all|experimental|low_risk|allowed_files|dirty_worktree|high_risk]" >&2
            exit 2
            ;;
    esac

    [[ "$FAILURES" -eq 0 ]] || exit 1
}

main "$@"
