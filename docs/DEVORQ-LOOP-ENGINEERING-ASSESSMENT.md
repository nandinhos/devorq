# DEVORQ — Assessment de Loop Engineering, Orquestração e Hardening

> **Status:** diagnóstico e plano canônico; nenhuma implementação autorizada
> **Data da auditoria:** 2026-07-13
> **Branch auditada:** `main`
> **Commit-base:** `54d602ad2b30470fc4f3ff9a3b5131dd08475568`
> **Escopo de alteração desta etapa:** somente este documento
> **Regra de execução:** sem commit, push, release ou alteração de código, scripts e versões

## 1. Sumário executivo

O DEVORQ tem **maturidade funcional intermediária-alta**, com uma superfície incomum para um framework Bash: CLI modularizada, gates, modos CLASSIC/AUTO, execução story-by-story, adapters para cinco runners, persistência local, lições, handoffs, review, debugging, segurança e uma suíte relevante. A maturidade das **garantias operacionais**, porém, é **intermediária**. Há uma diferença material entre possuir os componentes e conseguir provar, de ponta a ponta, que um loop só termina com sucesso quando seu objetivo foi verificado.

O principal achado não é ausência de funcionalidades; é a existência de **falsos positivos de conclusão** em caminhos centrais. O loop AUTO pode imprimir `AUTO MODE COMPLETE` e retornar `0` ainda que tenha acumulado falhas ou deixado stories pendentes. Uma story definitivamente falha é gravada com `passes=true`, o que a inclui na contagem de concluídas. No modo sem auto-commit, a story pode ser marcada como concluída com mudanças ainda não commitadas. O code review usado no dogfooding termina antes da elegibilidade por um retorno implícito sob `set -e`; depois desse defeito, as fases de reviewers, scoring e filtragem ainda são placeholders vazios.

Portanto, a abstração de **Loop Engineering agrega valor**, mas não deve começar pela criação dos oito comandos sugeridos. Ela já existe parcialmente sob nomes diferentes:

- implementação: `devorq auto`, `skills/devorq-auto/` e `lib/auto.sh`;
- code review: `devorq review` e `skills/devorq-code-review/`;
- debugging: `devorq debug`, `lib/debug.sh` e `scripts/debug-systematic.sh`;
- documentação/handoff: `devorq compact`, `devorq unify`, grill e foundation documents;
- execução: `DEVORQ_DELEGATE_FN` e `scripts/adapters/`;
- verificação: gates, `check-story.sh`, `devorq verify` e testes.

A evolução recomendada é extrair desses caminhos um **contrato mínimo comum** — perfil declarativo, estados terminais, política de risco, executor, verificador, juiz e evidência — sem criar um microframework. O primeiro consumidor deve ser apenas `implementation`, em modo experimental e compatível com `devorq auto`. Outros loops só entram quando seus verificadores específicos forem reais.

### Pontos fortes comprovados

- Núcleo Bash legível, execução local e baixa dependência externa (`bin/devorq`, `lib/`, `scripts/`).
- Separação recente entre router, dispatchers e comandos (`bin/devorq`, `lib/dispatchers/`, `lib/commands/`).
- Falha de processo em gates bloqueantes do `flow` já corrigida em relação a versões antigas (`lib/commands/workflow.sh:169-173`).
- Delegação desacoplada por contrato e dispatcher multi-runner (`AGENTS.md`, `scripts/adapters/delegate.sh`).
- No-diff guard, limite por story, lock quando `flock` existe e verificação pós-delegação no AUTO (`skills/devorq-auto/scripts/loop-auto.sh`).
- Escritas atômicas em partes sensíveis, uso de `jq --arg` e testes de segurança (`lib/context.sh:224-238`, `scripts/security-tests.sh`, `tests/security/`).
- Cobertura local ampla de CLI e fluxos: 75 testes unitários, 77 E2E e CI local com 47 grupos no baseline observado (`scripts/unit-tests.sh`, `e2e-tests/`, `scripts/ci-test.sh`).
- Regras canônicas explícitas; as três cópias presentes em `.devorq/rules/` são byte a byte iguais às correspondentes em `rules/`.

### Principais riscos

1. Estado terminal e exit code não representam honestamente o resultado do AUTO.
2. Executor ainda influencia excessivamente a própria conclusão; critérios de aceite não são executados nem confrontados com evidência.
3. `git add -A`, criação/troca de branch e ausência de dirty-worktree guard podem incluir alterações preexistentes no commit automático.
4. O code review promete uma pipeline multiagente que o script atual não executa.
5. A CI canônica fica verde enquanto a suíte específica de adapters fica vermelha.
6. Gates documentados como substantivos validam presença, contagem ou output, não necessariamente comportamento.
7. O schema de PRD existe, mas o `prd.json` do próprio DEVORQ não o satisfaz e nenhum caminho principal o valida.
8. Estado, evidência, lições, falhas, progresso e handoffs têm fontes concorrentes sem versionamento comum.
9. Locks, timeouts e comandos dos runners dependem de capacidades implícitas do ambiente; a degradação nem sempre é fail-closed.
10. README, SPEC, CHANGELOG, skills e documentos ativos contêm promessas divergentes do comportamento atual.

### Veredito

**Prosseguir com Loop Engineering, de forma condicional e incremental.** Primeiro, tornar os resultados atuais honestos. Depois, criar contratos versionados. Somente então introduzir um orquestrador mínimo e experimental. Não criar agora `migration`, `import-audit`, `release` ou `custom`; não há implementação ou verificador específico suficiente que justifique essas superfícies.

Não foi identificado P0 comprovado neste escopo. Os falsos sucessos e riscos de contaminação de commit são P1 por afetarem a confiabilidade central e a automação, mas não houve evidência de perda irreversível de dados, execução em produção ou exploração ativa que justificasse classificá-los como P0.

## 2. Método, baseline e evidências de execução

### 2.1. Baseline Git

Antes da análise:

| Verificação | Resultado |
|---|---|
| Raiz | `/home/nandodev/projects/devorq` |
| Repositório | raiz correta, com `bin/devorq`, `README.md`, `SPEC.md`, `lib/`, `scripts/` e `skills/` |
| Branch | `main`, acompanhando `origin/main` |
| Commit-base | `54d602ad2b30470fc4f3ff9a3b5131dd08475568` |
| Worktree inicial | limpo |
| Commits/pushes/releases | nenhum |

A análise confrontou documentação, código, testes e comportamento real. Documentos históricos foram usados como contexto, não como prova de que um defeito continua presente.

### 2.2. Dogfooding e probes

O comando slash solicitado, `/codereview_devorq`, não existe no router, nas skills ou na documentação executável. O equivalente canônico disponível foi executado:

```text
./bin/devorq review --branch HEAD
```

Resultado: exit `1`, após imprimir apenas `Executando Code Review...`. A causa está em `skills/devorq-code-review/scripts/review.sh:75-97`: `parse_args` termina com um teste `[[ ! -d "$PROJECT_ROOT" ]] && ...`; em um diretório válido esse teste retorna `1`, a função herda esse status e `set -e` encerra o script. O caminho esperado de “sem diff”, documentado com exit `3`, não chega a executar.

Outros probes comportamentais:

| Comando/cenário | Resultado observado | Conclusão |
|---|---|---|
| `./bin/devorq context get` | exit `1`, mostra uso | documentado no help geral, ausente no dispatcher de contexto |
| `./bin/devorq lessons apply` | exit `1` | documentado no README e implementado na biblioteca, ausente no dispatcher |
| `./bin/devorq gate e2e` | exit `1` | `gate_e2e`/`gate_8` existem, mas não são roteados |
| `./bin/devorq help flow` | exit `0`, help genérico | `help <comando>` é prometido, mas não implementado |
| AUTO com falha de delegação/verificação em repositório temporário | loop retorna `0` com story pendente/falha | status agregado não governa o exit code |
| validação do `prd.json` pelo schema versionado | 29 violações | schema, parser, fixtures e estado real divergem |

### 2.3. Testes executados

| Prova | Resultado |
|---|---|
| `bash scripts/unit-tests.sh` | exit `0`, 75/75 |
| `bash scripts/security-tests.sh` | exit `0`; resumo inconsistente: 36 executados, 26 aprovados, 0 falhos |
| ShellCheck completo em `bin/`, `lib/`, `scripts/` e skills, severidade error | exit `0` |
| `bash scripts/sync-version.sh --check` | exit `0`, declara versão global 4.0.0 alinhada |
| `npx playwright --version` | 1.61.1 |
| `npx playwright test --reporter=line` | exit `0`, 77 aprovados |
| `bash scripts/ci-test.sh` | exit `0`, 47/47 grupos e 77/77 E2E |
| `bash scripts/adapters/run-all-tests.sh` | exit `1`, 0/2 cenários aprovados |

O worktree foi novamente confirmado como limpo após as provas. Os testes dos adapters falham porque seus dry-runs esperam que uma story seja marcada como concluída sem produzir diff, enquanto o no-diff guard atual corretamente rejeita isso. O achado é duplo: as expectativas da suíte ficaram obsoletas e a suíte não participa da CI canônica (`scripts/adapters/test-opencode-delegate.sh:73-119`, `scripts/adapters/run-all-tests.sh`, `.github/workflows/ci.yml`, `scripts/ci-test.sh`).

## 3. Estado atual comprovado

### 3.1. Arquitetura atual

