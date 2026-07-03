#!/usr/bin/env bash
# lib/commands/lessons.sh — DEVORQ Lessons Commands
#
# Comandos: capture, search, validate, approve, compile, list, migrate
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

lessons::help() {
    cat << 'EOF'
LESSONS COMMANDS:
  lessons capture "<t>" "<p>" "<s>"
                           Capturar lição aprendida
  lessons search "<q>"      Buscar lições locais
  lessons validate [--auto]  Validar lição com Context7 [--auto=pula prompts]
  lessons approve <id>       Aprovar lição para skill
  lessons approve --all [--skill=<name>] [--auto]
  lessons compile [<id>]     Compilar lições approved → skill
  lessons compile --dry-run  Preview sem modificar arquivos
  lessons list [filtro]      Listar lições (all|pending|approved|validated|compiled)
  lessons migrate            Migrar lições existentes (campos approved)
  lessons auto-commit <skill> [--auto] [--force]
                           Compilar + git commit + push
EOF
}

# ============================================================
# lessons capture
# ============================================================

devorq::cmd_lessons() {
    local sub="${1:-}"
    local lib_lessons="${DEVORQ_LIB}/lessons.sh"

    case "$sub" in
        capture)
            shift
            # Aceita a sintaxe do README (flags) E a posicional "<t>" "<p>" "<s>".
            local title="" problem="" solution=""
            local -a pos=()
            while [ $# -gt 0 ]; do
                case "$1" in
                    --problem)  problem="${2:-}"; shift 2 ;;
                    --solution) solution="${2:-}"; shift 2 ;;
                    --stack)    export DEVORQ_STACK="${2:-}"; shift 2 ;;
                    --tags)     export DEVORQ_TAGS="${2:-}"; shift 2 ;;
                    --*)        devorq::warn "flag desconhecida ignorada: $1"; shift ;;
                    *)          pos+=("$1"); shift ;;
                esac
            done
            [ -z "$title" ]    && title="${pos[0]:-}"
            [ -z "$problem" ]  && problem="${pos[1]:-}"
            [ -z "$solution" ] && solution="${pos[2]:-}"
            [ -z "$title" ] && { devorq::error "Uso: devorq lessons capture \"<titulo>\" [--problem P] [--solution S] [--stack X] [--tags a,b]"; return 1; }
            if [ ! -f "$lib_lessons" ]; then
                devorq::warn "lib/lessons.sh nao encontrado - criando stub"
                devorq::info "LESSON: title=${title}"
                return 0
            fi
            source "$lib_lessons"
            lessons::capture "$title" "$problem" "$solution"
            ;;
        search)
            local query="${2:-}"
            [ -z "$query" ] && devorq::error "Uso: devorq lessons search \"<query>\""
            source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
            lessons::search "$query"
            ;;
        validate)
            shift
            local auto_flag="false"
            while [ $# -gt 0 ]; do
                case "$1" in
                    --auto) auto_flag="true"; shift ;;
                    -*) shift ;;
                    *) shift ;;
                esac
            done
            source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
            if [ "$auto_flag" = "true" ]; then
                LESSONS_AUTO=true lessons::validate
            else
                lessons::validate
            fi
            ;;
        auto-commit)
            shift
            _devorq_lessons_auto_commit "$@"
            ;;
        approve)
            shift
            _devorq_lessons_approve "$@"
            ;;
        compile)
            shift
            _devorq_lessons_compile "$@"
            ;;
        list)
            shift
            source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
            local filter="${1:-all}"
            lessons::list "$filter"
            ;;
        migrate)
            source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
            lessons::migrate
            ;;
        *)
            devorq::error "Uso: devorq lessons capture|search|validate|approve|compile|list|migrate"
            ;;
    esac
}

# ============================================================
# lessons approve
# ============================================================

