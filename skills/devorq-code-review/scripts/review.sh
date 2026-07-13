#!/usr/bin/env bash
#===============================================================
# devorq-code-review — review.sh v1.0.0
# Orquestrador principal da pipeline de 8 fases.
# Modelo-agnóstico: usa delegate_task (stack atual do Hermes).
#
# Usage:
#   review.sh <PROJECT_ROOT> [--branch <branch>] [--pr <number>]
#   review.sh --help
#
# Exit codes:
#   0  Review completo — report gerado
#   1  PR/branch nao elegivel (draft, closed, trivial)
#   2  Abortado pelo usuario
#   3  Nenhum diff para revisar
#   4  Erro de execucao
#===============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# Config
#-----------------------------------------------------------
REVIEW_TIMEOUT="${REVIEW_TIMEOUT:-300}"        # segundos por fase
PARALLEL_AGENTS="${PARALLEL_AGENTS:-3}"        # agentes simultaneos
CONFIDENCE_THRESHOLD=80                          # threshold minimo para reportar

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
review::usage() {
    cat <<EOF
Usage: review.sh <PROJECT_ROOT> [OPTIONS]

DEVORQ-CODE-REVIEW v1.0.0 — Pipeline de 8 fases.

OPTIONS:
  --branch <name>     Branch a revisar (default: HEAD)
  --pr <number>       Numero do PR (usa gh se disponivel)
  --base <branch>     Branch base (default: main)
  --json              Output JSON puro (para integracao)
  --quiet             Suprime logs de fase
  --help              Esta mensagem

EXAMPLES:
  review.sh . --branch minha-feature
  review.sh . --pr 42
  review.sh /projects/meu-projeto --base develop

EXIT CODES:
  0  Review completo — report no stdout
  1  Nao elegivel (draft/closed/trivial)
  2  Abortado
  3  Sem diff
  4  Erro de execucao
EOF
}

review::die() {
    echo "ERROR: $*" >&2
    exit "${1:-4}"
}

review::info()    { echo "[review] $*"; }
review::phase()  { echo ""; echo "━━━ [$1] $2 ━━━"; }
review::ok()     { echo "✅ $*"; }
review::warn()   { echo "⚠️  $*"; }
review::fail()   { echo "❌ $*"; }

#-----------------------------------------------------------
# Argument parsing
#-----------------------------------------------------------
parse_args() {
    PROJECT_ROOT=""
    BRANCH=""
    PR_NUMBER=""
    BASE_BRANCH="main"
    OUTPUT_JSON=false
    QUIET=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)    BRANCH="$2"; shift 2 ;;
            --pr)        PR_NUMBER="$2"; shift 2 ;;
            --base)      BASE_BRANCH="$2"; shift 2 ;;
            --json)      OUTPUT_JSON=true; shift ;;
            --quiet)     QUIET=true; shift ;;
            --help|-h)   review::usage; exit 0 ;;
            *)           PROJECT_ROOT="$1"; shift ;;
        esac
    done

    if [[ -z "$PROJECT_ROOT" ]]; then
        review::usage
        exit 1
    fi

    if [[ ! -d "$PROJECT_ROOT" ]]; then
        review::die 4 "Diretorio nao existe: $PROJECT_ROOT"
    fi
}

