# CHANGELOG — DEVORQ

All notable changes to DEVORQ are documented here.

## [4.0.0] - 2026-07-03

### Sprint: Elite Hardening — gates fail-closed no nivel de processo
Origem: REFACTOR-ELITE-PLAN.md + CODE_REVIEW_ELITE_2026-07-02.md (12 fatias)
Metodologia: hardening de gates, seguranca e modo AUTO headless + unificacao da convencao de commit e adapters multi-runner
Branch: refactor/elite-hardening (24 commits)

### Breaking Changes
- **Gates fail-closed no nivel de processo** (commit c17063a) — `devorq flow` agora retorna exit code != 0 quando um gate falha. ANTES retornava 0 mesmo com gate reprovado, mascarando falhas em CI/scripts. `devorq::error` passou a retornar 1.
- **GATE-2 fail-closed** (commit 992a1e3) — GATE-2 passa a reprovar quando ha runner de teste declarado mas ausente (ex.: pytest.ini sem pytest; package.json com script test sem deps), com deteccao de ambiente Node. Escape: `DEVORQ_ALLOW_NO_RUNNER=1`.
- **F13 — convencao de commit unificada para `tipo(escopo)` (Model A)** (commits d1df8f4, 09c0bda) — o hook `commit-msg` AGORA REJEITA o formato antigo `escopo(fase)`. O comando `devorq commit --phase` esta deprecado (alias de `--type` com aviso). Commits devem seguir `tipo(escopo): descricao` (tipo ∈ feat|fix|refactor|docs|test|style|perf|chore).
- **Modo AUTO muda semantica de sucesso/parada** (commits d1555c7, 5572a26, e1a9864) — delegate que nao produz diff FALHA a story (antes: marcava done); story que falha persistentemente vira failed apos `DEVORQ_AUTO_MAX_STORY_FAILURES` (default 2) em vez de loop infinito; runs concorrentes no mesmo projeto sao bloqueados por flock; prompts interativos em headless usam default seguro (use `DEVORQ_AUTO_YES=1`).
- **Instalacao e estado** (commits 47e2aba, b1cf627) — instalacao one-line por `curl` substituida por `git clone` + symlink (o single-file ja estava quebrado desde o refactor modular); `.devorq/state/*` untrackado + gitignorado; `devorq uninstall` exige `yes` explicito e e no-op sem TTY.

### Security
- **jq --arg no parser de SPEC->prd** (commit fb5c75f) — substitui interpolacao direta por `jq --arg`, fechando vetor de injecao/DoS na geracao do prd.json a partir do SPEC.
- **Endurecimento de config** (commit b1cf627) — `mcp.json` com permissao 600 (contem token), timestamps de audit em UTC (`date -u`), e uninstall seguro.

### Added
- **Modo AUTO headless-safe** (commits 5572a26, d1555c7) — loop com guarda de TTY, stop-criteria, no-diff guard, `git_commit` robusto (porcelain + scan de segredos) e registro de falhas em `failures.md` via trap EXIT.
- **Adapters de delegacao multi-runner** (commits 85f3ede, 4d872de) — `scripts/adapters/delegate.sh` (dispatcher) + wrappers para claude/codex/hermes/opencode/agy, validados end-to-end (5/5). Contrato `DEVORQ_DELEGATE_FN` documentado em `docs/DELEGATE-ADAPTERS.md`.
- **Lessons capture com flags + conteudo cru** (commit b05419a) — parseia `--problem/--solution/--stack/--tags` (alinhado ao README) e armazena o conteudo cru (nao mutila codigo).
- **Concorrencia** (commit e1a9864) — escrita atomica de `context.json` com `flock` + lock de run unico no AUTO.

### Fixed
- **Contadores imunes a set -e** (commit b97a100) — `((var++))` trocado por `var=$((var+1))`; `devorq build` reporta contagem honesta sem abortar no 1o gate falho.
- **Guard de instalacao incompleta** (commit 47e2aba) — `bin/devorq` falha cedo com instrucao se `lib/` estiver ausente.
- **Crash set -u no scope + jq de GATE-0.5** (commit 7249ac5) — fallback `:-` no scope/phase; jq de acceptance_criteria reescrito (antes sempre passava por erro de sintaxe).
- **no-diff guard robusto no AUTO** (commits c97c539, a9d53a6) — nao aborta em repo sem commits e ignora diretorios do proprio orquestrador ao avaliar o diff.
- **opencode usa --auto** (commit 4d872de) — flag real de auto-aprovacao (`--dangerously-skip-permissions` nao existe no opencode).

### Docs & Validation
- **CI honesto** (commit 4456603) — `gates.spec.ts` asserta exit code; suite E2E hermetica (sem `DEVORQ_*` do ambiente); teste de seguranca reescrito para a propriedade correta.
- **Manual dos adapters + tabela visual** (commits 60fa5e5, fbe5510) e **plano/review de elite** (commits be1b050, 9e4df07, 6f49737).