_devorq_lessons_approve() {
    local lesson_id=""
    local skill_name=""
    local batch_mode="false"
    local force_mode="false"

    while [ $# -gt 0 ]; do
        case "$1" in
            --all)
                batch_mode="true"
                shift
                ;;
            --force)
                force_mode="true"
                shift
                ;;
            --skill=*)
                skill_name="${1#*=}"
                shift
                ;;
            --auto)
                shift
                ;;
            -h|--help)
                echo "Uso: devorq lessons approve <id> [--skill=<name>] [--all] [--auto] [--force]"
                echo "     devorq lessons approve --all [--skill=<name>] [--auto] [--force]"
                return 0
                ;;
            -*)
                shift
                ;;
            *)
                lesson_id="$1"
                shift
                ;;
        esac
    done

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true

    if [ "$batch_mode" = "true" ]; then
        local count=0
        local dir="${DEVORQ_LESSONS_DIR:-${PWD}/.devorq/state/lessons}/captured"
        [ ! -d "$dir" ] && devorq::warn "Nenhuma licao capturada." && return 0

        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue

            if [ "$force_mode" = "true" ]; then
                local approved
                approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
                [ "$approved" = "true" ] && continue
            else
                if command -v jq &>/dev/null; then
                    local validated approved
                    validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
                    approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
                    [ "$validated" != "true" ] && continue
                    [ "$approved" = "true" ] && continue
                fi
            fi

            local id
            id=$(basename "$f" .json)
            if lessons::approve "$id" "$skill_name" "false" "$force_mode" &>/dev/null; then
                ((count++)) || true
            fi
        done
        devorq::success "Aprovadas: $count licoes"
    else
        if [ -z "$lesson_id" ]; then
            devorq::error "Uso: devorq lessons approve <id> [--skill=<name>] [--all] [--force]"
        fi
        lessons::approve "$lesson_id" "$skill_name" "false" "$force_mode"
    fi
}

# ============================================================
# lessons compile
# ============================================================

_devorq_lessons_compile() {
    local lesson_id=""
    local skill_path=""
    local dry_run="false"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                shift
                ;;
            --skill=*)
                skill_path="skills/${1#*=}"
                shift
                ;;
            -h|--help)
                echo "Uso: devorq lessons compile [<id>] [--dry-run] [--skill=<name>]"
                return 0
                ;;
            -*)
                shift
                ;;
            *)
                lesson_id="$1"
                shift
                ;;
        esac
    done

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
    lessons::compile "$lesson_id" "$skill_path" "$dry_run"
}

# ============================================================
# lessons auto-commit
# ============================================================

_devorq_lessons_auto_commit() {
    local skill_name=""
    local auto_mode="false"
    local force_mode="false"

    while [ $# -gt 0 ]; do
        case "$1" in
            --auto)
                auto_mode="true"
                shift
                ;;
            --force)
                force_mode="true"
                shift
                ;;
            -h|--help)
                echo "Uso: devorq lessons auto-commit <skill-name> [--auto] [--force]"
                return 0
                ;;
            -*)
                shift
                ;;
            *)
                skill_name="$1"
                shift
                ;;
        esac
    done

    [ -z "$skill_name" ] && devorq::error "Uso: devorq lessons auto-commit <skill-name> [--auto] [--force]"

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true

    local skill_path="skills/${skill_name}"
    echo -e "${CYAN}[AUTO-COMMIT]${RESET} Compilando skill: $skill_name"

    local compiled=0
    local dir="${DEVORQ_LESSONS_DIR:-${PWD}/.devorq/state/lessons}/captured"
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        if command -v jq &>/dev/null; then
            local approved sname
            approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
            sname=$(jq -r '.skill_name // ""' "$f" 2>/dev/null)
            [ "$approved" != "true" ] && continue
            [ "$sname" != "$skill_name" ] && continue
            lessons::_compile_lesson "$(basename "$f" .json)" "$skill_path" "false" &>/dev/null
            ((compiled++)) || true
        fi
    done

    if [ "$compiled" -eq 0 ]; then
        devorq::warn "Nenhuma licao approved para skill: $skill_name"
        return 1
    fi

    echo "Compiladas: $compiled licao(oes)"

    if [ ! -d ".git" ]; then
        devorq::info "Nao e um repo git - pulando commit"
        return 0
    fi

    local confirm="Y"
    if [ "$auto_mode" != "true" ] && [ "$force_mode" != "true" ]; then
        read -p "Commit + push skill '$skill_name'? [Y/n]: " confirm
        confirm="${confirm:-Y}"
    fi

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        git add "skills/${skill_name}/"
        git commit -m "feat(skill): $skill_name - auto-generated from approved lessons ($compiled lesson(s))"
        devorq::success "Commit: $skill_name"

        if git remote get-url origin &>/dev/null; then
            if git config --get credential.helper &>/dev/null || [ -n "${GITHUB_TOKEN:-}" ]; then
                if git push origin HEAD 2>&1; then
                    devorq::success "Push: origin/$(git rev-parse --abbrev-ref HEAD)"
                else
                    devorq::warn "Push falhou - verifique token ou conexao"
                fi
            else
                devorq::warn "Push ignorado - configure GITHUB_TOKEN ou git credential.helper"
                devorq::info "Dica: export GITHUB_TOKEN=ghp_... antes de rodar"
            fi
        else
            devorq::info "Sem remote configurado - pulando push"
        fi
    fi
}
