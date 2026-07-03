#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/gates.sh — DEVORQ 7 Gates
#
# GATE-1 (BLOQUEANTE): Spec Exists       — SPEC.md existe e não está vazio
# GATE-2 (BLOQUEANTE): Tests Pass        — devorq test passa (testa estrutura)
# GATE-3 (BLOQUEANTE): Context Documented— devorq context mostra estado atual
# GATE-4 (BLOQUEANTE): Lessons Reviewed  — devorq lessons search encontrou lições relevantes
# GATE-5 (BLOQUEANTE): Handoff Ready     — devorq compact gera JSON válido
# GATE-6 (Aviso):      Context7 Checked  — Docs consultadas (mesmo que rejeite)
# GATE-7 (Pipeline):   Systematic Debugging — Se erro: devorq debug antes de continuar

set -euo pipefail

# Sequencia canonica de gates do pipeline completo (devorq flow). Fonte unica
# consumida por cmd_flow e self-build, evitando divergencia/mensagens enganosas. DQ-028
: "${DEVORQ_GATE_SEQUENCE:=0 0.5 1 2 3 4 5 6 7}"
export DEVORQ_GATE_SEQUENCE

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

DEVORQ_ALLOW_DRAFT="${DEVORQ_ALLOW_DRAFT:-false}"

# Validar DEVORQ_ROOT ao carregar
if [ -z "${DEVORQ_ROOT:-}" ] || [ ! -d "$DEVORQ_ROOT" ]; then
    echo "[WARN] DEVORQ_ROOT não definido ou inválido: ${DEVORQ_ROOT:-undefined}" >&2
fi

# ============================================================
# helpers
# ============================================================

gate::pass() {
    echo -e "${GREEN}[PASS]${RESET} GATE-${1}: $*"
}

gate::fail() {
    echo -e "${RED}[FAIL]${RESET} GATE-${1}: $*"
}

gate::warn() {
    echo -e "${YELLOW}[WARN]${RESET} GATE-${1}: $*"
}

gate::info() {
    echo -e "${CYAN}[INFO]${RESET} GATE-${1}: $*"
}

# ============================================================
# GATE-0 — DDD Domain Exploration + env-context (OPCIONAL, pre-GATE-1)
# ============================================================

gate_0() {
    gate::info 0 "Domain Exploration + Environment Context"

    local intent="${DEVORQ_INTENT:-}"
    if [ -z "$intent" ]; then
        local ctx_file="${PWD}/.devorq/state/context.json"
        if [ -f "$ctx_file" ] && command -v jq &>/dev/null; then
            intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
        fi
    fi

    local env_context_run=false

    # Sempre executa env-context (primeira mensagem da sessão)
    local env_detect="${DEVORQ_ROOT}/skills/env-context/scripts/env-detect.sh"
    if [ -f "$env_detect" ]; then
        local env_output
        if env_output=$(bash "$env_detect" 2>/dev/null); then
            gate::info 0 "Environment detected:"
            echo "$env_output" | head -15
            env_context_run=true
        fi
    else
        gate::warn 0 "env-detect.sh não encontrado — skipping env-context"
    fi

    # DDD Domain Exploration — só se keywords detectadas
    if echo "$intent" | grep -qiE "domínio|ddd|modelagem|entidade|contexto|bounded|invariante"; then
        gate::info 0 "DDD keywords detectadas no intent"

        local ddd_validate="${DEVORQ_ROOT}/skills/ddd-deep-domain/scripts/ddd-validate-spec.sh"
        if [ ! -f "$ddd_validate" ]; then
            gate::warn 0 "ddd-validate-spec.sh não encontrado"
            return 0
        fi

        if bash "$ddd_validate" 2>/dev/null; then
            gate::pass 0 "DDD: SPEC.md tem modelo mental válido"
        else
            gate::fail 0 "DDD: SPEC.md parece CRUD sem modelo de domínio"
            gate::info 0 "Sugestão: devorq ddd explore"
            return 1
        fi
    else
        gate::info 0 "DDD não detectado — skip"
    fi

    # ============================================================
    # GATE-0 — grill-with-docs (OPCIONAL, pós DDD)
    # Não-bloqueante com BREAK/warn forte
    # Executado pelo agente (não bloqueia fluxo do devorq flow)
    # ============================================================

    if ! echo "$intent" | grep -qiE "bug|fix|corrigir|typo|erro|hotfix|debug|init|lessons|compact|sync|version|stats|test"; then
        if echo "$intent" | grep -qiE "implementar|criar|adicionar|feature|novo|domínio"; then
            local grill_script="${DEVORQ_ROOT}/skills/grill-with-docs/scripts/grill-detect.sh"
            if [ -f "$grill_script" ]; then
                gate::info 0 "grill-with-docs: verificando contexto..."
                bash "$grill_script" "${PWD}" "$intent" 2>&1 || true
            else
                gate::warn 0 "grill-detect.sh não encontrado — skipping grill-with-docs"
            fi
        fi
    fi

    gate::pass 0 "GATE-0 completo (env-context: ${env_context_run})"
    return 0
}