```text
bin/devorq
  ├─ lib/dispatchers/{init,workflow,state,delivery,discovery}.sh
  │    └─ lib/commands/*.sh
  ├─ CLASSIC: lib/commands/workflow.sh → lib/gates.sh
  ├─ AUTO Ralph: lib/commands/auto.sh
  │    └─ skills/devorq-auto/scripts/loop-auto.sh
  │         ├─ scripts/adapters/*-delegate.sh
  │         └─ skills/devorq-auto/scripts/check-story.sh
  ├─ AUTO guided: lib/auto.sh
  ├─ review: lib/commands/review.sh
  │    └─ skills/devorq-code-review/scripts/review.sh
  └─ estado distribuído
       ├─ .devorq/state/
       ├─ .devorq-auto/
       ├─ prd.json e progress.txt
       └─ HANDOFF.md / handoff.json
```

O router é simples e adequado ao projeto. Ele carrega helpers, contexto, lições e cinco dispatchers (`bin/devorq:24-75`). A modularização evita uma reescrita e oferece o seam natural para um futuro `lib/commands/loop.sh`. A ajuda geral, no entanto, não é derivada do próprio registro de comandos: há comandos roteados e não listados, além de comandos listados e não despachados (`bin/devorq:81-133`, `bin/devorq:139-199`).

Existem dois motores AUTO:

- `skills/devorq-auto/scripts/loop-auto.sh`: motor Ralph, padrão atual, com delegação, verificação, tentativas, branch e persistência própria;
- `lib/auto.sh`: motor guided/legado, sourceado pelo motor Ralph e depois parcialmente sobrescrito por funções homônimas.

Essa coexistência é uma dívida de fronteira, não motivo para reescrita. O caminho seguro é declarar um motor canônico e manter o outro como facade/depreciação com testes de compatibilidade (`lib/commands/auto.sh`, `lib/auto.sh`, `skills/devorq-auto/scripts/loop-auto.sh:22-24`).

O seletor de modo reconhece CLASSIC/AUTO por keywords e apresenta AUTO[N] como opção; a quantidade é efetivamente interpretada por `devorq auto [N]` (`skills/devorq-mode/mode-selector.sh:24-156`, `lib/commands/mode.sh`, `lib/commands/auto.sh:8-76`). Se `.devorq/` não existe, o seletor tenta `devorq init` com `|| true` e pode continuar apesar da falha de bootstrap (`mode-selector.sh:40-53`); esse fallback deve ser alinhado ao preflight fail-closed futuro. Grill e foundation já funcionam como especializações anteriores ao loop, por scripts próprios, e devem ser reutilizados em vez de recriados (`skills/grill-with-docs/`, `skills/project-foundation/`, `lib/gates.sh:54-150`).

### 3.2. Fluxo CLASSIC e gates

`devorq flow` exporta o intent e interrompe no primeiro gate que retorna erro (`lib/commands/workflow.sh:140-178`). Isso é uma melhoria real em relação aos relatórios históricos. O fluxo padrão, porém, é configurável por `DEVORQ_GATE_SEQUENCE` sem validação de obrigatoriedade e omite o gate 5.5 (`lib/commands/workflow.sh:163`). O `--resume` usa apenas uma lista histórica em `context.json`; não a vincula a intent, base commit, diff, versão do contrato ou run ID (`lib/commands/workflow.sh:156-167`).

| Gate | Comportamento implementado | Divergência relevante | Evidência |
|---|---|---|---|
| 0 | detecta ambiente; DDD por keywords; grill opcional | chamado “opcional”, mas DDD selecionado pode bloquear; falhas do grill são ignoradas | `lib/gates.sh:54-123` |
| 0.5 | valida cinco foundation documents | bloqueante e coerente; init interno ignora erro antes de pedir nova execução | `lib/gates.sh:127-150` |
| 1 | exige `SPEC.md` com pelo menos 100 bytes | não chama a validação estrutural existente em `lib/spec.sh` | `lib/gates.sh:153-179`, `lib/spec.sh` |
| 2 | tenta runners por stack e shellcheck | no próprio DEVORQ, não executa `scripts/unit-tests.sh`; ShellCheck cobre apenas `lib/*.sh` e `scripts/*.sh`, sem subdiretórios | `lib/gates.sh:181-288` |
| 3 | cria contexto se ausente e chama `ctx_lint` | erro de lint vira warning; qualquer arquivo criado permite PASS; `success_criteria` vazio não é erro | `lib/gates.sh:290-339`, `lib/context.sh:14-68` |
| 4 | conta arquivos de lição | não busca relevância para o intent; sempre retorna `0`; SPEC ainda o chama de bloqueante | `lib/gates.sh:341-368`, `SPEC.md:149-160` |
| 5 | gera e valida handoff | sem `jq`, confia no JSON; temp em `/tmp` é descrito como rename atômico apesar de poder cruzar filesystems | `lib/gates.sh:370-420` |
| 5.5 | consulta `unify_done` | sempre passa e não integra a sequência padrão | `lib/gates.sh:422-452`, `lib/commands/workflow.sh:163` |
| 6 | consulta Context7 | advisory e sempre retorna `0`, coerente se documentado assim | `lib/gates.sh:454-483` |
| 7 | executa `debug::check` | o fallback passa quando a lib não existe; no pacote atual a lib existe | `lib/gates.sh:485-503` |
| E2E/8 | executa Playwright e sempre retorna `0` | não é alcançável pelo dispatcher e pode instalar dependências durante um gate | `lib/gates.sh:505-565`, `lib/commands/workflow.sh:199-212` |

Se `lib/gates.sh` estiver ausente, o dispatcher simula o gate e retorna sucesso (`lib/commands/workflow.sh:188-192`). Para uma instalação incompleta, isso é fail-open e contradiz a filosofia declarada.

### 3.3. Modo AUTO

O motor principal seleciona stories por prioridade, delega por adapter, captura assinatura do diff, executa `check-story.sh`, registra progresso e opcionalmente commita. Ele traz proteções úteis: ausência de adapter é fail-closed salvo simulação explícita, no-diff bloqueia a conclusão, há limite de falhas por story e lock com `flock` (`skills/devorq-auto/scripts/loop-auto.sh:745-1002`).

Os defeitos que impedem tratá-lo como um loop confiável são:

1. `mark_failed` grava simultaneamente `passes=true`, `status=failed` e `failed=true`; a seleção de concluídas considera qualquer `passes=true` como concluída (`loop-auto.sh:363-429`).
2. O resumo sempre imprime `AUTO MODE COMPLETE`, e o retorno final não deriva de falhas ou pendências (`loop-auto.sh:1010-1032`).
3. `MAX_DELEGATE_RETRIES=1` é constante, embora a documentação o apresente como configuração (`loop-auto.sh:32`, `skills/devorq-auto/SKILL.md:252`, `docs/AUTO-MODE.md:113`).
4. Contadores de tentativas vivem apenas em memória e reiniciam após crash ou nova execução (`loop-auto.sh:827-835`).
5. Sem `DEVORQ_AUTO_COMMIT=1`, a story é marcada `done` após apenas um aviso de commit manual; isso diverge do significado de `passes` no schema, que exige verificação e commit (`loop-auto.sh:933-967`, `skills/devorq-auto/references/prd-schema.json:49-52`).
6. Com auto-commit, o commit ocorre antes de `mark_pass`, portanto a transição final do `prd.json` não entra no mesmo commit. Uma interrupção entre essas operações deixa código commitado e story pendente (`loop-auto.sh:933-965`).
7. `git add -A` inclui qualquer alteração da árvore; não há dirty-worktree guard, allowlist de arquivos nem prova de autoria do diff (`loop-auto.sh:510-566`).
8. A branch pode ser criada e ativada automaticamente antes de uma proteção explícita da árvore (`loop-auto.sh:510-530`).
9. Sem `flock`, a execução continua sem exclusão mútua; não há fallback por lock directory atômico (`loop-auto.sh:775-779`).
10. A assinatura de no-diff não detecta com segurança mudança de conteúdo em arquivo que já era untracked; ela também ignora diretórios do orquestrador por desenho (`loop-auto.sh:865-925`).
11. O modo headless continua story considerada complexa, descrito no código como “default seguro”; para risco desconhecido, o comportamento seguro é bloquear ou exigir política explícita (`loop-auto.sh:571-625`).
12. O trap de saída atualiza `failures.md`, mas não materializa um estado `cancelled`, não restaura transações parciais nem diferencia `SIGINT`, timeout e crash (`loop-auto.sh:779-782`).

### 3.4. Adapters e runners

O contrato `DEVORQ_DELEGATE_FN` é um bom ponto de extensão. `scripts/adapters/delegate.sh` normaliza `claude`, `codex`, `hermes`, `opencode` e `agy`, com timeout e journal. Wrappers finos evitam duplicação relevante (`AGENTS.md`, `scripts/adapters/delegate.sh`, `scripts/adapters/*-delegate.sh`).

O roteamento atual é por nome comercial em `DEVORQ_RUNNER`; não há descrição de capacidade, política de risco, fallback equivalente ou separação executor/verificador. O default de OpenCode inclui modelo comercial hardcoded (`scripts/adapters/delegate.sh:104-151`). O adapter valida título, mas não o contrato integral da story (`scripts/adapters/delegate.sh:48-60`).

Há um limite estrutural importante: um runner CLI pode executar comandos internamente. O DEVORQ não consegue prometer bloqueio de todo comando destrutivo apenas por prompt ou por inspecionar o comando externo `codex`, `claude` etc. Loops de alto risco devem exigir um runner com sandbox/telemetria compatível ou uma camada mediadora; se isso não estiver disponível, o comportamento correto é `blocked`.

### 3.5. Verificadores e juiz final

`check-story.sh` é um verificador genérico de stack, não um verificador de critérios de aceite. Ele não recebe a story, não associa comandos a critérios, não revisa o diff e não produz evidência estruturada (`skills/devorq-auto/scripts/check-story.sh`). As flags `--skip-lint` e `--skip-tests` são parseadas, porém nunca usadas (`check-story.sh:153-167`).

