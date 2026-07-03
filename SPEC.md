# DEVORQ v4.0.0 — Specification

> **Princípio de auto-construção:** o DEVORQ constrói a si próprio.
> Sistema operacional → usa-se para construir a si mesmo → refina → cresce.

**Versão:** 4.0.0 | **Atualizado:** 2026-07-03

---

## 1. Visão

**O que é:** Framework bash puro para metodologia de desenvolvimento sistemático.

**Funcionalidades principais:**
- Captura lições aprendidas (nunca mais o mesmo erro)
- Impõe gates bloqueantes (disciplina)
- Gera handoffs consistentes entre sessões e agentes
- Sistema de testes E2E para garantir qualidade
- Code review automatizado

**O que não é:** Uma aplicação web, plataforma fullstack, ou sistema de gerenciamento de projetos.

**Stack:**
- Bash 5+ (puro shell, sem dependências externas obrigatórias)
- jq 1.7+ (binary estático em ~/bin quando sem apt)
- Git
- SSH (para comunicação com HUB remoto via SSH mux)
- Node.js 18+ (para testes E2E opcionais)
- Playwright (para testes E2E opcionais)

**Filosofia:** O computador faz o trabalho repetitivo. O developer foca em decisões.

---

## 2. Arquitetura

### Estrutura de Diretórios

```
devorq_v3/
├── bin/
│   └── devorq                      # CLI entry point (source libs)
├── lib/
│   ├── commands/                    # Módulos de comandos CLI
│   │   ├── workflow.sh            # init, test, flow, gate
│   │   ├── lessons.sh            # capture, search, validate, approve, compile
│   │   ├── context.sh            # context, compact
│   │   ├── exploration.sh        # scope, ddd, env, spec, unify
│   │   ├── foundation.sh         # foundation
│   │   ├── integration.sh        # sync, vps, context7
│   │   ├── utils.sh             # version, upgrade, uninstall, build, stats
│   │   ├── skills.sh            # skills
│   │   ├── debug.sh             # debug
│   │   └── execution.sh         # mode, auto, review
│   ├── lessons.sh              # lessons core logic
│   ├── gates.sh                # 10 gates bloqueantes
│   ├── compact.sh              # handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh            # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check + devorq::debug (4 fases)
│   ├── stats.sh                # stats::run — métricas de uso
│   ├── vps.sh                  # vps::check|exec|pg_exec (SSH mux)
│   ├── auto.sh                # AUTO mode: lib de funções (sourceada pelo loop)
│   ├── spec.sh                # SPEC validation
│   └── unify.sh               # UNIFY phase
├── skills/                     # Skills do ecossistema
│   ├── project-foundation/    # 5W2H, Premissas, Riscos, Requisitos, Restrições
│   ├── env-context/           # Detecção automática de ambiente
│   ├── scope-guard/          # Contrato de escopo explícito
│   ├── ddd-deep-domain/       # Domain-Driven Design
│   ├── devorq-auto/          # Modo autônomo (loop-auto.sh + auto.sh)
│   ├── devorq-mode/          # Seletor AUTO/CLASSIC
│   ├── devorq-code-review/   # Code review multi-agente
│   ├── grill-with-docs/        # Sparring terminológico — CONTEXT.md + ADRs
│   └── learned-lesson/        # Gerada em runtime (gitignored)
├── scripts/
│   ├── sync-push.py          # local → HUB PostgreSQL
│   ├── sync-pull.py           # HUB PostgreSQL → local
│   ├── ci-test.sh            # Testes CI/CD
│   ├── e2e-test.sh          # Testes E2E bash
│   ├── validate-rules.sh      # Validação de diretrizes
│   └── cleanup-bin.sh         # Script de refatoração modular
├── e2e-tests/                # Testes E2E Playwright
│   ├── playwright.config.ts   # Configuração Playwright
│   ├── package.json          # Dependências Node.js
│   ├── tests/               # Suítes de testes
│   │   ├── debug.spec.ts     # Testes de debug
│   │   ├── devorq-cli.spec.ts # Testes de CLI
│   │   ├── gates.spec.ts     # Testes de gates
│   │   └── lessons.spec.ts   # Testes de lessons
│   └── reports/             # Relatórios de testes
├── .github/
│   └── workflows/
│       └── ci.yml           # CI/CD GitHub Actions
├── docs/                     # Documentação adicional
│   ├── SYSTEM_LEVANTAMENTO.md # Levantamento completo do sistema
│   ├── MELHORIAS_V3.md       # Melhorias e testes E2E
│   ├── REFATORACAO_PLANO.md  # Plano de refatoração
│   ├── PLANO_CORRECAO_CODE_REVIEW.md # Plano de correção
│   ├── COMPORTAMENTO_ESPERADO.md # Comportamento esperado
│   └── CODE_REVIEW_COMPLETO.md # Code review completo
├── .devorq/                  # Estado local (NÃO COMMITEAR)
│   ├── state/
│   │   ├── context.json     # Contexto atual do projeto
│   │   ├── session.json    # Dados da sessão corrente
│   │   ├── handoff.json   # Handoff para próxima sessão
│   │   └── lessons/       # Lições capturadas localmente
│   │       └── captured/   # Lições locais
│   ├── skills/             # Skills geradas
│   └── rules/              # Regras específicas
├── .trae/
│   └── project_rules.md     # Diretrizes do projeto
├── .devorq.bak/            # Backup antes de refatoração
├── SPEC.md                  # Esta especificação
├── README.md                # Visão geral + quick start
├── INSTALL.md               # Guia de instalação
├── EXTRAS.md                # Context-Mode, Context7, HUB, Self-Building
├── VERSION                  # Versão atual
└── prd.json                 # Product Requirements Document
```