#-----------------------------------------------------------
# FASE 0: Eligibility Check
#-----------------------------------------------------------
phase0_eligibility() {
    review::phase "0/7" "Eligibility Check"

    # Detectar tipo de input (PR vs branch local)
    local is_pr=false
    local pr_state=""

    if [[ -n "$PR_NUMBER" ]]; then
        if command -v gh &>/dev/null && gh auth status &>/dev/null; then
            is_pr=true
            pr_state=$(gh pr view "$PR_NUMBER" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
        fi
    fi

    # Obter diff para analise
    local diff_stat
    diff_stat=$(git -C "$PROJECT_ROOT" diff "$BASE_BRANCH...${BRANCH:-HEAD}" --stat 2>/dev/null || echo "")

    if [[ -z "$diff_stat" || "$diff_stat" == *"0 files changed"* ]]; then
        review::die 3 "Nenhum diff encontrado — nada para revisar"
    fi

    # Extrair metricas
    local files_changed
    local lines_added
    local lines_deleted
    files_changed=$(echo "$diff_stat" | tail -1 | awk '{print $1}' || echo "1")
    lines_added=$(echo "$diff_stat" | tail -1 | grep -oP '\d+(?= insertion)' | head -1 || echo "0")
    lines_deleted=$(echo "$diff_stat" | tail -1 | grep -oP '\d+(?= deletion)' | head -1 || echo "0")

    # Analisar se e trivial
    local is_trivial=false
    if [[ "$files_changed" -le 2 ]] && [[ "$lines_added" -le 10 ]] && [[ "$lines_deleted" -le 10 ]]; then
        # Verificar se sao mudancas triviais (formato, typos, comments)
        local diff_content
        diff_content=$(git -C "$PROJECT_ROOT" diff "$BASE_BRANCH...${BRANCH:-HEAD}" 2>/dev/null)
        if echo "$diff_content" | grep -qE '^\+.*[^a-zA-Z0-9_]'; then
            #mostly formatting
            is_trivial=true
        fi
    fi

    # Verificar se e PR draft ou closed
    if [[ "$is_pr" == true ]]; then
        case "$pr_state" in
            CLOSED) review::warn "PR #${PR_NUMBER} esta fechada"; review::die 1 "PR fechada" ;;
            MERGED) review::warn "PR #${PR_NUMBER} ja foi mergeada"; review::die 1 "PR ja mergeada" ;;
            OPEN)   review::ok "PR #${PR_NUMBER} aberta — continuando" ;;
        esac
    fi

    if [[ "$is_trivial" == true ]]; then
        review::warn "Mudancas triviais detectadas (< 10 linhas, < 3 arquivos)"
        review::die 1 "Mudancas triviais — review dispensavel"
    fi

    # Output do diff summary
    DIFF_SUMMARY=$(git -C "$PROJECT_ROOT" diff "$BASE_BRANCH...${BRANCH:-HEAD}" --stat)
    DIFF_CONTENT=$(git -C "$PROJECT_ROOT" diff "$BASE_BRANCH...${BRANCH:-HEAD}")

    review::ok "Elegivel: $files_changed arquivos, +$lines_added/-$lines_deleted linhas"

    echo ""
    echo "📊 Scope: $files_changed files | +$lines_added | -$lines_deleted"
}

#-----------------------------------------------------------
# FASE 1: Context Collection
#-----------------------------------------------------------
phase1_context() {
    review::phase "1/7" "Context Collection"

    # Buscar arquivos de spec/guia
    local spec_files="[]"
    local claude_files="[]"

    # SPEC.md e similares
    while IFS= read -r f; do
        [[ -n "$f" ]] && spec_files=$(echo "$spec_files" | jq ". += [\"$f\"]")
    done < <(find "$PROJECT_ROOT" -maxdepth 3 -iname "spec.md" -o -iname "*.spec.md" 2>/dev/null | head -10)

    # CLAUDE.md e similares
    while IFS= read -r f; do
        [[ -n "$f" ]] && claude_files=$(echo "$claude_files" | jq ". += [\"$f\"]")
    done < <(find "$PROJECT_ROOT" -maxdepth 3 \( -iname "claude.md" -o -iname ".claude.md" \) 2>/dev/null | head -10)

    GUIDANCE_FILES=$(echo "{}" | jq \
        --argjson specs "$spec_files" \
        --argjson claude "$claude_files" \
        '{spec: $specs, claude: $claude}')

    review::ok "Guidance files encontrados"
    echo "$GUIDANCE_FILES" | jq -r '.spec, .claude' 2>/dev/null | grep -v "^\[" | head -10 || true
}

#-----------------------------------------------------------
# FASE 2: Parallel Review (5 agentes)
# Executado pelo agente via delegate_task — este script apenas
# registra que a fase foi iniciada.
# Dimensoes: SPEC/CLAUDE compliance | Bugs | Git history | PR history | Code comments
#-----------------------------------------------------------
phase2_review() {
    review::phase "2/7" "Parallel Review (5 agentes)"
    review::fail "Review indisponivel: nenhum reviewer executado com evidencia verificavel"
    review::die 4 "Review indisponivel — configure reviewers reais antes de emitir veredito"
}