# ============================================================
# GATE-0.5 — Project Foundation (BLOQUEANTE)
# ============================================================

gate_0_5() {
    gate::info 0.5 "Project Foundation — 5W2H, Premissas, Riscos, Requisitos, Restrições"

    local foundation_dir="${PWD}/.devorq/state"
    local foundation_script="${DEVORQ_ROOT}/skills/project-foundation/scripts/foundation-validate.sh"

    if [ ! -f "$foundation_script" ]; then
        gate::warn 0.5 "project-foundation não instalado — instalando templates"
        local init_script="${DEVORQ_ROOT}/skills/project-foundation/scripts/foundation-init.sh"
        if [ -f "$init_script" ]; then
            bash "$init_script" "$foundation_dir" "$(basename "$(pwd)")" 2>/dev/null || true
        fi
        gate::warn 0.5 "Foundation docs criados — execute novamente"
        return 1
    fi

    # Executa validation script — ele já printa [PASS]/[FAIL] por doc e o que fazer em caso de falha
    bash "$foundation_script" "$foundation_dir" 2>&1 || return 1

    gate::pass 0.5 "Project Foundation — todos os 5 docs válidos"
    return 0
}

# ============================================================
# GATE-1 — Spec Exists (BLOQUEANTE)
# ============================================================

gate_1() {
    gate::info 1 "Spec Exists — SPEC.md existe e não está vazio"

    local spec_file="${PWD}/SPEC.md"

    if [ ! -f "$spec_file" ]; then
        if [ "$DEVORQ_ALLOW_DRAFT" = "true" ]; then
            gate::warn 1 "SPEC.md não encontrado — ALLOW_DRAFT ativo"
            return 0
        fi
        gate::fail 1 "SPEC.md não encontrado"
        return 1
    fi

    local size
    size=$(wc -c < "$spec_file")
    if [ "$size" -lt 100 ]; then
        gate::fail 1 "SPEC.md está vazio ou incompleto"
        return 1
    fi

    gate::pass 1 "SPEC.md existe e tem conteúdo"
}

# ============================================================
# GATE-2 — Tests Pass (BLOQUEANTE)
# ============================================================

