#!/bin/bash
# install-devorq.sh — Bootstrap do DEVORQ
# Uso: curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash

set -eEo pipefail

DEVORQ_HOME="${DEVORQ_HOME:-$HOME/.devorq}"
DEVORQ_REPO="https://github.com/nandinhos/devorq.git"
BIN_LINK="$HOME/.local/bin/devorq"

echo "DEVORQ Installer"

# Se já existe, informar
if [ -d "$DEVORQ_HOME" ]; then
    echo "DEVORQ já instalado em $DEVORQ_HOME"
    echo "Use: devorq update"
    exit 0
fi

# Clonar repo
echo "Clonando DEVORQ..."
git clone "$DEVORQ_REPO" "$DEVORQ_HOME"

# Criar symlink
mkdir -p "$HOME/.local/bin"
ln -sf "$DEVORQ_HOME/bin/devorq" "$BIN_LINK"

echo ""
echo "DEVORQ instalado com sucesso!"
echo "Adicione ao PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "Ou reinicie o terminal."
echo ""
echo "Depois: cd seu-projeto && devorq install"