#-----------------------------------------------------------
# FASE 3: Confidence Scoring
#-----------------------------------------------------------
phase3_scoring() {
    review::phase "3/7" "Confidence Scoring"

    review::info "Cada issue recebe score 0-100"
    review::info "Threshold: >= 80 para reportar"

    # Placeholder — scoring feito pelo agente via delegate_task
    SCORED_ISSUES='[]'
    CRITICAL_COUNT=0
    HIGH_COUNT=0
    FILTERED_COUNT=0
}

#-----------------------------------------------------------
# FASE 4: Filter
#-----------------------------------------------------------
phase4_filter() {
    review::phase "4/7" "Filter (threshold >= 80)"

    # Placeholder — filtragem feita pelo agente
    FILTERED_ISSUES='[]'
    CRITICAL_COUNT=0
    HIGH_COUNT=0
    FILTERED_COUNT=0
}

#-----------------------------------------------------------
# FASE 5: Systematic Debugging (se issues > 0)
#-----------------------------------------------------------
phase5_debug() {
    if [[ ${#FILTERED_ISSUES[@]} -eq 0 ]]; then
        review::phase "5/7" "Systematic Debugging"
        review::ok "Nenhuma issue para investigar"
        return 0
    fi

    review::phase "5/7" "Systematic Debugging"
    review::info "Investigando root cause de ${#FILTERED_ISSUES[@]} issues..."

    # Para cada issue, systematic-debugging entra em jogo
    # O agente que carregou a skill executa a investigacao

    echo ""
    echo "🔍 Para cada issue >= 80 confidence:"
    echo "   1. Reproduzir o problema"
    echo "   2. Rastrear data flow (upstream)"
    echo "   3. Identificar root cause"
    echo "   4. Reportar ANTES de propor fix"
    echo ""
    echo "[systematic-debugging skill integrada — ver SKILL.md]"
}

#-----------------------------------------------------------
# FASE 6: Approval Gate
#-----------------------------------------------------------
phase6_approval() {
    review::phase "6/7" "Manual Approval Gate"

    local total_issues=${#FILTERED_ISSUES[@]}

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "⛔  MANUAL APPROVAL REQUIRED"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "📋 Resumo: $total_issues issues (threshold: confidence >= 80)"
    echo ""

    if [[ "$total_issues" -gt 0 ]]; then
        echo "🔴 Issues identificadas:"
        for issue in "${FILTERED_ISSUES[@]}"; do
            local title score file line
            title=$(echo "$issue" | jq -r '.title // "unknown"')
            score=$(echo "$issue" | jq -r '.score // 0')
            file=$(echo "$issue" | jq -r '.file // "?"')
            line=$(echo "$issue" | jq -r '.line // "?"')
            echo "   [$score] $title ($file:$line)"
        done
    else
        echo "✅ Nenhuma issue acima do threshold"
    fi

    echo ""
    echo "AÇÕES DISPONÍVEIS:"
    echo "  [A] Tudo OK — prosseguir"
    echo "  [B] Corrigir issues (dispatch fix agent)"
    echo "  [C] Ver details de issue específica"
    echo "  [D] Ignorar issue X (aceitar risco)"
    echo "  [E] Abortar — nenhuma ação"
    echo ""
    echo "Escolha: " && read -r choice

    case "$choice" in
        A|a)   review::ok "Aprovado — prosseguindo";;
        B|b)   review::info "Dispatch fix agent — ver FASE 6 do SKILL.md";;
        C|c)   review::info "Details: issue detalhada no report completo";;
        D|d)   review::info "Ignorada — registrada no log";;
        E|e)   review::die 2 "Abortado pelo usuario";;
        *)     review::die 2 "Escolha invalida — approval nao concedida";;
    esac
}