Outras lacunas:

- não há `cd "$project_root"`; comandos relativos dependem do cwd do chamador;
- detectar um manifest marca um runner como presente mesmo quando a ferramenta foi pulada;
- em PHP, ausência de `vendor/` pode apenas imprimir “skipped” e ainda aprovar;
- o ShellCheck genérico é advisory e cobre somente `"$bash_dir"/*.sh`;
- não há validação funcional específica por tipo de loop.

Hoje o executor não aprova diretamente o teste, mas o mesmo orquestrador que delega também escolhe o verificador, interpreta o retorno e grava `passes`. Não existe um juiz final independente com tabela de estados. A separação atual é, portanto, parcial.

### 3.6. Code review

A skill descreve elegibilidade, cinco reviewers paralelos, confidence scoring, filtro, investigação, aprovação e relatório (`skills/devorq-code-review/SKILL.md`). O script não realiza essa promessa:

- o bug de `parse_args` encerra a execução válida (`review.sh:75-97`);
- a fase dos cinco reviewers apenas informa que será executada via `delegate_task` (`review.sh:197-212`);
- scoring fixa `SCORED_ISSUES='[]'` (`review.sh:217-228`);
- filtragem fixa `FILTERED_ISSUES='[]'` (`review.sh:233-240`);
- entrada de aprovação fora das opções conhecidas cai no caminho de aprovação;
- a skill fala em oito fases, enquanto a numeração e a execução do script não formam oito fases reais.

Esse componente deve falhar como `blocked/unavailable` até possuir um adapter de reviewer funcional. Retornar “nenhum issue” a partir de arrays placeholders seria um falso negativo de auditoria.

### 3.7. Contratos e PRD

Existe JSON Schema Draft-07 para PRD (`skills/devorq-auto/references/prd-schema.json`). Ele exige campos como `project`, `created`, `description`, `acceptanceCriteria`, `priority` e `passes`. O `prd.json` do repositório usa um formato híbrido, incluindo `acceptance_criteria`, e produziu 29 violações na validação independente.

O runtime aceita deliberadamente variantes (`acceptanceCriteria`/`acceptance_criteria`, `passes`/`status`) e não valida o schema antes de executar (`lib/auto.sh`, `loop-auto.sh`, `e2e-tests/tests/modes-classic-auto.spec.ts:15-16`). O parser `prd-from-spec.sh` transforma headings em stories, pode gerar critérios vazios e escreve por redirecionamento direto, sem validação ou rename atômico (`skills/devorq-auto/scripts/prd-from-spec.sh:49-166`).

O schema atual é uma intenção útil, mas não é contrato operacional. Antes de novos loops, deve haver uma versão canônica, migração explícita e validação em runtime.

### 3.8. Persistência, lições e handoffs

Há vários artefatos sobrepostos:

| Artefato | Papel atual | Problema |
|---|---|---|
| `.devorq/state/context.json` | contexto e gates concluídos | estado de gates não é vinculado a run/intent/base; arquivo local ignorado |
| `.devorq/state/logs/run-*.jsonl` | audit trail CLASSIC | best-effort e com poucos campos |
| `.devorq/state/lessons/captured/*.json` | pipeline canônica de captura/validação/compilação | sem `schema_version` comum e sem ligação obrigatória à evidência do run |
| `.devorq-auto/lessons.json` | lições internas do AUTO | segunda fonte, formato e ciclo de vida próprios |
| `.devorq-auto/failures.md` | resumo humano do AUTO | projeção parcial; não inclui todas as classes de falha |
| `progress.txt` | log humano append-only | headers repetidos, sem schema e sem correlação robusta |
| `.devorq/state/handoff.json` | handoff gerado | projeção mínima de contexto; ignora evidência e decisões |
| `HANDOFF.md` | handoff manual rastreado | concorre com o JSON local e pode ficar obsoleto |
| HUB/VPS sync | compartilhamento opcional | sem contrato explícito de precedência/sincronização |

`lib/helpers.sh:101-118` grava JSONL com `run_id`, timestamp, agent, event, status e detail. Não registra de modo canônico runner, modelo/perfil, loop/story, tentativa, arquivos, comandos, exit codes, testes, duração, motivo de parada ou IDs de evidência. Journals dos adapters registram parte desses dados em outro formato (`scripts/adapters/delegate.sh:62-67`).

A fonte canônica recomendada para lições reutilizáveis é `.devorq/state/lessons/captured/`, enriquecida com versão, origem e evidência. `.devorq-auto/lessons.json`, `failures.md`, `progress.txt` e handoffs devem se tornar **projeções ou entradas migradas**, não novas fontes de verdade.

### 3.9. Testes e CI

A quantidade de testes é uma força; a qualidade das asserções é desigual.

- Vários E2E de gates e flow verificam somente que stdout contém `GATE`, sem exigir o exit code esperado. Um flow que imprimiu falha de GATE-0.5 satisfez essa asserção (`e2e-tests/tests/devorq-cli.spec.ts:169-185`, `e2e-tests/tests/gates.spec.ts:82-118`, `gates.spec.ts:319-336`).
- Há bons testes de exit code para parte do gate 1 e modos, mas o padrão não é consistente.
- O teste de VPS herda configuração externa e aceita output contendo `VPS` ou `ERROR`; ele pode tentar contato real e ainda passar (`e2e-tests/tests/devorq-cli.spec.ts:330-340`). A suíte não é totalmente hermética.
- A CI não chama `scripts/adapters/run-all-tests.sh`, que atualmente falha.
- `scripts/security-tests.sh` reporta contadores internamente inconsistentes apesar de exit `0`.
- Não foram encontrados testes comportamentais completos para `Ctrl+C`, recuperação em cada ponto transacional, ausência de `flock`, dirty worktree, branch protegida, limites de arquivos/linhas/tempo, produção, rollback ou independência do verificador.
- Não há teste que valide o `prd.json` real e fixtures contra o schema versionado.
- A meta de cobertura presente no PRD não é medida; “77/77” mede casos aprovados, não percentual de caminhos ou contratos.

### 3.10. Documentação e versionamento

`VERSION`, `bin/devorq`, README, SPEC e CHANGELOG declaram 4.0.0, e `sync-version.sh --check` aprova esse núcleo. Isso não resolve o versionamento de componentes:

- `skills/devorq-auto/SKILL.md` tem frontmatter 1.2.0, heading 1.1.0 e referências internas 1.0/1.1/1.2;
- `loop-auto.sh` tem header 1.2.0 e runtime 1.2.1;
- `docs/AUTO-MODE.md` permanece 1.0.0;
- grill 1.0.0 ainda declara integração DEVORQ 3.6.2;
- scripts e dispatchers têm headers de eras diferentes;
- `sync-version.sh` não verifica toda a superfície que sua própria documentação sugere: skills, documentos de componentes e compatibilidade mínima não entram na política;
- skills podem e devem ter SemVer independente, mas não existe `requires_devorq` ou matriz de compatibilidade.

O diretório obrigatório citado no escopo, `skills/devorq/`, não existe. Há `skills/devorq-auto/`, `skills/devorq-mode/` e `skills/devorq-code-review/`. Isso deve ser corrigido na documentação ou materializado apenas se houver responsabilidade real para um skill agregador; criar um diretório vazio não agrega valor.

## 4. Gaps priorizados

### 4.1. Critério de severidade

- **P0 — crítico:** perda/corrupção irreversível provável, execução destrutiva em produção, bypass de segurança crítico ou impossibilidade generalizada de operar com segurança.
- **P1 — alto impacto:** quebra de garantia central, falso sucesso/falso negativo, contaminação provável de entrega ou regressão não detectada pela CI.
- **P2 — melhoria relevante:** dívida que reduz previsibilidade, manutenção, rastreabilidade ou portabilidade, sem quebrar por si só a garantia central em todo run.
- **P3 — evolução opcional:** oportunidade válida, condicionada a uso e evidência.

### 4.2. Registro de gaps

