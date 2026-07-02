#!/usr/bin/env bash
#===========================================================
# devorq-auto — loop-auto.sh v1.2.0
# Loop principal Ralph-style: delegate -> verify -> commit
# Com:
#   - Fallback automatico execute_code
#   - Lessons aprendidas por projeto
#   - Log estruturado: failures.md + runs/*.log + pending/*.json
#===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# SOURCE: Carregar funções compartilhadas de lib/auto.sh
#-----------------------------------------------------------
# lib/auto.sh contém as funções core (next_story, pending_count, etc.)
# que são reutilizadas pelo loop-auto.sh. As definições no loop-auto.sh
# (abaixo) sobrescrevem as de lib/auto.sh quando necessário.
#-----------------------------------------------------------
if [[ -f "${SKILL_DIR}/../../lib/auto.sh" ]]; then
    source "${SKILL_DIR}/../../lib/auto.sh"
fi

#-----------------------------------------------------------
# Config
#-----------------------------------------------------------
DEVORQ_AUTO_VERSION="1.2.1"
FORCE_CONTINUE=false
CAPTURE_LESSONS=true
MAX_DELEGATE_RETRIES=1
_AUTO_PROJECT_ROOT=""   # capturado p/ trap EXIT (failures.md nunca se perde)
# Stop-criteria: apos N tentativas, a story e marcada 'failed' e excluida da
# selecao — impede loop infinito re-selecionando a mesma story falha (overnight).
DEVORQ_AUTO_MAX_STORY_FAILURES="${DEVORQ_AUTO_MAX_STORY_FAILURES:-2}"
declare -A _AUTO_STORY_ATTEMPTS=()