---

## 3. Sistema de Gates

Cada gate é verde ou vermelho. **Vermelho = para e corrige.**

### Gates Implementados

```
┌────────┬────────────────────────┬──────────────────────────────────────────┐
│ GATE   │ NOME                    │ CRITÉRIO                                 │
├────────┼────────────────────────┼──────────────────────────────────────────┤
│ GATE-0 │ Exploration (opcional)  │ env-context + DDD + grill-with-docs (se CONTEXT.md existe)  │
│ GATE-0.5│ Project Foundation  │ 5W2H, Premissas, Riscos, Requisitos     │
│ GATE-1 │ Spec Exists          │ SPEC.md existe e não está vazio          │
│ GATE-2 │ Tests Pass           │ devorq test passa (estrutura OK)        │
│ GATE-3 │ Context Documented   │ devorq context mostra estado válido      │
│ GATE-4 │ Lessons Reviewed     │ devorq lessons search encontrou lições  │
│ GATE-5 │ Handoff Ready       │ devorq compact gera JSON válido          │
│ GATE-5.5│ UNIFY              │ Fase de fechamento (aviso)              │
│ GATE-6 │ Context7 Checked    │ docs consultadas (sempre passa — WARN OK)│
│ GATE-7 │ Systematic Debug    │ se erro: devorq debug antes de continuar │
└────────┴────────────────────────┴──────────────────────────────────────────┘
```

### Status dos Gates

| Gate | Status | Bloqueante |
|------|--------|------------|
| GATE-0 | ✅ Implementado | Não |
| GATE-0.5 | ✅ Implementado | Sim |
| GATE-1 | ✅ Implementado | Sim |
| GATE-2 | ✅ Implementado | Sim |
| GATE-3 | ✅ Implementado | Sim |
| GATE-4 | ✅ Implementado | Sim |
| GATE-5 | ✅ Implementado | Sim |
| GATE-5.5 | ✅ Implementado | Não |
| GATE-6 | ✅ Implementado | Não |
| GATE-7 | ✅ Implementado | Reativo |

**Nota:** GATE-6 é especial: Nunca bloqueia. É um aviso para consultar documentação. Mesmo que a API Context7 falhe ou esteja offline, GATE-6 passa.

