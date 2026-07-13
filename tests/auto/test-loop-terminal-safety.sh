#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOOP="$REPO_ROOT/skills/devorq-auto/scripts/loop-auto.sh"
TESTDIR="$(mktemp -d -t devorq-auto-terminal-XXXXXX)"

PASS=0
FAIL=0
RUN_RC=0
RUN_OUTPUT=""

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

pass() { printf 'PASS %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

require() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Dependencia obrigatoria ausente: %s\n' "$1" >&2
        exit 2
    }
}

assert_true() {
    local message="$1"
    shift
    if "$@"; then
        return 0
    fi
    printf '  assertiva falhou: %s\n' "$message" >&2
    return 1
}

new_project() {
    local name="$1"
    local project
    project="$(mktemp -d "$TESTDIR/${name}-XXXXXX")"

    git -C "$project" init -q -b main
    git -C "$project" config user.email "devorq-test@example.invalid"
    git -C "$project" config user.name "DEVORQ Test"
    printf '# fixture\n' > "$project/README.md"
    cat > "$project/prd.json" <<'JSON'
{
  "project": "terminal-safety-fixture",
  "stories": [
    {
      "id": "loop-terminal-001",
      "title": "Story de segurança terminal",
      "description": "Fixture hermética",
      "priority": 1,
      "passes": false,
      "status": "pending"
    }
  ]
}
JSON
    git -C "$project" add README.md prd.json
    git -C "$project" commit -q -m "test(auto): fixture"
    printf '%s\n' "$project"
}

new_delegate() {
    local name="$1"
    local body="$2"
    local delegate="$TESTDIR/${name}.sh"
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' "$body" > "$delegate"
    chmod +x "$delegate"
    printf '%s\n' "$delegate"
}

run_loop() {
    local project="$1"
    local delegate="$2"
    local iterations="$3"
    local force_continue="${4:-false}"
    local -a args=(--iterations "$iterations")

    if [[ "$force_continue" == "true" ]]; then
        args+=(--force-continue)
    fi

    RUN_OUTPUT="$TESTDIR/run-$(date +%s%N).log"
    set +e
    env \
        DEVORQ_AUTO_YES=1 \
        DEVORQ_AUTO_ALLOW_NO_RUNNER=1 \
        DEVORQ_DELEGATE_FN="$delegate" \
        bash "$LOOP" "$project" "${args[@]}" > "$RUN_OUTPUT" 2>&1
    RUN_RC=$?
    set -e
}

story_is_pending() {
    local project="$1"
    jq -e '.stories[0] | (.passes == false and .status != "done" and .status != "complete")' "$project/prd.json" >/dev/null
}

story_is_failed() {
    local project="$1"
    jq -e '.stories[0] | (.status == "failed" and .passes == false)' "$project/prd.json" >/dev/null
}

show_run_output() {
    printf '%s\n' '  saída do loop:' >&2
    sed -n '1,180p' "$RUN_OUTPUT" >&2
}

delegate_failure() {
    local project delegate
    project="$(new_project delegate-failure)"
    delegate="$(new_delegate delegate-failure 'exit 42')"
    run_loop "$project" "$delegate" 1

    assert_true 'delegate failure deve retornar rc não-zero' test "$RUN_RC" -ne 0 || { show_run_output; return 1; }
    if grep -Fq 'AUTO MODE COMPLETE' "$RUN_OUTPUT"; then
        printf '%s\n' '  assertiva falhou: delegate failure não pode anunciar AUTO MODE COMPLETE' >&2
        show_run_output
        return 1
    fi
    assert_true 'delegate failure deve preservar story pendente' story_is_pending "$project" || return 1
}

dirty_worktree() {
    local project delegate before_branch after_branch
    project="$(new_project dirty-worktree)"
    delegate="$(new_delegate dirty-worktree 'exit 42')"
    before_branch="$(git -C "$project" branch --show-current)"
    printf 'alteração alheia\n' > "$project/unrelated.txt"
    run_loop "$project" "$delegate" 1
    after_branch="$(git -C "$project" branch --show-current)"

    assert_true 'worktree dirty deve bloquear com rc não-zero' test "$RUN_RC" -ne 0 || { show_run_output; return 1; }
    assert_true 'worktree dirty não pode trocar/criar branch AUTO' test "$after_branch" = "$before_branch" || { show_run_output; return 1; }
}

no_diff_non_simulated() {
    local project delegate
    project="$(new_project no-diff)"
    delegate="$(new_delegate no-diff ':')"
    run_loop "$project" "$delegate" 1

    assert_true 'delegate sem diff deve retornar rc não-zero' test "$RUN_RC" -ne 0 || { show_run_output; return 1; }
    assert_true 'delegate sem diff deve preservar story pendente' story_is_pending "$project" || return 1
}

max_attempts_persisted() {
    local project delegate
    project="$(new_project max-attempts)"
    delegate="$(new_delegate max-attempts 'exit 42')"

    run_loop "$project" "$delegate" 2 true
    run_loop "$project" "$delegate" 1 true

    assert_true 'tentativas devem sobreviver a novo processo e marcar story failed' \
        story_is_failed "$project" || { show_run_output; return 1; }
}

commit_failure_index_recovery() {
    local project delegate hook
    project="$(new_project commit-failure)"
    delegate="$(new_delegate commit-failure 'printf "alteração da story\\n" > "$2/changed.txt"')"
    hook="$project/.git/hooks/commit-msg"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$hook"
    chmod +x "$hook"

    RUN_OUTPUT="$TESTDIR/run-$(date +%s%N).log"
    set +e
    env \
        DEVORQ_AUTO_YES=1 \
        DEVORQ_AUTO_ALLOW_NO_RUNNER=1 \
        DEVORQ_AUTO_COMMIT=1 \
        DEVORQ_DELEGATE_FN="$delegate" \
        bash "$LOOP" "$project" --iterations 1 > "$RUN_OUTPUT" 2>&1
    RUN_RC=$?
    set -e

    assert_true 'commit falho deve retornar rc não-zero' test "$RUN_RC" -ne 0 || { show_run_output; return 1; }
    assert_true 'commit falho deve preservar story pendente' story_is_pending "$project" || return 1
    assert_true 'commit falho não pode deixar index staged' git -C "$project" diff --cached --quiet || { show_run_output; return 1; }
}

run_case() {
    local scenario="$1"
    if "$scenario"; then
        pass "$scenario"
    else
        fail "$scenario"
    fi
}

main() {
    local scenario="${1:-all}"
    require git
    require jq
    [[ -x "$LOOP" ]] || { printf 'Loop não executável: %s\n' "$LOOP" >&2; exit 2; }

    case "$scenario" in
        delegate_failure|dirty_worktree|no_diff_non_simulated|max_attempts_persisted|commit_failure_index_recovery)
            run_case "$scenario"
            ;;
        all)
            run_case delegate_failure
            run_case dirty_worktree
            run_case no_diff_non_simulated
            run_case max_attempts_persisted
            run_case commit_failure_index_recovery
            ;;
        *)
            printf 'Uso: %s {all|delegate_failure|dirty_worktree|no_diff_non_simulated|max_attempts_persisted|commit_failure_index_recovery}\n' "$0" >&2
            exit 2
            ;;
    esac

    printf 'Resultado: %s passou, %s falhou\n' "$PASS" "$FAIL"
    [[ "$FAIL" -eq 0 ]]
}

main "$@"
