# DEVORQ Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar bootstrap e installer multi-projeto para o DEVORQ

**Architecture:** Script minimalista de bootstrap (`install-devorq.sh`) + comandos integrados ao `bin/devorq` (`install`, `update`, `activate`, `deactivate`). Instalação global em `~/.devorq/`, projetos pointam para ela.

**Tech Stack:** Bash, Git, curl

---

## File Structure

```
~/.devorq/                          ← Instalação global (criada pelo bootstrap)
  ├── bin/devorq                    ← CLI principal
  ├── lib/                          ← Módulos shell
  ├── .devorq/                      ← Skills, hooks, agents, rules
  └── VERSION                       ← Versão do framework

install-devorq.sh                   ← Script de bootstrap (raiz do repo)
bin/devorq                          ← Modify: adicionar comandos install/update/activate/deactivate
lib/                                ← Create: activation.sh (script de activation)
```

---

## Task 1: Criar install-devorq.sh (Bootstrap)

**Files:**
- Create: `install-devorq.sh` (raiz do repo)

- [ ] **Step 1: Criar install-devorq.sh**

```bash
#!/bin/bash
# install-devorq.sh — Bootstrap do DEVORQ
# Uso: curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash

set -e

DEVORQ_HOME="${DEVORQ_HOME:-$HOME/.devorq}"
DEVORQ_REPO="https://github.com/nandinhos/devorq.git"
BIN_LINK="$HOME/.local/bin/devorq"

echo "DEVORQ Installer v1.0"

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
```

- [ ] **Step 2: Tornar executável**

```bash
chmod +x install-devorq.sh
```

- [ ] **Step 3: Commit**

```bash
git add install-devorq.sh
git commit -m "feat(installer): adiciona script bootstrap install-devorq.sh"
```

---

## Task 2: Adicionar comandos em bin/devorq

**Files:**
- Modify: `bin/devorq` — adicionar handlers para install, update, activate, deactivate

- [ ] **Step 1: Verificar estrutura atual do bin/devorq para comandos**

```bash
grep -n "case" bin/devorq | head -20
```

- [ ] **Step 2: Adicionar comando install**

Adicionar em `bin/devorq` após os comandos existentes:

```bash
cmd_install() {
    local target_dir="${1:-.}"
    
    # Verifica se ~/.devorq/ existe
    if [ ! -d "$HOME/.devorq" ]; then
        echo "ERRO: DEVORQ não instalado. Execute: curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash"
        return 1
    fi
    
    cd "$target_dir" || return 1
    
    # Git pull no source
    echo "Atualizando DEVORQ..."
    git -C "$HOME/.devorq" pull origin main
    
    local version=$(cat "$HOME/.devorq/VERSION")
    
    # Verifica se já instalado
    if [ -f ".devorq/version" ]; then
        local installed_version=$(cat ".devorq/version")
        if [ "$installed_version" = "$version" ]; then
            echo "DEVORQ já está na versão $version (mais recente)"
            return 0
        fi
        echo "Atualizando de $installed_version para $version..."
    fi
    
    # Copiar arquivos (exceto state)
    echo "Instalando no projeto..."
    cp -r "$HOME/.devorq/bin/" .
    cp -r "$HOME/.devorq/lib/" .
    
    mkdir -p .devorq
    cp -r "$HOME/.devorq/.devorq/"* .devorq/
    rm -rf .devorq/state .devorq/logs
    mkdir -p .devorq/state .devorq/logs
    
    # Criar version file
    echo "$version" > .devorq/version
    
    # Inicializar git se não existir
    if [ ! -d ".git" ]; then
        git init
        echo ".devorq/" >> .gitignore
        echo ".devorq/logs/" >> .gitignore
        echo "Projeto inicializado com git"
    fi
    
    echo ""
    echo "DEVORQ $version instalado em $(pwd)"
    echo "Rode 'devorq activate' para ativar"
}
```

- [ ] **Step 3: Adicionar comando update**

