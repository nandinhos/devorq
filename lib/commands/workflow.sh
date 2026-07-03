#!/usr/bin/env bash
# lib/commands/workflow.sh — DEVORQ Workflow Commands
#
# Comandos: init, test, flow, gate
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

workflow::help() {
    cat << 'EOF'
WORKFLOW COMMANDS:
  init                       Inicializar .devorq/ no projeto
  test                       Testar estrutura do projeto
  flow "<intent>"           Workflow completo (gates 1-7)
  gate [0-7]                Executar gate específico
EOF
}

# ============================================================
# init
# ============================================================

devorq::cmd_init() {
    # Sanitizar PWD para prevenir path traversal
    local project_root
    project_root=$(cd "${PWD}" && pwd -P)
    local devorq_dir="${project_root}/.devorq"

    if [ -d "$devorq_dir" ]; then
        devorq::warn "Ja existe .devorq/ em ${project_root}"
    else
    mkdir -p "$devorq_dir/state/lessons/captured"
    mkdir -p "$devorq_dir/skills"
    mkdir -p "$devorq_dir/rules"

    if [ -f "${DEVORQ_ROOT}/.devorq/commit_convention.json" ]; then
        cp "${DEVORQ_ROOT}/.devorq/commit_convention.json" "$devorq_dir/"
    fi

    cat > "$devorq_dir/state/context.json" << 'EOFC'
{
  "project": "",
  "stack": [],
  "intent": "",
  "success_criteria": [],
  "commit_mode": "manual",
  "gates_completed": [],
  "last_updated": ""
}
EOFC

    cat > "$devorq_dir/state/session.json" << 'EOFS'
{
  "started_at": "",
  "ended_at": "",
  "handoff_id": null,
  "summary": ""
}
EOFS

    devorq::success "Inicializado .devorq/ em ${project_root}"
    devorq::info "Edite .devorq/state/context.json com project, stack e intent"

    local foundation_init="${DEVORQ_ROOT}/skills/project-foundation/scripts/foundation-init.sh"
    if [ -f "$foundation_init" ]; then
        local safe_project_name
        safe_project_name=$(basename "$project_root" | tr -cd 'a-zA-Z0-9._-')
        if bash "$foundation_init" "$devorq_dir/state" "$safe_project_name" 2>/dev/null; then
            devorq::info "Foundation docs criados em .devorq/state/"
            devorq::info "Execute: devorq foundation create para preencher"
        fi
    fi
    fi

    # Bootstrap regras + commit-msg hook (idempotente)
    if [ -f "${DEVORQ_LIB}/rules.sh" ]; then
        # shellcheck disable=SC1091
        source "${DEVORQ_LIB}/rules.sh"
        if declare -f devorq::rules::bootstrap_project &>/dev/null; then
            devorq::rules::bootstrap_project "$project_root" || devorq::warn "Bootstrap de regras falhou parcialmente"
        fi
    fi
}

# ============================================================
# structure check (checagem de sintaxe/estrutura)
# Renomeado de devorq::cmd_test para eliminar shadowing com
# lib/commands/test.sh (que roda a suite real). Ver DQ-001.
# ============================================================

