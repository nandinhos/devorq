#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/commit.sh — DEVORQ Commit Interativo
# Formato: tipo(escopo): descrição (detalhamento)
# Sem emojis, sem co-autoria, em português do Brasil

# Guard de segredos (DQ-014): antes do 'git add -A' cego, bloqueia se arquivos
# sensiveis (.env, *.pem/key, id_rsa, etc.) estao prestes a ser versionados.
# Override consciente via DEVORQ_ALLOW_SECRETS=1.
devorq::commit::guard_secrets() {
    local project_root="$1"
    local sensitive
    sensitive=$(git -C "$project_root" status --porcelain --untracked-files=all 2>/dev/null \
        | sed 's/^...//' \
        | grep -iE '(^|/)(\.env(\.[a-z0-9_-]+)?$|id_rsa$|id_dsa$|id_ed25519$|[^/]*\.(pem|key|p12|pfx|kdbx)$)' \
        | grep -ivE '\.env\.(example|sample|template|dist)$' \
        || true)
    [ -z "$sensitive" ] && return 0

    devorq::warn "Arquivos sensiveis nas mudancas (NAO versione segredos):"
    echo "$sensitive" | sed 's/^/    /' >&2
    if [ "${DEVORQ_ALLOW_SECRETS:-0}" = "1" ]; then
        devorq::warn "DEVORQ_ALLOW_SECRETS=1 — prosseguindo mesmo assim"
        return 0
    fi
    devorq::warn "Commit abortado. Adicione ao .gitignore ou use DEVORQ_ALLOW_SECRETS=1."
    return 1
}

devorq::commit::usage() {
    cat <<'USAGE_EOF'
Uso: devorq commit [--story <id>] [--type <tipo>] [--scope <scope>] [--message <msg>]

Commit manual seguindo convenção DEVORQ:
  tipo(escopo): descrição (detalhamento)

Flags:
  --story <id>     Usa título e description da story do prd.json
  --type <tipo>    Tipo convencional (feat/fix/refactor/docs/test/style/perf/chore; default: feat)
  --scope <scope>  Sobrescreve escopo (default: detecta do projeto)
  --message <msg>  Mensagem completa sem convenção (modo livre)
  --dry-run        Mostra preview sem commitar
  --push           Faz push após commit

Exemplos:
  devorq commit --story feat-001           # Interativo com story
  devorq commit --type fix --scope models  # Forçar tipo e scope
  devorq commit --message "fix: corrige bug" # Modo livre

Escopos válidos:
  core | models | services | livewire | notifications | routes | config |
  database | tests | bdd | gates | unify | docs | debug | spec | lessons |
  compact | vps | hub | context | release

Tipos válidos:
  feat | fix | refactor | docs | test | style | perf | chore
USAGE_EOF
}

# ============================================================
# Escopos e tipos válidos
# ============================================================
declare -A VALID_SCOPES
VALID_SCOPES=(
    ["core"]="core"
    ["models"]="models"
    ["services"]="services"
    ["livewire"]="livewire"
    ["notifications"]="notifications"
    ["routes"]="routes"
    ["config"]="config"
    ["database"]="database"
    ["tests"]="tests"
    ["bdd"]="bdd"
    ["gates"]="gates"
    ["unify"]="unify"
    ["docs"]="docs"
    ["debug"]="debug"
    ["spec"]="spec"
    ["lessons"]="lessons"
    ["compact"]="compact"
    ["vps"]="vps"
    ["hub"]="hub"
    ["context"]="context"
    ["release"]="release"
)

# Tipos convencionais (Model A: tipo(escopo)). Alinha com CLAUDE.md global e o hook.
declare -A VALID_TYPES
VALID_TYPES=(
    ["feat"]="feat"
    ["fix"]="fix"
    ["refactor"]="refactor"
    ["docs"]="docs"
    ["test"]="test"
    ["style"]="style"
    ["perf"]="perf"
    ["chore"]="chore"
)

