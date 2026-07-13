#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVORQ_ROOT="${DEVORQ_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# shellcheck source=../lib/contracts.sh
source "$DEVORQ_ROOT/lib/contracts.sh"
# shellcheck source=../lib/loop.sh
source "$DEVORQ_ROOT/lib/loop.sh"

usage() {
    cat <<'EOF'
Uso: devorq loop implementation --experimental --prd ARQUIVO --story ID --run-id ID
EOF
}

project="$PWD"
prd="$PWD/prd.json"
story_id=""
run_id=""
experimental=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --experimental) experimental=1; shift ;;
        --project) project="${2:-}"; shift 2 ;;
        --prd) prd="${2:-}"; shift 2 ;;
        --story) story_id="${2:-}"; shift 2 ;;
        --run-id) run_id="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; echo "[loop] argumento desconhecido: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$story_id" && -n "$run_id" ]] || { usage >&2; exit 2; }
project="$(cd "$project" && pwd)"
[[ "$prd" = /* ]] || prd="$project/$prd"

devorq::loop::run_implementation "$project" "$prd" "$story_id" "$run_id" "$experimental"
