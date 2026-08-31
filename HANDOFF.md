# HANDOFF — DEVORQ v4.1.0 → continuidade

> **Para quem pega o trabalho:** este é o ponto de retomada. Leia daqui até o fim
> **antes** de qualquer edição ou commit.
> Atualizado em 2026-08-31 (audit + fixes C1–C5/M8/T1 + **Blocos 3, 4 e 5 concluídos nesta sessão**). Repo: `github.com/nandinhos/devorq` · branch `main`.

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
  - **Bloco 3 (M4/M5/M9/M10), commits desta sessao:**
    - `fix(core): alinha mensagens de convencao a tipo(escopo)` → **M4**
    - `fix(core): help do router lista todos os comandos (M5)` → **M5** (+ teste de cobertura no `unit-tests.sh`)
    - `docs(core): frontmatter na skill security-hardening (M9)` → **M9**
    - `fix(core): OPENCODE_* como alias de DEVORQ_* nos adapters (M10)` → **M10** (+ correção do teste E2E do adapter)
    - `docs(compact): snapshot do handoff pos-Bloque-3` → este arquivo
  - **Bloco 4 (M1/M2/M3 + alinhamento de escopos), commits desta sessao:**
    - `fix(core): export de regras copia todas + escopos alinhados` → **M1-code / M4-escopos**
    - `docs(core): sincroniza versao v4.1.0, gates, excecao AUTO e regenera .devorq/rules` → **M1/M2/M3**
  - **Bloco 5 (M6/M7/M12/M13), commits desta sessao:**
    - `fix(core): guards de jq obrigatorio via require_jq` → **M6**
    - `fix(core): helpers portaveis de realpath, timeout e readlink` → **M7**
    - `fix(loop): endurece loop AUTO (executor/exit_code, mark_skip, retries, progress)` → **M12/M13**
- **CI / suites verdes** nesta sessao: `unit-tests.sh` 76/76, `security-tests.sh` ALL PASSED, `tests/auto/test-loop-terminal-safety.sh all` 8/8, `tests/loop/test-loop-implementation.sh` pass, `tests/contracts/test-contracts.sh` 14/14, `scripts/adapters/test-opencode-delegate.sh` TODOS PASSARAM. Ver §4.
- **Estado do plugin DSH:** skill `devorq` em `~/.dsh/skills/devorq/SKILL.md` (root user-dsh, rank 400 — já no catálogo); preset `~/.dsh/.agent-presets/devorq/` sem `customSkillDirs`. Reproduzível via `bash scripts/install-dsh-preset.sh` (idempotente).

---

## 2. Achados do audit (gaps de qualidade) — roadmap priorizado

> Audit somente-leitura em 6 superfícies (metodologia/docs, CLI/bash, pipeline AUTO, skills, testes, integração DSH). Bloco 1 + C5 já tratados. Restam, em ordem de valor:

**🔴 Bloco 3 — consistência de superfície (CONCLUÍDO nesta sessão ✅):**
- **M4** — convenção `escopo(fase)` **stale** no código; a canônica é `tipo(escopo)` (F13/v4.0.0): `lib/visual.sh:402`, `lib/rules.sh:218,232,592,598`, `lib/commit.sh:4`, `lib/dispatchers/delivery.sh:30`, `deliverable.md:88`. (O hook rejeita `escopo(fase)`.) ✅ substituído por `tipo(escopo)`; taxonomia invertida ("Fases válidas") realinhada a "Tipos válidos" nos mesmos blocos de mensagem (`rules.sh`/`commit.sh`).
- **M5** — help do `bin/devorq` omite 7 comandos implementados (`brainstorm, build, context7, env, grill, spec, uninstall`); header-comment omite `loop`/`verify`; `devorq::cmd_version` é dead code (o router resolve `version` inline em `:187`). Regenerar help do `case`/lista `devorq::cmd_*`; rotear `version`. ✅ help regenerado (33 comandos, case==help verificado), header-comment com `loop`/`verify`, `version` roteado p/ `devorq::cmd_version`; novo teste `test_help_covers_commands`.
- **M9** — `skills/security-hardening/SKILL.md` **sem frontmatter** (`name`/`description`) → não é skill DSH válida. Adicionar frontmatter. ✅ frontmatter YAML válido (`name`/`description`/`whenToUse`/`metadata`), duplicação removida do corpo.
- **M10** — drift `delegate.sh` (`DEVORQ_MODEL/TIMEOUT/DRY_RUN`) vs `opencode-delegate.sh` (`OPENCODE_*`); prompt duplicado. Tratar `OPENCODE_*` como alias do contrato `DEVORQ_*`. ✅ `OPENCODE_MODEL/TIMEOUT/DRY_RUN` agora caem para `DEVORQ_MODEL`/`DEVORQ_DELEGATE_TIMEOUT`/`DEVORQ_DELEGATE_DRY_RUN`. Obs.: o teste E2E `test-opencode-delegate.sh` estava quebrado por causa do fail-closed C4 (dry-run sem no-diff não marca done) — foi realinhado (e descrição no `AGENTS.md` atualizada).

