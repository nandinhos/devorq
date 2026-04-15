#!/bin/bash
# install-devorq.sh — Bootstrap do DEVORQ
# Uso: curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash

set -eEo pipefail

DEVORQ_HOME="${DEVORQ_HOME:-$HOME/.devorq}"
DEVORQ_REPO="https://github.com/nandinhos/devorq.git"

echo "DEVORQ Installer"

if [ -d "$DEVORQ_HOME" ]; then
    echo "DEVORQ já instalado em $DEVORQ_HOME"
    echo "Use: devorq update"
    exit 0
fi

echo "Clonando DEVORQ..."
git clone "$DEVORQ_REPO" "$DEVORQ_HOME"

mkdir -p "$HOME/.devorq/bin"
ln -sf "$DEVORQ_HOME/bin/devorq" "$HOME/.devorq/bin/devorq"
chmod +x "$HOME/.devorq/bin/devorq"

if [ -f "$HOME/.bashrc" ]; then
    if ! grep -q 'HOME/.devorq/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.devorq/bin:$PATH"' >> "$HOME/.bashrc"
        echo "PATH adicionado a ~/.bashrc"
    fi
elif [ -f "$HOME/.zshrc" ]; then
    if ! grep -q 'HOME/.devorq/bin' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.devorq/bin:$PATH"' >> "$HOME/.zshrc"
        echo "PATH adicionado a ~/.zshrc"
    fi
fi

echo ""
echo "DEVORQ instalado com sucesso!"
echo "Reinicie o terminal ou execute: source $shell_rc"
echo ""
echo "Depois: cd seu-projeto && devorq install"
