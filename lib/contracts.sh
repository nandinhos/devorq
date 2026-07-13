#!/usr/bin/env bash
# lib/contracts.sh - Contratos versionados do Loop Engineering

DEVORQ_CONTRACTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVORQ_CONTRACTS_SCHEMA_VERSION="v1"

devorq::contracts::die() {
    echo "[contracts] $*" >&2
    return 1
}

devorq::contracts::require_jq() {
    command -v jq >/dev/null 2>&1 || devorq::contracts::die "jq obrigatorio para validar contratos"
}

devorq::contracts::schema_path() {
    local type="${1:-}"

    case "$type" in
        loop|story|execution|verification|evidence|failure|lesson|handoff)
            printf '%s/schemas/%s.%s.schema.json\n' "$DEVORQ_CONTRACTS_ROOT" "$type" "$DEVORQ_CONTRACTS_SCHEMA_VERSION"
            ;;
        *)
            devorq::contracts::die "tipo de contrato desconhecido: ${type:-<vazio>}"
            ;;
    esac
}

devorq::contracts::read_json() {
    local source="${1:-}"

    [[ -n "$source" ]] || devorq::contracts::die "JSON do contrato ausente"
    if [[ -f "$source" ]]; then
        cat "$source"
    else
        printf '%s\n' "$source"
    fi
}

devorq::contracts::validate() {
    local type="${1:-}"
    local source="${2:-}"
    local schema expected_schema json

    devorq::contracts::require_jq || return 1
    schema=$(devorq::contracts::schema_path "$type") || return 1
    [[ -f "$schema" ]] || devorq::contracts::die "schema ausente: $schema"
    expected_schema="devorq.${type}/${DEVORQ_CONTRACTS_SCHEMA_VERSION}"
    json=$(devorq::contracts::read_json "$source") || return 1

    if ! jq -e . >/dev/null 2>&1 <<<"$json"; then
        devorq::contracts::die "JSON invalido para contrato $type"
        return 1
    fi

    if ! jq -e --arg type "$type" --arg schema "$expected_schema" '
        type == "object"
        and .schema_version == $schema
        and .document_type == $type
        and (.run_id | type == "string" and length > 0)
        and (.id | type == "string" and length > 0)
    ' >/dev/null <<<"$json"; then
        devorq::contracts::die "envelope invalido para contrato $type"
        return 1
    fi

    case "$type" in
        loop)
            jq -e '
                (.profile | type == "string" and length > 0)
                and (.objective | type == "string" and length > 0)
                and (.status | IN("pending", "planning", "running", "verifying", "completed", "failed", "blocked", "requires_owner_decision", "max_attempts_reached", "cancelled"))
            ' >/dev/null <<<"$json"
            ;;
        story)
            jq -e '
                (.title | type == "string" and length > 0)
                and (.description | type == "string" and length > 0)
                and (.acceptance_criteria | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
                and (.status | IN("pending", "planning", "running", "verifying", "completed", "failed", "blocked", "requires_owner_decision", "max_attempts_reached", "cancelled"))
            ' >/dev/null <<<"$json"
            ;;
        execution)
            jq -e '
                (.story_id | type == "string" and length > 0)
                and (.attempt | type == "number" and floor == . and . >= 1)
                and (.actor | type == "string" and length > 0)
                and (.status | IN("running", "succeeded", "failed", "blocked", "cancelled"))
                and (.exit_code | type == "number" and floor == .)
            ' >/dev/null <<<"$json"
            ;;
        verification)
            jq -e '
                (.story_id | type == "string" and length > 0)
                and (.verifier | type == "string" and length > 0)
                and (.checks | type == "array" and length > 0)
                and (.verdict | IN("passed", "failed", "blocked"))
            ' >/dev/null <<<"$json"
            ;;
        evidence)
            jq -e '
                (.evidence_type | type == "string" and length > 0)
                and (.path | type == "string" and length > 0)
                and (.sha256 | type == "string" and test("^[a-f0-9]{64}$"))
                and (.result | IN("passed", "failed", "blocked"))
            ' >/dev/null <<<"$json"
            ;;
        failure)
            jq -e '
                (.phase | type == "string" and length > 0)
                and (.category | type == "string" and length > 0)
                and (.error | type == "string" and length > 0)
                and (.retryable | type == "boolean")
            ' >/dev/null <<<"$json"
            ;;
        lesson)
            jq -e '
                (.hypothesis | type == "string" and length > 0)
                and (.action | type == "string" and length > 0)
                and (.result | type == "string" and length > 0)
                and (.status | IN("captured", "validated", "rejected"))
            ' >/dev/null <<<"$json"
            ;;
        handoff)
            jq -e '
                (.objective | type == "string" and length > 0)
                and (.terminal_state | IN("completed", "failed", "blocked", "requires_owner_decision", "max_attempts_reached", "cancelled"))
                and (.evidence_ids | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
                and (.next_step | type == "string" and length > 0)
            ' >/dev/null <<<"$json"
            ;;
    esac || {
        devorq::contracts::die "campos invalidos para contrato $type"
        return 1
    }
}
