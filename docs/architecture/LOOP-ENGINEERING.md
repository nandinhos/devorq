# Loop Engineering mínimo e experimental

> **Status:** F0–F2 implementadas de forma experimental para `implementation`;
> as extensões de F3–F6 permanecem arquitetura-alvo e exigem seus gates.
> **Decisão:** [ADR-001 — Loop Engineering mínimo](../adr/ADR-001-loop-engineering-minimo.md)
> **Origem:** [assessment](../DEVORQ-LOOP-ENGINEERING-ASSESSMENT.md),
> [plano de execução](../DEVORQ-LOOP-ENGINEERING-EXECUTION-PLAN.md) e
> [contrato de escopo](../DEVORQ-LOOP-ENGINEERING-SCOPE.md).

## Contexto e fronteira

O DEVORQ é uma CLI Bash local. O baseline já possui router, AUTO, verificadores, gates e
adapters, mas essas peças ainda não compartilham um contrato terminal confiável. O desenho
introduz apenas o menor lifecycle comum necessário para provar o perfil `implementation`.

| Superfície | Estado atual | Alvo experimental |
|---|---|---|
| Entrada AUTO | `lib/commands/auto.sh:devorq::cmd_auto` chama o loop Ralph e mantém o guided | permanece facade; não contém nova lógica de lifecycle |
| Controle | `skills/devorq-auto/scripts/loop-auto.sh:main` concentra seleção, execução, verificação e estado | state machine linear em `lib/loop.sh`, inicialmente só para `implementation` |
| Execução | `DEVORQ_DELEGATE_FN` e `scripts/adapters/delegate.sh` | mesmo contrato e mesmos adapters, selecionados por capability |
| Verificação | `skills/devorq-auto/scripts/check-story.sh:main` executa checks genéricos | adapter inicial do contrato `Verification v1`; verificadores específicos ficam fora do core |
| Persistência | `prd.json`, `.devorq-auto/`, `progress.txt` e logs locais concorrentes | fatos mínimos por run em `.devorq/state/runs/<run_id>/`; legados viram leitura/projeção durante migração |
| CLI nova | `devorq loop implementation --experimental` | continua limitada a um perfil até os gates de perfis especializados |

## Princípios obrigatórios

1. O lifecycle é linear e local; não há engine de DAG, scheduler, banco, broker ou plugin loader.
2. Somente `completed` representa sucesso. Todo outro terminal retorna não zero e não imprime
   conclusão.
3. Executor produz mudança e claim; verificador produz resultado e evidência; juiz deriva o
   terminal. Nenhum dos dois primeiros promove a própria execução.
4. Entrada inválida, versão desconhecida, evidência ausente, capacidade incompatível ou limite
   excedido bloqueiam antes da promoção.
5. Existe no máximo um writer por worktree. Mudanças preexistentes não pertencem ao loop.
6. `devorq auto`, `DEVORQ_DELEGATE_FN` e os adapters atuais permanecem compatíveis durante a
   janela de migração.

## Componentes e fluxo

```text
devorq auto ───────────────┐
                           ├─ facade → Loop Core (implementation)
devorq loop ... --experimental ┘            │
                                             ├─ valida contratos + policy
                                             ├─ persiste attempt antes do dispatch
                                             ├─ ExecutorAdapter → DEVORQ_DELEGATE_FN
                                             ├─ VerifierAdapter → checks + AC→evidence
                                             └─ Judge → terminal + exit não ambíguo
                                                        │
                                      .devorq/state/runs/<run_id>/
```

O core conhece contratos e funções por papel; não conhece `claude`, `codex`, `hermes`,
`opencode`, `agy` nem regras específicas de um domínio. Casos por fornecedor continuam
confinados a `scripts/adapters/delegate.sh` e aos wrappers existentes.

O perfil experimental versionado fica em `config/loop-profiles.json`: ele nomeia papéis
(`implementer`, `qa`, `fallback-long-context`) e limites, nunca fornecedores. O core registra
o resultado do adapter, enquanto a escolha de runner continua sob `DEVORQ_RUNNER` e seus
adapters compatíveis.

## Contratos v1

Os schemas usam JSON Schema Draft-07 em `schemas/<tipo>.v1.schema.json` e são localizados por
`lib/contracts.sh:devorq::contracts::schema_path`. O runtime aplica o subconjunto obrigatório
com `devorq::contracts::validate`; a CI confronta fixtures nos dois validadores. Todo documento
possui `schema_version`, `document_type`, `run_id` e ID estável. Versão desconhecida nunca é
inferida.

### Núcleo disponível em F1

