# HANDOFF — DEVORQ v4.1.0 → continuidade

> **Para quem pega o trabalho:** este é o ponto de retomada. Leia daqui até o fim
> **antes** de qualquer edição ou commit.
> Atualizado em 2026-08-31 (audit de qualidade + fixes C1–C5, M8, T1). Repo: `github.com/nandinhos/devorq` · branch `main`.

---

## 0. Como usar este handoff

1. O próximo agente carrega `AGENTS.md` automaticamente (inegociáveis: formato de commit, proibições) e, no DSH, a skill `devorq`. Este `HANDOFF.md` é o **snapshot de estado** — use como contexto inicial.
2. Antes de codar, leia: este arquivo → `AGENTS.md` → `SPEC.md` (escopo). A dívida técnica histórica está em `docs/auditoria-tecnica-2026-06-26.md` (IDs `DQ-xxx`); o **novo** roadmap de qualidade desta sessão está em §2.
3. **Ambiente DSH:** o plugin DEVORQ está instalado em `~/.dsh` (skill em `~/.dsh/skills/devorq/`, preset em `~/.dsh/.agent-presets/devorq/`). A composição do preset **só recarrega em nova sessão DSH** (generation por mtime/size do `agent.cordis.yml`) — abra uma nova sessão neste repo para usar o estado atual.

---

## 1. TL;DR do estado (v4.1.0)

- **DEVORQ é um orquestrador de agentes em Bash** (`bin/devorq` + `lib/` + `scripts/` + `skills/`). Não é app Laravel.
- **Foi feito nesta sessão (commits na `main`):**
  - `f4fbf0d` **fix(auto): bloqueia falso sucesso terminal no loop AUTO (C1-C4)**
  - `8075ffe` **test(security): corrige asserts de falso sucesso na suite de seguranca (T1)**
  - `d11f286` **feat(dsh): skill devorq canonica + plugin reproduzivel via install-dsh-preset.sh (C5,M8)**
- **CI / suites verdes** nesta sessão: `unit-tests.sh` 75/75, `security-tests.sh` ALL PASSED, `tests/auto/test-loop-terminal-safety.sh all` 8/8, `tests/loop/test-loop-implementation.sh` pass, `tests/contracts/test-contracts.sh` 14/14. Ver §4.
- **Estado do plugin DSH:** skill `devorq` em `~/.dsh/skills/devorq/SKILL.md` (root user-dsh, rank 400 — já no catálogo); preset `~/.dsh/.agent-presets/devorq/` sem `customSkillDirs`. Reproduzível via `bash scripts/install-dsh-preset.sh` (idempotente).

---

## 2. Achados do audit (gaps de qualidade) — roadmap priorizado

> Audit somente-leitura em 6 superfícies (metodologia/docs, CLI/bash, pipeline AUTO, skills, testes, integração DSH). Bloco 1 + C5 já tratados. Restam, em ordem de valor:

**🔴 Bloco 3 — consistência de superfície (PRÓXIMO):**
- **M4** — convenção `escopo(fase)` **stale** no código; a canônica é `tipo(escopo)` (F13/v4.0.0): `lib/visual.sh:402`, `lib/rules.sh:218,232,592,598`, `lib/commit.sh:4`, `lib/dispatchers/delivery.sh:30`, `deliverable.md:88`. (O hook rejeita `escopo(fase)`.)
- **M5** — help do `bin/devorq` omite 7 comandos implementados (`brainstorm, build, context7, env, grill, spec, uninstall`); header-comment omite `loop`/`verify`; `devorq::cmd_version` é dead code (o router resolve `version` inline em `:187`). Regenerar help do `case`/lista `devorq::cmd_*`; rotear `version`.
- **M9** — `skills/security-hardening/SKILL.md` **sem frontmatter** (`name`/`description`) → não é skill DSH válida. Adicionar frontmatter.
- **M10** — drift `delegate.sh` (`DEVORQ_MODEL/TIMEOUT/DRY_RUN`) vs `opencode-delegate.sh` (`OPENCODE_*`); prompt duplicado. Tratar `OPENCODE_*` como alias do contrato `DEVORQ_*`.

