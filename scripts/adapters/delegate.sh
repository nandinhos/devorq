#!/usr/bin/env bash
#============================================================
# scripts/adapters/delegate.sh
#
# Adapter GENERICO para o contrato DEVORQ_DELEGATE_FN: delega a
# implementacao de uma story ao CLI de LLM escolhido em DEVORQ_RUNNER.
# Um unico dispatcher para todos os runners — sem duplicar o boilerplate.
#
# Contrato (AGENTS.md "Contrato de delegacao"):
#   $DEVORQ_DELEGATE_FN "$story_json" "$project_root"
#     $1 = story_json (.id .title .description .acceptanceCriteria)
#     $2 = project_root (caminho absoluto)
#   Retorna 0 em sucesso, !=0 em falha.
#
# Uso:
#   export DEVORQ_DELEGATE_FN="$PWD/scripts/adapters/delegate.sh"
#   export DEVORQ_RUNNER=claude   # claude|codex|hermes|opencode|agy
#   bash skills/devorq-auto/scripts/loop-auto.sh "$PWD" --all
# (ou use um wrapper: claude-delegate.sh, codex-delegate.sh, ...)
#
# Env vars:
#   DEVORQ_RUNNER            (obrigatoria) claude|codex|hermes|opencode|agy
#   DEVORQ_MODEL             modelo a forcar (default: default do CLI; opencode: minimax/MiniMax-M3)
#   DEVORQ_DELEGATE_TIMEOUT  segundos ate matar (default: 1800)
#   DEVORQ_DELEGATE_DRY_RUN  se "1", imprime o plano e retorna 0 sem invocar
#============================================================
set -euo pipefail

readonly ADAPTER_NAME="delegate"
RUNNER="${DEVORQ_RUNNER:-}"
MODEL="${DEVORQ_MODEL:-}"
TIMEOUT="${DEVORQ_DELEGATE_TIMEOUT:-1800}"
DRY_RUN="${DEVORQ_DELEGATE_DRY_RUN:-0}"

adapter::die()  { echo "[${ADAPTER_NAME}] ERROR: ${2:-$1}" >&2; exit "${1:-1}"; }
adapter::info() { echo "[${ADAPTER_NAME}] $*"; }

#----- Runner obrigatorio + suportado
case "$RUNNER" in
    claude|codex|hermes|opencode|agy) ;;
    "") adapter::die 2 "DEVORQ_RUNNER nao definido. Use: claude|codex|hermes|opencode|agy" ;;
    *)  adapter::die 2 "DEVORQ_RUNNER='$RUNNER' nao suportado. Use: claude|codex|hermes|opencode|agy" ;;
esac

#----- Contrato
STORY_JSON="${1:-}"
PROJECT_ROOT="${2:-}"
[[ -z "$STORY_JSON" ]]   && adapter::die 2 "story_json ausente (arg \$1)"
[[ -z "$PROJECT_ROOT" ]] && adapter::die 2 "project_root ausente (arg \$2)"
[[ -d "$PROJECT_ROOT" ]] || adapter::die 3 "project_root nao e diretorio: $PROJECT_ROOT"
command -v jq >/dev/null 2>&1 || adapter::die 4 "jq nao encontrado (apt install jq)"