| ID | Pri. | Natureza | Gap comprovado | Impacto | Evidência principal |
|---|---|---|---|---|---|
| LE-G01 | P1 | bug | AUTO retorna sucesso e imprime conclusão sem derivar o resultado de falhas e pendências | automação a jusante recebe falso positivo | `loop-auto.sh:1010-1032`; probe controlado |
| LE-G02 | P1 | bug/contrato | story `failed` recebe `passes=true` e entra na contagem de concluídas | estado contraditório e retomada incorreta | `loop-auto.sh:363-429` |
| LE-G03 | P1 | bug/segurança operacional | auto-commit usa `git add -A`, sem dirty guard/allowlist; transição da story não é atômica com o commit | mudanças alheias podem entrar no commit; crash deixa estado divergente | `loop-auto.sh:510-566`, `933-965` |
| LE-G04 | P1 | bug | code review encerra em `parse_args`; pipeline real é substituída por arrays vazios | dogfooding indisponível e risco de falso “sem issues” | `review.sh:75-97`, `197-240` |
| LE-G05 | P1 | bug/contrato | verificador não avalia ACs, diff ou evidência; flags skip são inertes; runner pode ser “detectado” e não executado | executor pode ser aprovado sem prova funcional | `check-story.sh:47-215` |
| LE-G06 | P1 | bug/arquitetura | gates permitem simulação na ausência da biblioteca, contexto inválido, sequência arbitrariamente reduzida e resume obsoleto | flow pode pular controles necessários | `workflow.sh:156-225`, `gates.sh:290-368` |
| LE-G07 | P1 | teste | CI verde com adapters vermelhos; E2E críticos aceitam somente texto | regressões do loop não bloqueiam merge | `scripts/ci-test.sh`, `scripts/adapters/run-all-tests.sh`, E2E citados |
| LE-G08 | P1 | contrato | schema de PRD não é validado e o PRD do próprio projeto tem 29 violações | planejamento e runtime interpretam estados diferentes | `prd-schema.json`, `prd.json`, parsers AUTO |
| LE-G09 | P1 | guardrail | tentativas não persistem; lock degrada silenciosamente; sinais/crash não produzem estado recuperável | loops duplicados, repetição e término ambíguo | `loop-auto.sh:775-835` |
| LE-G10 | P1 | guardrail | limites de tempo total, arquivos, linhas, produção e capacidade de sandbox não compõem uma política única | blast radius não é limitado de forma verificável | `loop-auto.sh`, `scripts/adapters/delegate.sh` |
| LE-G11 | P2 | arquitetura | dois motores AUTO com funções e semânticas sobrepostas | correções podem atingir somente um caminho | `lib/auto.sh`, `lib/commands/auto.sh`, `loop-auto.sh` |
| LE-G12 | P2 | observabilidade | audit log e journals são best-effort, fragmentados e incompletos | não responde todas as perguntas operacionais do assessment | `lib/helpers.sh:101-118`, adapters |
| LE-G13 | P2 | memória | lições, failures, progress e handoffs concorrem sem schema/precedência | aprendizado não influencia consistentemente runs futuros | `.devorq/state/`, `.devorq-auto/`, `progress.txt`, `HANDOFF.md` |
| LE-G14 | P2 | documentação | README/SPEC/CHANGELOG superestimam gates, adapters e review | usuários confiam em garantias inexistentes | documentos e comportamento descritos nas seções 2 e 3 |
| LE-G15 | P2 | CLI | comandos documentados inexistem; comandos existentes não são listados; help específico é genérico | automação e UX ficam instáveis | `bin/devorq`, `lib/commands/context.sh`, `lib/commands/lessons.sh` |
| LE-G16 | P2 | versão | versões internas divergentes e sem compatibilidade mínima; check global tem cobertura parcial | migrações e suporte não sabem quais combinações são válidas | skills, scripts e `sync-version.sh` |
| LE-G17 | P2 | parser | SPEC→PRD é permissivo, não atômico e não validado | headings documentais viram stories inválidas | `prd-from-spec.sh:49-166` |
| LE-G18 | P2 | portabilidade | uso de GNU `timeout`, `date -Iseconds` e `flock` não tem política uniforme | WSL/Linux funcionam melhor que ambientes sem utilitários GNU | loop e adapters |
| LE-G19 | P2 | teste | E2E contém cenário VPS não hermético e não mede cobertura contratual | resultado depende do ambiente e mascara falha | `devorq-cli.spec.ts:330-340` |
| LE-G20 | P3 | oportunidade | perfis por capacidade e fallback equivalente ainda não existem | roteamento não otimiza risco/custo/contexto | `scripts/adapters/delegate.sh` |
| LE-G21 | P3 | oportunidade | loops especializados ainda não compartilham contrato | duplicação futura se cada comando crescer isoladamente | comandos/skills atuais |
| LE-G22 | P3 | oportunidade | integração HUB como projeção de runs/lessons não é definida | colaboração remota continua ad hoc | README e scripts de sync |

## 5. Dívidas documentais

| Documento/artefato | Situação | Ação recomendada |
|---|---|---|
| `README.md` | diz que adapters estão validados 5/5 e descreve gates/verificação com mais força que o código | corrigir após testes comportamentais; não esconder limitações atuais |
| `SPEC.md` | marca release como concluída, G4 como bloqueante e E2E como 100%, mas também registra `gate e2e` como gap | separar requisitos normativos de histórico de sprint; atualizar estados por prova |
| `CHANGELOG.md` | histórico válido, porém afirma hardening/adapters conforme o estado da release, hoje parcialmente regredido | preservar histórico; acrescentar correção futura, sem reescrever releases antigas |
| `docs/README.md` | classifica documentos históricos/resolvidos como ativos e contém inventário incompleto | transformar em índice com `canônico`, `histórico`, `arquivado`, owner e última verificação |
| `docs/AUTO-MODE.md` | v1.0.0, ordem de commit/mark e contrato de delegate desatualizados; link relativo para SPEC incorreto | reescrever a partir do contrato executável e matriz de estados |
| `docs/DEVORQ-RULES-CODE-REVIEW.md` | descreve ausências que já foram implementadas e é listado como ativo | arquivar como auditoria histórica ou revalidar integralmente |
| `docs/CODE_REVIEW_ELITE_2026-07-02.md` | baseline histórico valioso de 106 achados; parte foi corrigida em 4.0.0 e parte permanece | manter histórico, com banner apontando para este assessment como estado revalidado |
| `docs/REFACTOR-ELITE-PLAN.md` | plano concluído, mas contém itens explicitamente adiados que ainda são gaps | marcar concluído/histórico e mover pendências válidas para backlog canônico |
| `docs/DEVORQ-DEFICITS-FIX-PLAN.md` | marcado resolvido, ainda listado como ativo; contém paths pessoais/VPS/Grafana externos | arquivar e sanitizar referências operacionais não portáveis |
| `docs/ANALISE-KARPATHY-DEVORQ.md` | rationale histórico útil, mas declara superioridade/garantias sem a evidência atual | manter como análise histórica, não documentação operacional |
| `docs/FLOW-ORCHESTRATOR-ATTEST.md` | descreve simulação sem delegate e contagens antigas | arquivar ou substituir por atestação reproduzível baseada em testes |
| `docs/TEST_STRATEGY.md` | mistura estratégia futura, counts e flags não implementadas | converter em matriz de contratos e gaps de teste |
| `deliverable.md`, `HANDOFF.md`, `progress.txt` | artefatos rastreados de runs anteriores, com versões/estado envelhecidos | decidir se são fixtures/histórico; não tratá-los como status atual |
| `AGENTS.md` versus `.devorq/rules/` | três regras copiadas estão alinhadas; regras adicionais de `rules/` não aparecem na cópia local | documentar exatamente quais regras `init/export` replica |
| `skills/devorq/` | path citado como obrigatório, mas inexistente | remover referência ou definir responsabilidade antes de criar |

Não foi encontrado carregamento runtime de `docs/archive/` ou `docs/specs/archive/`. Sua influência é indireta: documentos ativos, CHANGELOG, testes e planos atuais ainda os referenciam. O risco maior de estado antigo influenciar comportamento está nos artefatos rastreados `prd.json`, `.devorq/state/*`, `.devorq-auto/*` e `progress.txt`, que os comandos realmente leem.

## 6. Proposta de arquitetura

### 6.1. Princípio de desenho

O DEVORQ não precisa de um “framework dentro do framework”. Precisa de um lifecycle pequeno e explícito, reutilizando Bash, `jq`, os adapters e os gates existentes.

```text
CLI compatível
  ├─ devorq auto ───────────────┐
  ├─ devorq review ─────────────┤ facades graduais
  └─ devorq loop <profile> ─────┘
                 │
        Loop Orchestrator mínimo
                 │
        profile + contract + risk
          ┌──────┴────────┐
          │               │
       executor        verifier
       adapter          policy
          │               │
          └──────┬────────┘
             final judge
                 │
       state + events + evidence
                 │
      projections: progress, handoff,
      failures e lessons candidatas
```

O orquestrador não implementa lógica específica de domínio. Ele apenas:

1. valida entrada e ambiente;
2. carrega um perfil declarativo;
3. calcula/aplica a política de risco;
4. escolhe executor e verificador por capacidade;
5. controla tentativas, tempo, estado e concorrência;
6. captura diff e evidências;
7. chama gates/verificadores específicos;
8. deixa o juiz derivar o estado terminal;
9. gera projeções de compatibilidade.

### 6.2. Go/no-go para a abstração

Criar o orquestrador somente após estes critérios:

- matriz de estados e exit codes coberta por testes;
- PRD/Story v1 validável e migração idempotente;
- AUTO atual sem falso sucesso em falha, pendência, no-diff e commit incompleto;
- adapters na CI e verdes com expectativas coerentes;
- dirty-worktree e lock fail-closed;
- ao menos três fluxos comprovadamente compartilham o mesmo lifecycle.

Hoje o último critério é parcialmente atendido por implementação, review e debugging, mas review ainda não é operacional. Isso justifica extrair internamente o lifecycle, não publicar oito comandos.

### 6.3. Perfis de loop

Um perfil é JSON declarativo versionado, não shell arbitrário. Campos mínimos:

```json
{
  "schema_version": "1.0",
  "id": "implementation",
  "planner": "story",
  "executor_capability": "implementer",
  "verifier_policy": "risk-proportional",
  "required_gates": ["preflight", "change", "tests", "diff", "final"],
  "limits": {
    "attempts_per_story": 3,
    "wall_time_seconds": 1800,
    "max_files": 20,
    "max_changed_lines": 1000
  },
  "completion_policy": "verified"
}
```

Valores são ilustrativos, não defaults aprovados. `custom` não deve permitir `source` de shell do projeto. Hooks, quando necessários, devem ser comandos declarados, resolvidos por allowlist e registrados como evidência.

Perfis candidatos e condição de entrada:

