#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/vps.sh — VPS HUB connectivity + sync
#
# SSH multiplexing para conexões rápidas (~0.3s/comando)
# Sincroniza .devorq/state/lessons ↔ PostgreSQL devorq.lessons

set -euo pipefail

# Exit codes (only define if not already defined)
[ -z "${EXIT_SUCCESS:-}" ] && readonly EXIT_SUCCESS=0
[ -z "${EXIT_ERROR:-}" ] && readonly EXIT_ERROR=1
[ -z "${EXIT_INVALID_ARGS:-}" ] && readonly EXIT_INVALID_ARGS=2
[ -z "${EXIT_NOT_FOUND:-}" ] && readonly EXIT_NOT_FOUND=3
[ -z "${EXIT_SSH_FAILED:-}" ] && readonly EXIT_SSH_FAILED=4

# Carrega config de infra de ~/.config/devorq/config (key=value, 0600) — apenas
# chaves whitelisted, sem default hardcoded de IP/usuario no repo (DQ-011).
devorq::vps::load_config() {
    local cfg="${HOME}/.config/devorq/config"
    [ -f "$cfg" ] || return 0
    local mode
    mode=$(stat -c '%a' "$cfg" 2>/dev/null || stat -f '%Lp' "$cfg" 2>/dev/null || echo "")
    if [ -n "$mode" ] && [ "$((8#$mode & 8#077))" -ne 0 ]; then
        echo "[WARN] ~/.config/devorq/config com permissoes inseguras (use chmod 600)" >&2
        return 0
    fi
    local key val
    while IFS='=' read -r key val; do
        key="${key// /}"
        case "$key" in
            DEVORQ_VPS_HOST|DEVORQ_VPS_PORT|DEVORQ_VPS_USER|DEVORQ_PG_DB|DEVORQ_PG_USER|DEVORQ_PG_CONTAINER|DEVORQ_MUX_SOCK)
                # if (nao '&& export') para sempre retornar 0 — senao, sob set -e,
                # re-sourcear vps.sh com a var ja setada abortaria (regressao DQ-011).
                if [ -z "${!key:-}" ]; then export "$key=${val// /}"; fi ;;
        esac
    done < "$cfg"
}
devorq::vps::load_config

VPS_HOST="${DEVORQ_VPS_HOST:-}"
VPS_PORT="${DEVORQ_VPS_PORT:-22}"
VPS_USER="${DEVORQ_VPS_USER:-}"

PG_DB="${DEVORQ_PG_DB:-hermes_study}"
PG_USER="${DEVORQ_PG_USER:-hermes_study}"

# Socket de mux por-usuario (evita colisao/hijack em /tmp compartilhado). DQ-015
MUX_SOCK="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux-$(id -u)}"

# ============================================================
# Sanitization helpers
# ============================================================

# M7: realpath portavel (GNU/BSD/macOS). Usa helpers.sh quando carregado;
# define fallback local p/ uso isolado (vps.sh e autonomo por design).
if ! declare -f devorq::util::realpath >/dev/null 2>&1; then
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
fi

devorq::sanitize_path() {
    local path="$1"
    local base_dir="${2:-.}"

    # Normaliza e valida que está dentro de base_dir
    local real_path real_base
    real_path=$(devorq::util::realpath "$path") || {
        echo "[ERROR] Path invalido: $path" >&2
        return $EXIT_INVALID_ARGS
    }
    real_base=$(devorq::util::realpath "$base_dir") || {
        echo "[ERROR] Base dir invalido: $base_dir" >&2
        return $EXIT_INVALID_ARGS
    }

    case "$real_path" in
        "$real_base"*) true ;;
        *) echo "[ERROR] Path traversal detectado: $path" >&2; return $EXIT_INVALID_ARGS ;;
    esac

    echo "$real_path"
}

devorq::validate_ssh_host() {
    local host="$1"
    local port="$2"

    # Validação básica de host
    if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo "[ERROR] Host invalido: $host" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Validação de porta
    if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        echo "[ERROR] Porta invalida: $port" >&2
        return $EXIT_INVALID_ARGS
    fi

    return $EXIT_SUCCESS
}

# ============================================================
# check — Testa conexão com VPS HUB
# ============================================================

devorq::vps_check() {
    # Infra obrigatoria via config/env, sem default hardcoded (DQ-011).
    if [ -z "$VPS_HOST" ] || [ -z "$VPS_USER" ]; then
        echo "[ERROR] DEVORQ_VPS_HOST/DEVORQ_VPS_USER nao definidos." >&2
        echo "        Configure ~/.config/devorq/config (chmod 600) ou exporte as variaveis." >&2
        return "${EXIT_INVALID_ARGS:-2}"
    fi
    echo "[VPS] Testando ${VPS_HOST}:${VPS_PORT}..."

    # Validação de inputs
    devorq::validate_ssh_host "$VPS_HOST" "$VPS_PORT" || return $?

    if ! command -v ssh &>/dev/null; then
        echo "[ERROR] ssh não encontrado"
        return $EXIT_NOT_FOUND
    fi

    mkdir -p "$(dirname "$MUX_SOCK")"

    local result
    result=$(ssh \
             -o "ControlMaster=auto" \
             -o "ControlPath=${MUX_SOCK}" \
             -o "ControlPersist=60" \
             -o "StrictHostKeyChecking=yes" \
             -o "UserKnownHostsFile=${HOME}/.ssh/known_hosts" \
             -o "ConnectTimeout=5" \
             -p "$VPS_PORT" \
             "${VPS_USER}@${VPS_HOST}" \
             "echo PING" 2>&1) || {
        echo "[ERROR] SSH falhou: $result"
        return $EXIT_SSH_FAILED
    }

    if echo "$result" | grep -q "PING"; then
        echo "[OK] VPS responde"
    else
        echo "[ERROR] Resposta inesperada: $result"
        return $EXIT_ERROR
    fi
}

