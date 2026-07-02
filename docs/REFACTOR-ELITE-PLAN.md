# Plano de Refatoração — DEVORQ Elite Hardening

> Branch: `refactor/elite-hardening` · Base: `main` (v3.8.5) · Início: 2026-07-02
> Origem: [`docs/CODE_REVIEW_ELITE_2026-07-02.md`](CODE_REVIEW_ELITE_2026-07-02.md)
>
> **Documento vivo.** Cada fatia: aplicar → testar (`scripts/unit-tests.sh` + check próprio) → commit → marcar aqui.
> Baseline: **75/75 unit tests verdes** antes da fatia 1.

## Princípio-guia

O tema central do review: o produto é **fail-open** onde promete ser **fail-closed**.
A raiz é `devorq::error` retornar 0. Estas fatias fazem o que já existe **falhar de verdade quando está vermelho**, com o menor diff correto. Sem redesign.

## Escopo desta leva: QUICK WINS

Itens de médio/estratégico prazo (adapters claude/codex, rollback por snapshot, sandbox
skip-permissions, verificação por story, unificação dos motores AUTO) ficam **fora** desta
branch — entram em planejamento próprio após aprovação. Guardrails duros do
`--dangerously-skip-permissions` **não** são aplicados aqui (mudam runtime; exigem ok explícito).

---

## Checklist de Fatias

- [x] **F1 — Núcleo fail-closed (clássico).** `devorq::error`→`return 1`; ajusta banner (`visual.sh`) e dica (`foundation.sh`) que não devem abortar; `cmd_flow` exporta `DEVORQ_INTENT`, rastreia falha e `return 1` + audit `fail`.
  Fecha: crítico *flow exit 0* · alta *error não aborta* · alta *intent não chega aos gates*.
- [x] **F2 — Contadores set -e safe.** `((var++))`→`var=$((var+1))` em toda a classe de runtime (gates.sh, context.sh, debug.sh, ci-test.sh, grill-refine.sh); cmd_build (utils.sh) não aborta no 1º gate falho e reporta contagem honesta.
  Fecha: alta *contadores morrem sob set -e* · alta *build aborta sem sumário*.
- [x] **F3 — Guard de instalação.** Guard no topo de `bin/devorq` (falha cedo com instrução); `README` Quick Start + `INSTALL` (seções sem-clone e Docker) migrados para `git clone` + symlink.
  Fecha: crítico *curl instala CLI quebrada*.
- [x] **F4 — GATE-2 fail-closed + Node.** Runner declarado mas ausente = FAIL (Python/PHP), com escape `DEVORQ_ALLOW_NO_RUNNER=1`; detecção Node/npm (`npm test`).
  Fecha: crítico *GATE-2 fail-open*.
- [x] **F5 — Crashes de CLI.** `commit.sh` scope/phase inválido sob `set -u` (fallback `:-`); jq com `)` extra em `foundation-validate.sh` reescrito (contava sempre 0).
  Fecha: alta *devorq commit unbound* · alta *GATE-0.5 jq sempre passa*.
- [x] **F6 — jq --arg no PRD (injeção).** `prd-from-spec.sh` + `lib/auto.sh`: critério via `jq --arg` (dado, não programa) + abort se jq falhar.
  Fecha: alta seg *aspa no SPEC zera prd.json*.
- [x] **F7 — Lessons capture (memória).** Parser de flags `--problem/--solution/--stack/--tags` (+ compat posicional); conteúdo gravado cru (jq --arg já escapa; só limite de tamanho).
  Fecha: alta *sintaxe do README grava lixo* · alta *sanitize mutila código*.
- [x] **F8 — AUTO headless-safe (TTY).** `can_prompt()` (TTY + `DEVORQ_AUTO_YES`) nos 3 prompts do loop + `visual.sh`; default headless = pular+continuar; `failures.md` via `trap EXIT`.
  Fecha: alta *prompts interativos matam runs headless*.