| Perfil | Reuso atual | Verificador obrigatório antes de publicar |
|---|---|---|
| `implementation` | AUTO + adapters + check-story | ACs, diff, testes e política de commit |
| `code-review` | skill/review | reviewers reais, scoring reproduzível e regra de “nenhuma evidência ≠ nenhum issue” |
| `debugging` | debug sistemático | reprodução, hipótese, teste de regressão e ausência da falha |
| `documentation` | compact/unify/grill | links, exemplos/comandos, drift contra CLI e estrutura |
| `migration` | não há loop completo | dry-run, invariantes pré/pós, backup e rollback ensaiado |
| `import-audit` | não há | resolução de imports, dependências e build por stack |
| `release` | commit/version/sync parciais | clean tree, versão, changelog, tag/branch policy e suite completa |
| `custom` | não há | sandbox de hooks, schema e política de confiança |

Os quatro últimos permanecem P3 até haver uso real e verificador concreto.

### 6.4. Contratos tipados

Manter JSON Schema Draft-07 inicialmente evita churn em relação ao schema existente. Schemas sugeridos sob `schemas/v1/`:

| Contrato | Fonte/reuso | Campos centrais |
|---|---|---|
| Story | evolui o `prd-schema.json`; aceita migração do formato híbrido | id, objective, description, acceptance_criteria, dependencies, priority, complexity, allowed_files, risks, status |
| Loop | novo envelope do objetivo; referencia stories, não duplica o PRD | id, profile, objective, scope, constraints, risks, acceptance, policy, base_commit |
| Execution | evento por tentativa | loop/story/attempt, actor, runner/profile, started/ended, commands, exit, diff/evidence IDs |
| Verification | resultado separado da execução | verifier, checks, AC mapping, pass/fail/blocked, evidence IDs |
| Evidence | artefato imutável e endereçável | type, path/hash, producer, timestamp, redaction, result |
| Failure | normaliza falhas hoje espalhadas | phase, category, error, retryable, evidence, correction |
| Lesson | evolui lessons capturadas | hypothesis, action, result, correction, evidence, scope, confidence, status |
| Handoff | projeção de run | objective, terminal/current state, evidence summary, decisions, next step |

Regras:

- todo documento tem `schema_version` e ID estável;
- `prd.json` continua como fonte de planejamento durante a migração;
- handoff não replica todo o event log; referencia IDs;
- `passes` permanece apenas como campo de compatibilidade derivado, nunca como estado canônico;
- schemas contêm apenas invariantes que o runtime consegue impor;
- runtime usa predicados `jq` fail-closed; CI confronta exemplos e predicados com um validador JSON Schema completo;
- migrações são explícitas, idempotentes, com backup e `--dry-run`; nenhuma conversão silenciosa.

### 6.5. Estados e condição de parada

Estados transitórios internos podem ser `pending`, `planning`, `running` e `verifying`. Os únicos estados terminais do loop são:

| Estado terminal | Quando usar | Sucesso de processo? |
|---|---|---|
| `completed` | todos os critérios obrigatórios têm evidência válida e a política de conclusão foi satisfeita | sim |
| `failed` | verificação ou execução falhou de modo definitivo | não |
| `blocked` | pré-condição/capacidade obrigatória ausente | não |
| `requires_owner_decision` | continuar exige escolha humana material | não |
| `max_attempts_reached` | orçamento persistido de tentativas acabou | não |
| `cancelled` | cancelamento explícito ou sinal tratado | não |

O juiz final é uma função determinística sobre verificações, gates, limites e política. O executor jamais escreve o estado terminal. Para o novo comando, recomenda-se exit codes distintos (`0`, `20`-`23`, `130`) e JSON de status; a facade `devorq auto` pode mapear qualquer término não concluído para `1` durante a compatibilidade. O contrato exato de exit codes é uma decisão antes da Fase 2.

### 6.6. Executor, verificador e juiz

```text
Executor produz mudança + relato
        ↓
Verificador produz resultado + evidências
        ↓
Juiz aplica política e deriva estado
```

Separação proporcional ao risco:

| Risco | Executor | Verificação | Juiz |
|---|---|---|---|
| baixo | qualquer implementer compatível | checks determinísticos; mesma sessão de modelo permitida para revisão explicativa | state machine |
| médio | implementer | contexto limpo e identidade de execução diferente; checks determinísticos obrigatórios | state machine |
| alto | implementer com sandbox | reviewer/qa independente e, quando possível, runner diferente; evidência completa | state machine, sem override silencioso |
| crítico/produção | runner com controles comprovados | verificador independente + aprovação do owner | owner autoriza; state machine registra decisão |

“Independente” significa identidade de execução e contexto separados, não obrigatoriamente fornecedor diferente. Fallback nunca pode reduzir a independência exigida pelo risco.

### 6.7. Matriz de roteamento por capacidade

Perfis lógicos:

```text
architect
implementer
reviewer
researcher
qa
documentation
fallback-long-context
```

Configuração deve mapear essas capacidades para adapters disponíveis. O algoritmo é determinístico:

1. filtrar runners disponíveis e compatíveis com edição/auditoria/sandbox/contexto;
2. eliminar os que violam risco e independência;
3. ordenar por prioridade configurada;
4. registrar perfil pedido, adapter escolhido, modelo efetivo e motivo;
5. em rate limit/timeout, tentar somente fallback equivalente;
6. se não houver equivalente, terminar `blocked`.

Nomes comerciais ficam confinados ao inventário de adapters. Não há necessidade de um scheduler, broker ou serviço externo.

### 6.8. Guardrails

| Guardrail | Política recomendada |
|---|---|
| tentativas | persistir por `loop_id/story_id`; incremento antes da execução; nunca zerar em resume |
| tempo | timeout por comando/runner e deadline monotônico do loop; timeout é estado/evidência, não sucesso |
| arquivos | allowlist da story + limite de quantidade; diff fora do escopo bloqueia antes de verificar |
| linhas | budget de adições+remoções; excedente exige decisão ou repartição da story |
| comandos destrutivos | exigir runner mediável/sandbox em risco alto; bloquear se a capacidade não puder ser provada |
| ambiente/produção | marcador explícito de ambiente e política de branches/remotes protegidos; heurística apenas reforça, nunca libera |
| no-diff | hash de conteúdo tracked e untracked, com manifest inicial; mudança em arquivo já untracked deve contar |
| dirty worktree | bloquear por padrão; exceção somente com allowlist e snapshot explícitos |
| concorrência | `flock` ou lock directory atômico portável; ausência de ambos bloqueia |
| idempotência | IDs de run/attempt, journal append-only e recovery por último evento válido |
| rollback | restaurar apenas arquivos comprovadamente pertencentes à tentativa; nunca `git reset --hard`; sempre preservar patch/evidência |
| branch | validar branch protegida, upstream e baseline antes de criar/trocar |
| commit | stage por allowlist, commit transacional com estado, hooks ativos e sem push implícito |
| headless | nenhuma leitura interativa; decisão ausente vira `blocked` ou `requires_owner_decision` |
| sinal | traps para INT/TERM; finalizar evento, liberar lock e marcar `cancelled` |

### 6.9. Observabilidade mínima

Fonte canônica sugerida: `.devorq/state/runs/<run_id>/events.jsonl`, append-only. Cada evento inclui, quando aplicável:

```text
schema_version, run_id, loop_id, profile, story_id, attempt,
timestamp, actor_role, capability, runner, model,
event, status, duration_ms, command_id, exit_code,
files, diff_stats, check_id, evidence_ids, stop_reason
```

Comandos e outputs devem ser redigidos; secrets e prompts completos não entram por default. Quando um runner opaco não expuser comandos internos, o registro deve dizer `command_observability=partial`, nunca fingir cobertura total. `progress.txt`, `failures.md`, handoff e resumo terminal são gerados a partir dos eventos.

### 6.10. Lições e memória

Estratégia recomendada:

1. evento/failure/evidence do run é fato imutável;
2. uma lição começa como candidata ligada a esses IDs;
3. validação humana/automática promove a candidata em `.devorq/state/lessons/captured/`;
4. busca por intent, stack e tags injeta apenas lições relevantes no próximo planejamento;
5. `.devorq-auto/lessons.json` é migrado uma vez e depois vira projeção de compatibilidade;
6. HUB é sink/source opcional com sincronização explícita, nunca autoridade implícita.

Isso preserva o pipeline `capture → validate → approve → compile` existente em `lib/lessons.sh` e remove a segunda autoridade do AUTO.

### 6.11. Compatibilidade e versionamento

- `VERSION` é a única fonte da versão do framework; CLI e docs públicas derivam dela.
- Skills mantêm SemVer independente, com `requires_devorq` e versão do contrato suportada.
- Scripts internos não ganham versão própria salvo quando expõem protocolo persistido/público.
- `schema_version` é independente da versão do framework.
- `sync-version.sh --check` verifica a fonte global, manifests de componentes e compatibilidade, sem forçar todas as skills à mesma versão.
- `devorq auto` permanece funcional durante pelo menos duas versões menores após `loop implementation` ficar estável.
- Toda depreciação emite warning acionável; migração tem dry-run, backup e rollback.

## 7. Plano incremental

### Fase 0 — Honestidade operacional e alinhamento documental

Objetivo: eliminar falsos sucessos antes de ampliar a arquitetura.

- corrigir estado terminal/exit do AUTO;
- separar failed/skipped/completed de `passes`;
- proteger dirty tree, branch e staging;
- fazer review falhar honestamente até ser funcional;
- alinhar gates, CLI help e documentação ao comportamento;
- incluir adapters e asserts de exit code na CI.

**Gate de saída:** nenhuma falha/pending/no-diff imprime conclusão ou retorna `0`; CI canônica fica vermelha quando um adapter contract quebra.

### Fase 1 — Contratos e schemas

Objetivo: tornar entrada, estado, verificação e evidência validáveis.

- inventário e ADR de campos existentes;
- Story/PRD v1 e migração do formato híbrido;
- schemas de loop, execution, verification, evidence, failure, lesson e handoff;
- validator runtime com `jq` e validação completa na CI;
- parser SPEC→PRD atômico e fail-closed.

