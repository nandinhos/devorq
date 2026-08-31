#!/usr/bin/env bash
# scripts/install-dsh-preset.sh — instala/repara o plugin DEVORQ no DeepSeek Harness (DSH).
#
# Cria/atualiza a partir do repo (fonte canônica):
#   <dshHome>/.agent-presets/devorq/{agent.cordis.yml,preset.yml}  ← preset DEVORQ (persona)
#   <dshHome>/skills/devorq/SKILL.md                               ← skill DEVORQ (user-dsh, rank 400)
#
# Idempotente: só escreve quando o conteúdo difere do repo; caso idêntico, é no-op.
# Não destrói outros presets/skills do usuário (só gerencia o namespace `devorq`).
#
# Uso:
#   bash scripts/install-dsh-preset.sh              # instala/repara
#   bash scripts/install-dsh-preset.sh --dry-run    # só mostra o que faria
#
# Env: DSH_HOME (default: $HOME/.dsh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DSH_HOME="${DSH_HOME:-${HOME:-}/.dsh}"
if [[ ! -d "$DSH_HOME" ]]; then
    echo "[install-dsh] DSH_HOME não encontrado: $DSH_HOME" >&2
    echo "[install-dsh] Defina DSH_HOME ou rode dentro do DeepSeek Harness." >&2
    exit 1
fi

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

PRESET_DIR="$DSH_HOME/.agent-presets/devorq"
SKILL_DIR="$DSH_HOME/skills/devorq"

install_one() {
    local src="$1" dst="$2"
    if [[ ! -f "$src" ]]; then
        echo "[install-dsh] Fonte ausente (skip): $src" >&2
        return 0
    fi
    if $DRY_RUN; then
        echo "[install-dsh] [dry-run] instalaria: $src -> $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        echo "[install-dsh] ok (já atualizado): $dst"
        return 0
    fi
    cp "$src" "$dst"
    echo "[install-dsh] instalado: $dst"
}

echo "[install-dsh] DSH_HOME=$DSH_HOME"
install_one "$REPO_ROOT/skills/devorq/SKILL.md"              "$SKILL_DIR/SKILL.md"
install_one "$REPO_ROOT/config/dsh/devorq/agent.cordis.yml"  "$PRESET_DIR/agent.cordis.yml"
install_one "$REPO_ROOT/config/dsh/devorq/preset.yml"        "$PRESET_DIR/preset.yml"

echo ""
echo "[install-dsh] Plugin DEVORQ instalado/reparado."
echo "[install-dsh]   Preset: $PRESET_DIR (persona DEVORQ, montado pelo DSH)"
echo "[install-dsh]   Skill:  $SKILL_DIR/SKILL.md (root user-dsh, rank 400 — auto-descoberta)"
echo "[install-dsh] Abra uma NOVA sessão no preset DEVORQ para o catálogo de skills refletir."
