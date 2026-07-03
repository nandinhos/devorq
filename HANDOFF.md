# HANDOFF — DEVORQ v4.0.0 → continuidade

> **Para quem pega o trabalho:** este é o ponto de retomada. Leia daqui até o fim
> **antes** de qualquer edição ou commit.
> Atualizado em 2026-07-03 (release v4.0.0 — Elite Hardening). Repo: `github.com/nandinhos/devorq_v3` · branch `main`.

---

## 0. Como usar este handoff

1. O Codex carrega `AGENTS.md` automaticamente a cada turno — ele tem os
   **inegociáveis** (formato de commit, proibições). Este `HANDOFF.md` é o
   **snapshot de estado**: cole-o como primeiro prompt da sessão Codex.
2. Rode o Codex em modo que **permita editar** (`--sandbox workspace-write`,
   approval interativo). O uso anterior do Codex neste repo foi só review
   (`sandbox=read-only`); para desenvolver isso não basta.
3. Antes de codar, leia: este arquivo → `AGENTS.md` → `SPEC.md` (escopo) →
   `docs/auditoria-tecnica-2026-06-26.md` (dívida técnica, por ID `DQ-xxx`).

---

## 1. TL;DR do estado

- **DEVORQ é um orquestrador de agentes em Bash** (`bin/devorq` + `lib/` + `scripts/`).
  Não é app Laravel — apesar da skill `laravel` poluindo o `skills/` (ver §8).
- **Release v4.0.0 (Elite Hardening) na `main`**: 12 fatias de hardening + F13
  (convenção `tipo(escopo)`) + adapters de delegação multi-runner. Fonte:
  `docs/REFACTOR-ELITE-PLAN.md` + `docs/CODE_REVIEW_ELITE_2026-07-02.md`.
- **Backlog anterior fechado: DQ-001..DQ-030, 30/30** (`docs/auditoria-tecnica-2026-06-26.md`).
- **CI verde + E2E 77/77 verde e estável** (ver §5). O `main` está estável.
- **Próximo milestone:** os itens de médio/estratégico prazo do
  `docs/REFACTOR-ELITE-PLAN.md` (verificação por AC executável, unificação dos 2
  motores AUTO, rollback por snapshot, sandbox skip-permissions).

**Veredito da auditoria (resumo):** a casca do DEVORQ é boa (router/dispatcher
real, hardening de input sólido), mas o histórico apontava um núcleo de execução
"teatro" (verde ≠ verificado). As correções DQ-001..030 atacaram exatamente isso
(fail-closed no AUTO, fim do wipe de `prd.json`, gates persistidos, observabilidade
real). Releia o §1 da auditoria para o contexto completo — **não confie em memória,
leia o arquivo.**

---

## 2. Duas camadas — o Codex só herda UMA

| Camada | O quê | Codex usa? |
|--------|-------|------------|
| **Portável (CLI Bash)** | `bin/devorq`, `lib/`, `scripts/` | ✅ **Sim — opere por aqui** |
| **Skills do Claude Code** | `skills/devorq-auto`, `skills/devorq-mode`, etc. (invocadas via *Skill tool*) | ❌ Não — Codex não tem Skill tool |

➡️ **Dirija tudo via CLI** (`bin/devorq <cmd>`), nunca via skills. As skills são
adaptadores do Claude Code; a lógica canônica vive em `lib/`/`scripts/`.

### Modo AUTO (delegate multi-runner)
O modo AUTO (story-by-story) depende do contrato `DEVORQ_DELEGATE_FN`. Desde v4.0.0
há **adapters funcionais para 5 runners**, validados end-to-end (claude, codex,
hermes, opencode, agy): use o dispatcher `scripts/adapters/delegate.sh` com
`DEVORQ_RUNNER=<runner>` (ou os wrappers `<runner>-delegate.sh`). Contrato e casos
de uso: `AGENTS.md` §"Contrato de delegação" + `docs/DELEGATE-ADAPTERS.md`. O loop
é **fail-closed**: delegate que não produz diff **não** marca a story como done;
story que falha vira `failed` após `DEVORQ_AUTO_MAX_STORY_FAILURES`; use
`DEVORQ_AUTO_YES=1` em headless. Para desenvolvimento manual, use o fluxo CLASSIC
(gates) — ver §4.

---

## 3. Convenções inegociáveis (resumo — fonte: `AGENTS.md`)

- **Commit**: 1ª linha casa `^(feat|fix|refactor|docs|test|style|perf|chore)\([a-z]+\):`
  → `tipo(escopo): descrição` (F13/v4.0.0 — o tipo agora é validado; o antigo
  `escopo(fase)` é **rejeitado**). Sem espaço antes do `(`. IDs (`DQ-031`) vão no
  **fim da descrição**. O hook `.git/hooks/commit-msg` **bloqueia** o que fugir.
- **Sem `Co-Authored-By:`** (hook bloqueia). **Português do Brasil.**
- **Sem refatoração fora de escopo. Sem features especulativas.**
- ⚠️ O `CLAUDE.md` global (commit *com* espaço) **não vale aqui** — o hook manda.

---

## 4. Fluxo de trabalho recomendado (CLASSIC, via CLI)

```bash
devorq init                 # bootstrap de regras + hook commit-msg (idempotente)
# edite .devorq/state/context.json: intent + success_criteria
devorq scope lite "<intent>"   # contrato mínimo antes de codar
# ... implemente ...
devorq flow                 # gates 1–7 (use --resume para retomar)
devorq verify
devorq commit               # confirmação [Y/n]; respeita o hook
```

---

## 5. Como VERIFICAR (rode você mesmo — não confie em contagens)