**Gate de saída:** todos os exemplos, fixtures e o PRD dogfood validam; inputs inválidos não alteram estado.

### Fase 2 — Orquestrador mínimo experimental

Objetivo: provar a abstração com um único perfil.

- `devorq loop implementation --experimental`;
- lifecycle e state machine, sem DAG genérico;
- tentativas/deadline/lock/recovery persistidos;
- routing por capacidade com defaults locais;
- facade de compatibilidade para `devorq auto`.

**Gate de saída:** paridade comportamental coberta entre AUTO e o perfil implementation, inclusive falhas e resume.

### Fase 3 — Verificação independente

Objetivo: separar executor, verificador e juiz proporcionalmente ao risco.

- classificação de risco reproduzível e sobrescrita explícita;
- interface de verifier e AC→evidence mapping;
- contexto/identidade independentes em risco médio+;
- owner gate para risco crítico.

**Gate de saída:** testes provam que output do executor sozinho nunca conclui o loop.

### Fase 4 — Observabilidade e memória

Objetivo: uma trilha canônica pequena, pesquisável e segura.

- event/evidence journal versionado;
- projeções de progress/failures/handoff;
- migração e normalização de lessons;
- política de retenção/redação.

**Gate de saída:** um run responde às 12 perguntas operacionais do escopo por consulta local, sem ler logs concorrentes manualmente.

### Fase 5 — Loops especializados

Objetivo: adicionar perfis somente onde há verificador específico.

Ordem recomendada: `code-review`, `debugging`, `documentation`. Avaliar `migration`, `import-audit`, `release` e `custom` após métricas dos três primeiros. Cada perfil entra experimental, sem duplicar comando existente; a facade antiga permanece durante migração.

**Gate de saída:** cada perfil tem testes de sucesso, falha, bloqueio, cancelamento, limite e falsa declaração do agente.

### Fase 6 — Dogfooding e hardening

Objetivo: usar o DEVORQ para provar o DEVORQ.

- matriz WSL/Linux/Docker/CI;
- fault injection em crash, timeout, Ctrl+C, lock, disco e runner indisponível;
- auditoria independente do assessment e dos contratos;
- janela de depreciação e release notes;
- somente então remover caminhos legados.

**Gate de saída:** zero falso sucesso em campanha de falhas, migração reversível e compatibilidade documentada.

## 8. Backlog executável

### LE-001 — Tornar o término do AUTO honesto

- **Problema:** resumo e exit code não derivam de falhas/pending; `failed` usa `passes=true`.
- **Objetivo:** implementar matriz de estado terminal e retorno não zero para todo término não concluído.
- **Arquivos prováveis:** `skills/devorq-auto/scripts/loop-auto.sh`, `lib/auto.sh`, `scripts/unit-tests.sh`, `e2e-tests/tests/modes-classic-auto.spec.ts`.
- **Dependências:** nenhuma.
- **Risco:** alto; altera automações que dependem do falso exit `0`.
- **Critérios de aceite:** failed não é completed; pending/failure/max/cancel nunca imprime COMPLETE; contagens são mutuamente exclusivas; estado e exit têm tabela documentada.
- **Testes:** delegate falha, verifier falha, no-diff, max attempts, pending residual, success real e restart.
- **Compatibilidade:** `devorq auto` usa exit `1` genérico inicialmente; JSON/status detalha a causa.
- **Rollback:** feature flag temporária para semântica nova por uma única versão; não restaurar `passes=true` em failed.

### LE-002 — Proteger árvore, branch e transação de commit

- **Problema:** `git add -A`, branch automática e conclusão/commit não atômicos.
- **Objetivo:** baseline da árvore, dirty guard, allowlist de stage e protocolo recuperável de commit+estado.
- **Arquivos prováveis:** `loop-auto.sh`, `lib/commit.sh`, novos helpers de change guard, testes AUTO.
- **Dependências:** LE-001.
- **Risco:** alto; toca no fluxo de entrega.
- **Critérios de aceite:** árvore suja bloqueia por default; arquivos preexistentes nunca são staged; branch protegida bloqueia; auto-commit inclui a transição coerente ou a recupera; hooks não são ignorados.
- **Testes:** tracked/untracked preexistente, arquivo fora da allowlist, hook falhando, crash antes/depois do commit, branch protegida.
- **Compatibilidade:** opt-in explícito e registrado para dirty tree; nenhum push automático novo.
- **Rollback:** desativar auto-commit mantendo diff e journal; nunca reset destrutivo.

### LE-003 — Corrigir ou bloquear honestamente o code review

- **Problema:** entrypoint quebra e fases centrais são placeholders vazios.
- **Objetivo:** impedir falso review e definir contrato mínimo de reviewer.
- **Arquivos prováveis:** `skills/devorq-code-review/scripts/review.sh`, `skills/devorq-code-review/SKILL.md`, `lib/commands/review.sh`, testes novos.
- **Dependências:** nenhuma para correção do entrypoint; Fase 3 para independência completa.
- **Risco:** médio.
- **Critérios de aceite:** argumentos válidos chegam à elegibilidade; ausência de reviewer produz blocked/nonzero; zero issues só é possível após execução e evidência de reviewers; opções inválidas não aprovam.
- **Testes:** no diff, diff elegível, reviewer ausente, reviewer falha, issues vazios reais, approval inválido e headless.
- **Compatibilidade:** manter `devorq review`; não publicar automaticamente em PR.
- **Rollback:** reverter para estado explicitamente indisponível, não para placeholder aprovador.

### LE-004 — Alinhar gates e resume à filosofia fail-closed

- **Problema:** biblioteca ausente simula sucesso; gates fracos; sequência/resume não são vinculados ao run.
- **Objetivo:** declarar gates obrigatórios/advisory e validar sua execução/evidência.
- **Arquivos prováveis:** `lib/gates.sh`, `lib/commands/workflow.sh`, `lib/context.sh`, testes de gates.
- **Dependências:** LE-001 para terminologia comum.
- **Risco:** alto; flows antes verdes podem bloquear.
- **Critérios de aceite:** instalação incompleta falha; sequência não remove required gates sem policy; resume exige intent/base/contract compatíveis; G1 valida spec; G2 executa suite configurada; G3 rejeita contexto inválido.
- **Testes:** gates lib ausente, override reduzido, intent alterado, base alterada, contexto vazio, suite falha e advisory explícito.
- **Compatibilidade:** warnings de migração e `--allow-*` explícitos, nunca defaults silenciosos.
- **Rollback:** restaurar individualmente um gate como advisory documentado, sem simular PASS.

### LE-005 — Tornar a CI contratual

- **Problema:** adapters vermelhos fora da CI e E2E de output aceitam fluxos falhos.
- **Objetivo:** bloquear regressões por exit, estado e efeitos, não apenas texto.
- **Arquivos prováveis:** `scripts/ci-test.sh`, `.github/workflows/ci.yml`, `scripts/adapters/*test*.sh`, `e2e-tests/tests/*.spec.ts`, `scripts/security-tests.sh`.
- **Dependências:** LE-001 a LE-004 para expectativas finais.
- **Risco:** médio; CI pode ficar vermelha até correções reais.
- **Critérios de aceite:** adapter suite faz parte do gate; testes dry-run esperam no-diff; flows assertam exit; counters de segurança fecham; VPS é hermético.
- **Testes:** mutação deliberada de exit/status, adapter sem diff, ambiente VPS definido, runner ausente.
- **Compatibilidade:** preservar comandos de CI existentes; apenas ampliar seu conteúdo.
- **Rollback:** separar job novo como required após período curto de observação, sem remover testes.

### LE-006 — Corrigir verdade documental e inventário CLI

- **Problema:** comandos e garantias divergem entre help, README, SPEC, CHANGELOG e docs ativas.
- **Objetivo:** gerar uma matriz canônica de comando→dispatcher→teste→doc e reclassificar documentos históricos.
- **Arquivos prováveis:** `bin/devorq`, docs citados na seção 5, `docs/README.md`.
- **Dependências:** LE-001 a LE-005 para não documentar semântica transitória.
- **Risco:** baixo.
- **Critérios de aceite:** todo comando público existe, aparece no help e tem teste; histórico é rotulado; nenhuma garantia maior que a prova.
- **Testes:** snapshot/contract test da ajuda contra registro de comandos e exemplos executáveis.
- **Compatibilidade:** aliases ou depreciação para comandos públicos; CHANGELOG histórico preservado.
- **Rollback:** reverter texto/índice; não reativar instrução sabidamente falsa.

### LE-101 — Definir catálogo e ADR dos contratos v1

- **Problema:** campos equivalentes vivem em PRD, lessons, handoffs e AUTO sem semântica única.
- **Objetivo:** inventariar/reusar campos e decidir autoridade, estados e versionamento.
- **Arquivos prováveis:** `docs/architecture/`, `docs/adr/`, `schemas/v1/`.
- **Dependências:** Fase 0.
- **Risco:** médio; generalização prematura.
- **Critérios de aceite:** cada campo tem definição, owner e fonte; duplicações são projeções explícitas; estados terminais são fechados.
- **Testes:** exemplos positivos/negativos revisados contra comportamento real.
- **Compatibilidade:** mapear todos os campos híbridos existentes.
- **Rollback:** ADR supersedível; schemas ainda experimentais.

### LE-102 — Implementar schemas e validator runtime