# ============================================================
# devorq::commit::run
# Executa commit interativo ou automatizado
# ============================================================
devorq::commit::run() {
    local story_id=""
    local scope=""
    local type=""
    local custom_message=""
    local dry_run="false"
    local do_push="false"

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --story)
                story_id="$2"
                shift 2
                ;;
            --scope)
                scope="$2"
                shift 2
                ;;
            --type)
                type="$2"
                shift 2
                ;;
            --phase)
                # alias deprecado: fase antiga -> tipo (Model A)
                devorq::warn "--phase esta deprecado; use --type (convencao tipo(escopo))"
                type="$2"
                shift 2
                ;;
            --message)
                custom_message="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --push)
                do_push="true"
                shift
                ;;
            --help|-h)
                devorq::commit::usage
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    # Verificar se é repo git
    if [[ ! -d "$project_root/.git" ]]; then
        devorq::error "Não é um repositório git: $project_root"
        return 1
    fi

    # Verificar se há changes
    if git -C "$project_root" diff --cached --quiet 2>/dev/null && \
       git -C "$project_root" diff --quiet 2>/dev/null; then
        devorq::warn "Nenhum change para commitar"
        return 0
    fi

    # Se --message foi passado, commit direto
    if [[ -n "$custom_message" ]]; then
        devorq::commit::direct "$project_root" "$custom_message" "$do_push" "$dry_run"
        return $?
    fi

    # Modo interativo
    devorq::commit::interactive "$project_root" "$story_id" "$scope" "$type" "$do_push" "$dry_run"
}

# ============================================================
# devorq::commit::interactive
# Commit interativo com convenção
# ============================================================
devorq::commit::interactive() {
    local project_root="$1"
    local story_id="$2"
    local initial_scope="$3"
    local initial_type="$4"
    local do_push="$5"
    local dry_run="$6"

    local title="" description="" detail=""
    local scope="$initial_scope" type="$initial_type"

    # Se story_id foi passada, carregar dados
    if [[ -n "$story_id" ]]; then
        local story_json
        story_json="$(devorq::auto::get_story "$project_root" "$story_id")"

        if [[ -z "$story_json" || "$story_json" == "null" ]]; then
            devorq::warn "Story $story_id não encontrada no prd.json"
        else
            title=$(echo "$story_json" | jq -r '.title // ""' 2>/dev/null)
            description=$(echo "$story_json" | jq -r '.description // ""' 2>/dev/null)
        fi
    fi

    echo ""
    devorq::info "═══ Commit DEVORQ ═══"
    echo ""

    # Detectar scope default se não informado
    if [[ -z "$scope" ]]; then
        scope="$(devorq::verify::detect_scope "$project_root")"
    fi

    # Tipo default se não informado
    if [[ -z "$type" ]]; then
        type="feat"
    fi

    # 1. Scope
    if [[ -z "$initial_scope" ]]; then
        echo -n "Scope [$scope]: "
        local input_scope
        read -r input_scope
        scope="${input_scope:-$scope}"

        # Validar scope
        if [[ -z "${VALID_SCOPES[$scope]:-}" ]]; then
            devorq::warn "Scope '$scope' não válido — usando 'core'"
            scope="core"
        fi
    fi

    # 2. Tipo (convencional)
    if [[ -z "$initial_type" ]]; then
        echo -n "Tipo [$type] (feat/fix/refactor/docs/test/style/perf/chore): "
        local input_type
        read -r input_type
        type="${input_type:-$type}"

        # Validar tipo
        if [[ -z "${VALID_TYPES[$type]:-}" ]]; then
            devorq::warn "Tipo '$type' não válido — usando 'feat'"
            type="feat"
        fi
    fi

    # 3. Description (título da mudança)
    if [[ -z "$title" ]]; then
        echo -n "Descrição: "
        read -r title
    else
        echo -n "Descrição [$title]: "
        local input_desc
        read -r input_desc
        title="${input_desc:-$title}"
    fi

    if [[ -z "$title" ]]; then
        devorq::error "Descrição é obrigatória"
        return 1
    fi

    # 4. Detail (opcional)
    echo -n "Detalhamento (opcional): "
    read -r detail

    # 5. Montar mensagem final
    local final_message
    if [[ -n "$detail" ]]; then
        final_message="${type}(${scope}): ${title} (${detail})"
    else
        final_message="${type}(${scope}): ${title}"
    fi

    echo ""
    echo "═══════════════════════════════════════"
    echo "  Preview do Commit:"
    echo "═══════════════════════════════════════"
    echo ""
    echo "  $final_message"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        devorq::info "Dry-run — nenhum commit foi feito"
        return 0
    fi

    # 6. Confirmar
    echo -n "Confirmar commit? [Y/n]: "
    local confirm
    read -r confirm
    confirm="${confirm:-Y}"

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        devorq::info "Commit cancelado"
        return 0
    fi

    # 7. Executar git add + commit
    devorq::info "Executando commit..."

    if devorq::commit::guard_secrets "$project_root" && git -C "$project_root" add -A; then
        if git -C "$project_root" commit -m "$final_message"; then
            devorq::success "Commit: $final_message"

            # 8. Push se solicitado
            if [[ "$do_push" == "true" ]]; then
                devorq::info "Push para origin..."
                if git -C "$project_root" push origin HEAD 2>&1; then
                    devorq::success "Push: origin/$(git -C "$project_root" rev-parse --abbrev-ref HEAD)"
                else
                    devorq::warn "Push falhou — verifique token ou conexão"
                fi
            fi

            return 0
        else
            devorq::error "Commit falhou"
            return 1
        fi
    else
        devorq::error "git add -A falhou"
        return 1
    fi
}

