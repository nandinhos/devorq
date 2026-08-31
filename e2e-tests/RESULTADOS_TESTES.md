# Resultados dos Testes E2E - DEVORQ v3.8.5

> ⚠️ **RELATÓRIO HISTÓRICO (2026-06-05, v3.8.5) — DESATUALIZADO.** As suítes
> atuais e a baseline verde vivem em `scripts/*-tests.sh` (ver §4 do `HANDOFF.md`).
> Este arquivo é mantido apenas como registro da sprint dogfooding v3.8.5.

> **Data:** 2026-06-05
> **Versao Testada:** DEVORQ v3.8.5
> **Ambiente:** WSL Ubuntu 24.04 (sprint dogfooding v3.8.5)
> **Status:** 77/77 = **100%** (deterministico em 3 runs)

## Resumo Executivo

Apos o fix do bug de namespace `devorq::sanitize_input` (que afetava
9 testes do refactor de lib/lessons.sh) e a correcao do `bin/devorq version`
(que retornava literal `VERSION` por bug do sync-version --fix), a suíte
Playwright agora passa 77/77 de forma deterministica.

3 runs consecutivas sem flakiness:
- Run 1 (7 workers paralelo): 77/77 em 3.5min
- Run 2 (7 workers paralelo): 77/77 em 2.7min
- Run 3 (1 worker serial): 77/77 em 5.4min

## O que Funciona

### Comandos Basicos
- `devorq version` - Retorna "DEVORQ v3.8.5" (regex /d+.d+.d+/)
- `devorq --help` - Mostra help completo com todos os subcomandos
- `devorq -h` - Equivalente a --help
- `devorq` (sem args) - Mostra help
- `devorq init` - Cria estrutura .devorq/ + 5 foundation docs
- `devorq test` - "Estrutura OK (devorq v3.8.5)"

### Sandbox e Isolamento
- Sandbox em /tmp com permissoes 0600
- Multiplos projetos simultaneos sem conflito
- Cleanup completo entre testes
- Estados residuais nao persistem

### GATE-0 ate GATE-7
- GATE-0 (Exploration): detecta env-context
- GATE-0.5 (Foundation): valida 5 docs
- GATE-1 (Spec): valida SPEC.md
- GATE-2 (Tests): "Nenhum framework de teste detectado (OK para CLI/bash puro)"
- GATE-3 (Context): valida context.json
- GATE-4 (Lessons): "1 licao(oes) capturada(s)"
- GATE-5 (Handoff): gera JSON valido
- GATE-6 (Context7): "Context7 nao configurado" (aviso, nao bloqueia)
- GATE-7 (Debug): "GATE-7 OK"

### Modos CLASSIC e AUTO
- Mode selector detecta CLASSIC vs AUTO corretamente
- Flow executa gates 0 -> 0.5 -> 1-7 na ordem
- Loop-auto interpreta prd.json corretamente

### Licoes Aprendidas
- Capture cria JSON com title/problem/solution preservados
- Search funciona com grep -iF -- (F-06 hardening)
- Validate auto-valida sem Context7
- List filtra por status
- Approve + compile funciona end-to-end

