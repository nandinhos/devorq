#!/usr/bin/env bash
# Adaptador de leitura de PRD legado para o contrato Story v1.
# Nao reescreve o PRD de entrada; publica o envelope apenas apos validar.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVORQ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Uso: migrate-prd-v1.sh --input PRD --story ID --output ENVELOPE

Adapta uma story de prd.json legado ou canônico ao envelope Story v1 sem
modificar o arquivo de entrada.
EOF
}

die() {
    echo "[prd-migrate] $*" >&2
    exit 1
}

input=""
story_id=""
output=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input) input="${2:-}"; shift 2 ;;
        --story) story_id="${2:-}"; shift 2 ;;
        --output) output="${2:-}"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; die "argumento desconhecido: $1" ;;
    esac
done

command -v jq >/dev/null 2>&1 || die "jq obrigatorio"
[[ -n "$input" && -n "$story_id" && -n "$output" ]] || { usage >&2; die "--input, --story e --output sao obrigatorios"; }
[[ -f "$input" && -r "$input" ]] || die "PRD de entrada ausente ou ilegivel: $input"
[[ ! -e "$output" ]] || die "saida ja existe; recusa sobrescrever: $output"
jq -e . "$input" >/dev/null 2>&1 || die "PRD contem JSON invalido"

# shellcheck source=../lib/contracts.sh
source "$DEVORQ_ROOT/lib/contracts.sh"

story=$(jq -ce --arg id "$story_id" '
    .stories // [] | map(select(.id == $id)) | .[0] // empty
' "$input")
[[ -n "$story" ]] || die "story nao encontrada: $story_id"

tmp="$(mktemp "${output}.tmp.XXXXXX")"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

jq -n --argjson source "$story" --arg run_id "migration-${story_id}" '
    def canonical_status:
        if .status == "done" or .status == "complete" or .passes == true then "completed"
        elif (.status // "pending") == "failed" then "failed"
        elif (.status // "pending") == "skipped" then "cancelled"
        else (.status // "pending") end;
    {
      schema_version: "devorq.story/v1",
      document_type: "story-envelope",
      run_id: $run_id,
      id: ("envelope-" + $source.id),
      story: {
        schema_version: "devorq.story/v1",
        document_type: "story",
        run_id: $run_id,
        id: $source.id,
        title: $source.title,
        objective: ($source.objective // $source.title),
        description: ($source.description // $source.title),
        acceptance_criteria: ($source.acceptance_criteria // $source.acceptanceCriteria // []),
        allowed_files: ($source.allowed_files // $source.files_to_check // $source.filesToCheck // []),
        priority: ($source.priority // 0),
        risk: ($source.risk // "low"),
        status: ($source | canonical_status)
      }
    }
' > "$tmp"

devorq::contracts::validate story "$(jq -c '.story' "$tmp")" \
    || die "story adaptada nao atende ao contrato v1"

mkdir -p "$(dirname "$output")"
mv "$tmp" "$output"
trap - EXIT