**Nota:** GATE-7 é reativo: Só entra em ação quando há erro. Se não há erro, GATE-7 é ignorado.

---

## 4. Contextos DDD (Domain-Driven Design)

O DEVORQ usa Domain-Driven Design para estruturar o conhecimento.

### Contextos Delimitados Identificados

#### Contexto: Framework Core
**Entidades:**
- CLI (entry point principal)
- Module (módulo de comando)
- Skill (skill carregável)

**Invariantes:**
- CLI sempre carrega módulos de `lib/commands/`
- Skill deve ter `SKILL.md` válido
- Módulo deve ter `devorq::cmd_*` functions

**Serviços:**
- CLI Dispatcher (roteia comandos)
- Module Loader (carrega módulos dinamicamente)
- Skill Loader (carrega skills de `skills/`)

---

#### Contexto: Lições Aprendidas
**Entidades:**
- Lesson (lição aprendida)
- Capture (ação de capturar)
- Skill (skill compilada de lessons)

**Invariantes:**
- Lesson ID deve ser único
- Lesson deve ter title, problem, solution
- Skill compilada deve manter referência à lesson original

**Serviços:**
- Lessons::capture (captura nova lesson)
- Lessons::validate (valida com Context7)
- Lessons::approve (aprova para skill)
- Lessons::compile (compila approved → SKILL.md)

**Repositórios:**
- Lessons Repository (`.devorq/state/lessons/captured/`)
- Skills Repository (`skills/`)

---

#### Contexto: Gates e Qualidade
**Entidades:**
- Gate (checkpoint bloqueante)
- AcceptanceCriteria (critério de aceite)
- Handoff (estado para próximo agente)

**Invariantes:**
- Gate vermelho bloqueia avanço
- Todos os gates devem estar verdes antes de merge
- Handoff deve ser JSON válido

**Serviços:**
- Gate Executor (executa gate específico)
- Gate Validator (valida critério)
- Handoff Generator (gera JSON de estado)

---

#### Contexto: Automações e Integrações
**Entidades:**
- VPS Connection (conexão SSH)
- HUB Sync (sincronização com servidor)
- Context7 API (consulta documentação)

**Invariantes:**
- VPS deve ter `StrictHostKeyChecking=yes`
- Sync deve usar variáveis de ambiente seguras
- Context7 API key não deve aparecer em logs

**Serviços:**
- VPS::check (testa conexão)
- Sync Push/Pull (sincroniza com HUB)
- Context7::check (verifica API disponível)

---

## 5. Módulos de Comandos

### Comandos CLI Implementados

| Módulo | Comandos | Status |
|--------|----------|--------|
| workflow.sh | init, test, flow, gate | ✅ |
| lessons.sh | capture, search, validate, approve, compile, list, migrate | ✅ |
| context.sh | context, compact | ✅ |
| exploration.sh | scope, ddd, env, spec, unify | ✅ |
| foundation.sh | foundation | ✅ |
| integration.sh | sync, vps, context7 | ✅ |
| utils.sh | version, upgrade, uninstall, build, stats | ✅ |
| skills.sh | skills | ✅ |
| debug.sh | debug | ✅ |
| execution.sh | mode, auto, review | ✅ |

**Total de comandos:** 45+

---

## 5. Sistema de Lições Aprendidas

### Schema JSON

```json
{
  "id": "lesson_20260422_143000_12345",
  "title": "Breve título descritivo do problema",
  "problem": "Descrição clara do problema encontrado",
  "solution": "Passo-a-passo da solução aplicada",
  "stack": ["bash", "jq", "postgresql"],
  "tags": ["devorq", "container", "docker-rootless"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": false,
  "validated_at": null,
  "approved": false,
  "compiled": false,
  "skill_name": null,
  "metadata": {}
}
```

### Flags de Estado

