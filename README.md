# DEVORQ v2.1 - Meta-Framework de Orquestração Multi-LLM

<div align="center">
  <p><strong>Automação de engenharia com contratos rigorosos, specs formalizadas e workflow validado.</strong></p>
</div>

---

## O que é o DEVORQ?

**DEVORQ** é um meta-framework de orquestração de desenvolvimento assistido por LLM. Não é uma aplicação — é um framework de workflow integrado a projetos externos.

Implemented in **Bash puro** (4.0+), sem dependências externas além de `git` e `jq`.

### Pilares da v2.1

1. **Contratos Rigorosos** — Toda tarefa começa com `/spec` → `/break` → `/scope-guard`
2. **Specs Formalizadas** — Front matter canônico com related_files e related_tasks
3. **Validação Automática** — `./bin/devorq spec status` detecta implementação via arquivos relacionados
4. **Governança de Skills** — Versionamento semver + CHANGELOG em cada skill
5. **Proteção de Sourcing** — Implementação obrigatória de *Bash Dual-Use Source Guard* em todos os módulos da `lib/`

---

## Quick Start

```bash
# Clonar
git clone https://github.com/nandinhos/devorq.git

# Integrar ao projeto
cp -r devorq/.devorq/ /caminho/do/projeto/
cp -r devorq/bin/ /caminho/do/projeto/
chmod +x /caminho/do/projeto/bin/devorq

# Verificar contexto
./bin/devorq context
```

---

## CLI Commands

```bash
./bin/devorq init                        # Inicializar projeto
./bin/devorq context                     # Mostrar contexto detectado
./bin/devorq flow "<intenção>"           # Executar workflow completo
./bin/devorq checkpoint                  # Criar checkpoint

./bin/devorq spec status                 # Listar specs e verificar implementação
./bin/devorq spec update                  # Atualizar status approved → implemented
./bin/devorq spec index                   # Gerar índice de specs

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

## Spex — Sistema de Specs

### Front Matter Canônico

```yaml
---
id: SPEC-2026-04-06-002
title: Nome da Spec
domain: arquitetura
status: draft|approved|implemented
priority: high|medium|low
owner: team-core
created_at: 2026-04-06
updated_at: 2026-04-06
source: manual
related_tasks:
  - TASK-001
  - TASK-002
related_files:
  - path/to/artifact/
  - bin/script
---
```

### Detecção de Implementação

O sistema usa critérios híbridos:
1. **Front matter válido** — status approved
2. **Contagem precisa** — related_files > 0
3. **Verificação de existência** — > 50% dos arquivos existem

```bash
./bin/devorq spec status   # Lista todas as specs
./bin/devorq spec update   # Promove approved → implemented
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
└── devorq           # CLI Engine em Bash

docs/specs/          # Specs com front matter
├── _index.md        # Índice automático
└── *.md             # Arquivos de spec
```

---

## Projetos com DEVORQ Integrado

- `eventos-control` — Laravel + Filament
- `nandorag` — App de notas com IA
- `transcriptor` — Automação de transcrição

---

## Installation

```bash
# Via clone
git clone https://github.com/nandinhos/devorq.git

# Para atualizar projeto existente
cp -r .devorq /path/to/project/
cp -r bin /path/to/project/
chmod +x bin/devorq
```

---

## Governança de Scripts Bash

Para garantir que módulos da `lib/` operem de forma segura tanto como bibliotecas quanto como ferramentas CLI, o DEVORQ adota o padrão **Bash Dual-Use Source Guard**.

Todo arquivo em `lib/*.sh` deve conter o seguinte guard no topo:

```bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0
```

Isso previne a execução acidental de lógica de interface (CLI) durante operações de `source`, mantendo a integridade do ambiente de execução.

---

**MIT License** — @nandinhos