# can_prompt: so pergunta se ha terminal E o usuario nao pediu modo nao-interativo.
# Em run headless (cron, pipe, agente autonomo) os prompts assumem default seguro
# em vez de ler EOF e morrer/travar. DEVORQ_AUTO_YES=1 forca nao-interativo.
devorq_auto::can_prompt() { [[ -t 0 && "${DEVORQ_AUTO_YES:-0}" != "1" ]]; }

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
devorq_auto::usage() {
    cat <<EOF
Usage: loop-auto.sh <PROJECT_ROOT> [OPTIONS]

Loop Ralph-style: uma story por iteracao.
1. Seleciona story de maior priority com passes=false
2. delegate_task para sub-agente implementar
3. Fallback automatico para execute_code se delegate falhar
4. check-story.sh para verificar
5. git commit se passou
6. Atualiza prd.json + lessons + failures.md

Args:
  PROJECT_ROOT    Diretorio do projeto (obrigatorio)

Options:
  --iterations N    Numero de iters (default: 1)
  --all             Executar todas as pendentes
  --force-continue  Pula stories com erro e continua (nao pergunta)
  --no-learn        Nao captura licoes aprendidas
  -h, --help        Este help

Output files:
  progress.txt         Log append-only de cada iteracao
  .devorq-auto/
    failures.md       Sumario das falhas (human-readable, latest)
    lessons.json      Falhas estruturadas (máquina)
    runs/YYYY-MM-DD_HH-MM.log   Log completo do batch
    pending/*.json    Context de cada story que falhou
EOF
}

devorq_auto::die() {
    echo "ERROR: $*" >&2
    exit "${1:-1}"
}

devorq_auto::info()    { echo "[$(date +%H:%M)] $*"; }
devorq_auto::success() { echo "✅ $*"; }
devorq_auto::fail()    { echo "❌ $*"; }
devorq_auto::warn()    { echo "⚠️  $*"; }
devorq_auto::learn()  { echo "📚 $*"; }

#-----------------------------------------------------------
# Devorq-auto directory structure
#-----------------------------------------------------------
DEVORQ_AUTO_DIR=""
RUN_LOG_FILE=""

devorq_auto::setup_dirs() {
    local project="$1"
    DEVORQ_AUTO_DIR="$project/.devorq-auto"
    mkdir -p "$DEVORQ_AUTO_DIR/pending" "$DEVORQ_AUTO_DIR/runs"

    # Create run log for this execution
    RUN_LOG_FILE="$DEVORQ_AUTO_DIR/runs/$(date +%Y-%m-%d_%H-%M).log"
}

#-----------------------------------------------------------
# Log to run file
#-----------------------------------------------------------
devorq_auto::log() {
    local msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" >> "$RUN_LOG_FILE"
    echo "$msg"
}

#-----------------------------------------------------------
# Lessons — persistencia de licoes aprendidas por projeto
#-----------------------------------------------------------
LESSONS_FILE=""

devorq_auto::lessons_init() {
    local project="$1"
    LESSONS_FILE="$project/.devorq-auto/lessons.json"

    if [[ ! -f "$LESSONS_FILE" ]]; then
        cat > "$LESSONS_FILE" <<'LESSONSEOF'
{
  "project": "",
  "created": "",
  "lessons": [],
  "stats": { "total": 0, "delegate_failed": 0, "verification_failed": 0, "complex_detected": 0 }
}
LESSONSEOF
        python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['project']=sys.argv[2]; d['created']=sys.argv[3]; json.dump(d,open(sys.argv[1],'w'),indent=2)" "$LESSONS_FILE" "$(basename "$project")" "$(date -Iseconds)"
    fi
}

devorq_auto::lessons_capture() {
    local project="$1"
    local story_id="$2"
    local story_title="$3"
    local failure_type="$4"  # "delegate" | "verification" | "complex" | "success"
    local details="${5:-}"

    [[ "$CAPTURE_LESSONS" != "true" ]] && return 0

    local tmp
    tmp=$(mktemp)

    python3 -c "
import json, sys
from datetime import datetime

with open(sys.argv[5]) as f:
    data = json.load(f)

lesson = {
    'story_id': sys.argv[1],
    'story_title': sys.argv[2],
    'type': sys.argv[3],
    'details': sys.argv[4],
    'timestamp': datetime.now().isoformat()
}

data['lessons'].append(lesson)
data['stats']['total'] += 1

ftype = sys.argv[3]
if ftype == 'delegate':
    data['stats']['delegate_failed'] += 1
elif ftype == 'verification':
    data['stats']['verification_failed'] += 1
elif ftype == 'complex':
    data['stats']['complex_detected'] += 1

with open(sys.argv[6], 'w') as f:
    json.dump(data, f, indent=2)
" "$story_id" "$story_title" "$failure_type" "$details" "$LESSONS_FILE" "$tmp"
    mv "$tmp" "$LESSONS_FILE"
}

devorq_auto::lessons_suggest() {
    local project="$1"
    local story_title="$2"

    [[ ! -f "$LESSONS_FILE" ]] && return 0

    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)

target = sys.argv[2].lower()
similar = [l for l in data['lessons'] if l['type'] in ('delegate', 'complex') and l['story_title'].lower() in target]
if similar:
    print()
    print('📚 Licao anterior relevante:')
    for l in similar[-2:]:
        print('  -> ' + l['story_id'] + ': ' + str(l.get('details', '')))
" "$LESSONS_FILE" "$story_title" 2>/dev/null || true
}

#-----------------------------------------------------------
# FAILURES.MD — Gerar sumario human-readable das falhas
#-----------------------------------------------------------
devorq_auto::failures_generate() {
    local project="$1"

    [[ ! -f "$LESSONS_FILE" ]] && return 0

    local failures_md="$DEVORQ_AUTO_DIR/failures.md"
    local total pending done

    total=$(devorq_auto::total_count "$project")
    pending=$(devorq_auto::pending_count "$project")
    done=$(devorq_auto::completed_count "$project")
    local progress_line="Progresso: ${done}/${total} done, ${pending} pending"

    PROJECT_ROOT="$project" \
    LESSONS_FILE="$LESSONS_FILE" \
    PROGRESS_LINE="$progress_line" \
    FAILURES_MD="$failures_md" \
    python3 << PYEOF
import json, sys, os
from datetime import datetime

project_name = os.path.basename(os.environ['PROJECT_ROOT'])
lessons_path = os.environ['LESSONS_FILE']
progress_line = os.environ['PROGRESS_LINE']
failures_md = os.environ['FAILURES_MD']

with open(lessons_path) as f:
    data = json.load(f)

failed = [l for l in data['lessons'] if l['type'] in ('delegate', 'verification', 'complex')]
failed.reverse()  # Most recent first

type_icon = {
    'delegate': '❌',
    'verification': '❌',
    'complex': '⚠️'
}

type_action = {
    'delegate': 'delegate_task falhou apos retries',
    'verification': 'check-story.sh failed',
    'complex': 'Story complexa detectada'
}

lines = []
lines.append(f'# DEVORQ-AUTO Failures — {project_name}')
lines.append(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")}')
lines.append('')
lines.append(f'## {len(failed)} Stories Pendentes de Correção')
lines.append('')

for l in failed:
    icon = type_icon.get(l['type'], '❌')
    action = type_action.get(l['type'], l['type'])
    dt = datetime.fromisoformat(l['timestamp']).strftime('%Y-%m-%d %H:%M')
    lines.append(f'### {icon} {l["story_id"]}: {l["story_title"]}')
    lines.append(f'- **Tipo:** {l["type"]} ({l["details"]})')
    lines.append(f'- **Data:** {dt}')
    lines.append(f'- **Action:** {action}')
    lines.append(f'- **Contexto:** \`.devorq-auto/pending/{l["story_id"]}.json\`')
    lines.append('')

lines.append('---')
lines.append(f'Total: {len(failed)} failures | Stats: delegate={data["stats"]["delegate_failed"]}, verification={data["stats"]["verification_failed"]}, complex={data["stats"]["complex_detected"]}')
lines.append(progress_line)

with open(failures_md, 'w') as f:
    f.write('\n'.join(lines))
PYEOF
}

#-----------------------------------------------------------
# PENDING — Salvar contexto da story que falhou
#-----------------------------------------------------------
devorq_auto::pending_save() {
    local project="$1"
    local story_json="$2"
    local failure_type="$3"
    local details="$4"

    local story_id
    story_id=$(echo "$story_json" | jq -r '.id')

    local pending_file="$DEVORQ_AUTO_DIR/pending/${story_id}.json"

    # Write story_json to temp file first to avoid escaping issues
    local json_tmp
    json_tmp=$(mktemp)
    echo "$story_json" > "$json_tmp"

    JSON_TMP="$json_tmp" \
    PENDING_FILE="$pending_file" \
    FAILURE_TYPE="$failure_type" \
    DETAILS="$details" \
    python3 << PYEOF
import json, os
from datetime import datetime

with open(os.environ['JSON_TMP']) as f:
    story = json.load(f)

pending = {
    'story_id': story['id'],
    'title': story['title'],
    'description': story.get('description', ''),
    'acceptanceCriteria': story.get('acceptanceCriteria') or story.get('acceptance_criteria') or [],
    'priority': story['priority'],
    'failure': {
        'type': os.environ['FAILURE_TYPE'],
        'details': os.environ['DETAILS'],
        'timestamp': datetime.now().isoformat()
    }
}

with open(os.environ['PENDING_FILE'], 'w') as f:
    json.dump(pending, f, indent=2)
PYEOF

    rm -f "$json_tmp"
    echo "Saved: $pending_file"
}

#-----------------------------------------------------------
# Detectar projeto
#-----------------------------------------------------------
devorq_auto::detect_project() {
    local dir="${1:-.}"

    if [[ -f "$dir/SPEC.md" ]]; then
        echo "$dir"
        return 0
    elif [[ -f "$dir/.git/config" ]]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return 0
    fi

    local parent="$dir"
    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        parent=$(dirname "$parent")
        if [[ -f "$parent/SPEC.md" ]] || [[ -f "$parent/.git/config" ]]; then
            echo "$parent"
            return 0
        fi
    done

    return 1
}

#-----------------------------------------------------------
# Verificar prd.json
#-----------------------------------------------------------
devorq_auto::require_prd() {
    local prd="$1/prd.json"
    [[ -f "$prd" ]] || devorq_auto::die 5 "prd.json nao encontrado em $1"
}

#-----------------------------------------------------------
# Selecionar proxima story
#-----------------------------------------------------------
# Stories incompletas: aceita prd.json com passes OU status (ex.: status=pending do prd raiz)
devorq_auto::jq_story_incomplete() {
    echo 'select((.passes != true) and (.status != "done" and .status != "complete"))'
}

devorq_auto::jq_story_complete() {
    echo 'select(.passes == true or .status == "done" or .status == "complete")'
}

devorq_auto::next_story() {
    local prd="$1/prd.json"
    local inc
    inc=$(devorq_auto::jq_story_incomplete)
    jq -c --argjson _unused 0 ".stories | sort_by(.priority // 999) | map($inc) | .[0] // empty" "$prd" 2>/dev/null
}

devorq_auto::pending_count() {
    local prd="$1/prd.json"
    local inc
    inc=$(devorq_auto::jq_story_incomplete)
    jq ".stories | map($inc) | length" "$prd" 2>/dev/null
}

devorq_auto::total_count() {
    local prd="$1/prd.json"
    jq '.stories | length' "$prd" 2>/dev/null
}

devorq_auto::completed_count() {
    local prd="$1/prd.json"
    local cmp
    cmp=$(devorq_auto::jq_story_complete)
    jq ".stories | map($cmp) | length" "$prd" 2>/dev/null
}

#-----------------------------------------------------------
# Atualizar prd.json
#-----------------------------------------------------------
devorq_auto::mark_failed() {
    local prd="$1/prd.json"
    local story_id="$2"
    local reason="$3"
    local tmp
    tmp=$(mktemp)
    # passes=true exclui da selecao (mesmo mecanismo de mark_skip); status=failed
    # mantem rastreavel. Valores via ambiente — nunca interpolados (DQ-004).
    DEVORQ_PRD="$prd" DEVORQ_STORY_ID="$story_id" DEVORQ_REASON="$reason" DEVORQ_TMP="$tmp" python3 -c '
import json, os
prd = os.environ["DEVORQ_PRD"]; sid = os.environ["DEVORQ_STORY_ID"]
reason = os.environ["DEVORQ_REASON"]; tmp = os.environ["DEVORQ_TMP"]
with open(prd) as f:
    data = json.load(f)
for s in data["stories"]:
    if s.get("id") == sid:
        s["passes"] = True; s["status"] = "failed"; s["failed"] = True; s["fail_reason"] = reason
        break
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
' 2>/dev/null
    if [[ -s "$tmp" ]] && { ! command -v jq >/dev/null 2>&1 || jq empty "$tmp" >/dev/null 2>&1; }; then
        mv "$tmp" "$prd"
    else
        rm -f "$tmp"
        devorq_auto::fail "mark_failed: falha ao atualizar story '$story_id'; prd.json preservado"
        return 1
    fi
}

devorq_auto::mark_pass() {
    local prd="$1/prd.json"
    local story_id="$2"
    local tmp
    tmp=$(mktemp)

    # Valores via ambiente (nunca interpolados no source) — evita quebra/injecao
    # quando story_id/path contem aspas, e nunca zera o prd.json (DQ-004).
    DEVORQ_PRD="$prd" DEVORQ_STORY_ID="$story_id" DEVORQ_TMP="$tmp" python3 -c '
import json, os
prd = os.environ["DEVORQ_PRD"]
story_id = os.environ["DEVORQ_STORY_ID"]
tmp = os.environ["DEVORQ_TMP"]
with open(prd) as f:
    data = json.load(f)
for s in data["stories"]:
    if s.get("id") == story_id:
        s["passes"] = True
        s["status"] = "done"
        break
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
' 2>/dev/null

    # So promove se nao-vazio e (havendo jq) JSON valido; senao preserva o prd.
    if [[ -s "$tmp" ]] && { ! command -v jq >/dev/null 2>&1 || jq empty "$tmp" >/dev/null 2>&1; }; then
        mv "$tmp" "$prd"
    else
        rm -f "$tmp"
        devorq_auto::fail "mark_pass: falha ao atualizar story '$story_id'; prd.json preservado"
        return 1
    fi
}

devorq_auto::mark_skip() {
    local prd="$1/prd.json"
    local story_id="$2"
    local reason="$3"
    local tmp
    tmp=$(mktemp)

    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
target_id = sys.argv[2]
target_reason = sys.argv[3]
for s in data['stories']:
    if s['id'] == target_id:
        s['passes'] = True
        s['status'] = 'skipped'
        s['skipped'] = True
        s['skip_reason'] = target_reason
        break
with open(sys.argv[4], 'w') as f:
    json.dump(data, f, indent=2)
" "$prd" "$story_id" "$reason" "$tmp"
    mv "$tmp" "$prd"
}

#-----------------------------------------------------------
# Append progress.txt
#-----------------------------------------------------------
devorq_auto::append_progress() {
    local progress="$1/progress.txt"
    local story_id="$2"
    local story_title="$3"
    local status="${4:-PASSED}"

    {
        echo "# devorq-auto progress — $(basename "$1")"
        echo "# Formato: [HH:MM] ✅|❌|⏭️  Story Title — PASSED|FAILED|SKIPPED"
        echo "[$(date +%H:%M)] ${status} ${story_id}: ${story_title} — ${status}"
    } >> "$progress"
}

#-----------------------------------------------------------
# Criar branch
#-----------------------------------------------------------
devorq_auto::ensure_branch() {
    local project="$1"
    local branch_file="$project/.devorq-auto/.last-branch"

    mkdir -p "$project/.devorq-auto"

    if [[ -f "$branch_file" ]]; then
        local existing_branch
        existing_branch=$(cat "$branch_file")
        if git -C "$project" rev-parse --verify "$existing_branch" >/dev/null 2>&1; then
            git -C "$project" checkout "$existing_branch" 2>/dev/null && return 0
            # checkout falhou (arvore suja?) — abortar em vez de seguir na branch errada
            devorq_auto::die 1 "checkout da branch $existing_branch falhou (arvore suja/conflito?)"
        fi
    fi

    local new_branch="devorq-auto/$(date +%Y%m%d-%H%M%S)"
    git -C "$project" checkout -b "$new_branch" 2>/dev/null \
        || devorq_auto::die 1 "checkout -b $new_branch falhou"
    echo "$new_branch" > "$branch_file"
}

#-----------------------------------------------------------
# Git commit
#-----------------------------------------------------------
devorq_auto::git_commit() {
    local project="$1"
    local story_id="$2"
    local story_title="$3"

    # porcelain (nao git diff) para enxergar arquivos NOVOS (untracked)
    if [[ -z "$(git -C "$project" status --porcelain 2>/dev/null)" ]]; then
        devorq_auto::info "Nenhum change para commitar"
        return 0
    fi

    # Guard de segredos ANTES do add -A (DQ-014). Inline: o loop nao carrega
    # lib/commit.sh; mesmo padrao de devorq::commit::guard_secrets.
    local sensitive
    sensitive=$(git -C "$project" status --porcelain --untracked-files=all 2>/dev/null \
        | sed 's/^...//' \
        | grep -iE '(^|/)(\.env(\.[a-z0-9_-]+)?$|id_rsa$|id_dsa$|id_ed25519$|[^/]*\.(pem|key|p12|pfx|kdbx)$)' \
        | grep -ivE '\.env\.(example|sample|template|dist)$' || true)
    if [[ -n "$sensitive" && "${DEVORQ_ALLOW_SECRETS:-0}" != "1" ]]; then
        devorq_auto::fail "Arquivos sensiveis nas mudancas (commit abortado; DEVORQ_ALLOW_SECRETS=1 p/ ignorar):"
        echo "$sensitive" | sed 's/^/    /' >&2
        return 1
    fi

    local scope="core"
    if command -v devorq &>/dev/null && declare -f devorq::verify::detect_scope &>/dev/null; then
        scope="$(devorq::verify::detect_scope "$project" 2>/dev/null || echo "core")"
    fi
    local message="${scope}(impl): ${story_title} (${story_id})"
    git -C "$project" add -A || { devorq_auto::fail "git add -A falhou"; return 1; }
    git -C "$project" commit -m "$message" || { devorq_auto::fail "git commit falhou (hook? nada staged?)"; return 1; }
}

#-----------------------------------------------------------
# Detectar complexidade de story
#-----------------------------------------------------------
devorq_auto::detect_complexity() {
    local story_title="$1"
    local story_desc="$2"

    local complex_keywords="migration|enum|policy|relation|many-to-many|factory|seeder|job|queue|event|listener|middleware|service provider|config|schema|refactor|multi|distributed|parallel"
    local complex_heuristic

    complex_heuristic=$(echo "$story_title $story_desc" | grep -Ei "$complex_keywords" | head -1 || true)

    if [[ -n "$complex_heuristic" ]]; then
        echo "complex:$complex_heuristic"
        return 0
    fi

    local total_len=$((${#story_title} + ${#story_desc}))
    if [[ $total_len -gt 500 ]]; then
        echo "complex:long_description"
        return 0
    fi

    return 1
}

#-----------------------------------------------------------
# Propor quebra de story
#-----------------------------------------------------------
devorq_auto::propose_break() {
    local story_json="$1"

    echo ""
    devorq_auto::warn "Story complexa detectada!"
    echo ""
    echo "  ID: $(echo "$story_json" | jq -r '.id')"
    echo "  Title: $(echo "$story_json" | jq -r '.title')"
    echo ""
    echo "  Suggestoes:"
    echo "    1. Continuar mesmo assim (pode falhar)"
    echo "    2. Marcar como SKIPPED (analise manual)"
    echo "    3. Abortar"
    echo ""
    local choice="1"
    if devorq_auto::can_prompt; then
        echo -n "  Escolha [1]: "
        read -r choice < /dev/stdin
    else
        devorq_auto::warn "nao-interativo: continuando com a story (default seguro)" >&2
        choice=1
    fi

    case "${choice:-1}" in
        2) echo "SKIPPED" ;;
        3) exit 2 ;;
        *) echo "CONTINUE" ;;
    esac
}

#-----------------------------------------------------------
# Mostrar status
#-----------------------------------------------------------
devorq_auto::show_status() {
    local project="$1"
    devorq_auto::require_prd "$project"

    local total pending completed
    total=$(devorq_auto::total_count "$project")
    pending=$(devorq_auto::pending_count "$project")
    completed=$(devorq_auto::completed_count "$project")

    echo ""
    echo "📋 prd.json — $total stories ($completed done, $pending pending)"
    echo "-----------------------------------------------------------"

    python3 -c "
import json
with open(sys.argv[1] + '/prd.json') as f:
    for s in sorted(json.load(f)['stories'], key=lambda x: x.get('priority', 0)):
        done = bool(s.get('passes')) or s.get('status') in ('done', 'complete', 'skipped')
        icon = '✅' if done and not s.get('skipped') else ('⏭️ ' if s.get('skipped') else '🔴')
        skipped = f' (SKIP: {s[\"skip_reason\"]})' if s.get('skipped') else ''
        print(f'  [{s.get(\"priority\", \"?\")}] \"{s.get(\"title\", \"\")}\" [{icon}]{skipped}')
" "$project"
}

#-----------------------------------------------------------
# Mostrar story atual
#-----------------------------------------------------------
devorq_auto::show_story() {
    local story_json="$1"
    local id title desc priority

    id=$(echo "$story_json" | jq -r '.id')
    title=$(echo "$story_json" | jq -r '.title')
    desc=$(echo "$story_json" | jq -r '.description // ""')
    priority=$(echo "$story_json" | jq -r '.priority // 0')

    echo ""
    echo "📖 Story: $id — $title"
    echo "   Priority: $priority"
    echo "   Desc: $desc"
    echo "   Criteria:"
    echo "$story_json" | jq -r '(.acceptanceCriteria // .acceptance_criteria // [])[] | "     - \(.)"'
}

#-----------------------------------------------------------
# DELEGATE — wrapper com retry
#-----------------------------------------------------------
devorq_auto::delegate_with_retry() {
    local story_json="$1"
    local project="$2"
    local attempt=0
    local last_error=""

    while [[ $attempt -lt $MAX_DELEGATE_RETRIES ]]; do
        attempt=$((attempt + 1))

        if [[ $attempt -eq 1 ]]; then
            devorq_auto::info "⏳ Delegando para sub-agente (tentativa $attempt)..."
        else
            devorq_auto::warn "Retry $attempt..."
        fi

        if [[ -n "${DEVORQ_DELEGATE_FN:-}" ]]; then
            local output
            output=$($DEVORQ_DELEGATE_FN "$story_json" "$project" 2>&1) && {
                devorq_auto::success "Delegate completo"
                return 0
            }
            last_error="$output"
        else
            # Fail-closed: sem driver de agente nada e implementado. NAO retornar
            # sucesso (senao a story seria marcada done sem codigo). DQ-005.
            if [[ "${DEVORQ_AUTO_SIMULATE:-0}" == "1" ]]; then
                devorq_auto::warn "⏳ SIMULATED (DEVORQ_AUTO_SIMULATE=1) — dry-run, nada implementado"
                return 0
            fi
            devorq_auto::fail "Sem DEVORQ_DELEGATE_FN: nenhum sub-agente para implementar."
            devorq_auto::warn "Rode via agent (Hermes/Claude Code/Codex) ou DEVORQ_AUTO_SIMULATE=1 para dry-run."
            return 1
        fi

        if [[ $attempt -lt $MAX_DELEGATE_RETRIES ]]; then
            devorq_auto::warn "Delegate falhou, tentando novamente em 2s..."
            sleep 2
        fi
    done

    devorq_auto::fail "Delegate falhou apos $MAX_DELEGATE_RETRIES retries: $last_error"
    return 1
}

#-----------------------------------------------------------
# Handle failure — save pending + lessons
#-----------------------------------------------------------
devorq_auto::handle_failure() {
    local project="$1"
    local story_json="$2"
    local story_id="$3"
    local story_title="$4"
    local failure_type="$5"
    local details="$6"

    # Save pending context
    devorq_auto::pending_save "$project" "$story_json" "$failure_type" "$details"

    # Capture lesson
    devorq_auto::lessons_capture "$project" "$story_id" "$story_title" "$failure_type" "$details"

    # Update progress
    devorq_auto::append_progress "$project" "$story_id" "$story_title" "FAILED"
}

#-----------------------------------------------------------
# Main loop
#-----------------------------------------------------------
main() {
    local project_root=""
    local iterations=1
    local all=false
    local positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --iterations) iterations="$2"; shift 2 ;;
            --all) all=true; iterations=999; shift ;;
            --force-continue) FORCE_CONTINUE=true; shift ;;
            --no-learn) CAPTURE_LESSONS=false; shift ;;
            -h|--help) devorq_auto::usage; exit 0 ;;
            *) positional+=("$1"); shift ;;
        esac
    done

    project_root="${positional[0]:-}"
    # Compat: loop-auto.sh <DIR> 3  → segundo token numérico = iterations (não sobrescreve DIR)
    if [[ ${#positional[@]} -ge 2 && "${positional[1]}" =~ ^[0-9]+$ ]]; then
        iterations="${positional[1]}"
    fi

    [[ -z "$project_root" ]] && { devorq_auto::usage; exit 1; }

    project_root=$(devorq_auto::detect_project "$project_root")         || devorq_auto::die 1 "Nao encontrei SPEC.md ou .git a partir de: $project_root"

    cd "$project_root"
    mkdir -p "$project_root/.devorq-auto"
    # Lock de run unico: dois runs AUTO simultaneos corromperiam prd.json/estado.
    if command -v flock &>/dev/null; then
        exec 8>"$project_root/.devorq-auto/.run.lock"
        flock -n 8 || devorq_auto::die 1 "Outro run AUTO ja esta ativo neste projeto (.devorq-auto/.run.lock)"
    fi
    # failures.md via trap EXIT: se o run morrer no meio (die/crash), o sumario
    # das falhas nao se perde — justamente quando ele mais importa.
    _AUTO_PROJECT_ROOT="$project_root"
    trap 'devorq_auto::failures_generate "$_AUTO_PROJECT_ROOT" 2>/dev/null || true' EXIT
    devorq_auto::require_prd "$project_root"

    # Setup dirs and init
    devorq_auto::setup_dirs "$project_root"
    devorq_auto::lessons_init "$project_root"

    # Start run log header
    devorq_auto::log "=== DEVORQ-AUTO v$DEVORQ_AUTO_VERSION RUN START ==="
    devorq_auto::log "Project: $project_root"
    devorq_auto::log "Force-continue: $FORCE_CONTINUE | Capture-lessons: $CAPTURE_LESSONS"

    local pending
    pending=$(devorq_auto::pending_count "$project_root")
    [[ $pending -eq 0 ]] && { echo "✅ Todas as stories ja passaram."; exit 0; }

    echo ""
    echo "devorq-auto loop v$DEVORQ_AUTO_VERSION — $pending stories pendentes"
    echo "Force-continue: $FORCE_CONTINUE | Capture-lessons: $CAPTURE_LESSONS"
    echo "Log: $RUN_LOG_FILE"
    echo "=============================================="

    devorq_auto::ensure_branch "$project_root"

    local loop=0
    local total_failures=0
    local failure_list=()

    while [[ $loop -lt $iterations ]]; do
        loop=$((loop + 1))

        local story_json
        story_json=$(devorq_auto::next_story "$project_root")
        [[ -z "$story_json" || "$story_json" == "null" ]] && {
            devorq_auto::log "All stories processed"
            echo "✅ Todas stories processadas."
            break
        }

        local story_id story_title story_desc story_priority
        story_id=$(echo "$story_json" | jq -r '.id')
        story_title=$(echo "$story_json" | jq -r '.title')
        story_desc=$(echo "$story_json" | jq -r '.description')
        story_priority=$(echo "$story_json" | jq -r '.priority')

        # Stop-criteria: cada re-selecao conta uma tentativa. Excedido o limite,
        # marca failed e exclui da selecao — garante terminacao do overnight.
        _AUTO_STORY_ATTEMPTS["$story_id"]=$(( ${_AUTO_STORY_ATTEMPTS["$story_id"]:-0} + 1 ))
        if [[ ${_AUTO_STORY_ATTEMPTS["$story_id"]} -gt $DEVORQ_AUTO_MAX_STORY_FAILURES ]]; then
            devorq_auto::warn "Story $story_id excedeu $DEVORQ_AUTO_MAX_STORY_FAILURES tentativas — marcando failed e pulando"
            devorq_auto::mark_failed "$project_root" "$story_id" "max_attempts_${DEVORQ_AUTO_MAX_STORY_FAILURES}" || true
            devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "FAILED"
            devorq_auto::log "FAILED (max attempts): $story_id"
            continue
        fi

        devorq_auto::log "--- Story: $story_id ---"
        devorq_auto::info "🚀 Iteration $loop — Story: $story_id"
        devorq_auto::show_story "$story_json"

        # Suggest previous lesson
        devorq_auto::lessons_suggest "$project_root" "$story_title"

        # Detect complexity
        local complexity
        complexity=$(devorq_auto::detect_complexity "$story_title" "$story_desc") || true
        local complex_result=""

        if [[ -n "$complexity" ]]; then
            devorq_auto::lessons_capture "$project_root" "$story_id" "$story_title" "complex" "$complexity"
            complex_result=$(devorq_auto::propose_break "$story_json")

            if [[ "$complex_result" == "SKIPPED" ]]; then
                devorq_auto::warn "Story marcada como SKIPPED"
                devorq_auto::mark_skip "$project_root" "$story_id" "$complexity"
                devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "SKIPPED"
                devorq_auto::log "SKIPPED: $story_id ($complexity)"
                continue
            elif [[ "$complex_result" == "CONTINUE" ]]; then
                devorq_auto::info "Prosseguindo mesmo assim..."
            fi
        fi

        # Assinatura da arvore ANTES do delegate (status + diff de conteudo), para
        # comparar depois: se nao mudou nada, o delegate foi no-op. Robusto a
        # sujeira pre-existente (ex: prd.json), ao contrario de checar porcelain vazio.
        local _pre_sig
        _pre_sig=$(git -C "$project_root" status --porcelain --untracked-files=all 2>/dev/null; git -C "$project_root" diff HEAD 2>/dev/null)

        # DELEGATE with retry
        local delegate_ok=false
        if devorq_auto::delegate_with_retry "$story_json" "$project_root"; then
            delegate_ok=true
        else
            devorq_auto::fail "Delegate falhou apos retries"
            devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "delegate" "failed_after_${MAX_DELEGATE_RETRIES}_retries"
            total_failures=$((total_failures + 1))
            failure_list+=("$story_id")

            if [[ "$FORCE_CONTINUE" == "true" ]]; then
                devorq_auto::warn "FORCE_CONTINUE=true — pulando story"
                continue
            fi

            local choice
            if devorq_auto::can_prompt; then
                echo ""
                echo "  [1] Abortar"
                echo "  [2] Pular story e continuar"
                echo "  [3] Tentar novamente"
                echo -n "  Escolha [1]: "
                read -r choice < /dev/stdin
            else
                devorq_auto::warn "nao-interativo: pulando $story_id e continuando (default seguro)"
                choice=2
            fi

            case "${choice:-1}" in
                2) devorq_auto::warn "Pulando $story_id"; continue ;;
                3) loop=$((loop - 1)); continue ;;
                *) devorq_auto::die 4 "Abortado pelo usuario" ;;
            esac
        fi

        # no-diff guard: delegate que nao produziu NENHUMA mudanca nao pode marcar
        # a story done (a suite pre-existente passaria vazia). Compara assinatura
        # antes/depois. Pula em modo simulate (dry-run intencional nao gera diff).
        # ponytail: nao detecta edicao apenas em arquivo untracked ja existente —
        # caso raro; upgrade seria hash de conteudo untracked se necessario.
        if [[ "${DEVORQ_AUTO_SIMULATE:-0}" != "1" ]]; then
            local _post_sig
            _post_sig=$(git -C "$project_root" status --porcelain --untracked-files=all 2>/dev/null; git -C "$project_root" diff HEAD 2>/dev/null)
            if [[ "$_pre_sig" == "$_post_sig" ]]; then
                devorq_auto::fail "Delegate nao produziu mudancas (no-diff) — story $story_id NAO sera marcada done"
                devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "verification" "no_diff_delegate_produziu_nada"
                total_failures=$((total_failures + 1))
                failure_list+=("$story_id")
                continue
            fi
        fi

        # Verification gate
        devorq_auto::info "🔍 Verificando..."
        devorq_auto::log "Running verification for: $story_id"
        if "$SKILL_DIR/scripts/check-story.sh" "$project_root"; then
            devorq_auto::success "✅ Verification PASSED — ${story_id}"

            # Commit por story (DQ-006): com DEVORQ_AUTO_COMMIT=1 o loop commita a
            # story verificada ANTES de marca-la done — ciclo recuperavel
            # 'delegate -> verify -> commit -> done'. Default permanece manual.
            if [[ "${DEVORQ_AUTO_COMMIT:-0}" == "1" ]]; then
                if devorq_auto::git_commit "$project_root" "$story_id" "$story_title"; then
                    devorq_auto::success "Commit por story OK"
                else
                    devorq_auto::warn "git_commit falhou — story NAO sera marcada done"
                    devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "commit" "git_commit_failed"
                    total_failures=$((total_failures + 1))
                    failure_list+=("$story_id")
                    continue
                fi
            else
                devorq_auto::warn "=============================================="
                devorq_auto::warn "⚠️  COMMIT MANUAL NECESSÁRIO (ou use DEVORQ_AUTO_COMMIT=1)"
                devorq_auto::warn "=============================================="
                echo ""
                echo "  Para commitar esta story, execute:"
                echo "  devorq commit --story ${story_id}"
                echo "  (formato: escopo(fase): descrição — ver rules/commit-convention.md)"
                echo ""
            fi

            # Guarda contra set -e: se mark_pass falhar (prd preservado), trata
            # como falha da story e segue o lote — sem abortar o run (DQ-004/revisao).
            if ! devorq_auto::mark_pass "$project_root" "$story_id"; then
                devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "mark_pass" "prd_update_failed"
                total_failures=$((total_failures + 1))
                failure_list+=("$story_id")
                continue
            fi
            devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "PASSED"
            devorq_auto::lessons_capture "$project_root" "$story_id" "$story_title" "success" ""
            devorq_auto::log "PASSED (pending manual commit): $story_id"

            local done total
            done=$(devorq_auto::completed_count "$project_root")
            total=$(devorq_auto::total_count "$project_root")
            devorq_auto::info "📊 Progress: $done/$total stories done"
        else
            devorq_auto::fail "Verification failed"
            devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "verification" "check-story.sh_failed"
            total_failures=$((total_failures + 1))
            failure_list+=("$story_id")

            if [[ "$FORCE_CONTINUE" == "true" ]]; then
                devorq_auto::warn "FORCE_CONTINUE=true — continuando mesmo assim"
                continue
            fi

            local choice
            if devorq_auto::can_prompt; then
                echo ""
                echo "  [1] Abortar"
                echo "  [2] Pular story e continuar"
                echo "  [3] Tentar novamente"
                echo -n "  Escolha [1]: "
                read -r choice < /dev/stdin
            else
                devorq_auto::warn "nao-interativo: pulando $story_id e continuando (default seguro)"
                choice=2
            fi

            case "${choice:-1}" in
                2) devorq_auto::warn "Pulando $story_id"; continue ;;
                3) loop=$((loop - 1)); continue ;;
                *) devorq_auto::die 3 "Verification failed — abortado" ;;
            esac
        fi

        echo ""
    done

    # Generate failures.md
    devorq_auto::failures_generate "$project_root"

    # Summary
    local done total
    done=$(devorq_auto::completed_count "$project_root")
    total=$(devorq_auto::total_count "$project_root")
    pending=$(devorq_auto::pending_count "$project_root")

    echo ""
    echo "═══════════════════════════════════════"
    echo "✅ AUTO MODE COMPLETE (v$DEVORQ_AUTO_VERSION)"
    echo "═══════════════════════════════════════"
    echo "$done stories done, $pending pending, $total_failures failures"
    echo ""
    echo "📊 progress:    $project_root/progress.txt"
    echo "📋 prd.json:    $project_root/prd.json"
    echo "📚 lessons:     $DEVORQ_AUTO_DIR/lessons.json"
    echo "📝 failures:    $DEVORQ_AUTO_DIR/failures.md"
    echo "📁 run log:     $RUN_LOG_FILE"
    echo "📁 pending ctx: $DEVORQ_AUTO_DIR/pending/"
    echo "⚠️  Lembre de: E2E antes do PR"
    echo "══════════════════════════════════════="

    devorq_auto::log "=== RUN END: $done done, $pending pending, $total_failures failures ==="
}

main "$@"