**🟠 Bloco 4 — consistência metodológica:**
- **M1** — versão fragmentada: `VERSION`=4.1.0, mas `rules/commit-convention.md:1`="v3.6.5+", `rules/visual-verification.md`="v3.6.5+", `HANDOFF.md`(antigo)/`e2e-tests/RESULTADOS_TESTES.md`/`CODE_REVIEW_MATURITY_REPORT.md` referenciam v3.x. `.devorq/rules/` tem só 3 de 7 regras e `agent-discipline.md` local = **v4.0.0** (canônica v4.1.0).
- **M2** — G-6 existe (Context7, `lib/gates.sh:458`) mas `commit-convention.md:15` o chama de "manual verification gate"; `AGENTS.md:41`/`agent-discipline.md:76` "Gates 1–7" pulam G-6 e ignoram G-0/G-0.5/G-5.5 (que existem em `lib/gates.sh`).
- **M3** — `rules/manual-commit.md` ("nunca commitar sem aprovação") contradiz o modo AUTO (`DEVORQ_AUTO_COMMIT=1`, commit por story). Falta a exceção AUTO + precedência.

**🟡 Bloco 5 — robustez:**
- **M6** — filosofia "jq opcional" violada: `lib/commands/brainstorm.sh`(11), `grill.sh`(15), `lib/commit.sh`(4), `lib/rules.sh` usam `jq` sem `devorq::contracts::require_jq`.
- **M7** — portabilidade GNU/BSD/macOS: `timeout` (`delegate.sh:139`, `gates.sh:538`), `realpath -q` (`helpers.sh:45,50`, `vps.sh:61,65`), `readlink -f` (`e2e-test.sh:11`) ausentes no macOS.
- **M12/M13** — `lib/loop.sh:157-159` valida só `-z "$executor"` (não `-x`); `exit_code` do contrato v1 hardcoded; `mark_skip` (`loop-auto.sh`) faz `mv` sem validar JSON; `MAX_DELEGATE_RETRIES=1` (retry morto); `progress.txt` não excluído do commit.

**Baixos (higiene):** references órfãs (`devorq-auto/references/prd-schema.json`, `env-context/references/laravel-filament.md`, `scope-guard/references/laravel-filament-scope.md`); `skills/README.md:27` lista `learned-lesson` inexistente; `devorq-code-review` "8 fases" vs 9 (FASE 8 pós-review); `mode-selector.sh` fora de `scripts/`; versão `devorq-auto` inconsistente (SKILL.md v1.2.0/1.1.0/1.0.0 vs script v1.2.1); mojibake em `rules/brainstorm.md:17` (采纳) e `rules/grill.md:52` ("nãoaceita"); `INSTALL.md` typos (caminho `~/devorq` na desinstalação, "afficher", "Manenha", "|| Sintoma"); `e2e-tests/RESULTADOS_TESTES.md` stale (v3.8.5, "16 arquivos" vs real 7); `unit::skip` chamado mas **não definido** em `unit-tests.sh`; `systematic_debug` é stub (security-tests.sh/pipeline-tests.sh).

---

## 3. Decisões e porquês (para não re-discutir)

- **Skill do plugin DSH em `~/.dsh/skills/` (user-dsh), NÃO `customSkillDirs` no preset.** O provider `dsh-skill-filesystem` não varre o dir do preset; `customSkillDirs` apontando para `/.agent-presets/<id>/skills` hardcoda o id e **quebra em cópia** do preset (copy é whole-directory). User-dsh (rank 400) é auto-descoberto e robusto. Fonte canônica no repo `skills/devorq/SKILL.md` + installer idempotente.
- **C4 foi defensivo:** `devorq::auto::git_commit` é **dead code** (o fluxo guiado usa `devorq::commit`, que tem guard_secrets+confirmação+hook+rc). Por isso tornei a função fail-closed (por-path, sem `add -A`/`--no-verify`/`|| true`) em vez de apenas mencionar.
- **C3 é robustez/consistência, não bug hard:** como `mark_pass` sempre altera `prd.json`, o `git_commit` já commitava o index inteiro (incluindo staged). O fix (`commit_paths` incluir `--cached`) é pró-ativo/correto; o teste é asserção do comportamento, não red→green.
- **Testes C1/C2 são red→green comprovados** (revert e confirmou falha). C3 é asserção positiva.