| Flag | Significado |
|------|-------------|
| `validated: false` | Precisa de validação manual ou via Context7 |
| `validated: true` | Revisada — solução confirmada |
| `approved: false` | Pendente de aprovação para skill |
| `approved: true` | Aprovada para virar skill |
| `compiled: false` | Não compilada em skill |
| `compiled: true` | Compilada em skill |

---

## 6. Testes

### Suite de Testes CI

```bash
bash scripts/ci-test.sh
# Baseline atual: 75/75 unit (scripts/unit-tests.sh) + 36 security (scripts/security-tests.sh) + 77/77 E2E (Playwright). ci-test.sh inclui FASE 5.5 sync-version --check e FASE 5.6 e2e.
```

### Testes E2E Playwright

```bash
cd e2e-tests
npm test
# Testes de CLI, gates, lessons, context
```

### Cobertura de Testes

| Tipo | Quantidade | Status |
|------|-----------|--------|
| Unit Tests | 75/75 | ✅ |
| Security Tests | 36 | ✅ |
| E2E (Playwright) | 77/77 | ✅ |
| E2E Tests | 77 (100% deterministico) | ✅ |
| shellcheck | - | ✅ 0 errors |

---

## 7. Fases de Desenvolvimento

### Status das Fases

```
FASE 1  ████████████████████  100%  ✅  Core bash + gates + lessons
FASE 2a ████████████████████  100%  ✅  PostgreSQL schema devorq.*
FASE 2b ████████████████████  100%  ✅  Sync push/pull Python scripts
FASE 3  ████████████████████  100%  ✅  Context-Mode (lib/context.sh)
FASE 4  ████████████████████  100%  ✅  Context7 integration (lib/context7.sh)
FASE 5  ████████████████████  100%  ✅  Systematic debug (lib/debug.sh)
FASE 6  ████████████████████  100%  ✅  Documentação (README+INSTALL+EXTRAS)
FASE 7  ████████████████████  100%  ✅  Self-building (build+upgrade+uninstall)
FASE 8  ████████████████████  100%  ✅  Meta-stats (devorq stats)
FASE 9  ████████████████████  100%  ✅  Refatoração modular (lib/commands/)
FASE 10 ████████████████████  100%  ✅  Testes E2E (Playwright)
FASE 11 ████████████████████  100%  ✅  Code Review (sprint v3.8.4 + v3.8.5)
FASE 12 ████████████████████  100%  ✅  Dogfooding v3.8.5 (E2E 100% + refactors)
```

### Fase Atual: Release v4.0.0 — Elite Hardening (2026-07-03)

**Status:** Concluido (12/12 fatias) — merge para main + tag v4.0.0.

**Entregas (v4.0.0):** gates fail-closed no nivel de processo (`devorq flow` e `devorq::error`
saem `!=0`); GATE-2 fail-closed + deteccao Node (escape `DEVORQ_ALLOW_NO_RUNNER=1`); convencao
de commit unificada em `tipo(escopo)` (hook rejeita `escopo(fase)`); modo AUTO robusto (no-diff
guard, stop-criteria, flock, headless-safe) + adapters de delegacao multi-runner (claude/codex/
hermes/opencode/agy, validados end-to-end); `jq --arg` no parser de PRD (seguranca). Fonte:
docs/REFACTOR-ELITE-PLAN.md + docs/CODE_REVIEW_ELITE_2026-07-02.md.

---

### Sprint anterior: v3.8.5 dogfooding (concluido 2026-06-05)

**Status:** Concluido (100% entregue)

**Entregas (sprint v3.8.5):**
1. ✅ E2E revival: 77/77 testes Playwright passando (deterministico, 3 runs estaveis)
2. ✅ Refactor bin/devorq: 1503 → 180 LOC + 5 dispatchers (init/workflow/state/delivery/discovery)
3. ✅ Refactor lib/lessons.sh: 995 → 91 LOC + 4 modulos (crud/search/sync/validate)
4. ✅ scripts/sync-version.sh: detecta/corrige drift em 7 pontos
5. ✅ GATE-0.5 Foundation: 5 docs obrigatorios (5w2h/premissas/riscos/requisitos/restricoes)
6. ✅ F-06 grep injection regression fixed: devorq::sanitize_input restaurado