### Security
- Input validation bloqueia caracteres perigosos (; ` $ ( ) { } [ ] < > !)
- Path traversal rejeitado
- SSH StrictHostKeyChecking=yes enforced
- Exit codes consistentes
- File permissions 0600 em dados sensiveis

## Causa Raiz dos 9 Fails Anteriores (v3.8.4 baseline 35%)

### Bug 1: `devorq::sanitize_input` missing (sprint v3.8.5 REGRESSAO)
- **Causa raiz:** Refactor de `lib/lessons.sh` (story-003) extraiu funcoes
  para `lib/lessons/{crud,search,sync}.sh` mas perdeu a definicao de
  `devorq::sanitize_input` no processo. A funcao existia em `lib/lessons.sh`
  com namespace `devorq::` mas o source do agregador nao a exportava
  (definida em outro lugar: `lib/helpers.sh` sem namespace).
- **Sintoma:** `lessons::capture` salvava lessons com title/problem/
  solution VAZIOS (degraded behavior: command not found mas continua)
- **Fix:** 3 commits
  - 243bf52: wrapper inicial usando `lib/helpers.sh:sanitize_input`
  - f78d6f8: restaurada implementacao ORIGINAL de v3.8.4 (Python regex
    via heredoc, preserva espacos e pontuacao comum)
  - 33c7786: split search.sh + validate.sh para melhorar separacao
- **Testes que afetava:** 9 (todos de lessons.spec.ts e security-e2e)

### Bug 2: `bin/devorq version` retornava literal `VERSION`
- **Causa raiz:** Bug durante o sprint: `echo VERSION > VERSION` (string
  literal em vez do valor). Em seguida, `sync-version.sh --fix` substituiu
  o valor canonico contaminado ("VERSION") em todos os lugares inclusive
  `readonly DEVORQ_VERSION="VERSION"`.
- **Sintoma:** `devorq version` retornava "DEVORQ vVERSION" em vez de
  "DEVORQ v3.8.5". Quebrava o teste E2E "devorq version deve retornar
  versao" que checa regex /d+.d+.d+/
- **Fix (1 linha):** `readonly DEVORQ_VERSION="3.8.5"` (commit fe90a69)
- **Testes que afetava:** 1 (devorq-cli.spec.ts:45)

## Analise de Flakiness

Zero flakiness detectado. Apos 3 runs consecutivas em 3 modos diferentes
(7w paralelo, 7w paralelo, 1w serial), todos os 77 testes passaram
identicamente. Nao ha race conditions, timeouts arbitrarios, ou
dependencias entre testes.

## Cobertura de Fluxos Criticos

- Init flow: 1 teste
- Sandbox/isolamento: 5 testes
- Gates 0-7: 11 testes (positivos + negativos)
- Flow completo: 1 teste
- Modos CLASSIC/AUTO: 5 testes
- prd.json/AUTO: 3 testes
- Lessons CRUD: 11 testes (capture/list/search/validate/approve/compile)
- Security: 5 testes (input validation/path/SSH/exit codes/permissions)
- CLI basico: 7 testes (version/help/init/test/gates)
- CLI context/compact: 2 testes
- CLI foundation: 2 testes
- CLI debug/stats: 2 testes
- CLI vps: 1 teste
- Debug: 3 testes
- Gaps conhecidos: VPS exec remoto (testado apenas check, nao exec real)

## Recomendacoes para Prevenir Regressoes

1. **Adicionar `bin/devorq version` ao GATE-2** (Tests Pass) - o gate atual
   chama `devorq test` mas nao `devorq version`. Um teste de smoke que
   `devorq version` retorna regex /d+.d+.d+/ pegaria esse bug imediatamente.

2. **Validacao do sync-version --fix** - antes de aplicar, garantir que
   o valor canonico NAO eh placeholder (nao pode ser literal "VERSION").
   Adicionar assertion no script.

3. **Re-rodar E2E no CI antes de merge** - .github/workflows/e2e.yml ja
   existe (sprint v3.8.5), mas so roda em push. Adicionar check em
   pull_request para gatear merge.

4. **Teste de regressao para sanitize_input** - tests/security/test_*
   ja tem F-06 mas nao cobre o caso de funcao com namespace. Adicionar
   teste explicito em tests/security-e2e.spec.ts:
   `devorq::sanitize_input deve estar disponivel em todas as libs`.

5. **Manter sync-version.sh idempotente** - rodar --fix 2x seguidas deve
   ser no-op. Adicionar teste em scripts/ci-test.sh que valida isso.

## Metricas Finais

| Metrica | v3.8.4 (stale) | v3.8.5 mid-sprint | v3.8.5 final |
|---------|----------------|---------------------|----------------|
| E2E pass rate | 35% (nunca re-rodado) | 88.3% (68/77) | **100% (77/77)** |
| Testes cobertos | 77 | 77 | 77 |
| Flakiness | Desconhecido | Suspeito (worker reportou) | Zero (3 runs estaveis) |
| Tempo medio | N/A | 3.5min (paralelo) | 2.7-3.5min (paralelo) / 5.4min (serial) |
| Determinismo | N/A | N/A | Sim (3/3 runs identicos) |

## Riscos Residuais

1. **VPS exec remoto nao testado** - test/devorq-cli.spec.ts:320 so
   testa `devorq vps check` (ping), nao `devorq vps exec` (real exec).
   Mitigacao: Story 2 do sprint v3.8.4 (whitelist SSH) tem suite
   propria de regressao (tests/security/test_F01_RCE_source.sh).

2. **Sandbox /tmp limitado** - 1 teste (`state residual`) usa
   /tmp/devorq-e2e-sandbox. Se /tmp estiver cheio ou read-only, suite
   pode falhar. Mitigacao: nenhum teste real do projeto depende de
   /tmp-devorq-e2e-* (sandbox e auto-criado/destruido).

3. **Context7 nao configurado** - 2 testes mostram "Context7 nao
   configurado" como WARN. Suite passa mas em producao real, o gate
   fica mais estrito. Mitigacao: documentado em docs/specs/v3.8.4 que
   Context7 e opcional.

4. **E2E suite nao roda em sandbox Docker** - os testes rodam em
   WSL Ubuntu 24.04 direto, nao em container. CI (.github/workflows/
   e2e.yml) roda ubuntu-latest mas sem sandbox extra. Mitigacao:
   workspace e isolado por /tmp e nome de projeto unico.

5. **sync-version.sh --fix com VERSION contaminado** - bug ja
   reproduzido (commit fe90a69) e lição capturada. Risco residual:
   se rodar --fix antes de garantir que VERSION tem valor real
   (sem placeholder), mesmo bug pode voltar. Mitigacao: licao
   capturada + recomendado validacao no script.

## Conclusao

A suíte E2E DEVORQ v3.8.5 alcancou 100% de sucesso (77/77) de forma
deterministica. Os 2 bugs identificados (sanitize_input missing e
DEVORQ_VERSION literal) foram corrigidos com mudancas minimas e
cirurgicas no codigo produtivo. A suite e estavel, paralela,
isolada, e reproduzivel em 3 modos de execucao.
