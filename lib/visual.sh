#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/visual.sh — DEVORQ Visual Verification
# Gate de verificação visual: Playwright E2E + manual
# Trigger: systematic-debugging quando teste falha (vermelho)

devorq::verify::usage() {
    cat <<'USAGE_EOF'
Uso: devorq verify [--playwright|--manual] [--story <id>]

Gate de verificação visual obrigatório antes do commit.
Executa Playwright E2E ou aguarda confirmação manual.

Flags:
  --playwright    Executa suite E2E do projeto
  --manual        Aguarda input do developer (Enter para confirmar)
  --story <id>    Verifica apenas a story específica do prd.json
  --skip-build    Pula devorq build (já executado)
  (nenhum)        Usa método padrão do projeto (Playwright se existir)

Exemplos:
  devorq verify                    # Usa método padrão
  devorq verify --playwright       # Força Playwright
  devorq verify --manual          # Modo manual
  devorq verify --story feat-001  # Story específica
USAGE_EOF
}

# ============================================================
# devorq::verify::run
# Executa verificação visual — Playwright ou manual
# Retorna: 0 = passou, 1 = falhou
# ============================================================
devorq::verify::run() {
    local method="${1:-auto}"
    local story_id="${2:-}"
    local skip_build="${3:-false}"

    local exit_code=0

    # 1. devorq build (gates 1-7) — sempre executa primeiro
    if [[ "$skip_build" != "true" ]]; then
        devorq::info "═══ Verificação Visual ═══"
        devorq::info "Executando devorq build (gates 1-7)..."
        echo ""

        if ! devorq build 2>&1; then
            devorq::error "devorq build falhou — gates não passaram"
            devorq::verify::trigger_debug "devorq build falhou (gates)"
            return 1
        fi

        echo ""
    fi

    # 2. Determinar método de verificação visual
    local visual_method="$method"
    if [[ "$method" == "auto" ]]; then
        visual_method="$(devorq::verify::detect_method)"
    fi

    # 3. Executar verificação visual
    case "$visual_method" in
        playwright)
            devorq::info "Verificação: Playwright E2E"
            if ! devorq::verify::playwright "$story_id"; then
                exit_code=1
            fi
            ;;
        manual)
            devorq::info "Verificação: Manual (aguardando confirmação)"
            if ! devorq::verify::manual "$story_id"; then
                exit_code=1
            fi
            ;;
        none)
            devorq::warn "Nenhum método de verificação visual configurado"
            devorq::info "Configure Playwright ou use --manual"
            return 0  # Não bloqueia se não há método
            ;;
        *)
            devorq::error "Método desconhecido: $visual_method"
            return 1
            ;;
    esac

    # 4. Se falhou — trigger systematic-debugging
    if [[ $exit_code -ne 0 ]]; then
        devorq::verify::trigger_debug "verificação visual falhou"
        return 1
    fi

    # 5. Se passou — mostrar hint de commit
    devorq::verify::show_commit_hint "$story_id"
    devorq::success "Verificação passou — faça commit manual"
    devorq::info "Dica: devorq commit --story $story_id"

    return 0
}

# ============================================================
# devorq::verify::detect_method
# Detecta método padrão: Playwright ou manual
# ============================================================
devorq::verify::detect_method() {
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    # Playwright: existe playwright.config.{ts,js,mjs} OU dir de testes e2e.
    # compgen -G expande o glob de verdade ([[ -f "...*" ]] testava nome literal).
    if compgen -G "${project_root}/playwright.config.*" >/dev/null 2>&1 \
       || [[ -d "$project_root/playwright_tests" ]] \
       || [[ -d "$project_root/e2e-tests" ]]; then
        echo "playwright"
        return
    fi

    # Fallback: manual
    echo "manual"
}