# ============================================================
# devorq::commit::direct
# Commit direto com mensagem customizada
# ============================================================
devorq::commit::direct() {
    local project_root="$1"
    local message="$2"
    local do_push="$3"
    local dry_run="$4"

    echo ""
    devorq::info "═══ Commit ═══"
    echo "  $message"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        devorq::info "Dry-run — nenhum commit foi feito"
        return 0
    fi

    # Confirmar
    echo -n "Confirmar? [Y/n]: "
    local confirm
    read -r confirm
    confirm="${confirm:-Y}"

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        devorq::info "Commit cancelado"
        return 0
    fi

    if devorq::commit::guard_secrets "$project_root" && git -C "$project_root" add -A; then
        if git -C "$project_root" commit -m "$message"; then
            devorq::success "Commit OK"

            if [[ "$do_push" == "true" ]]; then
                git -C "$project_root" push origin HEAD 2>&1 && \
                    devorq::success "Push OK" || \
                    devorq::warn "Push falhou"
            fi

            return 0
        fi
    fi

    devorq::error "Commit falhou"
    return 1
}

# ============================================================
# devorq::commit::from_story
# Gera commit a partir de uma story (usado por devorq auto)
# ============================================================
devorq::commit::from_story() {
    local project_root="$1"
    local story_id="$2"

    local story_json
    story_json="$(devorq::auto::get_story "$project_root" "$story_id")"

    if [[ -z "$story_json" || "$story_json" == "null" ]]; then
        return 1
    fi

    local title description
    title=$(echo "$story_json" | jq -r '.title // ""' 2>/dev/null)
    description=$(echo "$story_json" | jq -r '.description // ""' 2>/dev/null)

    local scope
    scope="$(devorq::verify::detect_scope "$project_root")"

    local message="feat(${scope}): ${title}"
    if [[ -n "$description" ]]; then
        message="${message} (${description})"
    fi

    devorq::info "Commit sugerido: $message"
    echo -n "Confirmar? [Y/n]: "
    local confirm
    read -r confirm
    confirm="${confirm:-Y}"

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        devorq::commit::guard_secrets "$project_root" || return 1
        git -C "$project_root" add -A
        git -C "$project_root" commit -m "$message" && \
            devorq::success "Commit OK" || \
            devorq::error "Commit falhou"
    fi
}

# ============================================================
# devorq::cmd_commit
# Comando principal — registrado em bin/devorq
# ============================================================
devorq::cmd_commit() {
    devorq::commit::run "$@"
}

# Help standalone
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

devorq::commit::usage