| Contrato | Autoridade e campos mínimos atuais | Regra de compatibilidade |
|---|---|---|
| `Story v1` | title, description, ACs não vazios e estado | legado é projetado pelo migrador; `acceptanceCriteria`/`acceptance_criteria` não chegam ambíguos ao core |
| `Loop v1` | profile, objetivo e estado canônico do loop | inicialmente somente `profile=implementation` é elegível; o schema não cria plugin/profile loader |
| `Execution v1` | story, attempt, actor, status de execução e exit code | exit `0` é relato de execução, nunca conclusão do loop |
| `Verification v1` | story, identidade declarada do verifier, checks e verdict | F1 valida forma; independência e AC→evidence só viram garantia após WS-08/G-F3 |
| `Evidence v1` | tipo, path, SHA-256 e resultado | referência inválida ou ausente não satisfaz aceite |
| `Failure`, `Lesson`, `Handoff` v1 | fatos/artefatos independentes com envelope comum | os schemas existem em F1, mas não são dependências do core F2 nem autoridades concorrentes |

`passes` não pertence aos schemas v1. A facade/migração o deriva de `completed` para leitores
legados enquanto `loop-auto.sh` ainda depender do campo; nenhum adapter precisa conhecer essa
projeção.

### Extensões exigidas pelos consumidores posteriores

Campos ainda não validados não são tratados como garantia por documentação. Antes de cada
consumer executar, seu schema e seu predicado runtime devem receber, de forma aditiva:

| Fase | Extensão necessária |
|---|---|
| F2 | `Loop`: completion policy, risco, capabilities, limites, base commit, deadline e stop reason; `Story`: objective, dependências, prioridade e allowed files |
| F2 | `Execution`: capability, adapter/modelo observável, timestamps, diff e evidence IDs |
| F3 | `Verification`: mapa AC→evidence e identidade verificável; contrato/predicado do Judge e policy de independência |
| F4 | `Evidence`: produtor, timestamp, redaction e observabilidade; eventos/projeções do run |

Até a extensão correspondente existir e passar seu gate, a capability permanece indisponível
ou `blocked`; o core não completa campos por inferência.

### Política de conclusão

| Política | `completed` exige |
|---|---|
| `verified` — padrão assistido | todos os gates e ACs obrigatórios com evidência válida |
| `committed` — opt-in explícito | tudo de `verified` mais commit pertencente à tentativa e coerente com o estado |

A facade `devorq auto` mantém o contrato simples: `0` somente para `completed`; qualquer outro
terminal é não zero. O JSON de estado carrega a causa precisa. Códigos não zero específicos são
um mapeamento reversível da CLI e não constituem a autoridade do estado.

## State machine

Estados transitórios:

```text
pending → planning → running → verifying
```

Estados terminais:

| Estado | Condição |
|---|---|
| `completed` | juiz confirmou gates, ACs, evidências, limites e completion policy |
| `failed` | execução ou verificação falhou definitivamente |
| `blocked` | contrato, precondição, lock, runner ou capability obrigatória está ausente |
| `requires_owner_decision` | continuar exige escolha material ou override de alto impacto |
| `max_attempts_reached` | orçamento persistido foi consumido |
| `cancelled` | owner, root, INT ou TERM cancelou o run |

Regras de transição:

- attempt é persistido antes do dispatch;
- crash com resultado ambíguo vai para reconciliação, nunca para retry cego;
- terminal é imutável, salvo migração versionada ou decisão do owner registrada;
- somente o juiz escreve terminal; executor e verificador encerram em `verifying`, `failed`,
  `blocked`, `requires_owner_decision` ou `cancelled`;
- sinal tratado registra `cancelled`, libera lock e impede novo dispatch.

## Executor, verificador e juiz por risco

Esta tabela é a policy-alvo de WS-08/G-F3. Os contratos F1 registram atores e verdicts, mas
ainda não provam identidade distinta nem possuem Judge; portanto F1 não pode anunciar essa
separação como garantia operacional.

| Risco | Executor | Verificador | Juiz/promoção |
|---|---|---|---|
| baixo | adapter compatível | checks determinísticos; revisão explicativa pode compartilhar fornecedor | função determinística |
| médio | adapter compatível | identidade e contexto separados; checks determinísticos obrigatórios | função determinística, sem override silencioso |
| alto | runner com controle/sandbox declarado | verificador independente e, se houver equivalente, runner diferente | função determinística; fallback não reduz a policy |
| crítico ou produção | escrita bloqueada por padrão; runner mediável quando autorizado | verificador independente mais evidência completa | owner gate obrigatório e decisão registrada |

“Independente” significa identidade de execução e contexto separados, não fornecedor obrigatório.
Sem candidato que preserve capability, sandbox e independência, o resultado é `blocked`.

## Persistência local e recuperação

Esta é a fronteira-alvo de WS-07/WS-09, não uma garantia entregue pelos contratos F1. O AUTO
do baseline ainda usa `.devorq-auto/` e mantém attempts em memória.