# ============================================================
# devorq::verify::playwright
# Executa suite Playwright E2E
# Retorna: 0 = passou, 1 = falhou
# ============================================================
devorq::verify::playwright() {
    local story_id="${1:-}"
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"
    local playwright_root=""
    local exit_code=0

    devorq::info "Executando Playwright E2E..."

    if compgen -G "${project_root}/playwright.config.*" >/dev/null 2>&1; then
        playwright_root="$project_root"
    elif compgen -G "${project_root}/e2e-tests/playwright.config.*" >/dev/null 2>&1 \
         || [[ -d "$project_root/e2e-tests" ]]; then
        playwright_root="$project_root/e2e-tests"
    elif [[ -d "$project_root/playwright_tests" ]]; then
        playwright_root="$project_root"
    fi

    # Verificar se Playwright está configurado
    if [[ -z "$playwright_root" ]]; then
        devorq::warn "Playwright não encontrado em $project_root"
        devorq::info "Fazendo fallback para verificação manual..."
        devorq::verify::manual "$story_id"
        return $?
    fi

    # Mudar para o diretório que contém a configuração Playwright.
    cd "$playwright_root" || return 1
    devorq::info "Diretório Playwright: $playwright_root"

    # Verificar se container Docker está rodando (para Sail)
    if devorq::verify::docker_is_running; then
        devorq::info "Container Docker detectado — usando Sail"
        local container_name
        container_name="$(devorq::verify::detect_container)"

        if [[ -n "$container_name" ]]; then
            devorq::info "Container: $container_name"
            # Executar Playwright dentro do container ou via Sail
            if command -v vendor/bin/sail &>/dev/null; then
                if PLAYWRIGHT_HTML_OPEN=never vendor/bin/sail exec "$container_name" npx playwright test 2>&1; then
                    devorq::success "Playwright: todos os testes passaram"
                    return 0
                else
                    devorq::fail "Playwright: testes falharam"
                    exit_code=1
                fi
            else
                # Executar localmente (sem Sail)
                if PLAYWRIGHT_HTML_OPEN=never npx playwright test 2>&1; then
                    devorq::success "Playwright: todos os testes passaram"
                    return 0
                else
                    devorq::fail "Playwright: testes falharam"
                    exit_code=1
                fi
            fi
        fi
    else
        # Sem Docker — executar localmente
        devorq::info "Executando Playwright localmente..."
        if PLAYWRIGHT_HTML_OPEN=never npx playwright test 2>&1; then
            devorq::success "Playwright: todos os testes passaram"
            return 0
        else
            devorq::fail "Playwright: testes falharam"
            exit_code=1
        fi
    fi

    return $exit_code
}

# ============================================================
# devorq::verify::manual
# Aguarda confirmação manual do developer
# Retorna: 0 = confirmado, 1 = cancelado
# ============================================================
devorq::verify::manual() {
    local story_id="${1:-}"
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    echo ""
    devorq::info "═══════════════════════════════════════"
    devorq::info "  VERIFICAÇÃO VISUAL MANUAL"
    devorq::info "═══════════════════════════════════════"
    echo ""

    if [[ -n "$story_id" ]]; then
        devorq::info "Story: $story_id"
    fi

    devorq::info "1. Abra a aplicação no browser (http://localhost:9070 ou similar)"
    devorq::info "2. Navegue até a tela da feature implementada"
    devorq::info "3. Verifique:"
    echo ""
    echo "  [ ] A tela abre sem erros (200 OK)"
    echo "  [ ] Os dados são exibidos corretamente"
    echo "  [ ] Não há erros no console do browser"
    echo "  [ ] A funcionalidade está operacional"
    echo ""

    local confirm="Y"
    if [[ -t 0 && "${DEVORQ_AUTO_YES:-0}" != "1" ]]; then
        echo -n "Confirmar que a verificação visual passou? [Y/n]: "
        read -r confirm
        confirm="${confirm:-Y}"
    else
        devorq::info "nao-interativo: assumindo verificacao visual confirmada (Y)"
    fi

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        devorq::success "Verificação manual confirmada"
        return 0
    else
        devorq::fail "Verificação manual cancelada"
        return 1
    fi
}

