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
./bin/devorq init                        # Inicializar projeto
./bin/devorq context                     # Mostrar contexto detectado
./bin/devorq flow "<intenção>"           # Executar workflow completo
./bin/devorq checkpoint                  # Criar checkpoint

./bin/devorq install                     # Instalar DEVORQ no projeto
./bin/devorq update                      # Atualizar DEVORQ global e replicar nos projetos
./bin/devorq activate                     # Ativar DEVORQ no projeto atual
./bin/devorq deactivate                  # Desativar DEVORQ

./bin/devorq upgrade <path>              # Atualizar DEVORQ em outro projeto

./bin/devorq spec new "título"          # Criar spec com numeração sequencial
./bin/devorq spec find "busca"          # Buscar specs por título ou ID
./bin/devorq spec status                 # Listar specs e verificar implementação
./bin/devorq spec update                # Atualizar status approved → implemented
./bin/devorq spec validate [--fix]      # Validar/Corrigir padronização
./bin/devorq spec migrate                # Migrar specs para novo padrão
./bin/devorq spec index                  # Gerar índice de specs

./bin/devorq handoff generate            # Gerar spec para próximo LLM
./bin/devorq handoff list                 # Histórico de handoffs

./bin/devorq skills                      # Listar skills disponíveis
./bin/devorq skill versions <skill>     # Listar versões de uma skill
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
domain: arquitetura | database | devops | actions | authorization | livewire | models | notifications | services | ui | backlog
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
./bin/devorq spec new "título da spec"    # Cria spec com próximo NUM sequencial
./bin/devorq spec find "busca"             # Busca fuzzy por título ou ID
./bin/devorq spec status                    # Lista todas as specs com warnings de ID
./bin/devorq spec update                   # Promove approved → implemented
./bin/devorq spec validate [--fix]         # Valida padronização (opção --fix para corrigir)
./bin/devorq spec migrate                  # Migra specs do formato antigo para novo padrão
./bin/devorq spec move <id> <status>      # Move spec para pasta de status
./bin/devorq spec index                    # Gera/regexera índice
```

### Detecção de Implementação

O sistema usa critérios híbridos:
1. **Front matter válido** — status approved
2. **Contagem precisa** — related_files > 0
3. **Verificação de existência** — > 50% dos arquivos existem

### Validação e Migração

```bash
# Validar todas as specs
./bin/devorq spec validate

# Corrigir automaticamente
./bin/devorq spec validate --fix

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
.devorq/
├── agents/          # 6 agentes especializados (laravel, filament, php, python, shell, general)
├── skills/          # 19 skills de workflow
├── rules/           # Regras por stack (laravel-tall, python, php)
├── state/           # Persistência local (context, contracts, specs)
└── templates/       # Padrões universais

bin/
├── devorq           # CLI Engine em Bash
└── spec-index       # Gerador automático do índice de specs

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

## Projetos com DEVORQ Integrado

- `gacpac-ti` — Sistema de gestão militar (Laravel + Filament)
- `eventos-control` — Laravel + Filament
- `nandorag` — App de notas com IA
- `transcriptor` — Automação de transcrição

---

## Installation

### Instalação do Zero

```bash
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash
```

Isso instala o DEVORQ em `~/.devorq/` e cria symlink em `~/.local/bin/devorq`.

### Instalar em um Projeto

```bash
cd meu-projeto
devorq install
```

Isso copia `bin/`, `lib/`, `.devorq/` para o projeto e cria `.devorq/version`.

### Atualizar DEVORQ

```bash
devorq update
```

Atualiza a instalação global e replica nos projetos.

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