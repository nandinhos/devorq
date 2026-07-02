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

- [ ] **F1 — Núcleo fail-closed (clássico).** `devorq::error`→`return 1`; ajusta banner (`visual.sh`) e dica (`foundation.sh`) que não devem abortar; `cmd_flow` exporta `DEVORQ_INTENT`, rastreia falha e `return 1` + audit `fail`.
  Fecha: crítico *flow exit 0* · alta *error não aborta* · alta *intent não chega aos gates*.
- [ ] **F2 — Contadores set -e safe.** `((var++))`→`var=$((var+1))` em `gates.sh`; `|| true` nos contadores de `ci-test.sh`.
  Fecha: alta *contadores morrem sob set -e*.
- [ ] **F3 — Guard de instalação.** Guard no topo de `bin/devorq`; `README`/`INSTALL` para `git clone`.
  Fecha: crítico *curl instala CLI quebrada*.
- [ ] **F4 — GATE-2 fail-closed + Node.** Runner declarado mas ausente = FAIL; detecção Node/npm.
  Fecha: crítico *GATE-2 fail-open*.
- [ ] **F5 — Crashes de CLI.** `commit.sh` scope inválido sob `set -u`; jq quebrado em `foundation-validate.sh`.
  Fecha: alta *devorq commit unbound* · alta *GATE-0.5 jq sempre passa*.
- [ ] **F6 — jq --arg no PRD (injeção).** `prd-from-spec.sh` + `lib/auto.sh`: `jq --arg`, abortar se falhar.
  Fecha: alta seg *aspa no SPEC zera prd.json*.
- [ ] **F7 — Lessons capture (memória).** Parsear flags `--problem/--solution/...`; armazenar conteúdo cru (sanitiza no uso).
  Fecha: alta *sintaxe do README grava lixo* · alta *sanitize mutila código*.
- [ ] **F8 — AUTO headless-safe (TTY).** Guarda de TTY em todos os `read`; `failures.md` via `trap EXIT`.
  Fecha: alta *prompts interativos matam runs headless*.
- [ ] **F9 — AUTO stop-criteria + no-diff + git_commit.** Parar story após N falhas; `git status --porcelain` vazio = falha; commit detecta untracked, sem `|| true`, `guard_secrets` antes do `add -A`.
  Fecha: alta *loop infinito na mesma story* · crítico *delegate no-op vira done* · alta *commit cego a arquivos novos*.
- [ ] **F10 — Concorrência mínima.** `flock` no loop AUTO; `ctx_write` com lock+tmp local para `context.json`.
  Fecha: alta *estado sem locking*.
- [ ] **F11 — CI honesto.** `gates.spec.ts` asserta exit code; helpers E2E limpam `DEVORQ_*` do env.
  Fecha: alta *gating depende do suite mais fraco* · alta *E2E não-hermética*.
- [ ] **F12 — Miudezas.** `chmod 600` mcp.json; `date -u` no audit; `.devorq*` fora do tracking; confirmação `yes` no uninstall.
  Fecha: várias baixas.

---

## Log de Execução

<!-- uma linha por fatia concluída: F# — commit <sha> — <resultado dos testes> -->