- **Problema:** schema existente não governa runtime.
- **Objetivo:** schemas v1 simples e validação fail-closed com `jq`, confrontada com JSON Schema completo na CI.
- **Arquivos prováveis:** `schemas/v1/*.schema.json`, `lib/contracts.sh`, testes de contrato.
- **Dependências:** LE-101.
- **Risco:** médio.
- **Critérios de aceite:** inputs inválidos retornam validation error antes de mutação; fixtures e exemplos validam nos dois validadores; versões desconhecidas bloqueiam.
- **Testes:** required/type/enum/ID/AC vazio/versão desconhecida e property-based corpus pequeno.
- **Compatibilidade:** validator reconhece formato legado apenas através de migração explícita.
- **Rollback:** permitir leitura v0 somente em modo migration; nunca executar v0 não validado.

### LE-103 — Migrar PRD híbrido e tornar SPEC→PRD atômico

- **Problema:** PRD dogfood inválido e parser permissivo.
- **Objetivo:** migrador idempotente e parser que só publica output validado.
- **Arquivos prováveis:** `prd.json`, `skills/devorq-auto/references/prd-schema.json`, `prd-from-spec.sh`, migrador novo, fixtures.
- **Dependências:** LE-102.
- **Risco:** alto; estado histórico de stories.
- **Critérios de aceite:** dry-run mostra diff; backup; segunda migração é no-op; heading sem contrato não vira story; falha preserva PRD anterior.
- **Testes:** snake/camel case, status conflitante, AC vazio, heading documental, interrupção durante geração.
- **Compatibilidade:** IDs e histórico preservados; `passes` derivado durante janela de migração.
- **Rollback:** backup versionado localmente e comando restore validado.

### LE-201 — Criar state machine e orquestrador mínimo experimental

- **Problema:** lifecycle está embutido no AUTO e não é reutilizável.
- **Objetivo:** separar controle de loop de lógica de implementation sem DAG/plugin framework.
- **Arquivos prováveis:** `lib/loop.sh`, `lib/commands/loop.sh`, dispatcher workflow, perfil `implementation.json`, testes.
- **Dependências:** Fases 0 e 1 concluídas.
- **Risco:** alto; nova fronteira arquitetural.
- **Critérios de aceite:** somente perfil implementation; estados válidos; juiz determinístico; input/output contratual; nenhuma lógica de runner no core.
- **Testes:** tabela completa de transições, estados impossíveis, input inválido e paridade AUTO.
- **Compatibilidade:** experimental; `devorq auto` permanece entrada principal inicialmente.
- **Rollback:** remover registro experimental preservando schemas e correções de Fase 0.

### LE-202 — Persistir tentativas, lock, deadline e recovery

- **Problema:** tentativas reiniciam e lock/sinais não são portáveis.
- **Objetivo:** run/attempt IDs e recuperação pelo journal.
- **Arquivos prováveis:** `lib/loop.sh`, helpers de lock, `.devorq/state/runs/` runtime, testes de fault injection.
- **Dependências:** LE-201.
- **Risco:** alto.
- **Critérios de aceite:** concorrente bloqueia; sem `flock` usa lock atômico; Ctrl+C vira cancelled; resume não repete tentativa concluída; deadline sobrevive a restart.
- **Testes:** dois processos, stale lock, SIGINT/TERM, kill entre eventos e clock/deadline.
- **Compatibilidade:** importar contadores legados quando possível; estado local continua ignorado pelo Git.
- **Rollback:** desabilitar resume novo; preservar journal para diagnóstico.

### LE-203 — Implementar change guard e budgets

- **Problema:** blast radius não é limitado.
- **Objetivo:** manifest inicial, allowed files e limites de diff por perfil/story.
- **Arquivos prováveis:** `lib/change-guard.sh`, schemas Story/Loop, adapters e testes.
- **Dependências:** LE-201.
- **Risco:** médio.
- **Critérios de aceite:** arquivo/linha fora do limite bloqueia antes da aprovação; untracked preexistente tem hash; exceção é explícita e evidenciada.
- **Testes:** rename, delete, symlink, arquivo untracked modificado, limite exato e path traversal.
- **Compatibilidade:** defaults conservadores com override por contrato, não env escondida.
- **Rollback:** elevar budgets, sem remover a captura de baseline.

### LE-204 — Roteamento por capacidades

- **Problema:** seleção atual é somente por nome de runner.
- **Objetivo:** mapear capability→adapter com fallback equivalente e razão registrada.
- **Arquivos prováveis:** config de routing, `lib/routing.sh`, `scripts/adapters/delegate.sh`, docs.
- **Dependências:** LE-201 e policy de risco.
- **Risco:** médio.
- **Critérios de aceite:** seleção determinística; indisponibilidade sem equivalente termina blocked; fallback não reduz sandbox/independência/contexto.
- **Testes:** binário ausente, rate limit, timeout, capabilities incompatíveis e ordem configurada.
- **Compatibilidade:** `DEVORQ_RUNNER` continua override explícito durante depreciação.
- **Rollback:** voltar a runner fixo preservando interface de capability.

### LE-301 — Criar interface de verificador e matriz de risco

- **Problema:** verificação genérica não mapeia ACs nem separa identidades.
- **Objetivo:** verification contract, checks determinísticos e política proporcional.
- **Arquivos prováveis:** `lib/verifier.sh`, `check-story.sh`, schemas, perfis e testes.
- **Dependências:** Fase 2.
- **Risco:** alto.
- **Critérios de aceite:** cada AC obrigatório aponta para evidência; missing runner é blocked; médio+ usa contexto/identidade separados; executor não pode gravar resultado.
- **Testes:** executor declara sucesso falso, AC sem evidência, verifier timeout/falha, risco reclassificado.
- **Compatibilidade:** `check-story.sh` vira adapter de verificação genérica, não é removido abruptamente.
- **Rollback:** usar somente checks determinísticos, mantendo o juiz separado.

### LE-302 — Implementar juiz final e owner gate

- **Problema:** não existe autoridade final explícita.
- **Objetivo:** derivar estado somente de policy+verification+limits e escalar decisões materiais.
- **Arquivos prováveis:** `lib/judge.sh`, loop core, CLI status e testes.
- **Dependências:** LE-301.
- **Risco:** alto.
- **Critérios de aceite:** resultado do executor é ignorado como aprovação; override crítico requer owner e fica registrado; headless sem decisão não continua.
- **Testes:** todas as combinações de gate, verifier, budget, owner e cancelamento.
- **Compatibilidade:** facade AUTO mapeia estados para exit legado.
- **Rollback:** tornar mais estados blocked; nunca devolver autoridade terminal ao executor.

### LE-401 — Consolidar event/evidence journal

- **Problema:** logs não respondem às perguntas operacionais e estão fragmentados.
- **Objetivo:** JSONL canônico com evidências endereçáveis e projeções humanas.
- **Arquivos prováveis:** `lib/helpers.sh`, `lib/loop.sh`, adapters, schemas de event/evidence, geradores de resumo.
- **Dependências:** Fases 1 a 3.
- **Risco:** médio; dados sensíveis e volume.
- **Critérios de aceite:** consulta local responde agente, runner/modelo, story, arquivos, comandos observáveis, testes, duração, tentativas, parada e evidência; redaction testada.
- **Testes:** segredo em env/output, runner opaco, evento truncado, append concorrente e replay.
- **Compatibilidade:** logs antigos continuam legíveis; novos campos são aditivos em v1.
- **Rollback:** desabilitar projeções/verbosidade, mantendo eventos mínimos.

### LE-402 — Normalizar lessons, failures, progress e handoff

- **Problema:** múltiplas fontes de memória sem precedência.
- **Objetivo:** fatos no journal, lições promovidas na fonte canônica e demais artefatos como projeções.
- **Arquivos prováveis:** `lib/lessons*`, `lib/compact.sh`, `.devorq-auto` migration, generators e docs.
- **Dependências:** LE-401.
- **Risco:** médio; histórico local.
- **Critérios de aceite:** migração idempotente; nenhuma lição perdida; busca injeta relevância no planejamento; handoff referencia evidência; progress/failures são regeneráveis.
- **Testes:** merge duplicado, conflito, lesson antiga, replay, sync HUB offline e schema desconhecido.
- **Compatibilidade:** manter arquivos antigos durante duas versões menores como read-only/projeção.
- **Rollback:** restaurar backups e continuar leitura legada, sem escrita dupla como autoridade.

### LE-501 — Publicar perfil code-review experimental

- **Problema:** review atual é uma pipeline separada e incompleta.
- **Objetivo:** usar executor/reviewer/judge comuns com verificações próprias de review.
- **Arquivos prováveis:** perfil `code-review`, skill/script review, adapters e testes.
- **Dependências:** LE-003 e Fases 2 a 4.
- **Risco:** alto; falso negativo de review.
- **Critérios de aceite:** reviewers reais; provenance por finding; deduplicação/scoring testados; ausência de evidência bloqueia; publicação externa continua opt-in.
- **Testes:** finding real fixture, falso positivo, reviewers divergentes, todos falham, diff vazio e headless.
- **Compatibilidade:** `devorq review` vira facade somente após paridade.
- **Rollback:** retirar perfil experimental e manter review bloqueado honestamente.

### LE-502 — Pilotar debugging e documentation

- **Problema:** fluxos existentes não compartilham lifecycle/evidência.
- **Objetivo:** provar generalidade com dois perfis de menor blast radius.
- **Arquivos prováveis:** perfis, `lib/debug.sh`, `scripts/debug-systematic.sh`, compact/unify/grill, testes.
- **Dependências:** Fases 2 a 4.
- **Risco:** médio.
- **Critérios de aceite:** debugging exige reprodução+regressão; documentation verifica comandos/links/drift; ambos usam estados/journal comuns sem duplicar core.
- **Testes:** bug não reproduzível, correção sem regressão, link/comando inválido e no-diff documental.
- **Compatibilidade:** comandos atuais permanecem facades.
- **Rollback:** remover perfis, preservar melhorias específicas verificáveis.