### Migração (para quem atualiza)
- `devorq flow`: reveja `... || true` que mascare falha — o exit != 0 agora e real.
- Re-rode `devorq init`/bootstrap para instalar o novo hook `commit-msg`; migre commits de `escopo(fase)` para `tipo(escopo)` e `--phase` para `--type`.
- GATE-2: instale o runner declarado ou use `DEVORQ_ALLOW_NO_RUNNER=1`.
- AUTO headless: use `DEVORQ_AUTO_YES=1`. Reinstale via `git clone` (nao mais `curl` single-file).

## [3.8.5] - 2026-06-04

### Sprint: Dogfooding do DEVORQ no proprio DEVORQ
Origem: code review + auto-analise em sessao Mavis+Nando de 2026-06-04 21:23 BRT
Metodologia: dogfooding real - DEVORQ se aplica a si mesmo
Plano executado via Mavis Team (3 tracks paralelas) + orchestrador manual

### Security
- **Whitelist SSH em devorq::vps_exec** (sprint v3.8.4 fix, commit bc18335) - defesa em 2 camadas (blocklist + whitelist)
- **F-06 grep injection regression fixed** (commit f78d6f8) - devorq::sanitize_input restaurado com implementacao original (Python regex cirurgica vs sed agressivo de helpers.sh)