**🟠 Bloco 4 — consistência metodológica (CONCLUÍDO nesta sessão ✅):**
- **M1** — versão fragmentada: `VERSION`=4.1.0, mas `rules/commit-convention.md:1`="v3.6.5+", `rules/visual-verification.md`="v3.6.5+", `HANDOFF.md`(antigo)/`e2e-tests/RESULTADOS_TESTES.md`/`CODE_REVIEW_MATURITY_REPORT.md` referenciam v3.x. `.devorq/rules/` tem só 3 de 7 regras e `agent-discipline.md` local = **v4.0.0** (canônica v4.1.0). ✅ headers de versão sincronizados p/ `v4.1.0` (`brainstorm`/`grill`/`visual-verification`/`commit-convention`); `export_essential_rules` corrigido (copia TODAS as regras, antes 3); `.devorq/rules/` regenerado (7 regras).
- **M2** — G-6 existe (Context7, `lib/gates.sh:458`) mas `commit-convention.md:15` o chama de "manual verification gate"; `AGENTS.md:41`/`agent-discipline.md:76` "Gates 1–7" pulam G-6 e ignoram G-0/G-0.5/G-5.5 (que existem em `lib/gates.sh`). ✅ doc de fluxo alinhada à `DEVORQ_GATE_SEQUENCE` (0, 0.5, 1–7, incl. G-6 Context7) em `AGENTS.md`/`agent-discipline.md`; exemplo de commit corrigido ("GATE-6 Context7").
- **M3** — `rules/manual-commit.md` ("nunca commitar sem aprovação") contradiz o modo AUTO (`DEVORQ_AUTO_COMMIT=1`, commit por story). Falta a exceção AUTO + precedência. ✅ exceção AUTO documentada (`DEVORQ_AUTO_COMMIT=1` → commit por story; **push nunca automático**; precedência explícita).
- **Extra (alinhamento de escopos, do M4):** lista de escopos unificada à canônica — `lib/commit.sh` (`VALID_SCOPES`+`usage`) corrigido (`migrations` removido, `release` adicionado); `rules.sh` já era correto. Nota de **enforcement** adicionada à regra canônica (hook valida só `^[a-z]+\([a-z]+\):`; a tabela lista escopos **recomendados** — **Opção B**, decisão do dono).

**🟡 Bloco 5 — robustez (CONCLUÍDO nesta sessão ✅):**
- **M6** — filosofia "jq opcional" violada: `lib/commands/brainstorm.sh`(11), `grill.sh`(15), `lib/commit.sh`(4), `lib/rules.sh` usam `jq` sem `devorq::contracts::require_jq`. ✅ `contracts.sh` passou a ser sourceado pelo router (`bin/devorq`); guards `devorq::contracts::require_jq` adicionados nas entradas: `cmd_brainstorm`, `cmd_grill`, `commit::interactive` (bloco story), `commit::from_story`, `rules::check_brainstorm` (quando há context_file). Fail early com mensagem acionável.
- **M7** — portabilidade GNU/BSD/macOS: `timeout` (`delegate.sh:139`, `gates.sh:538`), `realpath -q` (`helpers.sh:45,50`, `vps.sh:61,65`), `readlink -f` (`e2e-test.sh:11`) ausentes no macOS. ✅ helpers portáveis em `helpers.sh` (`devorq::util::realpath`, `devorq::util::run_timeout` [timeout|gtimeout|sem-limite], `devorq::util::readlink_f`) aplicados em `helpers.sh`/`vps.sh`/`gates.sh`; fallbacks inline em `delegate.sh` (timeout) e `e2e-test.sh` (`__readlink_f`). `vps.sh` mantém fallback local (autônomo, testável isolado).
- **M12/M13** — `lib/loop.sh:157-159` valida só `-z "$executor"` (não `-x`); `exit_code` do contrato v1 hardcoded; `mark_skip` (`loop-auto.sh`) faz `mv` sem validar JSON; `MAX_DELEGATE_RETRIES=1` (retry morto); `progress.txt` não excluído do commit. ✅ executor validado (path `-x` | comando PATH | função via `declare -F`); contrato `execution` grava o **exit_code real** do executor (`--argjson`); `mark_skip` valida JSON gerado antes de sobrescrever `prd.json`; `MAX_DELEGATE_RETRIES` agora **3** (configurável via `DEVORQ_AUTO_DELEGATE_RETRIES`); `commit_paths` exclui `progress.txt` do commit.

