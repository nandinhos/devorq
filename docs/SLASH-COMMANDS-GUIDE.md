# Guia de Slash Commands — DEVORQ

> Referência rápida de todos os comandos disponíveis no Claude Code.
> Localização: `.claude/commands/` (projeto) | `~/.claude/commands/` (global)

---

## Como Usar

Digite `/` seguido do nome do comando no chat do Claude Code. Alguns comandos aceitam argumentos:

```
/devorq implementar autenticação OAuth2
/spec criar sistema de notificações
/systematic-debugging erro 500 na rota /api/users
```

---

## Comandos de Modo — Workflow Completo

| Comando | Descrição | Quando Usar |
|---------|-----------|-------------|
| `/devorq <tarefa>` | Ativa fluxo DEVORQ v2.1 completo | Qualquer task nova |
| `/devorq-laravel <tarefa>` | Modo Laravel TALL Stack | Features Laravel/Livewire |
| `/devorq-shell <tarefa>` | Modo Shell/Bash scripting | Scripts, automações |
| `/devorq-python <tarefa>` | Modo Python | Scripts, análise de dados |
| `/devorq-filament <tarefa>` | Modo Filament PHP | Admin panels, resources |
| `/devorq-start` | Inicializar projeto DEVORQ | Primeiro uso no projeto |
| `/devorq-checkpoint` | Criar checkpoint de continuidade | Antes de encerrar |
| `/devorq-audit` | Auditoria da sessão atual | Encerramento de sessão |

---

## Comandos de Skills — Uso Individual

### Planejamento

| Comando | Descrição | Gate |
|---------|-----------|------|
| `/brainstorming <tema>` | Explorar opções e trade-offs antes de decidir | — |
| `/spec <feature>` | Gerar contrato formal de escopo | Gate 1 |
| `/break <task>` | Decompor tarefa complexa em subtarefas atômicas | — |
| `/env-context` | Detectar stack, runtime, banco de dados | — |

### Implementação

| Comando | Descrição | Gate |
|---------|-----------|------|
| `/pre-flight` | Validar enums, tipos, schema antes de codar | Gate 2 |
| `/tdd <task>` | Ciclo RED → GREEN → REFACTOR | — |
| `/systematic-debugging <bug>` | Investigação metódica de bugs | — |

### Validação

| Comando | Descrição | Gate |
|---------|-----------|------|
| `/quality-gate` | Checklist obrigatório pré-commit | Gate 3 |
| `/code-review <arquivo>` | Revisão baseada em Clean Code | — |

### Transferência e Encerramento

| Comando | Descrição | Gate |
|---------|-----------|------|
| `/handoff` | Gerar spec para próximo LLM | Gate 4 |
| `/session-audit` | Métricas de eficiência da sessão | — |
| `/learned-lesson` | Documentar lição aprendida | Gate 5 |

---

## Fluxo Obrigatório v2.1

```
┌─────────────────────────────────────────────────────────────┐
│  DEVORQ FLOW v2.1                                           │
├─────────────────────────────────────────────────────────────┤
│  1. /env-context     → detectar stack (automático)          │
│  2. /spec            → contrato de escopo    [GATE 1] ✋    │
│  3. /break           → decompor (se complexo)               │
│  4. /pre-flight      → validar tipos/enums   [GATE 2] ✋    │
│  5. /tdd             → RED → GREEN → REFACTOR               │
│  6. /quality-gate    → checklist pré-commit  [GATE 3] ✋    │
│  7. /session-audit   → métricas                             │
│  8. /learned-lesson  → capturar lição        [GATE 5] ✋    │
│  9. /devorq-checkpoint → para continuidade                  │
├─────────────────────────────────────────────────────────────┤
│  Se trocar de LLM: /handoff → [GATE 4] ✋                   │
└─────────────────────────────────────────────────────────────┘
```

**Gates (✋)** = pausa obrigatória para aprovação explícita do usuário.

---

## Regras de Ouro

1. **SEMPRE** `/spec` antes de qualquer código
2. **SEMPRE** `/quality-gate` antes de commit
3. **SEMPRE** `/session-audit` + `/learned-lesson` ao encerrar
4. **SEMPRE** `/handoff` antes de trocar de LLM
5. **NUNCA** pular gates de validação
6. **NUNCA** lógica de negócio no frontend

---

## Comandos CLI (Terminal)

```bash
# Pipeline de aprendizado
./bin/devorq lessons list           # listar lições pendentes
./bin/devorq lessons validate       # preparar para validação (Context7)
./bin/devorq lessons apply <skill>  # incorporar lição numa skill

# Versionamento de skills
./bin/devorq skill version <skill> patch|minor|major
./bin/devorq skill rollback <skill> <versão>
./bin/devorq skill versions <skill>

# Handoff
./bin/devorq handoff generate       # gerar spec para próximo LLM
./bin/devorq handoff status         # status do handoff atual
./bin/devorq handoff list           # histórico

# Geral
./bin/devorq init                   # inicializar projeto
./bin/devorq context                # mostrar contexto detectado
./bin/devorq checkpoint             # criar checkpoint
./bin/devorq skills                 # listar skills e versões
```

---

## Skills Disponíveis (17)

```
brainstorming v1.0.0    → design e exploração
break v1.0.0            → decomposição de tarefas
code-review v1.0.0      → revisão baseada em Clean Code
constraint-loader v1.0.0 → carrega artefatos por tipo
env-context v1.0.0      → detecção de stack e runtime
handoff v1.0.0          → transferência multi-LLM
integrity-guardian v1.0.0 → valida padrões Livewire/Alpine
learned-lesson v1.0.0   → documenta lições
pre-flight v1.0.0       → valida tipos, enums, schema
quality-gate v1.0.0     → checklist pré-commit
schema-validate v1.0.0  → integridade de schema de banco
scope-guard v1.0.0      → contrato de escopo (alias: /spec)
session-audit v1.1.0    → métricas de eficiência
spec v1.0.0             → especificação formal
spec-export v1.0.0      → exporta spec para arquivo
systematic-debugging v1.0.0 → investigação metódica
tdd v1.0.0              → RED → GREEN → REFACTOR
```

---

## Localização dos Arquivos de Comando

```
.claude/
└── commands/
    ├── devorq.md                   # /devorq
    ├── devorq-laravel.md           # /devorq-laravel
    ├── devorq-shell.md             # /devorq-shell
    ├── devorq-python.md            # /devorq-python
    ├── devorq-filament.md          # /devorq-filament
    ├── devorq-start.md             # /devorq-start
    ├── devorq-checkpoint.md        # /devorq-checkpoint
    ├── devorq-audit.md             # /devorq-audit
    ├── spec.md                     # /spec
    ├── break.md                    # /break
    ├── pre-flight.md               # /pre-flight
    ├── quality-gate.md             # /quality-gate
    ├── tdd.md                      # /tdd
    ├── session-audit.md            # /session-audit
    ├── learned-lesson.md           # /learned-lesson
    ├── systematic-debugging.md     # /systematic-debugging
    ├── code-review.md              # /code-review
    ├── handoff.md                  # /handoff
    ├── brainstorming.md            # /brainstorming
    └── env-context.md              # /env-context
```

---

> Para instalar em outro projeto: copiar a pasta `.claude/commands/` para a raiz do projeto.
> Documentação completa das skills: `.devorq/skills/<nome>/SKILL.md`