#-----------------------------------------------------------
# FASE 7: Report
#-----------------------------------------------------------
phase7_report() {
    review::phase "7/7" "Report"

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local branch="${BRANCH:-HEAD}"
    local files_count
    files_count=$(echo "$DIFF_SUMMARY" | tail -1 | awk '{print $1}' || echo "?")

    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "🔍  CODE REVIEW REPORT — devorq-code-review v1.0.0"
    echo "═══════════════════════════════════════════════════════"
    echo "Date:    $timestamp"
    echo "Branch:  $branch → $BASE_BRANCH"
    echo "Files:   $files_count changed"
    echo ""
    echo "───────────────────────────────────────────────────────"
    echo "📋 SUMMARY"
    echo "───────────────────────────────────────────────────────"
    echo "Issues Found: ${#FILTERED_ISSUES[@]} (threshold: confidence >= 80)"
    echo "  🔴 Critical (90-100): $CRITICAL_COUNT"
    echo "  🟠 High (80-89):      $HIGH_COUNT"
    echo "  🟡 Filtered (<80):     $FILTERED_COUNT"
    echo ""

    if [[ ${#FILTERED_ISSUES[@]} -gt 0 ]]; then
        echo "───────────────────────────────────────────────────────"
        echo "🔴 ISSUES (sorted by confidence)"
        echo "───────────────────────────────────────────────────────"
        local idx=1
        for issue in "${FILTERED_ISSUES[@]}"; do
            local title score file line type description
            title=$(echo "$issue" | jq -r '.title // "unknown"')
            score=$(echo "$issue" | jq -r '.score // 0')
            file=$(echo "$issue" | jq -r '.file // "?"')
            line=$(echo "$issue" | jq -r '.line // "?"')
            type=$(echo "$issue" | jq -r '.type // "unknown"')
            description=$(echo "$issue" | jq -r '.description // .violation // "no description"')

            local badge="🟠"
            [[ "$score" -ge 90 ]] && badge="🔴"

            echo ""
            echo "$idx. [$badge] (confidence: $score/100)"
            echo "   Title: $title"
            echo "   File:  $file:$line"
            echo "   Type:  $type"
            echo "   Desc:  $description"
            idx=$((idx + 1))
        done
    else
        echo "───────────────────────────────────────────────────────"
        echo "✅ COMPLIANCE — No issues above threshold"
        echo "───────────────────────────────────────────────────────"
    fi

    echo ""
    echo "───────────────────────────────────────────────────────"
    echo "📊 ELIGIBILITY"
    echo "───────────────────────────────────────────────────────"
    echo "Status:  ELIGIBLE"
    echo "Scope:   $files_count files | +$lines_added/-$lines_deleted"

    echo ""
    echo "═══════════════════════════════════════════════════════"

    # Se JSON output foi pedido
    if [[ "$OUTPUT_JSON" == true ]]; then
        echo ""
        echo "--- JSON OUTPUT ---"
        echo '{}' | jq \
            --arg timestamp "$timestamp" \
            --arg branch "$branch" \
            --arg base "$BASE_BRANCH" \
            --argjson files "$files_count" \
            --argjson critical "$CRITICAL_COUNT" \
            --argjson high "$HIGH_COUNT" \
            --argjson filtered "$FILTERED_COUNT" \
            --argjson issues "$FILTERED_ISSUES" \
            '{
                timestamp: $timestamp,
                branch: $branch,
                base: $base,
                files: $files,
                summary: {
                    critical: $critical,
                    high: $high,
                    filtered: $filtered,
                    total: ($critical + $high)
                },
                issues: $issues,
                verdict: (if ($critical + $high) == 0 then "CLEAN" else "ISSUES_FOUND" end)
            }'
    fi
}

#-----------------------------------------------------------
# Main
#-----------------------------------------------------------
main() {
    parse_args "$@"

    cd "$PROJECT_ROOT"

    echo "devorq-code-review v1.0.0"
    echo "========================================"

    # Executar fases
    phase0_eligibility      # Exit 1 ou 3 se nao elegivel
    phase1_context
    phase2_review          # Placeholder — executado pelo agente
    phase3_scoring         # Placeholder — executado pelo agente
    phase4_filter          # Placeholder — executado pelo agente
    phase5_debug           # Se ha issues
    phase6_approval        # EXIT 2 se abortado
    phase7_report

    review::ok "Review completo"

    # Cleanup de branches temporarias (se eram de PR)
    # Nao mexe em nada do repo do usuario

    exit 0
}

main "$@"
