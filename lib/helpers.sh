#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/helpers.sh - DEVORQ Helper Functions
# Exit codes: 0=sucesso, 1=erro, 2=invalid_args, 3=not_found, 4=validation_failed, 5=permission_denied

# Exit codes (constantes globais)
# SC2168: These are valid since file is sourced, not executed directly
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_ARGS=2
EXIT_NOT_FOUND=3
EXIT_VALIDATION_FAILED=4
EXIT_PERMISSION_DENIED=5

# Edicao in-place portavel de sed (GNU e BSD/macOS divergem na flag -i). DQ-029.
# Uso: devorq::sed_inplace '<expr>' <arquivo>
devorq::sed_inplace() {
    local expr="$1" file="$2"
    if sed --version >/dev/null 2>&1; then
        sed -i -e "$expr" "$file"      # GNU sed
    else
        sed -i '' -e "$expr" "$file"   # BSD/macOS sed (exige sufixo de backup vazio)
    fi
}

# Sanitize input - remove dangerous characters
sanitize_input() {
    local input="${1:-}"
    if [ -z "$input" ]; then
        echo ""
        return 0
    fi
    echo "$input" | sed 's/[^a-zA-Z0-9._\-]//g'
}

# Validate path - ensure path is within base_dir
validate_path() {
    local path="$1"
    local base_dir="${2:-.}"
    if [ -z "$path" ]; then
        echo "Path required" >&2
        return $EXIT_INVALID_ARGS
    fi
    local real_path
    real_path=$(devorq::util::realpath "$path") || {
        echo "Invalid path: $path" >&2
        return $EXIT_ERROR
    }
    local real_base
    real_base=$(devorq::util::realpath "$base_dir") || {
        echo "Invalid base_dir: $base_dir" >&2
        return $EXIT_ERROR
    }
    case "$real_path" in
        "$real_base"/*)
            echo "$real_path"
            return $EXIT_SUCCESS
            ;;
        *)
            echo "Path $path is outside $base_dir" >&2
            return $EXIT_VALIDATION_FAILED
            ;;
    esac
}

# Require arg - check if arg is provided
require_arg() {
    local arg="$1"
    local name="$2"
    if [ -z "$arg" ]; then
        echo "Argument required: $name" >&2
        return $EXIT_INVALID_ARGS
    fi
    return $EXIT_SUCCESS
}

# Require file - check if file exists
require_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "File not found: $file" >&2
        return $EXIT_NOT_FOUND
    fi
    return $EXIT_SUCCESS
}

# Log safe - remove credentials from log
log_safe() {
    local message="$1"
    echo "$message" | sed 's/password=.*/password=REDACTED/g' | sed 's/token=.*/token=REDACTED/g'
}

# CLI logging (used across lib/commands and lib/*.sh)
devorq::info()    { echo "[INFO] $*"; }
devorq::log()     { echo "[LOG] $*"; }
devorq::warn()    { echo "[WARN] $*" >&2; }
devorq::error()   { echo "[ERROR] $*" >&2; return 1; }
devorq::success() { echo "[OK] $*"; }
devorq::fail()    { echo "[FAIL] $*" >&2; return 1; }

# Trilha de execucao estruturada (JSONL) com run_id estavel por processo,
# correlacionando flow -> gates -> verify. Append-only em
# .devorq/state/logs/run-<run_id>.jsonl. Nunca falha o caller (best-effort). DQ-018.
devorq::audit_log() {
    local event="${1:-}" status="${2:-}" detail="${3:-}"
    [ -z "${DEVORQ_RUN_ID:-}" ] && export DEVORQ_RUN_ID="$(date +%Y%m%d_%H%M%S)_$$"
    local logs_dir="${DEVORQ_LOGS_DIR:-${PWD}/.devorq/state/logs}"
    mkdir -p "$logs_dir" 2>/dev/null || return 0
    local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)   # -u: sufixo Z exige UTC real, nao hora local
    local agent="${DEVORQ_AGENT:-}"   # qual agente/modelo agiu (DQ-023)
    local line
    if command -v jq &>/dev/null; then
        line=$(jq -nc --arg r "$DEVORQ_RUN_ID" --arg t "$ts" --arg e "$event" --arg s "$status" --arg d "$detail" --arg a "$agent" \
            '{run_id:$r, ts:$t, agent:$a, event:$e, status:$s, detail:$d}' 2>/dev/null)
    fi
    [ -z "${line:-}" ] && line="{\"run_id\":\"${DEVORQ_RUN_ID}\",\"ts\":\"${ts}\",\"agent\":\"${agent}\",\"event\":\"${event}\",\"status\":\"${status}\"}"
    printf '%s\n' "$line" >> "${logs_dir}/run-${DEVORQ_RUN_ID}.jsonl" 2>/dev/null || true
}

# ============================================================
# Helpers de portabilidade GNU/BSD/macOS (M7)
# ============================================================

# realpath portavel: usa `realpath` (GNU) quando existir; senao resolve via
# `cd -P + pwd` (funciona em BSD/macOS sem coreutils). Retorna 0 + caminho
# absoluto em stdout, ou !=0 se nao resolver.
devorq::util::realpath() {
    local p="${1:-}"
    [[ -n "$p" ]] || return 1
    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null && return 0
    fi
    if [[ -d "$p" ]]; then
        ( cd -P "$p" 2>/dev/null && pwd ) && return 0
    fi
    local dir base rdir
    dir=$(dirname "$p") || return 1
    base=$(basename "$p") || return 1
    rdir=$( ( cd -P "$dir" 2>/dev/null && pwd ) ) || return 1
    printf '%s/%s\n' "$rdir" "$base"
}

# timeout portavel: usa `timeout` (GNU) ou `gtimeout` (macOS coreutils via brew);
# se nenhum existir, executa sem limite com aviso (fallback seguro).
devorq::util::run_timeout() {
    local secs="${1:-0}"
    shift || true
    local to
    to=$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)
    if [[ -n "$to" ]]; then
        "$to" "$secs" "$@"
    else
        devorq::warn "timeout indisponivel (GNU coreutils) — executando sem limite de tempo"
        "$@"
    fi
}

# readlink -f portavel: resolve symlinks + caminho absoluto em GNU/BSD/macOS.
devorq::util::readlink_f() {
    local p="${1:-}"
    [[ -n "$p" ]] || return 1
    if command -v readlink >/dev/null 2>&1 && readlink -f "$p" >/dev/null 2>&1; then
        readlink -f "$p"
        return 0
    fi
    # Fallback: loop de symlink (mesmo padrao do bin/devorq) + cd -P
    local src="$p" dir
    while [[ -L "$src" ]]; do
        dir=$(cd -P "$(dirname "$src")" 2>/dev/null && pwd) || return 1
        src=$(readlink "$src")
        [[ "$src" != /* ]] && src="${dir}/${src}"
    done
    dir=$(cd -P "$(dirname "$src")" 2>/dev/null && pwd) || return 1
    printf '%s/%s\n' "$dir" "$(basename "$src")"
}