---

## 4. Como VERIFICAR (baseline atual — rode você mesmo, veja sumário inteiro)

```bash
bash scripts/unit-tests.sh                  # 75/75
bash scripts/security-tests.sh              # ALL PASSED
bash tests/auto/test-loop-terminal-safety.sh all   # 8/8
bash tests/loop/test-loop-implementation.sh # pass
bash tests/contracts/test-contracts.sh      # 14/14
bash scripts/install-dsh-preset.sh --dry-run # DSH installer (dry-run, no-write)
```

> **Lição da auditoria:** não filtre a saída com `grep` para "ver só o Pass" — regressões escaparam assim. Leia Pass/Fail inteiro.
> Suites herméticas criam repositórios temporários; não poluem o repo. `scripts/ci-test.sh` espelha o CI.

---

## 5. Próximo passo concreto (sugerido)

**Bloco 3 — M4 + M5** (rápido, alto impacto de consistência):
1. Substituir as mensagens `escopo(fase)` → `tipo(escopo)` em `lib/visual.sh:402`, `lib/rules.sh:218,232,592,598`, `lib/commit.sh:4`, `lib/dispatchers/delivery.sh:30`, `deliverable.md:88`.
2. Regenerar `devorq::help` do `bin/devorq` a partir do `case`/lista `devorq::cmd_*`; rotear `version` p/ `devorq::cmd_version` e remover o builtin (ou o inverso). Adicionar um teste garantindo que todo comando do `case` aparece no help.
3. **M9:** adicionar frontmatter (`name: security-hardening`, `description`, `metadata`) a `skills/security-hardening/SKILL.md` e remover duplicação no corpo.
4. **M10:** tratar `OPENCODE_*` como alias do contrato `DEVORQ_*` em `delegate.sh`/`opencode-delegate.sh`.

Commit (convenção): `fix(core): ...` / `docs(core): ...` / `fix(dsh): ...`.

---

## 6. Mapa rápido do código

| Caminho | Papel |
|---------|-------|
| `bin/devorq` | Entry point / dispatcher CLI |
| `lib/commands/`, `lib/dispatchers/` | Roteamento comando→módulo |
| `lib/gates.sh` | Gates + `DEVORQ_GATE_SEQUENCE` (fonte única) |
| `lib/auto.sh`, `skills/devorq-auto/scripts/loop-auto.sh` | Modo AUTO (loop story-by-story) — **loop-auto.sh é o ativo**; `lib/auto.sh` é o guiado/resíduo |
| `lib/commit.sh` | Commit seguro (guard de segredos, confirmação) |
| `lib/context.sh` | Estado `.devorq/state/context.json` |
| `lib/vps.sh`, `scripts/sync-*.py` | VPS/HUB sync |
| `lib/context7.sh`, `lib/lessons/` | Validação Context7 + lições |
| `scripts/*-tests.sh`, `scripts/ci-test.sh` | Suítes de teste |
| `skills/devorq/SKILL.md` | **Skill canônica devorq (repo)** — fonte do `~/.dsh/skills/devorq/` |
| `config/dsh/devorq/` | **Templates do preset DSH** (fonte do `~/.dsh/.agent-presets/devorq/`) |
| `scripts/install-dsh-preset.sh` | **Installer idempotente do plugin DSH** |

---

## 7. Higiene / notas

- **`aula-devorq.html`** (untracked, 57KB) — pré-existente; **não commitar**.
- **`.devorq/state/`** tem arquivos gitignored (context/handoff) — são estado local; não commitar.
- **`.devorq/rules/` desincronizado** (3 de 7 regras, versão v4.0.0 vs canônica v4.1.0) — regenerar com `devorq rules export project`.
- Em caso de conflito doc vs código, **o código e o hook são a verdade**.

---

*Dúvida de priorização: rastreie pelos IDs (Bloco 3=qualidade de superfície, Bloco 4=metodologia, Bloco 5=robustez) e, para a dívida histórica, pelos IDs `DQ-xxx`/`R-xx` da auditoria `docs/auditoria-tecnica-2026-06-26.md`.*