```bash
bash bin/devorq test            # suíte unit (NÃO use grep para filtrar!)
bash scripts/ci-test.sh         # espelha o CI; leia o sumário Pass/Fail INTEIRO
bash scripts/sync-version.sh --check   # drift de versão entre VERSION/CHANGELOG/etc.
bash scripts/security-tests.sh  # path traversal, SSH, SQLi, sanitize
```

- **Baseline v4.0.0: 75/75 unit + 36 security + 77/77 E2E** (estável, determinístico).
  Ainda assim: rode e leia o sumário completo. **Lição da auditoria:** 2 regressões
  de CI escaparam porque alguém filtrou a saída com `grep`. **Veja Pass/Fail inteiro.**
- **E2E é VERDE (77/77)** e estável desde o elite-hardening. Vermelho agora é
  **regressão real** — investigue, não ignore. `e2e.yml` está a caminho de required check.

### ⚠️ Poluição de estado ao rodar suites
Rodar as suites **suja** `.devorq/state/lessons/captured/` (e pode gerar
`skills/<algo>/` auto-gerado). **Sempre** restaure depois:

```bash
git checkout -- .devorq/state/ ; git clean -fdn   # confira o que seria removido
```

Não commite esse lixo. (É a provável origem do `skills/laravel/` atual — ver §8.)

---

## 6. O que está FEITO

- **v4.0.0 Elite Hardening (12 fatias):** gates fail-closed no nível de processo
  (`devorq flow` e `devorq::error` saem `!=0`); GATE-2 fail-closed + Node; F13
  convenção `tipo(escopo)`; AUTO robusto (no-diff guard, stop-criteria, flock,
  headless-safe); adapters multi-runner (claude/codex/hermes/opencode/agy);
  `jq --arg` no parser de PRD. Detalhe: `docs/REFACTOR-ELITE-PLAN.md`.
- Backlog auditoria **DQ-001..DQ-030: 30/30** (Apêndice D da auditoria). Highlights:
  fim do wipe de `prd.json` (DQ-004), AUTO fail-closed (DQ-005), `gates_completed`
  persistido + `flow --resume` (DQ-007), trilha JSONL (DQ-018), guard de segredos
  (DQ-014/015), `DEVORQ_GATE_SEQUENCE` fonte única (DQ-028).
- `main` com CI verde; `.devorq/version` e `VERSION` em **4.0.0**.

---

## 7. O que está EM ABERTO (honesto — defina o milestone)

> DQ-022 (adapter não-Hermes) e o E2E verde+gating **foram entregues** na v4.0.0.
> O locking concorrente também (flock, F10). Os itens residuais agora são o
> **roadmap médio/estratégico** do `docs/REFACTOR-ELITE-PLAN.md`, em ordem de valor:

1. **Verificação por AC executável** — o gate `check-story.sh` roda a suite do
   projeto mas **não valida os acceptanceCriteria** da story; hoje quem garante
   trabalho real é o no-diff guard. Adicionar validação por critério é a maior
   alavanca de confiança do AUTO overnight.
2. **Unificar os 2 motores AUTO** (`lib/auto.sh` vs `skills/devorq-auto/scripts/loop-auto.sh`)
   — evitar divergência (o loop-auto é o ativo; lib/auto.sh é resíduo).
3. **Rollback por snapshot git** + **sandbox opt-in** para o delegate
   skip-permissions (execução de código não confiável com as credenciais do usuário).
4. **Higiene imediata** (ver §8).

**Pendente do dono:** priorizar entre (1) verificação por AC, (2) unificação AUTO,
(3) rollback/sandbox, ou nova feature de produto.

---

## 8. Higiene imediata (faça antes de começar feature)

- **`skills/laravel/` + `skills/.index.md` (untracked) = CRUFT.** A lição `l1`
  tem title `"T"`, problema `"p"`, solução `null` — placeholder gerado num test
  run (05:42). **Não commite.** Remova:
  ```bash
  git clean -fdn   # revise
  git clean -fd skills/laravel skills/.index.md
  ```
- **Branches locais `fix/auditoria-*`** já foram integradas na `main` — podem ser
  podadas (`git branch -d` após confirmar merge).

---

## 9. Mapa rápido do código

| Caminho | Papel |
|---------|-------|
| `bin/devorq` | Entry point / dispatcher CLI |
| `lib/commands/`, `lib/dispatchers/` | Roteamento comando→módulo (1 dispatcher por módulo) |
| `lib/gates.sh` | Gates + `DEVORQ_GATE_SEQUENCE` (fonte única) |
| `lib/auto.sh`, `skills/devorq-auto/scripts/loop-auto.sh` | Modo AUTO (loop story-by-story) |
| `lib/context.sh` | Estado em `.devorq/state/context.json` (`gates_completed`, `run_id`) |
| `lib/commit.sh` | Commit seguro (guard de segredos, confirmação) |
| `lib/vps.sh`, `scripts/sync-*.py` | VPS/HUB sync (SQL parametrizado, sem root hardcoded) |
| `lib/context7.sh`, `lib/lessons/` | Validação Context7 + lições aprendidas |
| `scripts/*-tests.sh`, `scripts/ci-test.sh` | Suítes de teste (ver §5) |
| `docs/auditoria-tecnica-2026-06-26.md` | **Dívida técnica completa, IDs DQ-xxx / R-xx** |

---

*Dúvida de priorização: rastreie tudo pelos IDs `DQ-xxx` (§10 da auditoria) e
`R-xx` (§9 da auditoria). Em caso de conflito entre docs e código, **o código e o
hook são a verdade** — docs podem estar com drift.*