# ============================================================
# devorq::verify::trigger_debug
# Trigger systematic-debugging quando verificação falha
# ============================================================
devorq::verify::trigger_debug() {
    local failure_context="${1:-verificação falhou}"
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    # ponytail: banner em stderr, NAO usa devorq::error (que agora aborta sob set -e)
    {
        echo ""
        echo "[ERROR] ═══════════════════════════════════════"
        echo "[ERROR]   SYSTEMATIC DEBUGGING TRIGGERED"
        echo "[ERROR] ═══════════════════════════════════════"
        echo "[ERROR] Contexto: $failure_context"
        echo ""
    } >&2

    devorq::info "O fluxo systematic-debugging será iniciado automaticamente."
    devorq::info "Fases:"
    devorq::info "  1. Root Cause Investigation (identificar o problema)"
    devorq::info "  2. Pattern Analysis (encontrar padrões)"
    devorq::info "  3. Context7 Validation (validar contra docs oficiais)"
    devorq::info "  4. Implementation (correção + teste de regressão)"
    devorq::info "  5. Captura de lição (devorq lessons capture)"
    devorq::info "  6. Atualizar SPEC.md"
    echo ""

    # Chamar script de debug sistemático
    if [[ -f "${DEVORQ_ROOT}/scripts/debug-systematic.sh" ]]; then
        bash "${DEVORQ_ROOT}/scripts/debug-systematic.sh" "$failure_context" "$project_root"
    else
        devorq::warn "scripts/debug-systematic.sh não encontrado — executando inline"

        # Fallback: executar debug inline
        devorq::verify::debug_inline "$failure_context" "$project_root"
    fi

    echo ""
    devorq::info "Após correção, execute novamente:"
    devorq::info "  devorq verify --story <id>"
    echo ""
}

# ============================================================
# devorq::verify::debug_inline
# Debug sistemático inline (fallback)
# ============================================================
devorq::verify::debug_inline() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    echo ""
    devorq::info "═══ PHASE 1: Root Cause Investigation ═══"
    devorq::info "Coletando informações do erro..."

    # Detectar tipo de falha (CAT A/B/C/D)
    local failure_type
    failure_type="$(devorq::verify::classify_failure "$failure_context" "$project_root")"

    devorq::info "Tipo de falha: $failure_type"

    case "$failure_type" in
        "CAT A: E2E Cascade")
            devorq::info "Cascade failure — procurar página raiz do problema"
            ;;
        "CAT B: App Bug")
            devorq::info "Bug real na aplicação — investigar código"
            ;;
        "CAT C: Test Stale")
            devorq::info "Teste desatualizado — atualizar seletor"
            ;;
        "CAT D: Infra Issue")
            devorq::info "Problema de infraestrutura — verificar Docker/config"
            ;;
        *)
            devorq::warn "Tipo de falha não identificado"
            ;;
    esac

    echo ""
    devorq::info "═══ PHASE 2: Pattern Analysis ═══"
    devorq::info "Consulte ~/.hermes/skills/software-development/systematic-debugging/SKILL.md"
    devorq::info "para processo completo de debug sistemático."
    echo ""

    devorq::info "═══ PHASE 3: Context7 Validation ═══"
    devorq::info "Após identificar root cause, consultar docs oficiais via:"
    devorq::info "  mcp_context7_resolve_library_id(libraryName=\"laravel\")"
    devorq::info "  mcp_context7_query_docs(libraryId, query=problema)"
    echo ""

    devorq::info "═══ PRÓXIMOS PASSOS ═══"
    devorq::info "1. Investigue o erro seguindo systematic-debugging skill"
    devorq::info "2. Aplique correção validada com Context7"
    devorq::info "3. Crie teste de regressão"
    devorq::info "4. Execute: devorq verify --story <id> para re-verificar"
    devorq::info "5. Se passou: devorq commit --story <id>"
}