**Baixos (higiene):** references órfãs (`devorq-auto/references/prd-schema.json`, `env-context/references/laravel-filament.md`, `scope-guard/references/laravel-filament-scope.md`); `skills/README.md:27` lista `learned-lesson` inexistente; `devorq-code-review` "8 fases" vs 9 (FASE 8 pós-review); `mode-selector.sh` fora de `scripts/`; versão `devorq-auto` inconsistente (SKILL.md v1.2.0/1.1.0/1.0.0 vs script v1.2.1); mojibake em `rules/brainstorm.md:17` (采纳) e `rules/grill.md:52` ("nãoaceita"); `INSTALL.md` typos (caminho `~/devorq` na desinstalação, "afficher", "Manenha", "|| Sintoma"); `e2e-tests/RESULTADOS_TESTES.md` stale (v3.8.5, "16 arquivos" vs real 7); `unit::skip` chamado mas **não definido** em `unit-tests.sh`; `systematic_debug` é stub (security-tests.sh/pipeline-tests.sh).

---

## 3. Decisões e porquês (para não re-discutir)

- **Skill do plugin DSH em `~/.dsh/skills/` (user-dsh), NÃO `customSkillDirs` no preset.** O provider `dsh-skill-filesystem` não varre o dir do preset; `customSkillDirs` apontando para `/.agent-presets/<id>/skills` hardcoda o id e **quebra em cópia** do preset (copy é whole-directory). User-dsh (rank 400) é auto-descoberto e robusto. Fonte canônica no repo `skills/devorq/SKILL.md` + installer idempotente.
- **C4 foi defensivo:** `devorq::auto::git_commit` é **dead code** (o fluxo guiado usa `devorq::commit`, que tem guard_secrets+confirmação+hook+rc). Por isso tornei a função fail-closed (por-path, sem `add -A`/`--no-verify`/`|| true`) em vez de apenas mencionar.
- **C3 é robustez/consistência, não bug hard:** como `mark_pass` sempre altera `prd.json`, o `git_commit` já commitava o index inteiro (incluindo staged). O fix (`commit_paths` incluir `--cached`) é pró-ativo/correto; o teste é asserção do comportamento, não red→green.
- **Testes C1/C2 são red→green comprovados** (revert e confirmou falha). C3 é asserção positiva.
- **M4 foi além da substituição literal:** como `enforce_commit` imprimia a taxonomia antiga ("Fases válidas") logo após o formato `tipo(escopo)`, alinhei o mesmo bloco a "Tipos válidos" (feat|fix|refactor|docs|test|style|perf|chore) — senão a mensagem ficaria autocontraditória. `commit.sh` usage() idem. Escopos na tabela foram preservados (não é escopo do Bloco 3).
- **M5 regenerou o help por completo**, não só adicionou os 7 ausentes (reorganizei por grupo de dispatcher). O teste `test_help_covers_commands` garante que todo comando do `case` está no help (extrai o nome primário de cada padrão do `case` e compara com as linhas de topo do heredoc).
- **`devorq verify` (sem `--story`) não é a verificação deste repo:** entra em modo auto-debug orientado a story. Para verificar o repo, use as suites da §4 (que é o que a §4 pede).
- **Alinhamento de escopos (M4/Bloco 4):** as 3 fontes (`commit-convention.md`, `rules.sh`, `commit.sh`) agora são idênticas à canônica (21 escopos, `release` presente, `migrations` ausente — `database`/`models` cobrem migrations). O hook **não** valida a tabela (só `^[a-z]+\([a-z]+\):`); por decisão do dono (**Opção B**), a regra deixa explícito que a lista é de escopos **recomendados**, não exaustivos. Reverter para enforced (Opção A) quebraria commits históricos (`feat(agents)`, `fix(security)`…).
- **Export de regras:** `export_essential_rules` passou a copiar todos os `rules/*.md` (antes fixava `commit-convention manual-commit agent-discipline`). Isso faz `devorq rules export project` e o bootstrap regenerarem as 7 regras.