gate_2() {
    gate::info 2 "Tests Pass — devorq test passa"

    local has_tests=false
    local test_errors=0
    local test_cmd=""

    if [ -d "tests" ] || [ -f "phpunit.xml" ] || [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "bin/devorq" ] || [ -f "Makefile" ]; then
        has_tests=true
    fi

    if [ -f "composer.json" ] && [ -d "tests" ]; then
        if [ -f "vendor/bin/pest" ]; then
            test_cmd="vendor/bin/pest --compact"
            gate::info 2 "Runner detectado: Pest"
        elif [ -f "vendor/bin/phpunit" ]; then
            test_cmd="vendor/bin/phpunit --no-coverage"
            gate::info 2 "Runner detectado: PHPUnit"
        elif [ -f "artisan" ]; then
            test_cmd="php artisan test --compact"
            gate::info 2 "Runner detectado: artisan test"
        fi

        if [ -n "$test_cmd" ] && command -v php &>/dev/null; then
            $test_cmd 2>/dev/null
            local rv=$?
            if [ $rv -ne 0 ]; then
                gate::warn 2 "Testes falharam (exit code: $rv)"
                test_errors=$((test_errors+1))
            fi
        elif [ "${DEVORQ_ALLOW_NO_RUNNER:-0}" != "1" ]; then
            # fail-closed: PHP com tests/ mas runner ausente/nao-executavel
            gate::warn 2 "PHP com tests/ mas sem runner executavel (pest/phpunit/artisan, php ou vendor/ faltando) — DEVORQ_ALLOW_NO_RUNNER=1 para ignorar"
            test_errors=$((test_errors+1))
        fi
    fi

    if [ -f "pytest.ini" ] || { [ -f "pyproject.toml" ] && [ -d "tests" ]; }; then
        if [ -d "tests" ] && command -v pytest &>/dev/null; then
            pytest -q 2>/dev/null || {
                gate::warn 2 "pytest falhou"
                test_errors=$((test_errors+1))
            }
        elif [ "${DEVORQ_ALLOW_NO_RUNNER:-0}" != "1" ]; then
            # fail-closed: testes Python declarados mas pytest ausente
            gate::warn 2 "pytest.ini/pyproject+tests presentes mas pytest nao instalado — DEVORQ_ALLOW_NO_RUNNER=1 para ignorar"
            test_errors=$((test_errors+1))
        fi
    fi

    # Node/JS: package.json com script "test" (fail-closed se npm ausente)
    if [ -f "package.json" ]; then
        local has_test_script=false
        if command -v jq &>/dev/null; then
            jq -e '.scripts.test // empty' package.json &>/dev/null && has_test_script=true
        elif grep -qE '"test"[[:space:]]*:' package.json; then
            has_test_script=true
        fi
        if [ "$has_test_script" = "true" ]; then
            has_tests=true
            if command -v npm &>/dev/null; then
                npm test --silent 2>/dev/null || {
                    gate::warn 2 "npm test falhou"
                    test_errors=$((test_errors+1))
                }
            elif [ "${DEVORQ_ALLOW_NO_RUNNER:-0}" != "1" ]; then
                gate::warn 2 "package.json tem script test mas npm nao instalado — DEVORQ_ALLOW_NO_RUNNER=1 para ignorar"
                test_errors=$((test_errors+1))
            fi
        fi
    fi

    if [ -f "bin/devorq" ] || [ -f "Makefile" ]; then
        if command -v shellcheck &>/dev/null; then
            local sc_files=("bin/devorq")
            # Validar globs antes de passar para shellcheck
            shopt -s nullglob
            for f in lib/*.sh scripts/*.sh; do
                [ -f "$f" ] && sc_files+=("$f")
            done
            shopt -u nullglob
            if [ ${#sc_files[@]} -gt 1 ]; then
                local sc_errors
                sc_errors=$(shellcheck -S error "${sc_files[@]}" 2>/dev/null | grep -c "SC[12]" || true)
                if [ "$sc_errors" -gt 0 ]; then
                    gate::warn 2 "shellcheck: $sc_errors erro(s) de sintaxe"
                    test_errors=$((test_errors + sc_errors))
                fi
            fi
        fi
    fi

    if [ "$has_tests" = "false" ]; then
        gate::warn 2 "Nenhum framework de teste detectado (OK para CLI/bash puro)"
    fi

    if [ $test_errors -eq 0 ]; then
        gate::pass 2 "Tests Pass OK"
        return 0
    else
        gate::fail 2 "$test_errors problema(s) encontrado(s)"
        return 1
    fi
}

# ============================================================
# GATE-3 — Context Documented (BLOQUEANTE)
# ============================================================

gate_3() {
    gate::info 3 "Context Documented — devorq context mostra estado atual"

    if ! source "${DEVORQ_LIB}/context.sh" 2>/dev/null; then
        gate::warn 3 "lib/context.sh não disponível — algumas funcionalidades podem não funcionar"
    fi

    local ctx_file="${PWD}/.devorq/state/context.json"

    # Se não existe, criar com project/stack básico
    if [ ! -f "$ctx_file" ]; then
        if declare -f ctx_set &>/dev/null; then
            gate::warn 3 "context.json não existe — criando automaticamente"
            ctx_set "project" "${PWD##*/}" >/dev/null 2>&1
            ctx_set "stack" "[]" >/dev/null 2>&1
            ctx_set "intent" "" >/dev/null 2>&1
        else
            gate::fail 3 "lib/context.sh não disponível"
            return 1
        fi
    fi

    # Verificar conteúdo mínimo
    if declare -f ctx_lint &>/dev/null; then
        if ! ctx_lint >/dev/null 2>&1; then
            gate::warn 3 "context.json com problemas (campos ausentes)"
        fi
    else
        gate::warn 3 "ctx_lint não disponível — pulando validação de contexto"
    fi

    # Mostrar contexto atual
    if [ -f "$ctx_file" ]; then
        gate::pass 3 "Context Documented"
        if command -v jq &>/dev/null; then
            local intent project
            intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
            project=$(jq -r '.project // ""' "$ctx_file" 2>/dev/null || echo "")
            gate::info 3 "project=$project intent=${intent:0:60}..."
        fi
        return 0
    fi

    gate::fail 3 "context.json não pôde ser criado"
    return 1
}