- [x] **F9 — AUTO stop-criteria + no-diff + git_commit.** `mark_failed` após `DEVORQ_AUTO_MAX_STORY_FAILURES` (2) tentativas; no-diff via assinatura antes/depois do delegate; commit por porcelain (vê untracked) + secret-scan inline antes do `add -A` + `return 1` real; `ensure_branch` aborta em falha de checkout.
  Fecha: alta *loop infinito na mesma story* · crítico *delegate no-op vira done* · alta *commit cego a arquivos novos*.
- [x] **F10 — Concorrência mínima.** `ctx_set` com tmp local (rename atômico) + `flock`; `flock -n` de run único por projeto no loop AUTO.
  Fecha: alta *estado sem locking*.
- [x] **F11 — CI honesto.** `gates.spec.ts` asserta `exitCode` no par GATE-1 (fixture SPEC ≥100b); `security-e2e` reescrito p/ segurança real (input inerte, não mutilado); `runCommand` com env hermético (sem `DEVORQ_*`). Corrigida regressão do F9 (`git diff HEAD` 128 em repo sem commits).
  Fecha: alta *gating depende do suite mais fraco* · alta *E2E não-hermética* · seg *security-tests teatro*.
- [x] **F12 — Miudezas.** `chmod 600` no mcp.json; `date -u` no audit (Z era hora local); uninstall exige `yes` + guarda de TTY + sem mensagem falsa; estado efêmero untrackado + gitignorado (rules/lessons seed preservadas).
  Fecha: várias baixas.

---

## F13 — Convenção de commit (PROPOSTA — aguardando validação)

> Pedido do usuário: arrumar a causa raiz na fonte. **Não executado** — decisão de
> formato pendente (perguntei, usuário ausente). Feedback #1: sugerir antes de mexer
> em fluxo/decisão. Pronto para rodar assim que confirmar o modelo.

**Causa raiz:** duas semânticas concorrentes, ambas passando pelo hook permissivo
`^[a-z]+\([a-z]+\):` — `devorq commit`/AUTO produzem `escopo(fase)` (`core(impl):`),
enquanto os exemplos da doc + CLAUDE.md global + os commits desta branch usam
`tipo(escopo)` (`fix(gates):`). `commit-convention.md` se contradiz (formato diz
`escopo(fase)`, exemplos mostram `tipo(escopo)`).

**Recomendação: Model A — convencional `tipo(escopo)`** (alinha com o CLAUDE.md global do
usuário e a convenção universal). Mudanças, todas numa fatia:
1. `commit-convention.md` (e cópia em `.devorq/rules/`): trocar linha de formato para
   `tipo(escopo): descrição`; substituir tabela "Fases válidas" por "Tipos válidos"
   (feat/fix/refactor/docs/test/style/perf/chore); manter tabela de escopos.
2. `.git/hooks/commit-msg` + o template que o bootstrap instala: apertar regex para
   `^(feat|fix|refactor|docs|test|style|perf|chore)\([a-z]+\):`.
3. `lib/commit.sh`: prompt/flag `phase`→`type`, `VALID_PHASES`→`VALID_TYPES`, saída
   `${scope}(${phase})`→`${type}(${scope})` (linhas 267/269/395). **Mudança de interface
   do `devorq commit`.**
4. AUTO `loop-auto.sh:563` e `lib/auto.sh:268`: `${scope}(impl)`→`feat(${scope})`.
5. `~/.claude/CLAUDE.md` (global): remover colchetes/espaço do exemplo (o hook rejeita
   `[feat] (x):`) — deixar `feat(escopo): descrição`.

**Alternativa: Model B — `escopo(fase)`** (menor diff: só corrige os exemplos da doc +
aperta o hook para escopos/fases; `devorq commit`/AUTO já produzem isso). Diverge do
CLAUDE.md global e dos commits desta branch.

## Log de Execução