# ============================================================
# exec — Executa comando no VPS via SSH mux
# ============================================================

devorq::vps_exec() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Uso: devorq::vps_exec <comando>" && return $EXIT_INVALID_ARGS

    # Whitelist de comandos SSH permitidos (fix-sec-001 — code review 2026-06-01)
    # Bloqueia command injection via:
    # 1. Metacaracteres shell perigosos (; | ` $ newline CR backtick)
    # 2. Primeira palavra de cada sub-comando (separado por && ou ||) deve estar na whitelist
    # 3. Rejeita redirecionamento < > que nao seja do proprio caller
    local allowed_cmds=(
        systemctl journalctl docker
        ls cat grep tail head
        ps free df uptime
        whoami pwd
        mkdir                       # caller: lib/lessons.sh:408 (lessons::sync_vps)
    )

    # P1: Bloqueia metacaracteres SEMPRE proibidos (codex review 2026-06-04)
    #    Estes NAO sao permitidos nem em compound commands:
    #      ;        - command separator
    #      `        - command substitution backtick
    #      $        - variable expansion
    #      ( )      - subshell
    #      cntrl    - injecao multi-line (newline, CR, etc)
    #    Pipe/background (| &) e' validado no split por sub-comando (P2)
    # shellcheck disable=SC2016  # regex literal, nao queremos expansao
    if printf '%s' "$cmd" | grep -qE '[;`$()]|[[:cntrl:]]'; then
        echo "[ERROR] comando SSH contem metacaracteres proibidos" >&2
        return $EXIT_INVALID_ARGS
    fi

    # P2: Valida cada sub-comando (separado por && ou ||) individualmente
    #    Cada sub-comando NAO pode conter pipe/background (| &) e
    #    sua primeira palavra deve estar na whitelist.
    #    NOTA: BRE (sem -E) com classes POSIX basicas (s/ */) e' mais deterministico.
    local normalized
    normalized=$(printf '%s\n' "$cmd" | sed 's/ *&& */\n/g; s/ *|| */\n/g')
    local sub_cmds=()
    local sub_cmd
    while IFS= read -r sub_cmd; do
        [ -z "$sub_cmd" ] && continue
        # Trim leading/trailing whitespace
        sub_cmd="${sub_cmd#"${sub_cmd%%[![:space:]]*}"}"
        sub_cmd="${sub_cmd%"${sub_cmd##*[![:space:]]}"}"
        [ -z "$sub_cmd" ] && continue
        sub_cmds+=( "$sub_cmd" )
    done <<< "$normalized"
    for sub_cmd in "${sub_cmds[@]}"; do
        # Bloqueia pipe/background standalone (NAO && nem ||)
        if printf '%s' "$sub_cmd" | grep -qE '[|&]'; then
            echo "[ERROR] sub-comando SSH contem pipe/background nao permitido" >&2
            return $EXIT_INVALID_ARGS
        fi
        # Pega primeira palavra (delimitada por espaco ou tab)
        local first_word="${sub_cmd%%[ 	]*}"
        local ok=0
        local allowed
        for allowed in "${allowed_cmds[@]}"; do
            if [[ "$first_word" == "$allowed" ]]; then
                ok=1
                break
            fi
        done
        if ((ok == 0)); then
            echo "[ERROR] comando SSH nao permitido: $first_word" >&2
            echo "[INFO] Comandos permitidos: ${allowed_cmds[*]}" >&2
            return $EXIT_INVALID_ARGS
        fi
    done

    # Validação
    devorq::validate_ssh_host "$VPS_HOST" "$VPS_PORT" || return $?

    ssh \
        -o "ControlMaster=auto" \
        -o "ControlPath=${MUX_SOCK}" \
        -o "ControlPersist=60" \
        -o "StrictHostKeyChecking=yes" \
        -o "UserKnownHostsFile=${HOME}/.ssh/known_hosts" \
        -o "ConnectTimeout=10" \
        -p "$VPS_PORT" \
        "${VPS_USER}@${VPS_HOST}" \
        "$cmd"
}

# ============================================================
# pg_exec — Executa SQL no PostgreSQL do HUB
# ============================================================

devorq::vps_pg_exec() {
    local sql="$*"
    [ -z "$sql" ] && echo "Uso: devorq::vps_pg_exec <sql>" && return $EXIT_INVALID_ARGS

    # Validação de SQL básico (procurar caracteres perigosos)
    local dangerous_pattern='[;&|`\$\(\)\{\}\[\]< >!\\]'
    if echo "$sql" | grep -qE "$dangerous_pattern"; then
        echo "[ERROR] Caracteres perigosos detectados no SQL" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Usa printf %q para escapar correctamente
    local escaped
    escaped=$(printf '%s' "$sql" | sed "s/'/'\"'\"'/g")

    devorq::vps_exec "docker exec hermesstudy_postgres psql -U ${PG_USER} -d ${PG_DB} -c '${escaped}'"
}

# ============================================================
# lessons_count — Conta lições no HUB
# ============================================================

devorq::vps_lessons_count() {
    devorq::vps_pg_exec "SELECT count(*) FROM devorq.lessons;" 2>/dev/null || echo "0"
}

# Aliases para compatibilidade (deprecated)
vps::check() { devorq::vps_check "$@"; }
vps::exec() { devorq::vps_exec "$@"; }
vps::pg_exec() { devorq::vps_pg_exec "$@"; }
vps::lessons_count() { devorq::vps_lessons_count "$@"; }
