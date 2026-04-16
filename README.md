# DEVORQ v2.1 - Meta-Framework de Orquestração Multi-LLM

<div align="center">
  <p><strong>Automação de engenharia com contratos rigorosos, specs formalizadas e workflow validado.</strong></p>
</div>

---

## O que é o DEVORQ?

**DEVORQ** é um meta-framework de orquestração de desenvolvimento assistido por LLM. Não é uma aplicação — é um framework de workflow integrado a projetos externos.

![Fluxo de Trabalho DEVORQ v2.1](docs/images/fluxo.png)

Implemented in **Bash puro** (4.0+), sem dependências externas além de `git` e `jq`.

### Pilares da v2.1

1. **Contratos Rigorosos** — Toda tarefa começa com `/spec` → `/break` → `/scope-guard`
2. **Specs Formalizadas** — Front matter canônico com `related_files` e `related_tasks`
3. **Validação Automática** — `./bin/devorq spec status` detecta implementação via arquivos relacionados
4. **Governança de Skills** — Versionamento semver + CHANGELOG em cada skill
5. **Proteção de Sourcing** — *Bash Dual-Use Source Guard* obrigatório em `lib/`
6. **Índice Auto-Regenerável** — `bin/spec-index` é executado automaticamente no `pre-commit` quando specs são alteradas

---

## Quick Start

```bash
# Instalação do zero (via curl)
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash

# Instalar em um projeto
cd meu-projeto
devorq install

# Ativar no projeto
devorq activate
```

---

## CLI Commands

```bash
# Contexto e Info
devorq init                        # Inicializar projeto
devorq info                        # Mostrar contexto detectado
devorq context                     # Exportar contexto
devorq checkpoint                  # Criar checkpoint de continuidade

# Manutenção (Global)
devorq install [path]              # Instalar DEVORQ no projeto (estrutura minimal)
devorq update                      # Atualizar global + sincronizar projetos + limpar órfãos
devorq clean                       # Limpar bin/lib e .devorq/agents,skills,docs órfãos
devorq upgrade <path>             # Atualizar DEVORQ em projeto específico

# Context-Mode (Modo Monstro)
devorq context-mode status         # Verificar status do Modo Monstro
devorq context-mode stats           # Estatísticas do DB de sessão
devorq context-mode doctor          # Diagnóstico do context-mode
devorq context-mode init            # Inicializar sessão de indexação
devorq context-mode index [path]    # Re-indexar projeto no contexto
devorq context-mode search "<q>"    # Buscar no índice de contexto

# Specs
devorq spec index                  # Gerar índice de todas as specs
devorq spec list                   # Listar specs (do índice)
devorq spec status                 # Analisar status das specs
devorq spec new "<título>"         # Criar nova spec em draft/
devorq spec find "<busca>"         # Buscar specs por termo
devorq spec move <id> <status>     # Mover spec para outro status
devorq spec fix [--dry-run|--force] # Validar/Corrigir padronização
devorq spec migrate                 # Migrar specs para novo padrão

# Handoff multi-LLM
devorq handoff generate            # Gerar spec padronizada para próximo LLM
devorq handoff status               # Mostrar status do handoff atual
devorq handoff list                 # Listar histórico de handoffs
devorq handoff update <status>     # Atualizar status

# Pipeline de Aprendizado
devorq lessons list                # Listar lições pendentes, validadas e aplicadas
devorq lessons validate           # Exibir lições para validação
devorq lessons apply <nome>        # Aplicar lição numa skill

# Skills
devorq skills                      # Listar skills disponíveis
devorq skill versions <skill>     # Listar versões de uma skill
devorq skill version <skill> <bump> # Criar snapshot de nova versão
devorq skill rollback <skill> <v>  # Reverter skill para versão anterior
```

---

## As 19 Skills