Forma mínima:

```text
.devorq/state/runs/<run_id>/
├── events.jsonl      # autoridade append-only das transições e tentativas
└── evidence/         # artefatos endereçados por ID/hash quando necessários
```

- F2 grava somente eventos necessários a lock, attempt, deadline, terminal e recovery.
- F4 enriquece os mesmos eventos com evidência, redaction e projeções; não cria segunda
  autoridade.
- `state.json`, `progress.txt`, `failures.md`, handoff e lessons AUTO são cache/projeção ou
  legado de leitura, nunca fatos concorrentes.
- Escrita ocorre sob `flock` ou lock directory atômico. Sem mecanismo seguro, bloqueia.
- Replay ignora apenas cauda comprovadamente truncada e exige reconciliação; não inventa o
  último estado.
- Outputs e prompts completos não são persistidos por padrão. Quando o runner for opaco,
  registra-se `command_observability=partial`.

## Reuso dos adapters

O seam de execução continua sendo:

```text
"$DEVORQ_DELEGATE_FN" "$story_json" "$project_root"
```

O loop projeta `Story v1` para esse contrato e envolve exit/journal em `Execution v1`. O
adapter não precisa retornar ResultPacket nem conhecer o novo estado. Routing escolhe por
capability e disponibilidade, mas a chamada efetiva continua nos adapters existentes. Durante
a depreciação, `DEVORQ_RUNNER` permanece override explícito.

É proibido:

- copiar os `case` por runner para `lib/loop.sh` ou profiles;
- criar um adapter novo apenas para renomear flags já cobertas por `delegate.sh`;
- tratar exit `0` do runner como verificação ou conclusão;
- executar fallback que reduza sandbox, independência ou capability.

## Limites do experimento

| Limite | Comportamento |
|---|---|
| Perfis | somente `implementation`; demais perfis exigem verificador próprio e gate separado |
| Escopo de arquivo | manifest inicial + `allowed_files`; alteração externa bloqueia antes do juiz |
| Budget | attempts, wall time, arquivos e linhas são obrigatórios no profile/run; excedente não promove |
| Git | sem `git add -A`, hard reset, push ou troca implícita de branch protegida |
| Produção | escrita e comandos destrutivos proibidos por padrão; crítico exige owner gate |
| Concorrência | um writer por worktree; integração de patches é serial |
| Extensibilidade | sem shell arbitrário em profile, plugin loader, DAG runtime ou serviço remoto |
| Compatibilidade | facade AUTO permanece por no mínimo duas versões menores após estabilidade do novo caminho |

## Seams e gatilhos de extração

| Seam barato agora | Limite preservado | Gatilho observável para revisitar |
|---|---|---|
| Funções por papel em um core Bash | executor, verifier, judge, state e routing trocam dados apenas por contratos v1 | extrair módulo adicional somente quando dois consumidores reais exigirem implementações diferentes e a duplicação aparecer em pelo menos dois call sites |
| JSONL local por run | persistência acessada por funções de state/events, nunca por leitura espalhada | considerar outro storage se dois hosts precisarem coordenar o mesmo projeto ou replay p95 exceder 2 s em corpus de 100 mil eventos; owner: maintainer do runtime |
| Adapter contract atual | nomes comerciais permanecem fora do core | criar/evoluir adapter somente quando uma capability obrigatória não puder ser expressa pelo contrato atual em dois casos reais; owner: maintainer de adapters |
| `check-story.sh` como adapter genérico | verificação específica fica atrás de `Verification v1` | criar verifier específico quando um perfil tiver dois casos reais e ao menos um AC obrigatório não puder ser provado pelos checks genéricos |
| `devorq auto` como facade | tradução legado↔v1 fica na borda | remover guided/legado somente após G-F6, duas versões menores de depreciação e nenhum consumidor conhecido dependente |
| Um único profile `implementation` | profile declara policy; não injeta código no core | admitir novo profile apenas após dois casos reais, verificador específico, threat model e ganho demonstrado sobre comando existente |

Nenhum gatilho autoriza extração automática. Quando disparado, exige nova decisão arquitetural e
teste de compatibilidade.

## Promoção e rollback

- **G-F1:** schemas em `schemas/*.v1.schema.json`, predicados runtime, fixtures, PRD migrado e
  restore devem estar verdes;
  estado v1 inválido não executa.
- **G-F2:** paridade AUTO/implementation, tabela de transições, lock, recovery, deadline,
  change guard e budgets devem estar verdes antes de anunciar a CLI experimental.
- **G-F3:** claim falsa do executor não conclui; AC→evidence e policy de risco são verificadas
  independentemente.
- Rollback retira o registro experimental e preserva contratos, correções F0, diff e evidências.
  Nunca usa hard reset nem remove mudanças preexistentes.
