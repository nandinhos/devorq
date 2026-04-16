---
related_tasks: []
related_files: []
id: SPEC-0068-16-04-2026-spec0021-devorq-installer
title: DEVORQ Installer — Bootstrap e Deploy Multi-Projeto
domain: operacao
status: implemented
priority: high
owner: team-core
source: manual
author: nandodev
created_at: 2026-04-13
updated_at: 2026-04-15
---

# SPEC-0021: DEVORQ Installer

## Contexto

O DEVORQ precisa de um mecanismo de instalação/bootstrap que permita:
1. Instalar o framework do zero em qualquer máquina
2. Instalar/atualizar o DEVORQ em projetos novos ou existentes
3. Manter controle de versão entre installations

## Arquitetura

```
~/.devorq/                    ← Instalação "global" do devorq (source)
  ├── bin/devorq              ← CLI principal
  ├── lib/                    ← Módulos shell
  ├── .devorq/                ← Skills, hooks, agents, rules
  └── VERSION                 ← Versão do framework (e.g., "2.1")

~/projects/meu-projeto/      ← Projeto que usa devorq
  ├── bin/                    ← Copiado de ~/.devorq/bin
  ├── lib/                    ← Copiado de ~/.devorq/lib
  ├── .devorq/                ← Copiado (exceto state/)
  └── .devorq/version         ← Versão instalada neste projeto
```

## Fluxo de Bootstrap (Zero-Setup)

```bash
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash
```

**install-devorq.sh** (~50 linhas):
- Cria `~/.devorq/` via `git clone`
- Cria symlink `~/.local/bin/devorq` → `~/.devorq/bin/devorq`
- Adiciona `~/.local/bin/` ao PATH se necessário

## Comandos

### `devorq install`
Executado dentro da pasta do projeto-alvo.

**Fluxo:**
1. Verifica se `~/.devorq/` existe → erro se não
2. `git pull` em `~/.devorq/`
3. Copia `bin/`, `lib/`, `.devorq/` para `./` (exceto `.devorq/state/`)
4. Cria `./.devorq/version` com a versão atual
5. Inicializa `.devorq/state/` e `.devorq/logs/` se não existirem
6. Se projeto não for git repo, cria `.git/` automaticamente

### `devorq update`
Executado de qualquer lugar.

**Fluxo:**
1. `git pull` em `~/.devorq/`
2. Escaneia `$HOME/projects/*/` (ou similar) por projetos com `.devorq/version`
3. Para cada projeto com versão diferente: atualiza

### `devorq activate`
Executado dentro do projeto (após install).

**Fluxo:**
1. Verifica se `.devorq/` existe → erro se não
2. Exporta `DEVORQ_ROOT="$(pwd)/.devorq"`
3. Adiciona `bin/` ao PATH via source
4. Disponibiliza hooks git
5. Exibe mensagem: "DEVORQ ativado — vX.Y"

**Opções:**
- `devorq activate` — ativa no diretório atual
- `devorq activate --global` — ativa em todo shell (persistent)

### `devorq deactivate`
Remove devorq do PATH da sessão atual.

## Tratamento de Erros

| Situação | Comportamento |
|----------|---------------|
| `devorq install` sem `~/.devorq/` | Erro: "Execute install-devorq.sh primeiro" |
| `devorq install` em projeto já instalado | Verifica versão: se diferente atualiza, se igual avisa |
| `devorq activate` sem install | Erro: "Rode devorq install primeiro" |
| Projeto não é git repo | Cria `.git/` automaticamente |
| `devorq update` falha git pull | Mantém versão atual, erro explicativo |

## Arquivos Instalados no Projeto

| Arquivo/Diretório | Origem | Obrigatório |
|-------------------|--------|-------------|
| `bin/` | ~/.devorq/bin | Sim |
| `lib/` | ~/.devorq/lib | Sim |
| `.devorq/` | ~/.devorq/.devorq | Sim |
| `.devorq/version` | Gerado na install | Sim |
| `.devorq/state/` | Criado vazio | Sim |
| `.devorq/logs/` | Criado vazio | Sim |

**Arquivos NÃO copiados:**
- `tests/`, `docs/`, `README.md`, `AGENTS.md`
- `.devorq/state/handoffs/` (é local do projeto)

## Implementação

1. Criar `install-devorq.sh` na raiz do repo
2. Adicionar comandos `install`, `update`, `activate`, `deactivate` em `bin/devorq`
3. Criar script de activation (`lib/activation.sh` ou similar)
4. Documentar em `docs/INSTALL.md`