| Skill | Função |
|-------|--------|
| `spec` | Geração de especificação com contrato detalhado |
| `break` | Decompõe tarefas complexas em subtarefas |
| `scope-guard` | Gera contratos FAZER/NÃO FAZER/ARQUIVOS |
| `pre-flight` | Valida tipos, enums e dependências |
| `env-context` | Detecta stack, LLM, runtime, banco |
| `quality-gate` | Checklist pré-commit |
| `session-audit` | Métricas de eficiência |
| `tdd` | Ciclo RED → GREEN → REFACTOR |
| `schema-validate` | Integridade de schema de banco |
| `spec-export` | Handoff spec para troca de LLM |
| `systematic-debugging` | Investigação metódica de bugs |
| `code-review` | Revisão baseada em Clean Code |
| `brainstorming` | Fase de design/exploração |
| `learned-lesson` | Documenta lições para sessões futuras |
| `handoff` | Gera spec padronizada para transferência entre LLMs |
| `constraint-loader` | Carrega artefatos por tipo de task |
| `integrity-guardian` | Valida padrões Livewire/Alpine em Blade |
| `filament-expert` | Motor de regras Filament PHP |
| `spec-manager` | Automação de status e organização de specs |

---

## Specs — Sistema de Especificações

### Nomenclatura de Arquivos (SPEC-NUM-DD-MM-AAAA-TITLE)

```
SPEC-NUM-DD-MM-AAAA-TITLE.md
```

| Componente | Descrição |
|------------|-----------|
| `SPEC-` | Prefixo fixo |
| `NUM` | Número sequencial global (4 dígitos, zero-padded) |
| `DD-MM-AAAA` | Data de criação |
| `TITLE` | Título em kebab-case |

**Exemplo:** `SPEC-0004-31-03-2026-devorq-v20-evolucao-e-evolucao-de-arquitetura.md`

### Front Matter Canônico

```yaml
---
id: SPEC-NUM-DD-MM-AAAA-titulo-em-kebab-case
title: Título legível da spec
domain: arquitetura | importacao | ui_ux | refactor | seguranca | operacao
status: backlog | brainstorming | draft | approved | planning | in_progress | validated | implemented | blocked | archived
priority: low | medium | high | critical
owner: team-core
created_at: DD-MM-AAAA
updated_at: DD-MM-AAAA
source: manual | devorq | proposal/[caminho]
related_tasks: []
related_files: []
---
```

> **Regra:** Todo arquivo em `docs/specs/` (exceto `_index.md`) DEVE ter Front Matter completo e nome seguindo o padrão `SPEC-NUM-DD-MM-AAAA-TITLE.md`. O `_index.md` é gerado automaticamente pelo `bin/spec-index` — nunca editado manualmente.

### Comandos de Spec

```bash
./bin/devorq spec new "título da spec"       # Cria spec com próximo NUM sequencial
./bin/devorq spec find "busca"                # Busca fuzzy por título ou ID
./bin/devorq spec status                     # Lista todas as specs com warnings de ID
./bin/devorq spec update                     # Promove approved → implemented
./bin/devorq spec fix [--dry-run|--force]    # Valida padronização (--force para corrigir)
./bin/devorq spec migrate                    # Migra specs do formato antigo para novo padrão
./bin/devorq spec move <id> <status>         # Move spec para pasta de status
./bin/devorq spec index                      # Gera/regexera índice
```

### Detecção de Implementação

O sistema usa critérios híbridos:
1. **Front matter válido** — status approved
2. **Contagem precisa** — related_files > 0
3. **Verificação de existência** — > 50% dos arquivos existem

### Validação e Migração

```bash
# Validar todas as specs (dry-run)
./bin/devorq spec fix --dry-run

# Corrigir automaticamente (com confirmação)
./bin/devorq spec fix --force

# Migrar specs do padrão antigo (SPEC-YYYY-MM-DD-NNN) para novo
./bin/devorq spec migrate

# Após migrate, organizar nas pastas:
./bin/devorq spec move SPEC-XXXX status
```

---

## Fluxo Obrigatório v2.1

```
1. /env-context     → Detectar stack e constraints (automático)
2. /spec            → Gerar contrato detalhado → [Gate 1]
3. /break           → Decompor se complexo → [opcional]
4. /pre-flight      → Validar tipos, enums e schema → [Gate 2]
5. handoff generate → Spec para próximo LLM → [Gate 4] (se trocar LLM)
6. tdd              → RED → GREEN → REFACTOR
7. /quality-gate    → Checklist pré-commit → [Gate 3]
8. /session-audit   → Métricas (OBRIGATÓRIO)
9. /learned-lesson  → Capturar lições → [Gate 5]
10. checkpoint      → Para continuidade
```

---

## Estrutura