```bash
cmd_update() {
    if [ ! -d "$HOME/.devorq" ]; then
        echo "ERRO: DEVORQ não instalado localmente"
        return 1
    fi
    
    echo "Atualizando DEVORQ..."
    git -C "$HOME/.devorq" pull origin main
    
    local version=$(cat "$HOME/.devorq/VERSION")
    echo "DEVORQ atualizado para v$version"
    
    # Scatter para projetos
    local projects_dir="${PROJECTS_DIR:-$HOME/projects}"
    if [ -d "$projects_dir" ]; then
        echo "Atualizando projetos..."
        for proj in "$projects_dir"/*; do
            if [ -f "$proj/.devorq/version" ]; then
                local proj_version=$(cat "$proj/.devorq/version" 2>/dev/null)
                if [ "$proj_version" != "$version" ]; then
                    echo "  - $(basename "$proj"): $proj_version → $version"
                    # Recopia arquivos
                    cp -r "$HOME/.devorq/bin/" "$proj/"
                    cp -r "$HOME/.devorq/lib/" "$proj/"
                    cp -r "$HOME/.devorq/.devorq/"* "$proj/.devorq/"
                    rm -rf "$proj/.devorq/state" "$proj/.devorq/logs"
                    mkdir -p "$proj/.devorq/state" "$proj/.devorq/logs"
                    echo "$version" > "$proj/.devorq/version"
                fi
            fi
        done
    fi
    
    echo "Concluído."
}
```

- [ ] **Step 4: Adicionar comando activate**

```bash
cmd_activate() {
    if [ ! -d ".devorq" ]; then
        echo "ERRO: DEVORQ não instalado neste projeto. Rode: devorq install"
        return 1
    fi
    
    export DEVORQ_ROOT="$(pwd)/.devorq"
    export PATH="$(pwd)/bin:$PATH"
    
    # Source dos hooks
    if [ -f "$DEVORQ_ROOT/hooks/prepare-commit-msg" ]; then
        chmod +x "$DEVORQ_ROOT/hooks/"*.sh 2>/dev/null || true
    fi
    
    local version=$(cat ".devorq/version" 2>/dev/null || echo "?")
    echo "DEVORQ ativado — v$version em $(pwd)"
}
```

- [ ] **Step 5: Adicionar comando deactivate**

```bash
cmd_deactivate() {
    if [ -n "$DEVORQ_ROOT" ]; then
        echo "DEVORQ desativado (era: $DEVORQ_ROOT)"
    fi
    unset DEVORQ_ROOT
    # Remove do PATH (implementação simplificada)
    export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$(pwd)/bin" | tr '\n' ':' | sed 's/:$//')
}
```

- [ ] **Step 6: Hook no main case**

No `case "$1"` do bin/devorq, adicionar:

```bash
install) cmd_install "$2";;
update) cmd_update;;
activate) cmd_activate;;
deactivate) cmd_deactivate;;
```

- [ ] **Step 7: Commit**

```bash
git add bin/devorq
git commit -m "feat(installer): adiciona comandos install, update, activate, deactivate"
```

---

## Task 3: Documentar em docs/INSTALL.md

**Files:**
- Create: `docs/INSTALL.md`

- [ ] **Step 1: Criar documentação**

```markdown
# DEVORQ Installer

## Instalação do Zero

```bash
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash
```

Isso instala o DEVORQ em `~/.devorq/` e cria symlink em `~/.local/bin/devorq`.

## Instalar em um Projeto

```bash
cd meu-projeto
devorq install
```

Isso copia bin/, lib/, .devorq/ para o projeto e cria `.devorq/version`.

## Ativar no Projeto

```bash
devorq activate
```

Exporta DEVORQ_ROOT e adiciona bin/ ao PATH.

## Atualizar DEVORQ

```bash
devorq update
```

Atualiza a instalação global e replica nos projetos.
```

- [ ] **Step 2: Commit**

```bash
git add docs/INSTALL.md
git commit -m "docs: adiciona guia de instalação"
```

---

## Verificação

- [ ] `shellcheck install-devorq.sh` → sem erros
- [ ] `shellcheck bin/devorq` → sem erros
- [ ] `bats tests/` → todos passam
- [ ] `install-devorq.sh` executa sem erro em ambiente limpo

---

## Execution Options

**1. Subagent-Driven (recommended)** - Dispatch fresh subagent per task
**2. Inline Execution** - Execute in this session with checkpoints

Qual abordagem prefere?