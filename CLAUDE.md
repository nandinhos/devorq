# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## O que é este projeto

DEVORQ é um meta-framework de orquestração de desenvolvimento assistido por LLM. Não é uma aplicação — é um framework de workflow integrado a projetos externos. Implementado em **Bash puro** (4.0+), sem dependências externas além de `git` e `jq`.

## Comandos CLI

```bash
# Fluxo principal
./bin/devorq init                        # Inicializar e detectar contexto do projeto
./bin/devorq flow "<intenção>"           # Executar workflow completo
./bin/devorq context                     # Mostrar contexto detectado
./bin/devorq checkpoint                  # Criar checkpoint de continuidade
./bin/devorq skills                      # Listar skills disponíveis com versões
./bin/devorq agent                       # Mostrar modo de agente ativo

# Handoff multi-LLM
./bin/devorq handoff generate            # Gerar spec padronizada para próximo LLM (Gate 4)
./bin/devorq handoff status              # Status do handoff atual
./bin/devorq handoff list                # Histórico de handoffs
./bin/devorq handoff update <status>     # Atualizar status do handoff

# Pipeline de aprendizado
./bin/devorq lessons list                # Listar lições pendentes/validadas/aplicadas
./bin/devorq lessons validate            # Preparar lições para validação via Context7 (Gate 6)
./bin/devorq lessons apply <nome>        # Aplicar lição numa skill (Gate 7)

# Versionamento de skills
./bin/devorq skill rollback <skill> <v>  # Reverter skill para versão anterior
./bin/devorq skill version <skill> <bump># Criar snapshot de nova versão (patch|minor|major)
./bin/devorq skill versions <skill>      # Listar versões disponíveis
```

**Validar scripts shell:**
```bash
bash -n bin/devorq                  # Syntax check no CLI principal
bash -n lib/*.sh                    # Syntax check em todos os módulos
shellcheck bin/devorq               # Linting (requer shellcheck instalado)
shellcheck lib/*.sh
```

**Instalar em outro projeto:**
```bash
cp -r .devorq /caminho/do/projeto/
cp -r bin /caminho/do/projeto/
chmod +x /caminho/do/projeto/bin/devorq
```

## Arquitetura

### Camadas do framework

```
bin/           → CLI público (entry points para usuários)
lib/           → Módulos Bash reutilizáveis (lógica interna)
.devorq/       → Configuração do workflow (agents, skills, rules, state)
prompts/       → Arquivos de ativação por LLM
```

### lib/ — Módulos principais

| Arquivo | Responsabilidade |
|---------|-----------------|
| `detect.sh` | Detecção de stack (lê composer.json, package.json, requirements.txt) |
| `core.sh` | Funções utilitárias base |
| `cli.sh` | Parsing de argumentos do CLI |
| `orchestration.sh` | Coordenação de fases do workflow |
| `orchestration/flow.sh` | Engine principal do fluxo |
| `state.sh` | Leitura/escrita de `.devorq/state/` |
| `mcp.sh` | Integração com servidores MCP |
| `feature-lifecycle.sh` | Rastreamento de ciclo de vida de features |
| `error-recovery.sh` | Recuperação de erros e fallbacks |

### .devorq/ — Configuração de workflow

**`agents/`** — 6 agentes especializados, cada um em `<stack>/SKILL.md`:
- `general/` → Orquestrador central, detecta stack e delega
- `laravel/` → Expert TALL Stack (Tailwind, Alpine, Livewire, Laravel)
- `filament/` → Expert em admin panels com Filament PHP
- `php/` → PHP puro com padrões PSR e strict types
- `python/` → Análise de dados, type hints, pytest
- `shell/` → Bash scripting com `set -eEo pipefail`

**`skills/`** — 15 skills de workflow, cada uma em `<nome>/SKILL.md` + `CHANGELOG.md` + `VERSIONS/`:
- `scope-guard/` → Gera contratos FAZER/NÃO FAZER/ARQUIVOS/DONE_CRITERIA
- `pre-flight/` → Valida tipos, enums e dependências antes de codar (chama constraint-loader)
- `env-context/` → Detecta stack, LLM, runtime, banco de dados
- `quality-gate/` → Checklist pré-commit (testes, lint, N+1, escopo, integrity-guardian)
- `session-audit/` → Métricas de eficiência + /learned-lesson obrigatório no encerramento
- `tdd/` → Ciclo RED → GREEN → REFACTOR
- `schema-validate/` → Integridade de schema de banco
- `spec-export/` → Handoff spec para troca de LLM
- `systematic-debugging/` → Investigação metódica de bugs
- `code-review/` → Revisão baseada em Clean Code
- `brainstorming/` → Fase de design/exploração
- `learned-lesson/` → Documenta lições para sessões futuras (obrigatório pós-session-audit)
- `handoff/` → Gera spec padronizada para transferência entre LLMs (Gate 4)
- `constraint-loader/` → Carrega artefatos por tipo de task antes de implementar
- `integrity-guardian/` → Valida padrões Livewire/Alpine em Blade (integrado ao quality-gate)