# ============================================================
# GATE-4 — Lessons Reviewed (NÃO BLOQUEANTE)
# ============================================================

gate_4() {
    gate::info 4 "Lessons Reviewed — devorq lessons search encontrou lições relevantes"

    if ! source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null; then
        gate::warn 4 "lib/lessons.sh não disponível — lições não serão verificadas"
    fi

    local lessons_dir="${PWD}/.devorq/state/lessons/captured"
    local found=0

    if [ -d "$lessons_dir" ]; then
        found=$(find "$lessons_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        found=${found:-0}
    fi

    if [ "$found" -gt 0 ]; then
        gate::pass 4 "Lessons Reviewed — $found lição(ões) capturada(s)"
        return 0
    fi

    # Sem lessons é OK — só um aviso (projetos novos)
    gate::warn 4 "Nenhuma lesson capturada ainda (OK para projetos novos)"
    return 0
}

# ============================================================
# GATE-5 — Handoff Ready (BLOQUEANTE)
# ============================================================

gate_5() {
    gate::info 5 "Handoff Ready — devorq compact gera JSON válido"

    if ! source "${DEVORQ_LIB}/compact.sh" 2>/dev/null; then
        gate::fail 5 "lib/compact.sh não disponível"
        return 1
    fi

    if ! declare -f compact::generate &>/dev/null; then
        gate::fail 5 "lib/compact.sh não disponível"
        return 1
    fi

    local handoff_file="${PWD}/.devorq/state/handoff.json"
    local tmp
    tmp=$(mktemp) || { gate::fail 5 "Falha ao criar temp file"; return 1; }
    trap "rm -f '$tmp'" EXIT

    # Gerar handoff e validar JSON
    if compact::generate "$tmp" >/dev/null 2>&1; then
        if command -v jq &>/dev/null; then
            if jq empty "$tmp" 2>/dev/null; then
                # JSON válido — mover para localização real (atômico no mesmo FS)
                mkdir -p "$(dirname "$handoff_file")"
                mv "$tmp" "$handoff_file"
                trap - EXIT
                gate::pass 5 "Handoff Ready — JSON válido gerado"
                return 0
            else
                gate::fail 5 "JSON gerado é inválido"
                rm -f "$tmp"
                trap - EXIT
                return 1
            fi
        else
            # Sem jq, confiar na saída
            mv "$tmp" "$handoff_file"
            trap - EXIT
            gate::pass 5 "Handoff Ready (jq não disponível, validação manual)"
            return 0
        fi
    fi

    gate::fail 5 "devorq compact falhou"
    rm -f "$tmp"
    return 1
}

# ============================================================
# GATE-5.5 — UNIFY Check (NÃO BLOQUEANTE)
# ============================================================

gate_5_5() {
    gate::info 5.5 "UNIFY — fase de fechamento"

    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ ! -f "$ctx_file" ]; then
        gate::warn 5.5 "context.json não existe — pulando UNIFY check"
        return 0
    fi

    if command -v jq &>/dev/null; then
        local unify_done
        unify_done=$(jq -r '.unify_done // false' "$ctx_file" 2>/dev/null || echo "false")

        if [ "$unify_done" != "true" ]; then
            gate::warn 5.5 "UNIFY ainda não executado nesta sessão"
            gate::info 5.5 "Execute: devorq unify [feature]"
            gate::info 5.5 "Ou inclua --unify no devorq flow para executar automaticamente"
        else
            local unify_file
            unify_file=$(jq -r '.unify_file // "unknown"' "$ctx_file" 2>/dev/null || echo "unknown")
            gate::pass 5.5 "UNIFY executado: $unify_file"
        fi
    fi

    return 0  # Sempre passa — não bloqueante
}

# ============================================================
# GATE-6 — Context7 Checked (Aviso)
# ============================================================