---

## 4. Como VERIFICAR (baseline atual — rode você mesmo, veja sumário inteiro)

```bash
bash scripts/unit-tests.sh                  # 76/76 (inclui teste M5: help cobre o case)
bash scripts/security-tests.sh              # ALL PASSED
bash tests/auto/test-loop-terminal-safety.sh all   # 8/8
bash tests/loop/test-loop-implementation.sh # pass
bash tests/contracts/test-contracts.sh      # 14/14
bash scripts/adapters/test-opencode-delegate.sh   # TODOS PASSARAM (fail-closed pos-C4)
bash scripts/install-dsh-preset.sh --dry-run # DSH installer (dry-run, no-write)
```

> **Lição da auditoria:** não filtre a saída com `grep` para "ver só o Pass" — regressões escaparam assim. Leia Pass/Fail inteiro.
> Suites herméticas criam repositórios temporários; não poluem o repo. `scripts/ci-test.sh` espelha o CI.

---

## 5. Próximo passo concreto (sugerido)

**✅ Blocos 3, 4 e 5 CONCLUÍDOS nesta sessão** (Bloco 3: M4/M5/M9/M10; Bloco 4: M1/M2/M3 + escopos; Bloco 5: M6/M7/M12/M13). Trilha completa em §2.

**Próximo: baixos/higiene (roadmap residual do audit):**
1. References órfãs (`devorq-auto/references/prd-schema.json`, `env-context/references/laravel-filament.md`, `scope-guard/references/laravel-filament-scope.md`).
2. `skills/README.md:27` lista `learned-lesson` inexistente; `devorq-code-review` "8 fases" vs 9 (FASE 8 pós-review); versão `devorq-auto` inconsistente (SKILL.md v1.2.0/1.1.0/1.0.0 vs script v1.2.1); `mode-selector.sh` fora de `scripts/`.
3. Mojibake em `rules/brainstorm.md:17` (采纳) e `rules/grill.md:52` ("nãoaceita"); `INSTALL.md` typos (caminho `~/devorq` na desinstalação, "afficher", "Manenha", "|| Sintoma"); `e2e-tests/RESULTADOS_TESTES.md` stale (v3.8.5, "16 arquivos" vs real 7).
4. `unit::skip` chamado mas **não definido** em `unit-tests.sh`; `systematic_debug` é stub (security-tests.sh/pipeline-tests.sh).

Commit (convenção): `chore(core): ...` / `docs(core): ...`.

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
- **`.devorq/rules/` sincronizado** (regenerado no Bloco 4 — 7 regras, v4.1.0). Se as regras canônicas mudarem de novo, re-rodar `devorq rules export project`.
- **Escopos:** a lista é a da canônica (21 escopos, `release` presente, `migrations` ausente). O hook **não** valida a tabela (só `^[a-z]+\([a-z]+\):`); por Opção B, escopos novos recorrentes devem ser adicionados à tabela e a `lib/commit.sh`/`lib/rules.sh`.
- **`test-opencode-delegate.sh`** foi realinhado ao fail-closed C4 (dry-run sem no-diff não marca done) — é o comportamento correto agora; não reverter para "marca done".
- **Loop AUTO (Bloco 5):** `MAX_DELEGATE_RETRIES` agora é 3 (configurável via `DEVORQ_AUTO_DELEGATE_RETRIES`); `progress.txt` e `.devorq-auto/` são excluídos do commit (`commit_paths`); `mark_skip` valida JSON antes de sobrescrever `prd.json`.
- **Portabilidade (M7):** `devorq::util::realpath` / `run_timeout` / `readlink_f` em `helpers.sh`; se um script standalone precisar, copiar o fallback (padrão `delegate.sh`/`e2e-test.sh`).
- Em caso de conflito doc vs código, **o código e o hook são a verdade**.

---

*Dúvida de priorização: rastreie pelos IDs (Bloco 3=qualidade de superfície, Bloco 4=metodologia, Bloco 5=robustez) e, para a dívida histórica, pelos IDs `DQ-xxx`/`R-xx` da auditoria `docs/auditoria-tecnica-2026-06-26.md`.*
