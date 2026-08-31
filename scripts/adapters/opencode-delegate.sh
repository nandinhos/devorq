#!/usr/bin/env bash
#============================================================
# scripts/adapters/opencode-delegate.sh
#
# Adapter para o contrato DEVORQ_DELEGATE_FN que delega
# implementacao de story ao CLI do opencode em modo batch.
#
# Contrato (vide AGENTS.md "Contrato de delegacao"):
#   $DEVORQ_DELEGATE_FN "$story_json" "$project_root"
#     $1 = story_json (string com .id .title .description .acceptanceCriteria)
#     $2 = project_root (caminho absoluto do projeto)
#   Retorna 0 em sucesso, !=0 em falha.
#
# Uso:
#   export DEVORQ_DELEGATE_FN="$PWD/scripts/adapters/opencode-delegate.sh"
#   bash skills/devorq-auto/scripts/loop-auto.sh "$PWD" --all
#
# Env vars opcionais (OPENCODE_* sao alias do contrato DEVORQ_*; o canonico vence):
#   OPENCODE_MODEL      (default: DEVORQ_MODEL ou minimax/MiniMax-M3)
#   OPENCODE_EFFORT     variant opencode: max|high|medium|minimal (default: max)
#   OPENCODE_AGENT      (default: build)
#   OPENCODE_TIMEOUT    segundos ate matar (default: DEVORQ_DELEGATE_TIMEOUT ou 1800)
#   OPENCODE_DRY_RUN    se "1", imprime o que faria e retorna 0 sem invocar
#============================================================
set -euo pipefail

readonly ADAPTER_NAME="opencode-delegate"

OPENCODE_MODEL="${OPENCODE_MODEL:-${DEVORQ_MODEL:-minimax/MiniMax-M3}}"
OPENCODE_EFFORT="${OPENCODE_EFFORT:-max}"
OPENCODE_AGENT="${OPENCODE_AGENT:-build}"
OPENCODE_TIMEOUT="${OPENCODE_TIMEOUT:-${DEVORQ_DELEGATE_TIMEOUT:-1800}}"
OPENCODE_DRY_RUN="${OPENCODE_DRY_RUN:-${DEVORQ_DELEGATE_DRY_RUN:-0}}"

adapter::die() { echo "[${ADAPTER_NAME}] ERROR: $*" >&2; exit "${1:-1}"; }
adapter::info() { echo "[${ADAPTER_NAME}] $*"; }
# shellcheck disable=SC2317
adapter::warn() { echo "[${ADAPTER_NAME}] WARN: $*" >&2; }

#----- Validacao de args (contrato)
STORY_JSON="${1:-}"
PROJECT_ROOT="${2:-}"

[[ -z "$STORY_JSON" ]] && adapter::die 2 "story_json ausente (arg \$1)"
[[ -z "$PROJECT_ROOT" ]] && adapter::die 2 "project_root ausente (arg \$2)"
[[ -d "$PROJECT_ROOT" ]] || adapter::die 3 "project_root nao e diretorio: $PROJECT_ROOT"

command -v jq >/dev/null 2>&1 || adapter::die 4 "jq nao encontrado (apt install jq)"

#----- Parse do story_json (sem corromper com SED in-place — DQ-029)
STORY_ID=$(printf '%s' "$STORY_JSON" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
STORY_TITLE=$(printf '%s' "$STORY_JSON" | jq -r '.title // ""' 2>/dev/null || echo "")
STORY_DESC=$(printf '%s' "$STORY_JSON" | jq -r '.description // ""' 2>/dev/null || echo "")
STORY_CRITERIA=$(printf '%s' "$STORY_JSON" | jq -r \
    '(.acceptanceCriteria // .acceptance_criteria // []) | map("- " + .) | join("\n")' \
    2>/dev/null || echo "")

[[ -z "$STORY_TITLE" ]] && adapter::die 5 "story_json sem .title (id=$STORY_ID)"

#----- Log no run journal do .devorq-auto (DQ-018 trilha por-agente)
RUN_LOG_DIR="$PROJECT_ROOT/.devorq-auto/runs"
mkdir -p "$RUN_LOG_DIR"
JOURNAL="$RUN_LOG_DIR/adapter-${STORY_ID}-$(date +%Y%m%d-%H%M%S).log"

adapter::journal() { printf '[%s] [%s] %s\n' "$(date -Iseconds)" "$ADAPTER_NAME" "$*" >> "$JOURNAL"; }

adapter::journal "invoke story_id=$STORY_ID model=$OPENCODE_MODEL effort=$OPENCODE_EFFORT agent=$OPENCODE_AGENT dry_run=$OPENCODE_DRY_RUN"

#----- Construcao do prompt (focado, contexto limpo — Ralph)
PROMPT=$(cat <<PROMPT_EOF
Voce esta implementando uma story do DEVORQ em modo AUTO.

Projeto: ${PROJECT_ROOT}
Story ID: ${STORY_ID}
Titulo: ${STORY_TITLE}
Descricao: ${STORY_DESC}

Criterios de aceitacao (TODOS devem ser satisfeitos):
${STORY_CRITERIA}

Instrucoes:
1. Leia os arquivos necessarios do projeto antes de editar.
2. Implemente a mudanca MINIMA que satisfaz todos os criterios.
3. NAO faca refatoracao fora do escopo.
4. NAO commite — o loop fara isso.
5. NAO altere prd.json ou progress.txt — o loop gerencia.
6. Responda em portugues do Brasil.
7. Ao terminar, retorne um resumo curto (ate 5 linhas) do que mudou.
PROMPT_EOF
)

#----- Dry-run: imprime o que faria e sai 0
if [[ "$OPENCODE_DRY_RUN" == "1" ]]; then
    adapter::info "DRY-RUN story_id=$STORY_ID"
    adapter::info "  model=$OPENCODE_MODEL effort=$OPENCODE_EFFORT agent=$OPENCODE_AGENT"
    adapter::info "  dir=$PROJECT_ROOT timeout=${OPENCODE_TIMEOUT}s"
    adapter::info "  prompt_len=${#PROMPT} chars"
    adapter::journal "dry_run OK (no opencode invocation)"
    exit 0
fi

#----- Verifica opencode CLI
command -v opencode >/dev/null 2>&1 || {
    adapter::journal "opencode binary not found"
    adapter::die 6 "opencode nao encontrado no PATH (instale: https://opencode.ai)"
}

#----- Invocacao real
adapter::info "Delegando story_id=$STORY_ID para opencode (model=$OPENCODE_MODEL, effort=$OPENCODE_EFFORT)"
adapter::journal "opencode run begin"

set +e
timeout "${OPENCODE_TIMEOUT}" opencode run \
    --model "$OPENCODE_MODEL" \
    --variant "$OPENCODE_EFFORT" \
    --agent "$OPENCODE_AGENT" \
    --dir "$PROJECT_ROOT" \
    --title "devorq story $STORY_ID" \
    --auto \
    "$PROMPT" >> "$JOURNAL" 2>&1
RC=$?
set -e

adapter::journal "opencode run end rc=$RC"

if [[ $RC -eq 124 ]]; then
    adapter::journal "TIMEOUT apos ${OPENCODE_TIMEOUT}s"
    adapter::die 124 "opencode run excedeu timeout de ${OPENCODE_TIMEOUT}s"
fi

if [[ $RC -ne 0 ]]; then
    adapter::die "$RC" "opencode run falhou (rc=$RC) — veja $JOURNAL"
fi

adapter::info "OK story_id=$STORY_ID"
adapter::journal "success"
exit 0