# ============================================================
# devorq::verify::classify_failure
# Classifica tipo de falha (CAT A/B/C/D)
# ============================================================
devorq::verify::classify_failure() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    # Lógica de classificação
    # CAT A: E2E cascade — página de erro cobre tudo
    # CAT B: App bug — teste correto, código errado
    # CAT C: Test stale — UI mudou, teste não atualizou
    # CAT D: Infra — auth, storage, network

    # Heurística simples baseada no contexto
    if [[ "$failure_context" =~ "playwright" ]]; then
        echo "CAT B: App Bug (Playwright detectou erro real)"
    elif [[ "$failure_context" =~ "build" ]]; then
        echo "CAT D: Infra Issue (gate falhou)"
    else
        echo "CAT B: App Bug (verificação falhou)"
    fi
}

# ============================================================
# devorq::verify::show_commit_hint
# Mostra hint de commit baseado na story
# ============================================================
devorq::verify::show_commit_hint() {
    local story_id="${1:-}"
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"

    if [[ -z "$story_id" ]]; then
        return 0
    fi

    # Ler story do prd.json
    local story_json
    story_json="$(devorq::auto::get_story "$project_root" "$story_id")"

    if [[ -z "$story_json" || "$story_json" == "null" ]]; then
        devorq::warn "Story $story_id não encontrada no prd.json"
        return 1
    fi

    local title description scope phase

    title=$(echo "$story_json" | jq -r '.title // ""' 2>/dev/null)
    description=$(echo "$story_json" | jq -r '.description // ""' 2>/dev/null)

    # Detectar scope e phase do path/categoria
    scope="$(devorq::verify::detect_scope "$project_root")"
    phase="impl"

    echo ""
    devorq::info "═══ Hint de Commit ═══"
    echo ""
    echo "  Formato: escopo(fase): descrição (detalhamento)"
    echo ""
    echo "  Sugestão:"
    echo "    feat($scope): $title"
    echo ""
    echo "  Complete com detalhamento (opcional):"
    echo "    feat($scope): $title (alteração específica)"
    echo ""
}

# ============================================================
# devorq::verify::detect_scope
# Detecta scope baseado no projeto
# ============================================================
devorq::verify::detect_scope() {
    local project_root="${1:-$PWD}"

    # Detectar pelo nome do projeto
    local project_name
    project_name="$(basename "$project_root")"

    case "$project_name" in
        clickup)
            echo "clickup"
            ;;
        events)
            echo "events"
            ;;
        *)
            echo "core"
            ;;
    esac
}

# ============================================================
# devorq::verify::docker_is_running
# Verifica se Docker está disponível
# ============================================================
devorq::verify::docker_is_running() {
    command -v docker &>/dev/null && docker info &>/dev/null
}

# ============================================================
# devorq::verify::detect_container
# Detecta nome do container Docker do projeto
# ============================================================
devorq::verify::detect_container() {
    local project_root="${DEVORQ_PROJECT_ROOT:-$PWD}"
    local project_name
    project_name="$(basename "$project_root")"

    # Tentar detectar pelo nome do projeto
    local container_candidates
    container_candidates=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "$project_name|_app" || true)

    if [[ -n "$container_candidates" ]]; then
        echo "$container_candidates" | head -1
        return
    fi

    echo ""
}

# ============================================================
# devorq::auto::get_story
# Obtém story do prd.json por ID
# ============================================================
devorq::auto::get_story() {
    local project="$1"
    local story_id="$2"

    if [[ ! -f "$project/prd.json" ]]; then
        echo "null"
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo "null"
        return
    fi

    echo "$(jq --arg id "$story_id" '.stories[] | select(.id == $id)' "$project/prd.json" 2>/dev/null)"
}

# ============================================================
# devorq::cmd_verify
# Comando principal — alias para devorq::verify::run
# ============================================================
devorq::cmd_verify() {
    local method="auto"
    local story_id=""
    local skip_build="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --playwright)
                method="playwright"
                shift
                ;;
            --manual)
                method="manual"
                shift
                ;;
            --story)
                story_id="$2"
                shift 2
                ;;
            --skip-build)
                skip_build="true"
                shift
                ;;
            --help|-h)
                devorq::verify::usage
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    devorq::verify::run "$method" "$story_id" "$skip_build"
}

# Help: devorq verify --help
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Arquivo foi sourceado — exposes functions
    return 0
fi

# Arquivo executado diretamente — mostra usage
devorq::verify::usage