#----- Parse do story_json
STORY_ID=$(printf '%s' "$STORY_JSON"    | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
STORY_TITLE=$(printf '%s' "$STORY_JSON" | jq -r '.title // ""'     2>/dev/null || echo "")
STORY_DESC=$(printf '%s' "$STORY_JSON"  | jq -r '.description // ""' 2>/dev/null || echo "")
STORY_CRITERIA=$(printf '%s' "$STORY_JSON" | jq -r \
    '(.acceptanceCriteria // .acceptance_criteria // []) | map("- " + .) | join("\n")' \
    2>/dev/null || echo "")
[[ -z "$STORY_TITLE" ]] && adapter::die 5 "story_json sem .title (id=$STORY_ID)"

#----- Journal por-agente (DQ-018)
RUN_LOG_DIR="$PROJECT_ROOT/.devorq-auto/runs"
mkdir -p "$RUN_LOG_DIR"
JOURNAL="$RUN_LOG_DIR/${RUNNER}-${STORY_ID}-$$.log"
adapter::journal() { printf '[%s] [%s/%s] %s\n' "$(date -Iseconds 2>/dev/null || date)" "$ADAPTER_NAME" "$RUNNER" "$*" >> "$JOURNAL"; }
adapter::journal "invoke story_id=$STORY_ID runner=$RUNNER model=${MODEL:-<default>} timeout=${TIMEOUT}s dry=$DRY_RUN"

#----- Prompt focado (Ralph: contexto limpo, mudanca minima)
PROMPT=$(cat <<PROMPT_EOF
Voce esta implementando uma story do DEVORQ em modo AUTO.

Projeto: ${PROJECT_ROOT}
Story ID: ${STORY_ID}
Titulo: ${STORY_TITLE}
Descricao: ${STORY_DESC}

Criterios de aceitacao (TODOS devem ser satisfeitos):
${STORY_CRITERIA}

Instrucoes:
1. Leia os arquivos necessarios antes de editar.
2. Implemente a mudanca MINIMA que satisfaz todos os criterios.
3. NAO faca refatoracao fora do escopo.
4. NAO commite — o loop DEVORQ fara isso.
5. NAO altere prd.json ou progress.txt — o loop gerencia.
6. Responda em portugues do Brasil.
7. Ao terminar, retorne um resumo curto (ate 5 linhas) do que mudou.
PROMPT_EOF
)

#----- Dry-run: mostra o plano e sai 0 (sem invocar LLM)
if [[ "$DRY_RUN" == "1" ]]; then
    adapter::info "DRY-RUN story=$STORY_ID runner=$RUNNER model=${MODEL:-<default>} dir=$PROJECT_ROOT prompt_len=${#PROMPT}"
    adapter::journal "dry_run OK"
    exit 0
fi

command -v "$RUNNER" >/dev/null 2>&1 || {
    adapter::journal "runner binary '$RUNNER' not found"
    adapter::die 6 "'$RUNNER' nao encontrado no PATH"
}

#----- Monta o comando por runner (flags reais de cada CLI)
#      Cada runner: modo nao-interativo + escrita autonoma + working dir no projeto.
declare -a CMD
case "$RUNNER" in
    claude)   # Claude Code CLI: -p print, --dangerously-skip-permissions
        CMD=(claude -p "$PROMPT" --dangerously-skip-permissions --add-dir "$PROJECT_ROOT")
        [[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
        ;;
    agy)      # Antigravity CLI: -p print, --dangerously-skip-permissions
        CMD=(agy -p "$PROMPT" --dangerously-skip-permissions --add-dir "$PROJECT_ROOT")
        [[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
        ;;
    codex)    # Codex CLI: exec nao-interativo, -s workspace-write permite editar o projeto
        CMD=(codex exec --cd "$PROJECT_ROOT" -s workspace-write --skip-git-repo-check)
        [[ -n "$MODEL" ]] && CMD+=(--model "$MODEL")
        CMD+=("$PROMPT")
        ;;
    hermes)   # Hermes CLI: -z prompt nao-interativo, --yolo auto-aprova tools
        CMD=(hermes -z "$PROMPT" --yolo)
        [[ -n "$MODEL" ]] && CMD+=(-m "$MODEL")
        ;;
    opencode) # opencode run em batch (model default minimax/MiniMax-M3)
        CMD=(opencode run --model "${MODEL:-minimax/MiniMax-M3}" --variant "${OPENCODE_EFFORT:-max}" \
             --agent "${OPENCODE_AGENT:-build}" --dir "$PROJECT_ROOT" \
             --title "devorq story $STORY_ID" --dangerously-skip-permissions "$PROMPT")
        ;;
esac

adapter::info "Delegando story=$STORY_ID → $RUNNER (model=${MODEL:-<default>}, timeout=${TIMEOUT}s)"
adapter::journal "run begin: ${CMD[0]} ..."

# claude/agy/hermes operam no cwd → rodamos dentro do projeto. codex/opencode recebem o dir por flag.
set +e
( case "$RUNNER" in claude|agy|hermes) cd "$PROJECT_ROOT" ;; esac
  timeout "$TIMEOUT" "${CMD[@]}" ) >> "$JOURNAL" 2>&1
RC=$?
set -e

adapter::journal "run end rc=$RC"
if [[ $RC -eq 124 ]]; then
    adapter::die 124 "$RUNNER excedeu timeout de ${TIMEOUT}s — veja $JOURNAL"
fi
if [[ $RC -ne 0 ]]; then
    adapter::die "$RC" "$RUNNER falhou (rc=$RC) — veja $JOURNAL"
fi

adapter::info "OK story=$STORY_ID ($RUNNER)"
adapter::journal "success"
exit 0