```
~/.devorq/                    ← GLOBAL (source único)
├── bin/devorq               ← CLI Engine
├── lib/                     ← Bibliotecas Bash
├── skills/                  ← 19 skills
├── agents/                  ← 6 agentes
├── rules/                   ← Regras globais
├── hooks/                   ← Hooks pre-commit
└── VERSION                  ← 2.1

projeto/.devorq/             ← LOCAL (minimal)
├── state/                   ← checkpoints, audits, handoffs
├── rules/                   ← regras específicas do projeto
└── version                  ← tracking de versão
```

docs/specs/          # Specs com front matter canônico
├── _index.md        # Índice automático (gerado por bin/spec-index)
├── backlog/          # Ideias brutas pendentes
├── brainstorming/   # Specs em estruturação
├── draft/           # Specs prontas para aprovação
├── approved/        # Specs aprovadas para implementação
├── planning/        # Specs em planejamento
├── in_progress/     # Specs sendo implementadas
├── validated/       # Specs validadas (testes passaram)
├── implemented/     # Specs implementadas e funcionando
├── blocked/         # Specs bloqueadas por dependência
└── archived/        # Specs arquivadas
```

---

## Arquitetura Global v2.1

### Modelo Anterior (local por projeto)
- `bin/`, `lib/`, `.devorq/skills`, `.devorq/agents` copiados para cada projeto
- Duplicação, difícil atualização

### Modelo Novo (global)
```
~/.devorq/                    ← SOURCE GLOBAL (uma instalação)
├── bin/devorq               ← CLI único
├── lib/                     ← libs compartilhadas
├── skills/                  ← 19 skills centralizados
├── agents/                  ← 6 agentes centralizados
├── rules/                   ← regras globais
└── VERSION                  ← 2.1

projeto/.devorq/             ← MINIMAL LOCAL (por projeto)
├── state/                   ← persistência específica
├── rules/                   ← regras do projeto (se houver)
└── version                  ← 2.1 (tracking)
```

### Vantagens
- **Skills atualizados uma vez** → todos os projetos usam
- **Agents centralizados** → manutenção simplificada
- **Limpeza automática** → `devorq update` remove órfãos
- **Versionamento por projeto** → cada projeto sabe sua versão

---

## Installation

### Instalação do Zero

```bash
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash
```

Isso instala o DEVORQ em `~/.devorq/` e adiciona ao PATH.

### Instalar em um Projeto

```bash
cd meu-projeto
devorq install
```

Isso cria `.devorq/state/`, `.devorq/version` — estrutura minimal (não copia bin/lib/skills).

### Atualizar DEVORQ

```bash
devorq update
```

Atualiza o global (`~/.devorq/`) e sincroniza version files em todos os projetos.
Também limpa bin/lib e .devorq/agents, skills, docs órfãos automaticamente.

### Limpeza Manual

```bash
devorq clean    # Remove bin/lib e .devorq/agents, skills, docs órfãos
```

---

## Governança de Scripts Bash

Para garantir que módulos da `lib/` operem de forma segura, o DEVORQ adota o padrão **Bash Dual-Use Source Guard** (v2.1).

Todo arquivo em `lib/*.sh` deve conter o seguinte guard no topo:

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2
    exit 1
fi
```

Isso impede a execução direta de bibliotecas de funções, garantindo que só operem via `source`.

---

## Automação no Pre-Commit

O DEVORQ utiliza dois hooks automáticos:

### pre-commit
Executa automaticamente:

1. Verificação de contrato `/scope-guard`
2. Lint (stack-aware)
3. Detecção de arquivos sensíveis (`.env`, `*.key`, `*.pem`)
4. **Movimentação de specs** — se `status` mudou no front matter, move arquivo para subpasta correspondente
5. **Regeneração do índice de specs** — se qualquer `docs/specs/*.md` estiver no staging, `bin/spec-index` é executado e o `_index.md` atualizado é incluído no commit

### prepare-commit-msg
Valida e higieniza mensagens de commit:

- **Bloqueia emojis** (🤖🚀✅❌⚠️💡🔥✨📝🎯🏆⭐💎🎉👏👍👎😅😂😍🥰😎🤔😮🙄😤🥺😱)
- **Bloqueia Co-Authored-By** (case-insensitive)
- **Permite** commits normais, merge e template

Para instalar os hooks em projetos integrados:

```bash
cp .devorq/hooks/pre-commit .git/hooks/pre-commit
cp .devorq/hooks/prepare-commit-msg .git/hooks/prepare-commit-msg
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/prepare-commit-msg
```

---

**MIT License** — @nandinhos