### LE-503 — Decidir os demais loops por evidência

- **Problema:** criar migration/import/release/custom agora seria generalização prematura.
- **Objetivo:** medir demanda e escrever contrato/verificador antes da superfície CLI.
- **Arquivos prováveis:** somente ADR/backlog inicialmente; perfis após aprovação.
- **Dependências:** métricas de LE-501/502.
- **Risco:** baixo no planejamento, alto para release/custom.
- **Critérios de aceite:** ao menos dois casos reais por perfil, verificador específico, threat model e ganho sobre comandos existentes.
- **Testes:** definidos no ADR de cada perfil antes da implementação.
- **Compatibilidade:** nenhum comando reservado sem implementação.
- **Rollback:** abandonar perfil sem tocar no core.

### LE-601 — Campanha de dogfooding e hardening

- **Problema:** happy paths predominam e ambiente real vaza para testes.
- **Objetivo:** provar invariantes em WSL, Linux, Docker e CI sob falhas.
- **Arquivos prováveis:** `scripts/ci-test.sh`, workflows, testes de fault injection, docs de atestação.
- **Dependências:** Fases 0 a 5.
- **Risco:** médio.
- **Critérios de aceite:** zero falso sucesso em matriz; recuperação idempotente; sem rede/produção involuntária; relatório reproduzível ligado ao commit.
- **Testes:** crash points, Ctrl+C, timeout, rate limit, lock, disco cheio simulado, runner ausente, dirty tree, protected branch e migration rollback.
- **Compatibilidade:** matriz inclui `devorq auto`, `flow`, `review`, formatos legados e novos.
- **Rollback:** não remover caminho legado até campanha e janela de depreciação concluídas.

## 9. Decisões necessárias do owner

### OD-01 — O que significa `completed` para implementation?

- **Contexto:** schema/documentação antigos associam `passes=true` a verificação e commit; o default atual marca done antes do commit manual.
- **Opções:** (A) completed exige commit; (B) completed significa diff verificado, com commit fora do loop; (C) política por perfil/run.
- **Benefícios:** A maximiza durabilidade; B respeita revisão manual; C atende ambos explicitamente.
- **Riscos:** A cria commits automáticos indesejados; B pode deixar trabalho não entregue; C aumenta um pouco o contrato.
- **Recomendação técnica:** C, com `completion_policy=verified|committed`; default `verified` no uso assistido e `committed` somente com opt-in AUTO explícito.
- **Consequência de adiar:** não é possível fechar estados, transação e exit codes sem ambiguidade.

### OD-02 — Política para worktree sujo

- **Contexto:** usuários podem querer rodar DEVORQ sobre trabalho em andamento, mas o loop não distingue autoria do diff.
- **Opções:** bloquear sempre; permitir por default; bloquear com exceção por allowlist+snapshot.
- **Benefícios:** bloqueio é simples; permissão é flexível; exceção controlada equilibra uso e segurança.
- **Riscos:** bloqueio pode incomodar; permissão contamina commits/evidência; exceção exige manifest.
- **Recomendação técnica:** bloquear por default e permitir somente por contrato explícito de arquivos, sem `git add -A`.
- **Consequência de adiar:** auto-commit e rollback continuam sem baseline confiável.

### OD-03 — Nível de independência por criticidade

- **Contexto:** independência pode significar nova sessão, outro runner ou aprovação humana.
- **Opções:** mesma sessão sempre; identidade separada a partir de risco médio; fornecedor diferente obrigatório; owner em risco crítico.
- **Benefícios:** separação reduz viés; fornecedor diferente reduz falha correlacionada; owner preserva governança.
- **Riscos:** custo/latência/disponibilidade e acoplamento comercial.
- **Recomendação técnica:** identidade/contexto separados em médio+, runner diferente quando disponível em alto, owner obrigatório em crítico; nunca exigir fornecedor específico.
- **Consequência de adiar:** routing e verifier policy não podem ser estabilizados.

### OD-04 — Fronteira de produção e comandos destrutivos

- **Contexto:** prompts não controlam comandos internos de runners opacos.
- **Opções:** confiar no runner; exigir sandbox/capacidade declarada; proibir loops em ambientes marcados produção.
- **Benefícios:** sandbox permite automação controlada; proibição é mais segura e simples.
- **Riscos:** confiança é insuficiente; sandbox varia por runner; proibição limita release/migration.
- **Recomendação técnica:** proibir escrita em produção por default; alto/crítico exige runner com controle comprovado e owner gate. Owner deve fornecer branches, remotes e marcadores protegidos do seu ambiente.
- **Consequência de adiar:** perfis migration/release/custom não devem sair do estado experimental.

### OD-05 — Retenção e privacidade da observabilidade

- **Contexto:** comandos, diffs e outputs podem conter segredos ou dados sensíveis.
- **Opções:** logs mínimos sem retenção automática; retenção local por prazo; sincronização HUB opt-in.
- **Benefícios:** mais dados facilitam auditoria; menos dados reduzem exposição.
- **Riscos:** retenção longa vaza contexto; retenção curta reduz investigação.
- **Recomendação técnica:** eventos locais redigidos, outputs completos opt-in, retenção configurável e HUB estritamente opt-in.
- **Consequência de adiar:** Fase 4 não pode definir defaults seguros.

### OD-06 — Destino do AUTO guided e janela de depreciação

- **Contexto:** `lib/auto.sh` e o loop Ralph têm semânticas sobrepostas.
- **Opções:** manter ambos indefinidamente; remover guided na primeira versão; facade por duas versões menores.
- **Benefícios:** facade reduz ruptura; remoção imediata reduz manutenção.
- **Riscos:** manutenção dupla prolongada versus quebra de automações.
- **Recomendação técnica:** eleger Ralph/orquestrador como canônico e manter facade testada por no mínimo duas versões menores.
- **Consequência de adiar:** toda correção continuará exigindo auditoria em dois motores.

### OD-07 — Publicação da nova superfície CLI

- **Contexto:** a abstração é válida, mas oito comandos agora seriam prematuros.
- **Opções:** publicar todos; publicar somente implementation experimental; manter abstração interna até três perfis maduros.
- **Benefícios:** superfície precoce gera feedback; espera reduz compatibilidade futura.
- **Riscos:** comandos vazios/duplicados versus descoberta tardia de UX.
- **Recomendação técnica:** publicar apenas `devorq loop implementation --experimental` na Fase 2; adicionar `code-review`, `debugging` e `documentation` um a um; adiar os demais.
- **Consequência de adiar:** nenhuma para a Fase 0/1; somente o desenho do help público permanece aberto.

## 10. Arquivos prováveis por fase

Esta lista é prospectiva; **nenhum deles foi alterado nesta etapa**, além deste assessment.

| Fase | Arquivos/diretórios prováveis |
|---|---|
| 0 | `loop-auto.sh`, `check-story.sh`, `review.sh`, `lib/gates.sh`, `lib/commands/workflow.sh`, CI/E2E/adapters tests, README/SPEC/docs ativas |
| 1 | `schemas/v1/`, `lib/contracts.sh`, parser/migrador PRD, fixtures e docs de arquitetura/ADR |
| 2 | `lib/loop.sh`, `lib/commands/loop.sh`, dispatcher, perfis e testes de state machine |
| 3 | `lib/verifier.sh`, `lib/judge.sh`, políticas de risco e testes adversariais |
| 4 | `lib/helpers.sh`, lessons/compact, schemas de eventos/evidências e migradores |
| 5 | perfis especializados, skills/comandos existentes e testes específicos |
| 6 | CI/workflows, fault-injection, compatibilidade e documentação de atestação |

## 11. Riscos do plano e controles

| Risco | Controle |
|---|---|
| overengineering | um perfil na Fase 2; sem DAG, serviço, banco ou plugin loader |
| quebra de scripts existentes | facades, exit mapping legado, depreciação e contract tests |
| schema duplicar estruturas | inventário/ADR antes dos arquivos; referências entre contratos e projeções |
| dependência externa | Bash+jq no runtime; validador completo apenas na CI |
| logs vazarem dados | redaction, outputs opt-in e retenção definida pelo owner |
| falso senso de sandbox | capability comprovada ou blocked; nunca segurança apenas por prompt |
| rollback destruir trabalho | manifest por tentativa; sem hard reset; patch/evidência preservados |
| matriz de runners crescer demais | capabilities pequenas e adapters existentes; sem lógica comercial no core |
| documentação voltar a divergir | matriz comando→código→teste→doc e exemplos executáveis na CI |
| especialização prematura | dois casos reais e verificador específico antes de cada novo perfil |

## 12. Fase recomendada para começar

Começar pela **Fase 0 — Honestidade operacional e alinhamento documental**, nesta ordem:

1. LE-001: término e estado do AUTO;
2. LE-002: dirty tree, staging e transação;
3. LE-003: review honesto;
4. LE-005: CI contratual;
5. LE-004: gates/resume;
6. LE-006: documentação e inventário CLI.

Não iniciar o orquestrador enquanto LE-G01 a LE-G09 não tiverem testes vermelhos antes da correção e verdes depois dela. O primeiro dogfood de cada mudança deve executar o próprio DEVORQ em repositórios temporários, capturar exit code, estado final, diff e evidência, e então rodar a suíte completa. A conclusão nunca pode depender da frase produzida por um agente.

---

**Regra de parada cumprida:** este documento encerra a primeira etapa. Qualquer implementação, alteração de versão, commit, push ou release depende de aprovação explícita do plano pelo owner.