<!-- uma linha por fatia concluída: F# — commit <sha> — <resultado dos testes> -->
- **F1** — commit `c17063a` — 75/75 unit + check runnable OK (flow sem intent → exit 1; flow c/ gate falho → exit 1, sem "Flow completo!"). Nota: hook `commit-msg` exige `tipo(escopo):` sem espaço (contradiz docs → reconciliar em fatia futura).
- **F2** — commit `b97a100` — 75/75 unit + build chega ao sumário (7/7) + check isolado do path de falha (laço conta 7/7 sem abortar no 1º).
- **F3** — commit `47e2aba` — 75/75 unit + check runnable OK (bin/devorq isolado → erro acionável; instalação normal → `DEVORQ v3.8.5`).
- **F4** — commit `992a1e3` — 75/75 unit + 6 cenários (Python/PHP/Node fail-closed, escape hatch, Node OK, repo sem regressão).
- **Checkpoint pós-F4** — E2E Playwright **77/77** (gate real de CI) verde; trace `|| devorq::error` confirmou só o caso desejado (upgrade). Confirmada poluição de estado do E2E (`.devorq/state/*.json`) → restaurada; reforça F11 (hermeticidade) e F12 (`.devorq` fora do tracking).
- **F5** — commit `7249ac5` — 75/75 unit + checks (jq conta 2 sem-criteria; scope inválido não crasha sob set -u).
- **F6** — commit `fb5c75f` — 75/75 unit + check (SPEC com aspas/`$()`/backtick → prd.json válido, critérios literais).
- **F7** — commit `b05419a` — 75/75 unit + checks (flags README parseadas; código `$()`/`[]`/`${}` preservado cru; posicional compatível).
- **F8** — commit `5572a26` — 75/75 unit + check headless E2E (loop com delegate falho: exit 0 sem hang, sem "Abortado", pulou via default, failures.md via trap).
- **F9** — commit `d1555c7` — 75/75 unit + 5 checks E2E (no-diff na 1ª iteração c/ árvore pré-suja; loop termina via stop-criteria; secret-scan bloqueia .env; untracked commitado formato `core(impl):`; nada-a-commitar → 0).
- **F10** — commit `e1a9864` — 75/75 unit + checks (20 escritas concorrentes → 21/21 campos íntegros; 2º run AUTO bloqueado pelo lock).
- **F11** — commits `c97c539` (fix F9) + `4456603` — E2E **77/77** verde; gates.spec asserta exit code, security-e2e testa segurança real, env hermético. E2E pegou regressão do F9 (exit 128) — corrigida.
- **F12** — commit `b1cf627` — 75/75 unit + checks (audit UTC real; uninstall não-interativo não remove; mcp.json 600; estado efêmero untrackado).

## Status: 12/12 fatias concluídas ✅

Todos os 4 findings críticos + as altas priorizadas fechadas. Validação final: **75/75 unit + 77/77 E2E + shellcheck limpo**.

**Validação do AUTO em ambas as direções** (além dos checks de falha por fatia):
- Sucesso ponta a ponta: delegate com diff real → no-diff passa → check-story passa → `mark_pass` (done) → `git_commit` → exit 0, `status=done`, exatamente 1 commit `core(impl):`. ✓
- Falha: delegate no-op → no-diff detectado (não done); delegate sempre falha → termina via stop-criteria; headless não trava nem morre; 2 runs concorrentes → 2º bloqueado.
- `gate 0` com o branch grill agora vivo (via export DEVORQ_INTENT da F1): exit limpo para intents `implementar` e `fix`.
- **Ressalva:** o pipeline foi exercitado com delegate simulado (script que gera diff). A delegação a um LLM real (claude/opencode) — qualidade do prompt e do código gerado — não foi testada; é inerente (exige API/LLM) e cabe aos adapters do roadmap estratégico.
Fora de escopo desta branch (planejamento próprio): adapters claude/codex, rollback por snapshot git, sandbox skip-permissions, verificação por story (AC executável), unificação dos dois motores AUTO, reconciliação de rules/skills. Ver roadmap médio/estratégico em `CODE_REVIEW_ELITE_2026-07-02.md`.