devorq::cmd_structure_check() {
    devorq::info "Testando estrutura..."
    local errors=0

    bash -n "${DEVORQ_ROOT}/bin/devorq" 2>/dev/null || {
        devorq::warn "bin/devorq: syntax error"
        errors=$((errors+1))
    }
    
    for f in "${DEVORQ_LIB}"/*.sh; do
        bash -n "$f" 2>/dev/null || {
            devorq::warn "$f: syntax error"
            errors=$((errors+1))
        }
    done

    [ -f "${DEVORQ_LIB}/lessons.sh" ] || {
        devorq::warn "lib/lessons.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/gates.sh" ] || {
        devorq::warn "lib/gates.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/compact.sh" ] || {
        devorq::warn "lib/compact.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/vps.sh" ] || {
        devorq::warn "lib/vps.sh: not found"
        errors=$((errors+1))
    }

    if [ $errors -eq 0 ]; then
        devorq::success "Estrutura OK (devorq v${DEVORQ_VERSION})"
    else
        devorq::error "$errors erro(s) encontrado(s)"
    fi
}

# ============================================================
# flow
# ============================================================

devorq::cmd_flow() {
    local resume=false intent=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --resume) resume=true; shift ;;
            *) intent="$1"; shift ;;
        esac
    done
    [ -z "$intent" ] && { devorq::error "Uso: devorq flow [--resume] \"<intent>\""; return 1; }

    # Gates leem DEVORQ_INTENT (gates.sh:60) — sem export, DDD/grill/G-4 rodam vazios.
    export DEVORQ_INTENT="$intent"
    devorq::log "Intent: ${intent}"
    devorq::log "Executando gates 0 -> 0.5 -> 1-7..."
    declare -f devorq::audit_log &>/dev/null && devorq::audit_log "flow" "start" "$intent" || true

    # Retomada (DQ-007): com --resume, pula gates ja persistidos em gates_completed.
    local completed=""
    if [ "$resume" = "true" ] && command -v jq &>/dev/null && [ -f "${PWD}/.devorq/state/context.json" ]; then
        completed=$(jq -r '.gates_completed // [] | join(" ")' "${PWD}/.devorq/state/context.json" 2>/dev/null || echo "")
        [ -n "$completed" ] && devorq::info "Retomando — gates ja concluidos: $completed"
    fi

    for gate in ${DEVORQ_GATE_SEQUENCE:-0 0.5 1 2 3 4 5 6 7}; do
        if [ "$resume" = "true" ] && printf ' %s ' "$completed" | grep -q " ${gate} "; then
            devorq::info "--- GATE ${gate} (ja concluido — pulando) ---"
            continue
        fi
        devorq::info "--- GATE ${gate} ---"
        if ! devorq::cmd_gate "$gate" 2>&1; then
            echo "[ERROR] Gate ${gate} falhou — parando flow" >&2
            declare -f devorq::audit_log &>/dev/null && devorq::audit_log "flow" "end" "falhou gate ${gate}" || true
            return 1
        fi
    done

    declare -f devorq::audit_log &>/dev/null && devorq::audit_log "flow" "end" "completo" || true
    devorq::success "Flow completo!"
}

# ============================================================
# gate
# ============================================================

devorq::cmd_gate() {
    local gate_num="${1:-}"
    local lib_gate="${DEVORQ_LIB}/gates.sh"

    if [ ! -f "$lib_gate" ]; then
        devorq::warn "lib/gates.sh nao encontrado - gate simulado"
        devorq::info "GATE-${gate_num}: (sem lib/gates.sh - implementar)"
        return 0
    fi

    # Guard: evitar re-sourcing do mesmo arquivo
    if ! declare -f gate_0 &>/dev/null; then
        source "$lib_gate"
    fi

    local rv=0
    case "$gate_num" in
        0)   gate_0;   rv=$? ;;
        0.5) gate_0_5; rv=$? ;;
        1)   gate_1;   rv=$? ;;
        2)   gate_2;   rv=$? ;;
        3)   gate_3;   rv=$? ;;
        4)   gate_4;   rv=$? ;;
        5)   gate_5;   rv=$? ;;
        5.5) gate_5_5; rv=$? ;;
        6)   gate_6;   rv=$? ;;
        7)   gate_7;   rv=$? ;;
        *)   devorq::fail "Gate invalido: $gate_num (aceitos: 0, 0.5, 1-7, 5.5)"; return 1 ;;
    esac

    # Persiste a conclusao do gate (DQ-007): sem isso, gates_completed nunca
    # era escrito e stats/handoff/GATE-7/retomada liam estado-fantasma.
    if [ "$rv" -eq 0 ] && declare -f ctx_mark_gate &>/dev/null; then
        ctx_mark_gate "$gate_num" || true
    fi

    # Trilha de execucao estruturada (DQ-018)
    if declare -f devorq::audit_log &>/dev/null; then
        devorq::audit_log "gate" "$([ "$rv" -eq 0 ] && echo pass || echo fail)" "gate-${gate_num}" || true
    fi

    return $rv
}