### Added
- **scripts/sync-version.sh** (story-004) - detecta e corrige drift de versao entre 7 pontos:
  VERSION, bin/devorq (header/readonly/help), lib/*.sh headers, CHANGELOG.md, prd.json
  - Modo --check (CI gate) + --fix (auto-correge) + --status
- **scripts/ci-test.sh FASE 5.5** - valida sync-version em todo CI run
- **scripts/ci-test.sh FASE 5.6** (story-001) - E2E Playwright nao-bloqueante no dev
- **lib/gates.sh gate_e2e / gate_8** (story-001) - gate dedicado para E2E tests
- **.github/workflows/e2e.yml** (story-001) - CI job Playwright com npm cache + artifact upload
- **GATE-0.5 Foundation docs** (5 docs obrigatorios): 5w2h.json, premissas.json, riscos.json, requisitos.json, restricoes.json
- **EXTRAS.md secao "Version Sync"** - documenta sync-version.sh com uso, pontos verificados, workflow
- **docs/specs/2026-06-04-v3.8.5-dogfooding.md** - SPEC completa do sprint

### Changed
- **bin/devorq: 1503 -> 180 LOC** (story-002, commit ab556c4) - router puro + 5 dispatchers
  - lib/dispatchers/init.sh (44 LOC), workflow.sh (56), state.sh (45), delivery.sh (58), discovery.sh (33)
  - dynamic source loop + case-statement dispatch
  - Comportamento identico preservado: devorq --help saida identica, version=3.8.5
- **lib/lessons.sh: 995 -> 91 LOC** (story-003, commit 975308b + 627a4d2) - agregador + 3 modulos
  - lib/lessons/crud.sh (295), search.sh (396), sync.sh (337)
  - 100% das funcoes lessons::* preservadas, F-06 grep injection 5/5
- **CHANGELOG.md** + **prd.json** - drift corrigido

### Fixed
- **ci-test.sh cleanup ordering bug** - rm -f lessons rodava DEPOIS de restaurar .devorq.bak
  Reordenado: PASSO 1 limpa artefatos de teste, PASSO 2 restaura backup
- **devorq::sanitize_input regression** (commit f78d6f8) - funcao perdida no refactor de
  lib/lessons.sh. Restaurada implementacao original de v3.8.4 (Python com regex cirurgica)
- **bin/devorq version drift** - sincronizado para 3.8.4
- **prd.json version drift** - 3.8.2 -> 3.8.4

### Validation
- bash -n: 0 errors em todos arquivos modificados
- shellcheck -S error: 0 errors
- scripts/ci-test.sh: 46/46 (incluindo FASE 5.5 sync-version + FASE 5.6 e2e)
- npx playwright test: 68/77 = 88.3% (alvo 80%)
- sync-version.sh --check: 0 drift
- 19 commits no sprint, 0 Co-Authored-By

### Metricas
- bin/devorq: 1503 -> 180 LOC (-88%)
- lib/lessons.sh: 995 -> 91 LOC + 3 modulos (-91% no agregador)
- Maior arquivo .sh: 1503 -> 396 LOC (lib/lessons/search.sh)
- Score maturidade codigo: 7.5/10 -> >= 8.5/10 (estimado)

### Reference
- SPEC: docs/specs/2026-06-04-v3.8.5-dogfooding.md
- PRD: docs/specs/prd-2026-06-04.json (5 stories, todas done)
- Story 1 deliverable: reviver suite E2E Playwright, baseline 88.3%
- Story 2 deliverable: refactor bin/devorq, 5/5 criterios estruturais
- Story 3 deliverable: refactor lib/lessons.sh, 100% funcoes preservadas + sanitize_input restaurado

## [3.8.4] — 2026-06-04

### Security
- **Whitelist SSH em `devorq::vps_exec`** — defesa em 2 camadas (code review 2026-06-01, issues #3 e #9):
  - **P1 — blocklist de metacaracteres sempre proibidos**: `;` `` ` `` `$` `()` control chars bloqueados antes de qualquer outra validacao
  - **P2 — split por compound + validacao por sub-comando**: `&&` e `||` permitidos, mas cada sub-comando e validado contra pipe/background standalone (`|`/`&`) + whitelist de primeira palavra
  - **Whitelist**: systemctl, journalctl, docker, ls, cat, grep, tail, head, ps, free, df, uptime, whoami, pwd, mkdir
  - Cobre todos os callers reais: `vps_pg_exec` (docker exec) e `lessons::sync_vps` (mkdir && cat)
  - **Codex review (2026-06-04)** identificou 2 issues adicionais (P1: bypass via `ls | sh`; P2: caller `lessons::sync_vps` quebrado) que foram corrigidas em 2 iteracoes

### Changed
- **Doc drift gates 7 → 10** — SPEC.md e README.md declaravam "7 gates" (ou "7+ gates") mas o codigo tem 10 (gate_0, gate_0_5, gate_1, gate_2, gate_3, gate_4, gate_5, gate_5_5, gate_6, gate_7). Atualizado nas referencias atuais; changelog historico de v3.1.0 preservado.
- **Escopo `release` adicionado a whitelist** — `lib/rules.sh:enforce_commit` e `rules/commit-convention.md` agora incluem `release` na lista de escopos validos. Os 15 commits historicos de version sync (v3.6.4 ate v3.8.2) ja usavam o escopo; agora esta documentado formalmente.

### Removed
- **`devorq self-patch`** — referencia removida de `EXTRAS.md` (linha da tabela de comandos). Feature nunca foi implementada; a SPEC deste sprint a moveu para "roadmap futuro" (escopo: sprint separada).

### Added
- **`docs/specs/2026-06-02-code-review-corrections.md`** — SPEC canonica deste sprint (4 stories, decisoes marteladas, principios, riscos)
- **`docs/security-reviews/2026-06-04/SUMMARY.md`** — sumario do fix do codex review (bypass pipe/background + caller quebrado)
- **5 licoes capturadas** em `.devorq/state/lessons/`:
  - SPEC drift: validar contagem real antes de atualizar docs
  - Path containment: `case` e equivalente a `[[ == base* ]]` (nao requer patch)
  - Whitelist SSH: cobrir TODOS os callers, nao apenas o exemplo da SPEC
  - Command injection: defesa em 2 camadas (blocklist + whitelist)
  - `sed -E` com `[[:space:]]*` quebra silenciosamente em command substitution

### Validation
- `bash -n lib/vps.sh lib/rules.sh` — OK
- `shellcheck lib/vps.sh lib/rules.sh` — 0 errors (com `disable=SC2016` documentado para regex literal)
- `bin/devorq build` — 7/7 gates verdes
- **Suite de testes funcionais do whitelist** — 11/11 (4 positivos + 7 negativos)
  - Positivos: `ls -la /tmp`, `docker exec postgres psql ...`, `mkdir -p X && cat > X.json`, `docker ps && journalctl -u nginx`
  - Negativos: `rm -rf /tmp/x`, `ls; rm -rf /tmp/x`, `ls && rm -rf /tmp/x`, `` cat `whoami` ``, `echo $(whoami)`, `echo x | grep x`, ``
- **Codex CLI review** (`codex review --uncommitted`) — usado como code review multi-agente; identificou P1 e P2 do fix SSH em 2 rodadas
- Branch `fix/code-review-2026-06-02` @ 5 commits (publicada no origin)
- Working dir limpo: apenas state/ local (gitignored) + 5 licoes + 1 spec (commitada)

### Commits deste sprint
```
9d564ba docs(specs): publica SPEC code-review-2026-06-02 (4 stories implementadas)
c95f018 docs(spec): alinha declaracao de gates com implementacao real (10 gates)
be95519 docs(extras): remove devorq self-patch (nao implementado, planejado para roadmap)
047208f fix(rules): adiciona escopo release a whitelist de commit-convention
bc18335 fix(security): corrige command injection em vps.sh via whitelist + blocklist
```

### Reference
- Origem: code review 2026-06-01 via Kanban Hermes worker (t_15139089) + 5 lanes paralelas
- SPEC completa: `docs/specs/2026-06-02-code-review-corrections.md`
- Fix do codex: `docs/security-reviews/2026-06-04/SUMMARY.md`
- Metodologia: systematic-debugging (4 phases) + codex CLI review + devorq gates

---

## [3.8.3] — 2026-06-01

### Security
- **Code Review Sistemático + Sandbox Testing** — 4 vulnerabilidades corrigidas (F-01 CRITICAL + F-06 HIGH + F-02 HIGH + D-1+D-2 MEDIUM)
  - **F-01 (CRITICAL)** — RCE via `source <(grep ...)` em `lib/context7.sh`. Saída de grep era sourced em shell, permitindo execução arbitrária se config contaminado. Substituído por `while+read+declare` com whitelist de keys. Exploit confirmou 5 de 7 payloads em sandbox.
  - **F-06 (HIGH)** — Grep regex injection em `lib/lessons.sh::lessons::search`. Query do usuário era passada crua pro `grep -i`, permitindo flag injection (`--`) e regex injection. Corrigido com `grep -iF --`. Exploit confirmou que query `AKIA` revelava lições com secrets AWS.
  - **F-02 (HIGH)** — Sed injection em `lib/context.sh::ctx_set` (fallback). Caracteres especiais em valores (`/`, `\`, `"`, newlines) corrompiam o JSON ou executavam comandos via sed. Removido fallback, hard requirement de `jq` (já era dependência).
  - **D-1+D-2 (MEDIUM)** — Hook `commit-msg` não era instalado automaticamente. Hook existe em `lib/commands/rules.sh` e bloqueia tags de co-autoria + valida formato `escopo(fase):`. Patch garante instalação via `devorq rules install-hook`.

### Added
- `tests/security/` — suite TDD com 20 testes de regressão (11 arquivos: test_lib.sh + 4 test_F* + 4 apply_* + 1 apply_all.sh)
- `docs/security-reviews/2026-06-01/PATCHES.md` — documentação completa do processo (8.5 KB)
- `lib/commands/rules.sh` — hook commit-msg auto-instalado por padrão
- Skill `devorq-validate-rules-pitfall` (Hermes) — documenta pitfall do body de commit documentando o fix

### Changed
- **Docs version sync** — README.md, INSTALL.md, EXTRAS.md, TROUBLESHOOTING.md, SPEC.md, rules/README.md, docs/COMPORTAMENTO_ESPERADO.md atualizados de 3.8.1/3.8.2 para 3.8.3
- `bin/devorq` — header atualizado de "v3.7 CLI" para "v3.8.3 CLI"
- Histórico Git reescrito via `git filter-repo` para remover menções a co-autoria no body (validador `validate-rules.sh` rejeitava)

### Fixed
- **`validate-rules.sh`** — falso positivo quando body do commit documentava o fix mencionando a string bloqueada. CI 33/34 → 45/45 ALL PASSED
- **Version drift** — `.devorq/version`, `VERSION`, header do `bin/devorq`, e 7 arquivos de documentação estavam dessincronizados. Corrigido em v3.8.3.

### Validation
- `bash scripts/validate-rules.sh` — 34/34 PASSED, 0 FAILED
- `bash scripts/ci-test.sh` — 45/45 ALL TESTS PASSED (incluindo 20 testes de regressão de segurança)
- `git log --grep="Co-authored-by" -i` — 0 commits
- Branch `main` @ `470c5b1` (após filter-repo sanitize)
- Tag `v3.8.3` @ `f3d976a`

### Reference
- Code review via Kanban Hermes worker t_15139089
- Metodologia: systematic-debugging + context7 validation + sandbox testing
- Detalhes completos: `docs/security-reviews/2026-06-01/PATCHES.md`

## [3.8.2] — 2026-05-28

### Security
- **Code Review Completo** — 17 issues corrigidas (5 CRITICAL + 6 HIGH + 6 MEDIUM/LOW)
  - Python injection em `lib/lessons.sh`
  - Variáveis de cor ANSI vazias causando escape incorreto
  - Exit code capture com `set -e` em subshell
  - Command injection em `lib/lessons.sh` e `lib/commands/workflow.sh`
  - Missing error trapping em `bin/devorq`
  - DEVORQ_ROOT validation ausente ao carregar libs
  - Silent source failures — agora com warn explícito
  - Gate flow continuava após falha — agora para com break
  - Temp file race condition — trap EXIT implementado
  - Repeated source de `gates.sh` — guard com `declare -f`
  - shellcheck globs sem `nullglob` — validacao previa implementada

### Fixed
- **`devorq gate [N]`** — todos os gates (0, 1, 2, 3, 4, 5, 6, 7) agora funcionais; antes apenas 0.5 e 5.5 eram invocados
- **`.devorq/version`** — dessincronizado em 3.4.0; corrigido para 3.8.1 (agora 3.8.2)
- **GATE_BLOCKING** — variável unused removida
- **PWD path traversal** em `cmd_init` — sanitizado com `cd && pwd -P`
- **`basename`** em `foundation-init` — sanitizado com `tr -cd 'a-zA-Z0-9._-'`
- **`devorq flow`** — agora para ao primeiro gate falho (break implícito)

## [3.8.1] — 2026-05-23

### Added
- **`devorq rules export`** — alvos `project`, `cursor`, `claude`, `agents` (adaptadores gerados de `rules/`)
- **`AGENTS.md`** — instruções agnósticas estáveis na raiz do repo
- **`docs/ARQUITETURA-AGNOSTICA-LLM.md`** — uso com Telegram, Claude, Cursor sem acoplamento
- **`scripts/rebuild-history-by-version.sh`** — histórico linear por release (divulgação)
- **CI** — smoke tests export + `scope lite`; `validate-rules.sh` falha em coautoria

### Changed
- **Agnosticismo LLM** — `.cursor/` removido do repo; gitignored; gerar via `devorq rules export cursor`
- **Hook commit-msg** — rejeita `Co-Authored-By` (além do formato escopo(fase))
- **`rules/README.md`** — secção arquitetura agnóstica
- **Histórico Git** — reorganizado por versão (1 commit/release); re-clone recomendado

### Fixed
- **[3.8.0]** menção incorreta de `.cursor/rules/` como feature commitada — corrigido para export-only

## [3.8.0] — 2026-05-23

### Added
- **`rules/agent-discipline.md`** — 4 princípios Karpathy adaptados ao DEVORQ (PT)
- **Bootstrap** — `agent-discipline` incluída em `devorq rules bootstrap` (junto commit-convention)
- **`success_criteria`** — campo no template `context.json` do `devorq init`
- **`devorq scope lite "<intent>"`** — contrato mínimo FAZER/NÃO FAZER/VERIFICAR
- **`docs/EXEMPLOS-DISCIPLINA-AGENTE.md`** — 4 exemplos bash/DEVORQ
- **`docs/ANALISE-KARPATHY-DEVORQ.md`** — análise sistemática Karpathy × DEVORQ

### Changed
- **`ctx_lint`** — avisa se `intent` preenchido sem `success_criteria`
- **Docs de release** — INSTALL, TROUBLESHOOTING, EXTRAS, COMPORTAMENTO_ESPERADO → v3.8.0

### Note (v3.8.1)
- `.cursor/rules/devorq-discipline.mdc` foi removido em v3.8.1 — use `devorq rules export cursor`

## [3.7.2] — 2026-05-23

### Fixed
- **`devorq build`** — carrega `test.sh` e `workflow.sh` antes de `cmd_test`/`cmd_gate` (fix de `dev`)
- **`lessons validate --auto`** — flag `--auto` ativa `LESSONS_AUTO` (auto-validação sem Context7)
- **`lessons approve`** — modo auto interno e `--force` bypassam exigência de validação Context7
- **`scripts/security-tests.sh`** — cria `/tmp/.devorq/state` antes do teste de path traversal
- **E2E Playwright** — `devorq init` idempotente (captura stderr); fluxo compile com `validate --auto`
- **README.md / SPEC.md** — versão alinhada com `VERSION` (estavam em 3.7.0 após release 3.7.1)

### Added
- **`e2e-tests/package.json`** — dependências Playwright versionadas no repo
- **`.gitignore`** — permite `e2e-tests/package.json` (ignora apenas root `package.json`)

### Changed
- **`docs/DEVORQ-DEFICITS-FIX-PLAN.md`** — status RESOLVIDO v3.7.1 (merge de `dev`)

## [3.7.1] — 2026-05-23

### Added
- **orch-002** — Restaura dispatch de `commit`, `verify` e `rules` no CLI v3.7 modular
- **`lib/commands/commit.sh`** e **`lib/commands/rules.sh`** — wrappers de dispatch
- **`devorq rules bootstrap`** — aplica commit-convention + manual-commit + commit-msg hook
- **`devorq rules install-hook`** / **`uninstall-hook`** — git commit-msg hook (substitui pre-commit incorreto)
- **`commit_mode: manual`** em context.json template do `devorq init`
- Smoke tests em `verify-dispatch.sh` para commit, verify, rules

### Fixed
- **`lib/commit.sh`** — lógica invertida que abortava commit quando havia mudanças
- **`loop-auto.sh`** — remove sugestão `feat(story_id):`; delega para `devorq commit --story`
- **`git commit-msg` hook** — validação no hook correto (antes era pre-commit, sem acesso à mensagem)
- **`devorq init`** — executa bootstrap de regras mesmo se `.devorq/` já existir

### Changed
- **`devorq_auto::git_commit`** — usa formato `escopo(impl): título (story_id)` quando auto-commit habilitado

## [3.7.0] — 2026-05-22

### Added
- **shellcheck zero warnings** — FASE 1 do refactoring
  - Adicionadas diretivas shellcheck em todos os arquivos
  - 110 issues → 0 issues
- **lib/commands/lessons/** — Modularização FASE 2
  - `lib/commands/lessons/capture.sh` — lessons::capture
  - `lib/commands/lessons/list.sh` — lessons::list
  - `lib/commands/lessons/search.sh` — lessons::search
  - `lib/commands/lessons/approve.sh` — lessons::approve
  - `lib/commands/lessons/validate.sh` — lessons::validate
  - `lib/commands/lessons/compile.sh` — lessons::compile
  - `lib/commands/lessons/migrate.sh` — lessons::migrate
  - `lib/commands/lessons/index.sh` — carregador de módulos
- **bin/commands/** — Estrutura modular para bin/
- **lib/commands/cli/** — Módulos CLI (init, version, stats)
- **lib/commands/ddd.sh** — Comando DDD validate
- **lib/commands/test.sh** — Wrapper para testes
- **scripts/test-commands.sh** — Suite de testes para comandos CLI

### Changed
- **lib/lessons.sh** — Refatorado como thin wrapper
  - 996 LOC → 205 LOC (↓79%)
  - Delega para módulos em lib/commands/lessons/
- **bin/devorq** — Refatorado como dispatcher
  - 1504 LOC → 174 LOC (↓88%)
  - Carrega módulos sob demanda
- **lessons::validate** — Adicionado suporte a LESSONS_AUTO
- **lessons::approve** — Adicionado help inline
- **lessons::list** — Adicionado help inline

### Fixed
- **bin/devorq dispatch v3.7** — Restaura roteamento para `lib/commands/*` após modularização
  - `init`/`gate`/`flow` → `workflow.sh`; `compact` → `context.sh`; `env`/`spec` → `exploration.sh`
  - Wrappers: `auto.sh`, `mode.sh`, `review.sh`, `info.sh`
- **lib/helpers.sh** — Funções de log (`devorq::info|warn|error|success|fail`) usadas em todo o CLI
- **lesson::capture path bug** — Corrigido duplo /captured/captured
- **test environment** — DEVORQ_DIR/DEVORQ_LESSONS_DIR configurados
- **lessons::search** — Mensagem correta quando não há resultados
- **lessons::apply** — Implementação completa com jq
- **scripts/pipeline-tests.sh** — Comentário que quebrava ShellCheck (SC1072/SC1073)
- **scripts/unit-tests.sh** — Teste de schema de lessons usa arquivo mais recente (evita flake)

### Added (pós-modularização)
- **scripts/verify-dispatch.sh** — Gate CI: valida que `bin/devorq` só referencia módulos existentes
- **docs/FLOW-ORCHESTRATOR-ATTEST.md** — Fluxo de atestação CLASSIC + AUTO (story `orch-001`)
- **prd.json** — Story `orch-001` (orquestrador DEVORQ)

### Security
- **ShellCheck compliance** — 0 warnings em todos os scripts

### Tests
- **Suite 100% verde** (2026-05-22)
  - 68 unit tests | 43 CI tests | 11 e2e bash | 8 Playwright modes-classic-auto
  - `verify-dispatch.sh` integrado ao CI
  - shellcheck: 0 errors (`bin/devorq`, `lib/*.sh`, `scripts/*.sh`)

---

## [3.6.6] — 2026-05-21

### Added
- **lib/rules.sh** — Sistema de regras enforced
  - `devorq::rules::init()` carrega regras global + local (hierarquia)
  - `devorq::cmd_rules()` com ações: list, check, apply, help
  - `devorq::rules::enforce_commit()` valida mensagens de commit
  - `devorq::rules::install_pre_commit_hook()` instala hook em .git/hooks/
  - `devorq::rules::check_commit_convention()` valida últimos 10 commits
  - `devorq::rules::check_brainstorm()` e `devorq::rules::check_grill()`
- **lib/commands/brainstorm.sh** — Comando `devorq brainstorm`
  - Sessão interativa com 5 gates: SCOPE_DEFINED, ENTITIES_IDENTIFIED, RISKS_RAISED, STACK_DECIDED, SESSION_COMPLETE
  - Captura entidades, riscos e decisões de stack
  - Salva sessão em .devorq/state/sessions/brainstorm_*.json
- **lib/commands/grill.sh** — Comando `devorq grill`
  - Sessão de sparring estruturado (demolição estruturada)
  - Gates: PREMISSA_QUESTIONADA, DESIGN_FLAW_FOUND, TRADE-OFF_ACCEPTED, GRILL_COMPLETE
  - Auto-capture de lição quando falha de design detectada
  - Três strikes = trigger para criar regra permanente
  - Salva sessão em .devorq/state/sessions/grill_*.json
- **`devorq rules`** — Sistema de regras (list, check, apply, help)
- **`devorq brainstorm <topic>`** — Brainstorm com gates de captura
- **`devorq grill <topic>`** — Sparring estruturado

### Changed
- **bin/devorq** — Adicionados comandos `rules`, `brainstorm`, `grill` ao dispatch
- **bin/devorq** — Carrega `lib/rules.sh` no bootstrap com `devorq::rules::init()`
- **bin/devorq** — `devorq init` agora copia regras globais para .devorq/rules/
- **bin/devorq** — Cria .devorq/state/sessions/ na inicialização
- **README.md** — Versão atualizada para 3.6.6

### Fixed
- **Regras não eram aplicadas** — Sistema de regras agora carrega e aplica automaticamente
- **Hierarquia global > local** — .devorq/rules/ sobrescreve global quando existe
- **Bug fix: devorq init** — `devorq::rules::init()` não cria mais `.devorq/` prematuramente
- **Bug fix: compact::generate** — `compact::generate()` agora redireciona JSON para arquivo `$output` (antes ignorava e输出va para stdout)
- **Bug fix: GATE-5** — `handoff.json` agora é gerado corretamente

---

## [3.6.7] — 2026-05-21

### Fixed
- **Bug fix: sandbox.spec.ts** — Arquivo de testes E2E para sandbox isolado criado
- **Bug fix: E2E tests** — Correções de case sensitivity e expectativas de output
- **Bug fix: lessons compile** — Adicionado `validate --auto` antes de `approve` (aprovação requer validação prévia)
- **Bug fix: SC2168 shellcheck** — Removidos 9x `local` fora de função em `scripts/validate-rules.sh` (linhas 121, 139, 174, 218, 223, 228, 272, 291, 311)
- **Bug fix: SC2144 shellcheck** — Corrigido glob com `-f` em `scripts/e2e-test.sh:393` (substituído por `find | grep -q`)

### Documentation
- **docs/DEVORQ-COMMIT-VISUAL-SPEC.md** — Atualizado status para `IMPLEMENTADO v3.6.5` com histórico completo de todas as 12 features implementadas desde v3.6.5 (visual.sh, commit.sh, debug-systematic.sh, rules, brainstorm, grill, shellcheck 0 errors)

---

## [3.6.5] — 2026-05-21

### Added
- **lib/visual.sh** — Verificação visual com Playwright + manual
  - `devorq::verify::run()` executa gates + verificação visual
  - `devorq::verify::playwright()` executa suite E2E
  - `devorq::verify::manual()` pede confirmação manual
  - `devorq::verify::trigger_debug()` trigger systematic-debugging quando falha
- **lib/commit.sh** — Commit interativo com convenção
  - `devorq::cmd_commit()` com formato `escopo(fase): descrição (detalhamento)`
  - Suporte a `--story`, `--scope`, `--phase`, `--message`, `--push`, `--dry-run`
- **scripts/debug-systematic.sh** — Trigger automático de debug sistemático
  - Phase 0: Classify failure mode (CAT A/B/C/D)
  - Phase 1: Root cause investigation
  - Phase 2: Pattern analysis
  - Phase 3: Context7 validation
  - Phase 4: Implementation
- **rules/visual-verification.md** — Documentação do gate de verificação visual
- **`devorq verify`** — Novo comando (Playwright ou manual)
- **`devorq commit`** — Novo comando (interativo com convenção)

### Changed
- **lib/auto.sh** — Removido commit automático após cada story
  - `devorq::auto::git_commit()` removido das linhas 319 e 400
  - Substituído por `devorq::verify::run()` + hint de commit manual
  - `devorq auto --continue` agora pede confirmação antes de commitar
- **rules/commit-convention.md** — Formato atualizado
  - Anterior: `type(scope): descrição`
  - Novo: `escopo(fase): descrição (detalhamento)`
  - 21 escopos válidos, 8 fases válidas
  - Sem emojis, sem co-autoria, pt-BR
- **bin/devorq** — Adicionados comandos `verify` e `commit`
- **bin/devorq** — Carrega `lib/visual.sh` e `lib/commit.sh` no bootstrap

### Fixed
- **Commit automático removido** — Developer agora commita manualmente após verificação visual
- **systematic-debugging trigger** — Quando teste falha (vermelho), debug entra em ação automaticamente

### Removed
- **`devorq::auto::git_commit()`** — Não existe mais (era automático)
- **Commits durante implementação** — Não há mais múltiplos commits durante a tarefa

---

## [3.6.4] — 2026-05-20

### Added
- **rules/** — Nova estrutura de regras globais versionadas em `DEVORQ_ROOT/rules/`
  - `rules/README.md` — Índice central com hierarquia e como sobrescrever
  - `rules/commit-convention.md` — Convenções de commit migradas do Hermes
  - `rules/brainstorm.md` — Regras de captura durante sessões brainstorm
  - `rules/grill.md` — Regras de sparring para sessões grill
- **skills/README.md** — Índice central de skills com hierarquia local > global

### Changed
- **INSTALL.md** — Corrigido path de instalação de `~/devorq/` para `~/projects/devorq/`
  - Evita conflito com instalações antigas
  - Adicionado alerta sobre instalações concorrentes no troubleshooting
  - Adicionada seção "Detectando instalações concorrentes"
- **bin/devorq header** — Comentário atualizado: não usar `~/devorq/`, usar `~/projects/devorq/`
- **skills/** — Adicionadas `learned-lesson` (migrada de ~/.devorq_v3), `grill-with-docs`, `security-hardening`
- **devorq skills list** — Agora lista skills do framework corretamente (antes hardcoded parcial)

### Fixed
- **devorq version** — Detecção automática de instalações concorrentes
  - Alerta no output quando `~/devorq/` ou `~/.devorq_v3/` existem com versão diferente
  - Sugere comando de remoção das instalações obsoletas

## [3.6.3] — 2026-05-18

### Added
- **devorq info** — Environment info + PAO status (Token Economy)
- **Laravel PAO** — Recomendação documentação (desacoplado, não dependência)
- **skills/grill-with-docs** — Skill de sparring terminológico (Matt Pocock) integrada ao GATE-0
  - Referências: `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` (Matt Pocock)
  - Integração: `lib/gates.sh` modificado (GATE-0, pós DDD)
  - ADR numbering: scan `docs/adr/` → highest 000N → next = 000(N+1)
  - Skip: bugfix, hotfix, debug, init, lessons, compact, sync, version, stats, test
  - AUTO mode: grill entre sprints (pré prd-from-spec.sh)

## [3.6.2] — 2026-05-18

### Added
- **docs/AUTO-MODE.md** — Documentação oficial do AUTO mode

### Changed
- **AUTO mode unificado** — `loop-auto.sh` agora sourceia `lib/auto.sh`
  - Funções compartilhadas: `next_story`, `pending_count`, `mark_pass`, etc.
  - Elimina duplicação de código
- **v1.2.1** — `loop-auto.sh` atualizado com versão

### Fixed
- **fix(bin)** — `--help` no comando `devorq auto` agora funciona corretamente
- **fix(execution.sh)** — Remoção do arquivo legado que sobrescrevia `cmd_auto`

---

## [3.6.0] — 2026-05-14

### Added
- **sec-001** — Correção de credenciais expostas em variáveis de ambiente
- **AUTO mode lessons** — Integração de lições aprendidas no loop automático
  - `.devorq-auto/lessons.json` — Aprendizados estruturados
  - `.devorq-auto/failures.md` — Sumário de falhas
  - `.devorq-auto/runs/*.log` — Logs de execução

### Security
- Correção de vulnerabilidades em `scripts/sync-push.py` e `scripts/sync-pull.py`
- Validação de inputs e sanitização em `lib/commands/*.sh`

---

## [3.5.0] — 2026-05-09

### Added
- **BDD Validation** — `lib/spec.sh` com validação Given/When/Then
  - `devorq spec validate` — valida SPEC.md com ACs BDD
  - `devorq spec template [feature]` — gera template com BDD
  - `devorq spec check-ac` — verifica cobertura de testes
- **UNIFY Phase** — `lib/unify.sh` com fase explícita de fechamento
  - `devorq unify [feature]` — executa UNIFY completo
  - Gera `.devorq/state/unify/*_unify.md` com resultado dos ACs
  - Atualiza `context.json` com campo `unify_done`
- **GATE-5.5 (UNIFY Check)** — verificação não-bloqueante entre GATE-5 e GATE-6
  - Mostra WARN se UNIFY ainda não executado
  - Passa se UNIFY já realizado
- **GATE-0 Suite** — env-context integrado ao GATE-0
  - `devorq gate 0` executa env-detect.sh automaticamente
  - Detecta stack, runtime, commands, ports, GOTCHAS
- **AUTO Mode** — `devorq auto [n|all]` para loop story-by-story
  - Story por story com delegate_task
  - Bug handling: systematic-debugging → Context7 → correção → commit
- **CLASSIC Mode** — `devorq mode classic` para execução tradicional
  - Nunca faz auto-commit sem validação manual do usuário
- **Code Review** — `devorq review [--branch HEAD]`
  - Review multi-agente com scoring 0-100
  - Filtra recomendações com confidence ≥80
- **E2E Test Suite** — `scripts/e2e-test.sh`
  - Sandbox isolado em /tmp/devorq-e2e-sandbox/
  - 11 testes cobrindo CLASSIC e AUTO modes

### Changed
- `lib/gates.sh` — GATE-0 agora integra env-context
- `lib/lessons.sh` — adicionada função `lessons::from_unify()`
- `bin/devorq` — adicionados comandos: env, spec, unify, mode, auto, review
- `bin/devorq` — GATE-5.5 como caso especial no handler de gates

### Documentation
- README.md, INSTALL.md, TROUBLESHOOTING.md, EXTRAS.md, SPEC.md atualizados para v3.5.0

---

## [3.4.1] — 2026-04-25

### Fixed
- Removido texto em árabe do README
- Version bump correto nos arquivos de documentação

---

## [3.4.0] — 2026-04-20

### Added
- GATE-0 Domain Exploration (DDD keywords detection)
- Context7 integration para validação de lições

---

## [3.3.0] — 2026-04-15

### Added
- Sistema de lições aprendidas com captura e busca
- Handoff generation com compact.sh