**Problemas Identificados no Code Review:**

#### Críticos (Devem ser corrigidos antes de produção)
| # | Problema | Severidade | Módulo |
|---|----------|------------|---------|
| 1 | Credenciais expostas em variáveis | 🔴 CRÍTICA | Segurança |
| 2 | SSH sem validação de host | 🔴 CRÍTICA | VPS |
| 3 | Injeção de comando | 🔴 CRÍTICA | Input validation |
| 4 | Path traversal | 🔴 CRÍTICA | File handling |

#### Altos (Devem ser corrigidos em breve)
| # | Problema | Severidade | Módulo |
|---|----------|------------|---------|
| 5 | Nomenclatura inconsistente | 🔴 ALTA | Código |
| 6 | Exit codes inconsistentes | 🔴 ALTA | Erro handling |
| 7 | Validação de input ausente | 🔴 ALTA | Input validation |
| 8 | shellcheck warnings | 🟡 MÉDIA | Código |

---

## 8. DEV-MEMORY HUB (repo separado: dev-memory-laravel)

```
VPS srv163217:6985
├── PostgreSQL
│   ├── devorq.lessons    (id, title, problem, solution, stack[], tags[], embedding, project, source, validated, applied, validated_at, metadata, created_at, updated_at)
│   ├── devorq.memories   (id, project, content, tags[], embedding, metadata, created_at, updated_at)
│   ├── devorq.sessions   (id, project, started_at, ended_at, handoff_id, summary)
│   └── devorq.handoffs   (id, from_agent, to_agent, context, created_at)
└── dev-memory-laravel    (interface web — repo separado)
```

**Acesso PostgreSQL:**
```bash
ssh -p 6985 root@187.108.197.199 "docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study -c 'SELECT * FROM devorq.lessons LIMIT 5;'"
```

---

## 9. Diretrizes de Desenvolvimento

### Diretrizes Globais

1. **Planejamento** - Sempre planeje antes da implementação
2. **Comunicação** - Use `AskUserQuestionTool` para perguntas
3. **Commits** - Nunca adicione Claude como coautor
4. **Permissões** - Peça para executar sudo
5. **Agentes** - Máximo 3 agentes simultâneos
6. **Metodologia** - Problema → Pense → Depure → Entenda → Resolva → Teste → Continue

### Diretrizes de Código

1. **Testes** - Cobertura completa após implementação
2. **Validação** - Todos os testes devem passar (verde)
3. **Commits** - Conventional Commits em português
4. **Commits** - Aguardar validação manual antes de fazer
5. **Commits** - Sem emojis
6. **Commits** - Sem co-autoria
7. **Laravel** - Use Artisan para criar arquivos

### Formato de Commits

```
tipo(escopo): descrição em português

Exemplos:
feat(gates): implementa gate 0.5 com validacao foundation
fix(lessons): corrige captura em projetos novos
docs(arquitetura): adiciona documentacao da arquitetura
test(gates): implementa testes e2e para gates
```

---

## 10. Critérios de Qualidade

### Code Review (2026-05-13)

| Aspecto | Pontuação | Status |
|---------|----------|--------|
| Estrutura | 7/10 | ⚠️ OK |
| Qualidade de Código | 5/10 | ❌ PRECISA MELHORAR |
| Performance | 7/10 | ⚠️ OK |
| Segurança | 6/10 | ❌ PRECISA MELHORAR |
| Testes | 6/10 | ⚠️ PRECISA MELHORAR |
| Documentação | 7/10 | ⚠️ OK |
| Manutenibilidade | 6/10 | ❌ PRECISA MELHORAR |

**Veredicto:** ⚠️ **APROVADO COM RESSALVAS**

O sistema funciona e atende aos requisitos básicos, mas possui **múltiplas áreas críticas** que precisam de atenção antes de produção.