**`rules/stack/`** — Regras por stack:
- `laravel-tall.md` → Proibições específicas (x-show em Livewire, eager loading obrigatório, etc.)
- `python.md` → Type hints, docstrings, pytest
- `php.md` → strict_types, PSR

**`state/`** — Persistência local (git-ignored):
- `context.json` → Stack, LLM, runtime detectados
- `contracts/` → Contratos de /scope-guard
- `checkpoints/` → Snapshots para continuidade
- `session-audits/` → Histórico de métricas
- `specs/` → Specs exportadas

### Como agents e skills se relacionam

O agente detectado pelo `general/SKILL.md` carrega automaticamente as skills relevantes para a stack. Skills são independentes de agente — podem ser chamadas diretamente como slash commands. O CLI `bin/devorq flow` executa o pipeline completo coordenado pelo `orchestration/flow.sh`.

## Fluxo Obrigatório v2.0 (ao ativar qualquer `/devorq`)

```
1. /env-context          → Detectar stack e constraints (automático)
2. /scope-guard          → Contrato de escopo (OBRIGATÓRIO) → [Gate 1]
3. /pre-flight           → Validar tipos, enums e schema → [Gate 2]
4. handoff generate      → Spec para próximo LLM → [Gate 4] (se trocar LLM)
5. tdd                   → RED → GREEN → REFACTOR
6. /quality-gate         → Checklist pré-commit (OBRIGATÓRIO) → [Gate 3]
7. /session-audit        → Métricas (OBRIGATÓRIO)
8. /learned-lesson       → Capturar lições (OBRIGATÓRIO) → [Gate 5]
9. checkpoint            → Para continuidade
```

**Os 5 Gates** — pausam o fluxo para aprovação explícita do usuário:
- Gate 1: contrato de escopo | Gate 2: pre-flight | Gate 3: quality-gate
- Gate 4: handoff | Gates 5-7: pipeline de aprendizado (lição → Context7 → skill)

## Comandos Slash Disponíveis

| Comando | Ativa |
|---------|-------|
| `/devorq` | Fluxo completo |
| `/devorq-laravel` | Modo Laravel TALL |
| `/devorq-shell` | Modo Shell/Bash |
| `/devorq-python` | Modo Python |
| `/devorq-filament` | Modo Filament |
| `/devorq-start` | Inicializar projeto |
| `/devorq-checkpoint` | Criar checkpoint |
| `/devorq-audit` | Auditoria de sessão |

## Regras de Ouro

1. **SEMPRE** usar /scope-guard antes de qualquer código
2. **SEMPRE** executar /quality-gate antes de commit
3. **SEMPRE** fazer /session-audit + /learned-lesson ao final da sessão
4. **SEMPRE** usar `handoff generate` antes de trocar de LLM
5. **NUNCA** pular gates de validação
6. **SEMPRE** criar checkpoint antes de interromper

## Versionamento de Skills

Toda skill usa semver: `PATCH` para correções, `MINOR` para lições incorporadas, `MAJOR` para reescrita.

```bash
./bin/devorq skill version scope-guard minor   # cria VERSIONS/vX.Y.0.md
./bin/devorq skill rollback scope-guard v1.0.0 # reverte SKILL.md
```

## Pipeline de Auto-Aprendizado

```
/learned-lesson → [Gate 5] → lessons validate (Context7) → [Gate 6] → lessons apply → [Gate 7] → skill versionada
```

## Adicionando novos agentes ou skills

- Novos agentes: criar `agents/<nome>/SKILL.md` seguindo o padrão dos existentes
- Novas skills: criar `skills/<nome>/SKILL.md` com seções de ativação e instruções
- Registrar slash commands novos em `SLASH_COMMANDS.md`
- Atualizar `prompts/claude.md` e outros prompts se a skill deve ser auto-carregada

## MCP Integration

O projeto usa Context7 para validar contra documentação oficial. Configurado em `.mcp.json`. Use para confirmar sintaxe de APIs, versões de frameworks, existência de métodos antes de gerar código.

---

> Documentação completa: https://github.com/nandinhos/devorq
