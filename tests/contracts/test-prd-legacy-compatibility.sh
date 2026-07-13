#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATOR="${DEVORQ_PRD_MIGRATOR:-$REPO_ROOT/scripts/migrate-prd-v1.sh}"
TESTDIR="$(mktemp -d -t devorq-prd-compatibility-XXXXXX)"
FAILURES=0

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

write_fixtures() {
    cat > "$TESTDIR/legacy-prd.json" <<'JSON'
{
  "project": "legacy-fixture",
  "stories": [
    {
      "id": "legacy-001",
      "title": "Preservar compatibilidade legada",
      "description": "Story no formato historico.",
      "acceptanceCriteria": ["Mantem criterios"],
      "filesToCheck": ["README.md", "lib/auto.sh"],
      "priority": 2,
      "passes": false,
      "status": "pending"
    }
  ]
}
JSON

    cat > "$TESTDIR/canonical-prd.json" <<'JSON'
{
  "schema_version": "devorq.prd.v1",
  "project": "canonical-fixture",
  "stories": [
    {
      "schema_version": "devorq.story/v1",
      "id": "canonical-001",
      "title": "Preservar contrato canonico",
      "objective": "Preservar contrato canonico",
      "description": "Story no formato v1.",
      "acceptance_criteria": ["Mantem criterios"],
      "allowed_files": ["README.md"],
      "priority": 1,
      "status": "pending"
    }
  ]
}
JSON

    printf '{"stories": [' > "$TESTDIR/invalid-prd.json"
}

run_migrator() {
    local input="$1"
    local story_id="$2"
    local output="$3"

    set +e
    "$MIGRATOR" --input "$input" --story "$story_id" --output "$output" > "$TESTDIR/migrator.log" 2>&1
    MIGRATOR_RC=$?
    set -e
}

assert_envelope() {
    local output="$1"
    local id="$2"
    local title="$3"
    local description="$4"
    local criteria="$5"
    local files="$6"
    local priority="$7"

    [[ -s "$output" ]] || return 1
    jq -e \
        --arg id "$id" \
        --arg title "$title" \
        --arg description "$description" \
        --argjson criteria "$criteria" \
        --argjson files "$files" \
        --argjson priority "$priority" \
        '.schema_version == "devorq.story/v1"
         and .story.id == $id
         and .story.title == $title
         and .story.objective == $title
         and .story.description == $description
         and .story.acceptance_criteria == $criteria
         and .story.allowed_files == $files
         and .story.priority == $priority
         and .story.status == "pending"' \
        "$output" >/dev/null
}

test_legacy_non_destructive_adaptation() {
    local input="$TESTDIR/legacy-prd.json"
    local output="$TESTDIR/legacy-envelope.json"
    local before after
    before="$(sha256sum "$input" | awk '{print $1}')"
    run_migrator "$input" legacy-001 "$output"
    after="$(sha256sum "$input" | awk '{print $1}')"

    if [[ "$MIGRATOR_RC" -ne 0 ]]; then
        fail "migrador deve adaptar PRD legado sem erro"
        return
    fi
    if [[ "$before" != "$after" ]]; then
        fail "migrador nao pode reescrever PRD legado"
    else
        pass "PRD legado preservado byte a byte"
    fi
    if assert_envelope "$output" legacy-001 "Preservar compatibilidade legada" "Story no formato historico." '["Mantem criterios"]' '["README.md","lib/auto.sh"]' 2; then
        pass "envelope story v1 preserva mapeamento legacy camelCase"
    else
        fail "envelope story v1 invalido para fixture legada"
    fi
}

test_canonical_adaptation() {
    local input="$TESTDIR/canonical-prd.json"
    local output="$TESTDIR/canonical-envelope.json"
    local before after
    before="$(sha256sum "$input" | awk '{print $1}')"
    run_migrator "$input" canonical-001 "$output"
    after="$(sha256sum "$input" | awk '{print $1}')"

    if [[ "$MIGRATOR_RC" -ne 0 ]]; then
        fail "migrador deve aceitar PRD canonico"
        return
    fi
    if [[ "$before" != "$after" ]]; then
        fail "migrador nao pode reescrever PRD canonico"
    else
        pass "PRD canonico preservado byte a byte"
    fi
    if assert_envelope "$output" canonical-001 "Preservar contrato canonico" "Story no formato v1." '["Mantem criterios"]' '["README.md"]' 1; then
        pass "envelope story v1 preserva formato canonico"
    else
        fail "envelope story v1 invalido para fixture canonica"
    fi
}

test_invalid_json_rejected() {
    local input="$TESTDIR/invalid-prd.json"
    local output="$TESTDIR/invalid-envelope.json"
    local before after
    before="$(sha256sum "$input" | awk '{print $1}')"
    run_migrator "$input" invalid-001 "$output"
    after="$(sha256sum "$input" | awk '{print $1}')"

    if [[ "$MIGRATOR_RC" -eq 0 ]]; then
        fail "migrador deve rejeitar JSON invalido"
    else
        pass "JSON invalido rejeitado"
    fi
    if [[ "$before" != "$after" ]]; then
        fail "falha de migracao nao pode alterar input invalido"
    else
        pass "input invalido preservado"
    fi
    if [[ -e "$output" ]]; then
        fail "falha de migracao nao pode publicar envelope"
    else
        pass "falha de migracao nao publica envelope"
    fi
}

main() {
    [[ -x "$MIGRATOR" ]] || {
        echo "Migrador nao executavel: $MIGRATOR" >&2
        echo "Contrato esperado: migrate-prd-v1.sh --input PRD --story ID --output ENVELOPE" >&2
        exit 2
    }
    require jq
    require sha256sum
    write_fixtures

    case "${1:-all}" in
        legacy) test_legacy_non_destructive_adaptation ;;
        canonical) test_canonical_adaptation ;;
        invalid) test_invalid_json_rejected ;;
        all)
            test_legacy_non_destructive_adaptation
            test_canonical_adaptation
            test_invalid_json_rejected
            ;;
        *)
            echo "Uso: $0 [all|legacy|canonical|invalid]" >&2
            exit 2
            ;;
    esac

    [[ "$FAILURES" -eq 0 ]] || exit 1
}

main "$@"