### Metas de Qualidade

| Métrica | Atual | Meta |
|---------|-------|------|
| Testes | 75/75 unit + 77/77 E2E | ✅ |
| Testes E2E | 50+/50+ | 100% |
| Cobertura | ~40% | > 80% |
| shellcheck | ⚠️ Warnings | 0 warnings |
| Code smells | ⚠️ 30+ | < 10 |
| Vulnerabilidades | 0 criticas | 0 |

---

## 11. Próximos Passos

### Imediato (Esta semana)
1. ✅ ~~Corrigir vulnerabilidades de segurança críticas (#1-#4)~~ — FEITO em v3.8.3 (sec-001..004) e v3.8.4 (bc18335)
2. ✅ ~~Implementar validação de inputs em todas funções~~ — FEITO em v3.8.4 (commit 975308b)
3. ✅ ~~Padronizar nomenclatura de funções~~ — FEITO (devorq:: namespace)

### Curto prazo (2 semanas)
1. ✅ ~~Aumentar cobertura de testes para 60%+~~ — FEITO: E2E 100%, security 11/11, sync-version integrado
2. ✅ ~~Corrigir todos shellcheck warnings~~ — FEITO: 0 errors em todos arquivos modificados
3. ✅ ~~Implementar tratamento de erros consistente~~ — FEITO: exit codes padronizados

### Médio prazo (1 mês)
1. ✅ ~~Refatorar funções muito longas~~ — FEITO: bin/devorq 1503→180, lib/lessons 1045→91
2. Adicionar docblocks em funções internas restantes (parcial)
3. ✅ ~~Atualizar toda documentação~~ — FEITO: CHANGELOG/SPEC/README/PRDs/docs/specs/README atualizados
4. Adicionar GATE-E2E alcançável via `devorq gate e2e` (gap conhecido do sprint v3.8.5)
5. Rodar codex CLI review multi-agente do diff consolidado antes de merge publico

---

## 12. Recursos

### Documentação
- [README.md](file:///home/nandodev/projects/devorq_v3/README.md) - Visão geral
- [INSTALL.md](file:///home/nandodev/projects/devorq_v3/INSTALL.md) - Guia de instalação
- [EXTRAS.md](file:///home/nandodev/projects/devorq_v3/EXTRAS.md) - Features extras

### Análises
- [docs/CODE_REVIEW_COMPLETO.md](file:///home/nandodev/projects/devorq_v3/docs/CODE_REVIEW_COMPLETO.md) - Code review completo
- [docs/COMPORTAMENTO_ESPERADO.md](file:///home/nandodev/projects/devorq_v3/docs/COMPORTAMENTO_ESPERADO.md) - Comportamento esperado
- [docs/PLANO_CORRECAO_CODE_REVIEW.md](file:///home/nandodev/projects/devorq_v3/docs/PLANO_CORRECAO_CODE_REVIEW.md) - Plano de correção

### Testes
- [scripts/ci-test.sh](file:///home/nandodev/projects/devorq_v3/scripts/ci-test.sh) - Testes CI
- [e2e-tests/](file:///home/nandodev/projects/devorq_v3/e2e-tests/) - Testes E2E

---

## 13. Changelog

### v4.0.0 (2026-07-03) — Elite Hardening (breaking)
- ⚠️ BREAKING: `devorq flow` retorna exit `!=0` em gate falho (antes: sempre `0`); `devorq::error` retorna 1
- ⚠️ BREAKING: GATE-2 fail-closed (runner declarado ausente = FAIL; escape `DEVORQ_ALLOW_NO_RUNNER=1`)
- ⚠️ BREAKING: convencao de commit unificada em `tipo(escopo)` — hook rejeita `escopo(fase)`; `--phase` deprecado
- ⚠️ BREAKING: modo AUTO — delegate no-op nao vira `done`; stop-criteria; flock; headless-safe
- ✅ Adapters de delegacao multi-runner (claude/codex/hermes/opencode/agy) validados end-to-end
- ✅ Seguranca: `jq --arg` no parser de SPEC->prd; `mcp.json` 600; audit UTC
- ✅ 12 fatias de hardening (docs/REFACTOR-ELITE-PLAN.md); baseline 75/75 unit + 77/77 E2E

### v3.8.5 (2026-06-05)
- ✅ E2E suite Playwright: 77/77 = 100% (3 runs estaveis, deterministico)
- ✅ Refactor bin/devorq: 1503 → 180 LOC + 5 dispatchers
- ✅ Refactor lib/lessons.sh: 1045 → 96 LOC + 4 modulos (crud/search/sync/validate)
- ✅ scripts/sync-version.sh: detecta/corrige drift em 7 pontos
- ✅ GATE-0.5 Foundation: 5 docs obrigatorios
- ✅ F-06 grep injection: regression fixed (devorq::sanitize_input restaurado)
- ✅ Cleanup fix: ci-test.sh cleanup ordering corrigido
- ✅ CI workflow: .github/workflows/e2e.yml + FASE 5.6 + GATE-E2E

### v3.8.4 (2026-06-04)
- ✅ Whitelist SSH em 2 camadas (blocklist + whitelist por sub-comando)
- ✅ Escopo `release` documentado na whitelist de commit-convention
- ✅ Doc drift 7 → 10 gates corrigido em SPEC.md e README.md
- ✅ `devorq self-patch` removido de EXTRAS.md (feature fantasma)
- 📄 SPEC: `docs/specs/2026-06-02-code-review-corrections.md`
- 📄 Review: `docs/security-reviews/2026-06-04/SUMMARY.md`

### v3.8.3 (2026-06-01)
- ✅ Code Review Sistemático (4 vulnerabilidades: F-01 RCE, F-06 grep injection, F-02 sed injection, D-1+D-2 hook)
- ✅ Suite TDD de regressão de segurança (20 testes)
- ✅ Hook `commit-msg` auto-instalado
- 📄 `docs/security-reviews/2026-06-01/PATCHES.md`

### v3.8.2 (2026-05-28)
- ✅ Code Review Completo (17 issues corrigidas: 5 CRITICAL + 6 HIGH + 6 MEDIUM/LOW)
- ✅ Gates 0, 1, 2, 3, 4, 6, 7 funcionais (antes só 0.5 e 5.5)

### v3.8.1 (2026-05-23)
- ✅ Version sync de 3.4.0 → 3.8.1
- ✅ `GATE_BLOCKING` variável removida

### v3.8.0 (2026-05-23)
- ✅ Agent discipline (Karpathy)
- ✅ Success criteria + scope lite
- ✅ Cursor rules export

### v3.6.0 (2026-05-13)
- ✅ Refatoração modular completa (10 módulos em lib/commands/)
- ✅ Sistema de testes E2E com Playwright
- ✅ Diretrizes de desenvolvimento (.trae/project_rules.md)
- ✅ Code review completo realizado
- 🔄 Correções de code review em andamento

### v3.5.0 (2026-05-09)
- ✅ Sistema de gates expandido (GATE-0, GATE-0.5)
- ✅ Skills do ecossistema
- ✅ Project Foundation docs

### v3.4.0 (2026-05-08)
- ✅ AUTO mode (story-by-story)
- ✅ UNIFY phase
- ✅ DDD integration

### v3.3.0 (2026-05-07)
- ✅ VPS HUB integration
- ✅ Sync push/pull
- ✅ PostgreSQL schema

### v3.2.0 (2026-05-06)
- ✅ Lessons learned system
- ✅ Context7 integration
- ✅ Systematic debug

### v3.1.0 (2026-05-05)
- ✅ Core CLI
- ✅ 7 gates bloqueantes
- ✅ Handoff system

---

*Documento mantido sob controle de versão*
*Última atualização: 2026-06-04 (sprint code-review-2026-06-02 — 5 commits, 4 stories, +1 SPEC, +1 codex review)*
