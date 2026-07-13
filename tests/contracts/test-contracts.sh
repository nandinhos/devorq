#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../lib/contracts.sh
source "$REPO_ROOT/lib/contracts.sh"

PASS=0
FAIL=0

pass() { printf 'PASS %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }

assert_valid() {
    local type="$1" json="$2"
    if devorq::contracts::validate "$type" "$json"; then
        pass "$type valido"
    else
        fail "$type deveria ser valido"
    fi
}

assert_invalid() {
    local type="$1" json="$2"
    if devorq::contracts::validate "$type" "$json" >/dev/null 2>&1; then
        fail "$type deveria bloquear input invalido"
    else
        pass "$type bloqueia input invalido"
    fi
}

valid_documents() {
    assert_valid loop '{"schema_version":"devorq.loop/v1","document_type":"loop","run_id":"run-1","id":"loop-1","profile":"implementation","objective":"Validar contratos","status":"pending"}'
    assert_valid story '{"schema_version":"devorq.story/v1","document_type":"story","run_id":"run-1","id":"story-1","title":"Story","description":"Descricao","acceptance_criteria":["Passa"],"status":"pending"}'
    assert_valid execution '{"schema_version":"devorq.execution/v1","document_type":"execution","run_id":"run-1","id":"execution-1","story_id":"story-1","attempt":1,"actor":"implementer","status":"succeeded","exit_code":0}'
    assert_valid verification '{"schema_version":"devorq.verification/v1","document_type":"verification","run_id":"run-1","id":"verification-1","story_id":"story-1","verifier":"qa","checks":["bash tests/contracts/test-contracts.sh"],"verdict":"passed"}'
    assert_valid evidence '{"schema_version":"devorq.evidence/v1","document_type":"evidence","run_id":"run-1","id":"evidence-1","evidence_type":"test","path":"tests.log","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","result":"passed"}'
    assert_valid failure '{"schema_version":"devorq.failure/v1","document_type":"failure","run_id":"run-1","id":"failure-1","phase":"execution","category":"runner","error":"timeout","retryable":true}'
    assert_valid lesson '{"schema_version":"devorq.lesson/v1","document_type":"lesson","run_id":"run-1","id":"lesson-1","hypothesis":"H","action":"A","result":"R","status":"captured"}'
    assert_valid handoff '{"schema_version":"devorq.handoff/v1","document_type":"handoff","run_id":"run-1","id":"handoff-1","objective":"Concluir","terminal_state":"blocked","evidence_ids":["evidence-1"],"next_step":"Owner decide"}'
}

invalid_documents() {
    assert_invalid story '{"schema_version":"devorq.story/v2","document_type":"story","run_id":"run-1","id":"story-1","title":"Story","description":"Descricao","acceptance_criteria":["Passa"],"status":"pending"}'
    assert_invalid story '{"schema_version":"devorq.story/v1","document_type":"story","id":"story-1","title":"Story","description":"Descricao","acceptance_criteria":["Passa"],"status":"pending"}'
    assert_invalid story '{"schema_version":"devorq.story/v1","document_type":"story","run_id":"run-1","id":"story-1","title":"Story","description":"Descricao","acceptance_criteria":[],"status":"pending"}'
    assert_invalid execution '{"schema_version":"devorq.execution/v1","document_type":"execution","run_id":"run-1","id":"execution-1","story_id":"story-1","attempt":1,"actor":"implementer","status":"succeeded","exit_code":"0"}'
    assert_invalid handoff '{"schema_version":"devorq.handoff/v1","document_type":"handoff","run_id":"run-1","id":"handoff-1","objective":"Concluir","terminal_state":"running","evidence_ids":["evidence-1"],"next_step":"Owner decide"}'
    assert_invalid loop '{not-json'
}

main() {
    local scenario="${1:-all}"
    command -v jq >/dev/null 2>&1 || { echo "jq nao encontrado" >&2; exit 2; }

    case "$scenario" in
        valid) valid_documents ;;
        invalid) invalid_documents ;;
        all)
            valid_documents
            invalid_documents
            ;;
        *)
            echo "Uso: $0 [all|valid|invalid]" >&2
            exit 2
            ;;
    esac

    printf 'Contratos: %s passou, %s falhou\n' "$PASS" "$FAIL"
    [[ "$FAIL" -eq 0 ]]
}

main "$@"
