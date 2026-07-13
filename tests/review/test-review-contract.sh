#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REVIEW="$REPO_ROOT/skills/devorq-code-review/scripts/review.sh"
TESTDIR="$(mktemp -d -t devorq-review-contract-XXXXXX)"
FAILURES=0

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

setup_repo() {
    git -C "$TESTDIR" init -q -b main
    git -C "$TESTDIR" config user.email "test@devorq"
    git -C "$TESTDIR" config user.name "devorq-test"
    printf '%s\n' "base" > "$TESTDIR/README.md"
    git -C "$TESTDIR" add README.md
    git -C "$TESTDIR" commit -q -m "chore(test): base"
    git -C "$TESTDIR" switch -q -c review-target

    printf '%s\n' \
        "alpha" "bravo" "charlie" "delta" "echo" "foxtrot" \
        "golf" "hotel" "india" "juliet" "kilo" "lima" > "$TESTDIR/feature-one.txt"
    printf '%s\n' \
        "mike" "november" "oscar" "papa" "quebec" "romeo" \
        "sierra" "tango" "uniform" "victor" "whiskey" "xray" > "$TESTDIR/feature-two.txt"
    printf '%s\n' \
        "yankee" "zulu" "alfa" "beta" "gama" "delta" \
        "epsilon" "zeta" "eta" "theta" "iota" "kappa" > "$TESTDIR/feature-three.txt"
    git -C "$TESTDIR" add feature-one.txt feature-two.txt feature-three.txt
    git -C "$TESTDIR" commit -q -m "feat(review): diff nao trivial"
}

run_review_without_reviewer() {
    set +e
    REVIEW_OUTPUT=$(printf 'Z\n' | bash "$REVIEW" "$TESTDIR" --base main --branch HEAD --quiet 2>&1)
    REVIEW_RC=$?
    set -e
}

test_reviewer_unavailable() {
    if [[ "$REVIEW_RC" -eq 0 ]]; then
        fail "review sem resultado real de reviewer retornou sucesso"
    else
        pass "review sem reviewer retorna erro"
    fi

    if grep -qiE 'unavailable|indispon' <<<"$REVIEW_OUTPUT"; then
        pass "review sem reviewer informa indisponibilidade"
    else
        fail "review sem reviewer nao informa indisponibilidade"
    fi
}

test_invalid_approval() {
    local approval_gate
    approval_gate=$(sed -n '/^phase6_approval()/,/^#-----------------------------------------------------------/p' "$REVIEW")

    if grep -qiE 'Escolha invalida, continuando como \[A\]' <<<"$approval_gate"; then
        fail "approval gate tratou escolha invalida como aprovacao"
    else
        pass "approval gate bloqueia escolha invalida"
    fi
}

main() {
    local scenario="${1:-all}"

    [[ -x "$REVIEW" ]] || { echo "review.sh nao executavel: $REVIEW" >&2; exit 1; }
    command -v git >/dev/null 2>&1 || { echo "git nao encontrado" >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq nao encontrado" >&2; exit 1; }

    setup_repo
    run_review_without_reviewer

    case "$scenario" in
        reviewer_unavailable) test_reviewer_unavailable ;;
        invalid_approval) test_invalid_approval ;;
        all)
            test_reviewer_unavailable
            test_invalid_approval
            ;;
        *)
            echo "Uso: $0 [all|reviewer_unavailable|invalid_approval]" >&2
            exit 2
            ;;
    esac

    [[ "$FAILURES" -eq 0 ]] || exit 1
}

main "$@"