gate_6() {
    gate::info 6 "Context7 Checked — Docs consultadas (mesmo que rejeite)"

    if [ -f "${DEVORQ_LIB}/context7.sh" ]; then
        source "${DEVORQ_LIB}/context7.sh" 2>/dev/null || true
        if declare -f ctx7_check &>/dev/null; then
            # Captura output e exit code — set -e não pode interferir
            local ctx7_output rv
            set +e
            ctx7_output=$(ctx7_check 2>&1)
            rv=$?
            set -e
            # Imprime output da ctx7_check
            [ -n "$ctx7_output" ] && echo "$ctx7_output"
            if [ $rv -eq 0 ]; then
                gate::pass 6 "Context7 Checked"
            else
                gate::warn 6 "Context7 não configurado (sem API key ou API offline)"
            fi
            return 0
        fi
    fi

    gate::warn 6 "Context7 não configurado (lib não encontrada)"
    return 0
}

# ============================================================
# GATE-7 — Systematic Debugging (Pipeline)
# ============================================================

gate_7() {
    gate::info 7 "Systematic Debugging — workflow de debug sistemático"

    # Carregar lib de debug se existir (Fase 5)
    if [ -f "${DEVORQ_LIB}/debug.sh" ]; then
        source "${DEVORQ_LIB}/debug.sh" 2>/dev/null || true
        if declare -f debug::check &>/dev/null; then
            debug::check
            return $?
        fi
    fi

    gate::pass 7 "Systematic Debugging OK (lib/debug.sh não presente — Fase 5)"
    return 0
}

# ============================================================
# GATE-E2E — Playwright E2E tests (story-001 e2e revival)
# Nao-bloqueante aqui. Reporta status, mas retorna 0 sempre.
# Promocao a required check em andamento via .github/workflows/e2e.yml
# apos estabilidade observada (E2E 77/77 deterministico).
# ============================================================

gate_e2e() {
    gate::info E2E "E2E Tests (Playwright) — story-001 baseline"

    local e2e_dir="${DEVORQ_ROOT}/e2e-tests"

    if [ ! -d "$e2e_dir" ]; then
        gate::warn E2E "e2e-tests/ nao encontrado em $e2e_dir"
        return 0
    fi

    if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
        gate::warn E2E "node/npx nao disponivel (gate nao verificado)"
        return 0
    fi

    # Instala deps sob demanda (rapido se ja cacheado)
    if [ ! -d "$e2e_dir/node_modules" ]; then
        gate::info E2E "Instalando dependencias E2E (primeira execucao)..."
        (cd "$e2e_dir" && npm install --no-fund --no-audit --silent) >/dev/null 2>&1 || {
            gate::warn E2E "npm install falhou em e2e-tests/"
            return 0
        }
    fi

    # Roda a suite (com timeout de 5 min)
    local e2e_output
    e2e_output=$(cd "$e2e_dir" && unset NODE_OPTIONS && timeout 300 npx playwright test --reporter=line 2>&1) || true

    local e2e_passed e2e_failed e2e_total
    e2e_passed=$(echo "$e2e_output" | grep -oE "[0-9]+ passed" | head -1 | grep -oE "[0-9]+" || echo "0")
    e2e_failed=$(echo "$e2e_output" | grep -oE "[0-9]+ failed" | head -1 | grep -oE "[0-9]+" || echo "0")
    e2e_total=$(( ${e2e_passed:-0} + ${e2e_failed:-0} ))

    if [ "$e2e_failed" -eq 0 ] && [ "$e2e_passed" -gt 0 ]; then
        gate::pass E2E "Playwright ${e2e_passed}/${e2e_total} passed (baseline 2026-06-04)"
    elif [ "$e2e_total" -eq 0 ]; then
        gate::warn E2E "Suite nao executou — verifique logs em $e2e_dir/playwright-report"
    else
        # Nao bloqueante: imprime mas retorna 0
        gate::warn E2E "Playwright ${e2e_passed}/${e2e_total} passed (${e2e_failed} failed) — nao-bloqueante no dev"
    fi

    if [ -d "$e2e_dir/playwright-report" ]; then
        gate::info E2E "Relatorio HTML: $e2e_dir/playwright-report/index.html"
    fi

    return 0
}

# Alias numerico para consistencia com gate_0, gate_1, ... gate_7
# Uso: devorq gate e2e  →  gate_e2e
# Tambem acessivel como gate_8 (apos gate_7) — slot reservado para E2E
gate_8() {
    gate_e2e
}
