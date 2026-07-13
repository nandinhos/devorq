# DEVORQ — Plano de Execução Multiagente para Loop Engineering

> **Status:** plano de execução; implementação ainda não iniciada
> **Data:** 2026-07-13
> **Plano:** `LEP-2026-07-13-01`
> **Branch de referência:** `main`
> **Commit-base de referência:** `54d602ad2b30470fc4f3ff9a3b5131dd08475568`
> **Diagnóstico de origem:** `docs/DEVORQ-LOOP-ENGINEERING-ASSESSMENT.md`

## 1. Resultado esperado

Executar a evolução do DEVORQ por waves multiagente, mantendo um único orquestrador responsável por integrar decisões, validar evidências e derivar o estado final. Subagentes recebem escopo fechado, devolvem pacotes estruturados e não decidem que a própria tarefa foi concluída.

O plano usa subagentes para análise, implementação, verificação, revisão adversarial e documentação. Não exige troca interativa de modelo e não acopla os papéis a fornecedores. Runners são selecionados futuramente por capacidades.

O resultado arquitetural continua incremental:

- primeiro eliminar falsos sucessos e tornar a CI contratual;
- depois estabelecer contratos versionados;
- então provar um orquestrador mínimo apenas com `implementation`;
- separar executor, verificador e juiz;
- consolidar evidências e memória;
- adicionar perfis especializados somente quando houver verificadores reais;
- finalizar com dogfooding e fault injection.

Este DAG organiza a **entrega**. Ele não autoriza nem propõe um engine de DAG dentro do DEVORQ.

### 1.1. Síntese multiagente aplicada

O plano foi compilado pelo root a partir de três IRs independentes:

- arquitetura de execução: dependências, hotspots, waves e seams;
- protocolo de orquestração: packets, leases, papéis, escalonamento e autoridade do root;
- verificação: oráculos de exit/estado/efeito, fault injection e rollback.

Um quarto passe refute-first revisou o rascunho. Oito bloqueios foram incorporados: separação entre protocolo externo e contratos futuros do produto, política de risco antes do routing, antecipação de owner gates, mutation sets exatos no dispatch, serialização dos perfis, reverificação após integração, rollback por patch inverso e testes explícitos para budgets/fallback/produção/owner gate. A síntese abaixo contém apenas decisões que sobreviveram a esse passe.

## 2. Princípios invariantes

| ID | Invariante | Consequência operacional |
|---|---|---|
| INV-01 | Somente `completed` representa sucesso | qualquer outro estado terminal retorna não zero e não imprime conclusão |
| INV-02 | Executor, verificador e juiz são autoridades distintas | autorrelato do executor é claim, nunca prova |
| INV-03 | Todo aceite obrigatório referencia evidência reproduzível | stdout com `done` ou `passed` não promove task/wave |
| INV-04 | Existe no máximo um writer por worktree | paralelismo de mutação exige worktrees isolados; integração é serial |
| INV-05 | Mudanças preexistentes pertencem ao usuário | sem `git add -A`, hard reset ou rollback fora do manifest da tentativa |
| INV-06 | Tentativa é persistida antes do dispatch | crash ambíguo exige reconciliação antes de retry |
| INV-07 | Fallback preserva capacidade e política de risco | sem equivalente, o estado é `blocked` |
| INV-08 | Runtime continua Bash+jq, local e transparente | sem banco, broker, serviço externo ou plugin loader obrigatório |
| INV-09 | Facades existentes permanecem durante migração | `auto`, `flow` e `review` não desaparecem sem paridade e depreciação |
| INV-10 | Eventos/evidências são fatos; demais artefatos são projeções | `progress`, `failures`, lessons AUTO e handoff não concorrem como autoridade |
| INV-11 | Nenhum agente amplia o próprio escopo ou orçamento | excedente termina `blocked`, `max_attempts_reached` ou decisão do owner |
| INV-12 | Push, release, produção e bypass de gate são ações do owner | nunca são inferidos de uma task de implementação |

Evidências do baseline: `loop-auto.sh:363-429`, `loop-auto.sh:510-566`, `loop-auto.sh:745-1032`, `check-story.sh:47-215`, `review.sh:75-97`, `review.sh:197-240`, `lib/commands/workflow.sh:156-225`, `scripts/adapters/delegate.sh` e o assessment de origem.

## 3. Modelo de orquestração

### 3.1. Papéis

| Papel | Responsabilidade | Pode editar? | Pode promover? |
|---|---|---:|---:|
| Root Orchestrator | congela baseline, cria packets, concede leases, integra, executa gates e deriva estados | sim | sim |
| Scout | coleta evidência e reduz contexto para um recorte | não | não |
| Contract Architect | define schemas, interfaces, ADRs e compatibilidade | somente mutation set próprio | não |
| Implementer | aplica uma dead-spec em arquivos permitidos | somente mutation set próprio | não |
| Test Engineer | cria oráculos comportamentais e fault injection | somente arquivos de teste permitidos | não |
| Independent Verifier | reproduz aceite sobre snapshot/diff congelado | não | não |
| Adversarial Reviewer | tenta refutar design, correção, escopo e recovery | não | não |
| Documentation Curator | atualiza fatos, decisões e índice depois da prova | somente docs atribuídos | não |
| Final Judge | função determinística operada pelo root | não | deriva estado, sem editar solução |

Um mesmo agente não acumula `Implementer` e `Independent Verifier` na mesma task de risco médio ou superior. Em risco alto, usar também contexto limpo e, quando houver equivalente, runner diferente. Risco crítico exige owner gate.

### 3.2. Autoridade exclusiva do root

Somente o root pode:

- congelar `base_commit`, snapshot e manifest inicial;
- validar os packets e suas dependências;
- conceder/revogar `mutation lease`;
- escolher capability e fallback sem reduzir a política;
- reconciliar diff, checks e evidências;
- promover ou rejeitar uma wave;
- autorizar retry após crash/timeout;
- derivar estado terminal;
- integrar patches e resolver colisões;
- autorizar commit se a execução tiver essa permissão;
- escalar uma decisão ao owner.

Push, release, publicação externa e escrita em produção continuam fora da autoridade implícita do orquestrador.

“Resolver colisões” significa aplicar mecanicamente patches sem conflito. Qualquer resolução semântica, edição corretiva ou alteração de contrato abre uma nova tentativa para um implementer e exige novo verificador. O root não pode editar a solução e, em seguida, julgá-la com evidência anterior.

## 4. Linguagem interna `DEVORQ-IR/1`

Subagentes não retornam narrativa livre como resultado operacional. Eles recebem `TaskPacket` e devolvem `ResultPacket` JSON validado. Logs e outputs grandes são armazenados como artefatos e referenciados por ID/hash.

`DEVORQ-IR/1` começa como protocolo **externo do processo de entrega**, mantido pelo root. F0 não depende de o DEVORQ já possuir schemas, journal ou state machine novos: seus oráculos são exit code, `prd.json`, estado Git e logs de processos temporários. F1 formaliza contratos do produto; F2 adiciona estado durável; F4 incorpora o journal canônico. Isso evita usar uma capacidade futura para provar a fase que ainda irá construí-la.

### 4.1. TaskPacket

```json
{
  "ir_version": "DEVORQ-IR/1",
  "task_id": "LE-F0-AUTO-001",
  "run_id": "run-...",
  "attempt_id": "attempt-01",
  "role": "implementer",
  "capability": "bash-state-and-git-safety",
  "objective": "Eliminar falso sucesso no término do AUTO",
  "base_commit": "...",
  "snapshot_ref": "sha256:...",
  "workspace_ref": "worktree://...",
  "lease_id": "lease-...",
  "environment": "local-test",
  "completion_policy": "verified",
  "input_artifact_refs": ["assessment#LE-G01"],
  "read_set": ["skills/devorq-auto/scripts/loop-auto.sh"],
  "mutation_set": ["skills/devorq-auto/scripts/loop-auto.sh", "e2e-tests/tests/..."],
  "scope_in": ["estado terminal", "exit code", "contagens"],
  "scope_out": ["routing", "schemas v1", "loops especializados"],
  "dependencies": [],
  "invariants": ["INV-01", "INV-02", "INV-05"],
  "risk": "high",
  "acceptance": ["AC-01", "AC-02"],
  "verification_plan": ["TEST-01", "TEST-02"],
  "evidence_contract": ["exit_code", "final_state", "diff_hash", "test_log_ref"],
  "budget": {"attempts": 2, "files": 2, "changed_lines": 250},
  "deadline": "definido no dispatch",
  "owner_decisions": ["OD-01"],
  "stop_conditions": ["diff fora do mutation_set", "AC impossível sem ampliar escopo"],
  "response_schema": "ResultPacket/1"
}
```

Orçamentos acima são exemplo. O packet real define números antes do dispatch; o agente não os amplia.

### 4.2. ResultPacket

```json
{
  "ir_version": "DEVORQ-IR/1",
  "task_id": "LE-F0-AUTO-001",
  "run_id": "run-...",
  "attempt_id": "attempt-01",
  "role": "implementer",
  "status": "verifying",
  "claims": [{"id": "CL-01", "statement": "falhas retornam não zero"}],
  "changed_files": ["skills/devorq-auto/scripts/loop-auto.sh"],
  "diff_hash": "sha256:...",
  "checks": [{"id": "TEST-01", "exit_code": 0, "log_ref": "evidence://..."}],
  "acceptance_evidence": [{"acceptance_id": "AC-01", "evidence_refs": ["evidence://..."]}],
  "evidence_refs": ["evidence://diff/...", "evidence://test/..."],
  "risks": [],
  "challenges": [],
  "unresolved": [],
  "retryability": "not_applicable",
  "observability": "complete",
  "stop_reason": null,
  "recommended_next_action": "independent_verification"
}
```

`confidence` pode ser registrada para triagem, mas nunca participa do juiz terminal.

### 4.3. Estados

Estados transitórios:

```text
pending
planning
running
verifying
```

Estados terminais:

```text
completed
failed
blocked
requires_owner_decision
max_attempts_reached
cancelled
```

Packets inválidos, versão desconhecida, evidência ausente ou mutação fora do escopo não são corrigidos por inferência; bloqueiam a task.

Estados permitidos por papel:

- implementer: `verifying`, `failed`, `blocked`, `requires_owner_decision` ou `cancelled`;
- verifier/adversary: `verifying`, `failed`, `blocked`, `requires_owner_decision` ou `cancelled`;
- somente o juiz operado pelo root produz `completed`, `max_attempts_reached` ou o estado terminal canônico do run.

Um ResultPacket de implementer/verifier com `completed` é inválido, mesmo que o restante do JSON satisfaça o schema.

## 5. Regras de concorrência e isolamento

### 5.1. Leituras

- Scouts, verificadores e adversários podem executar em paralelo.
- Cada agente recebe somente o context packet necessário ao seu recorte.
- O assessment e fatos compartilhados são referenciados, não copiados para cada resposta.

### 5.2. Mutações

- No worktree compartilhado: um único `mutation lease`, execução serial.
- Mutação paralela: somente em worktrees isolados e com mutation sets disjuntos.
- A integração dos patches é sempre serial pelo root.
- Arquivos hotspot (`loop-auto.sh`, `lib/loop.sh`, schemas, router, CI e docs centrais) têm owner único por wave.
- Agente não usa `git add`, `commit`, `push`, `checkout`, `switch`, `stash` ou reset, salvo autorização literal no TaskPacket.
- Testes que alterem estado executam em repositórios temporários próprios.

### 5.3. Colisões

Antes do dispatch, o root calcula interseções entre `mutation_set`:

```text
interseção vazia + testes isolados   = paralelo permitido em worktrees isolados
interseção não vazia                 = serial
arquivo central compartilhado       = owner único + integração serial
estado/teste global não isolável     = serial mesmo com paths disjuntos
```

O paralelismo pode ser ampliado somente após prova de isolamento. Ele nunca é requisito para avançar.

Os mutation sets apresentados neste plano são estimativas de planejamento. Antes de G-PRE, cada TaskPacket deve expandi-los para paths exatos e normalizados, incluindo arquivos novos, testes e documentação. Glob, diretório genérico ou categoria como `docs/` e `tests/` não concede permissão de escrita. Arquivo criado fora do packet invalida a tentativa.

## 6. DAG de execução

```text
PRE-FLIGHT
   │
   ├─ W-01A WS-01 AUTO/Git safety ─┐
   └─ W-01B WS-02 review/gates ────┤ isolados
                                    ↓
   W-02 WS-03 CI + CLI + docs
        │ G-F0
   W-03 WS-04 contratos v1
        ↓
   W-04 WS-05 migração PRD
        │ G-F1
   W-05 WS-06 orquestrador mínimo
        ↓
   W-06 WS-07 runtime safety/routing
        │ G-F2
   W-07 WS-08 verifier + judge
        │ G-F3 + adversarial review
   W-08 WS-09 observabilidade/memória
        │ G-F4
   W-09A WS-10 code-review
        ↓
   W-09B WS-11 debug/docs
        ↓
   W-09C WS-12 decisões dos demais perfis (read-only)
        ↓
        G-F5
   W-10 WS-13 dogfooding/hardening
        │ G-F6
   RELEASE CANDIDATE — não release automática
```

## 7. Workstreams

### WS-01 — Estado terminal, árvore e commit do AUTO

- **Fase:** F0.
- **Agentes:** Test Engineer, `bash-state-and-git-safety`, Independent Verifier.
- **Objetivo:** executar LE-001/002.
- **Mutation set provável:** `loop-auto.sh`, `lib/auto.sh`, `lib/commit.sh` e testes AUTO novos.
- **Aceite:** falha/pending/no-diff/cancel/commit incompleto nunca concluem; failed não usa `passes=true`; mudança preexistente nunca é staged.
- **Provas:** tabela de estados/exits, dirty tree, tracked/untracked, hook falho e crash nos limites da transação.
- **Stop:** política de completion/dirty tree ausente; teste RED não reproduz o baseline.
- **Rollback:** desligar auto-commit preservando diff/evidência; nunca restaurar o falso sucesso.

### WS-02 — Review e gates fail-closed

- **Fase:** F0.
- **Agentes:** Test Engineer, `bash-fail-closed`, Independent Verifier.
- **Objetivo:** executar LE-003/004.
- **Mutation set provável:** review skill/script, `lib/gates.sh`, workflow/context e testes dedicados.
- **Aceite:** review sem reviewers retorna blocked; zero issues exige proveniência; gate ausente, sequência inválida, contexto inválido e resume obsoleto bloqueiam.
- **Provas:** no diff, reviewer ausente/falho, opção inválida, gate lib ausente, intent/base alterados e contexto vazio.
- **Stop:** solução tenta manter arrays placeholders ou PASS simulado.
- **Rollback:** review explicitamente indisponível; gate pode ser advisory documentado, nunca sucesso fabricado.

### WS-03 — CI, CLI e verdade documental

- **Fase:** F0.
- **Dependências:** WS-01 e WS-02.
- **Agentes:** `qa-contract-and-docs`, Documentation Curator, Independent Verifier.
- **Objetivo:** executar LE-005/006.
- **Mutation set provável:** CI, workflows, adapter/security tests, router/help e documentação operacional.
- **Aceite:** adapters participam da CI; exit/estado/efeito são oráculos; VPS/rede são herméticos; help e docs correspondem ao dispatcher real.
- **Provas:** mutação deliberada do estado torna CI vermelha; snapshot comando→dispatcher→teste→doc.
- **Stop:** documentação antecede comportamento instável ou CI exige rede real.
- **Rollback:** job novo pode ficar não-required durante observação; testes não são removidos.

### WS-04 — Contratos v1

- **Fase:** F1.
- **Dependência:** G-F0.
- **Agentes:** Contract Architect, Schema Implementer, Schema Verifier, Adversarial Reviewer.
- **Objetivo:** executar LE-101/102.
- **Mutation set provável:** `schemas/v1/`, `lib/contracts.sh`, testes de contrato, architecture docs e ADRs.
- **Aceite:** cada campo possui owner/fonte; `passes` é projeção; input inválido/versão desconhecida bloqueia antes da mutação; níveis de risco e requisitos mínimos de independência são tipados antes do routing.
- **Provas:** corpus positivo/negativo nos predicados jq e JSON Schema completo da CI.
- **Stop:** autoridade duplicada ou invariante não aplicável pelo runtime.
- **Rollback:** schemas experimentais e ADR supersedível; v0 somente para migrador.

### WS-05 — Migração PRD e parser atômico

- **Fase:** F1.
- **Dependência:** WS-04.
- **Agentes:** State Migration Implementer, Independent Verifier.
- **Objetivo:** executar LE-103.
- **Mutation set provável:** `prd.json`, schema anterior, parser, migrador e fixtures.
- **Aceite:** dry-run, backup/restore, IDs preservados, segunda execução no-op e publicação somente após validação.
- **Provas:** camel/snake case, estados conflitantes, AC vazio, heading documental e interrupção durante geração.
- **Stop:** perda de ID/histórico ou conversão silenciosa.
- **Rollback:** restore ensaiado; PRD anterior permanece intacto.

### WS-06 — Orquestrador mínimo de implementation

- **Fase:** F2.
- **Dependência:** G-F1.
- **Agentes:** `bash-orchestrator`, Contract Verifier, Adversarial Reviewer.
- **Objetivo:** executar LE-201.
- **Mutation set provável:** `lib/loop.sh`, comando/dispatcher, router, profile implementation e testes da state machine.
- **Aceite:** lifecycle linear, transições fechadas, core sem fornecedor/domínio e `devorq auto` preservado.
- **Provas:** tabela completa de transições e paridade de sucesso/falha com AUTO.
- **Stop:** necessidade de scheduler, plugin loader ou DAG runtime.
- **Rollback:** retirar somente o comando experimental.

### WS-07 — Durabilidade, change guard e inventário de routing

- **Fase:** F2.
- **Dependência:** WS-06 com interfaces congeladas.
- **Agentes:** `bash-runtime-safety`, Test Engineer, Independent Verifier.
- **Objetivo:** executar LE-202/203 e a parte de inventário/disponibilidade de LE-204.
- **Mutation set provável:** run state, change guard, routing, loop core, adapter e testes de fault injection.
- **Aceite:** lock portável, attempts/deadline persistidos, recovery, allowed files/budgets e seleção de candidatos por capability/disponibilidade; até WS-08, fallback não promove execução de risco.
- **Provas:** concorrência, stale lock, SIGINT/TERM, crash, rename/delete/symlink/untracked/traversal e runner ausente.
- **Stop:** estado pós-crash não reconciliável ou roteador tenta aplicar risco/independência sem o juiz/verifier de WS-08.
- **Rollback:** desabilitar resume/routing experimental preservando journal e interfaces.

### WS-08 — Verificador independente e juiz

- **Fase:** F3.
- **Dependência:** G-F2.
- **Agentes:** Verification Implementer diferente do core, Independent Verifier e dois adversários read-only.
- **Objetivo:** executar LE-301/302 e fechar a filtragem de LE-204 por risco, independência e owner gate.
- **Mutation set provável:** verifier, judge, check-story, verification schema/profile e testes.
- **Aceite:** executor não grava terminal; cada AC obrigatório possui evidência; risco médio+ separa identidade/contexto; crítico exige owner; fallback só é elegível se preservar toda a policy.
- **Provas:** executor mente, AC sem evidência, timeout, indisponibilidade, reclassificação de risco e tabela do juiz.
- **Stop:** override silencioso, mesma identidade indevida ou evidência não endereçável.
- **Rollback:** checks determinísticos conservadores e mais estados blocked; nunca devolver aprovação ao executor.

### WS-09 — Event journal, evidência e memória

- **Fase:** F4.
- **Dependência:** G-F3.
- **Agentes:** Local Observability Implementer, Privacy Reviewer, Migration Verifier.
- **Objetivo:** executar LE-401/402.
- **Mutation set provável:** events/helpers/loop, lessons/compact, schemas e testes de observabilidade.
- **Aceite:** JSONL por run versionado e replayable; projeções regeneráveis; observabilidade parcial declarada; segredos redigidos.
- **Provas:** replay, concorrência, evento truncado, segredo em env/output, lessons antigas e HUB offline.
- **Stop:** retenção indefinida, output sensível sem política ou escrita dupla autoritativa.
- **Rollback:** eventos mínimos e leitura legada; projeções novas desativáveis.

### WS-10 — Perfil code-review

- **Fase:** F5.
- **Dependências:** WS-02 e G-F4.
- **Agentes:** Code Review Pipeline Implementer, reviewers independentes e verifier de findings.
- **Objetivo:** executar LE-501.
- **Mutation set provável:** profile, review skill/script/command e testes específicos.
- **Aceite:** reviewers reais, proveniência, deduplicação/scoring; ausência de evidência é blocked; publicação continua opt-in.
- **Provas:** finding real, falso positivo, divergência, todos falham, diff vazio e headless.
- **Stop:** placeholder, finding sem origem ou falsa lista vazia.
- **Rollback:** retirar perfil; manter review indisponível de forma honesta.

### WS-11 — Perfis debugging e documentation

- **Fase:** F5.
- **Dependência:** G-F4.
- **Agentes:** Profile Implementer, Debug Verifier, Documentation Verifier.
- **Objetivo:** executar LE-502.
- **Mutation set provável:** profiles, debug scripts/libs, compact/unify e testes específicos.
- **Aceite:** debugging exige reprodução+regressão; documentation verifica links/comandos/drift; nenhum lifecycle duplicado.
- **Provas:** bug não reproduzível, correção sem regressão, link/comando inválido e no-diff.
- **Stop:** lógica específica entra no core ou novo perfil não tem dois casos reais e verificador.
- **Rollback:** remover somente o perfil reprovado.

### WS-12 — Decisão sobre os demais perfis

- **Fase:** F5.
- **Dependências:** WS-10 e WS-11 verificados.
- **Agentes:** Scout de casos reais, Threat Model Reviewer, Contract Architect e root.
- **Objetivo:** executar LE-503 sem implementar `migration`, `import-audit`, `release` ou `custom`.
- **Mutation set previsto:** somente ADR/backlog com paths exatos definidos no TaskPacket.
- **Aceite:** cada perfil candidato possui ao menos dois casos reais, verifier específico, threat model e ganho comprovado sobre comandos existentes; caso contrário é rejeitado/deferido.
- **Provas:** inventário de casos, subtraction test, riscos e trigger-to-revisit.
- **Stop:** proposta depende de uso hipotético, duplica comando ou exige lógica de domínio no core.
- **Rollback:** ADR pode ser supersedido; nenhum código/perfil é criado nesta task.

### WS-13 — Dogfooding e hardening

- **Fase:** F6.
- **Dependências:** G-F5.
- **Agentes:** QA Matrix em ambientes isolados, dois Adversarial Reviewers e root synthesizer.
- **Objetivo:** executar LE-601.
- **Mutation set provável:** CI/workflows, fault injection, E2E e atestação documental.
- **Aceite:** zero falso sucesso, recovery idempotente, sem rede/produção involuntária e compatibilidade ligada ao commit.
- **Provas:** WSL/Linux/Docker/CI; crash, timeout, signal, lock, disk, runner, dirty tree e rollback da migração.
- **Stop:** qualquer falso sucesso, evidência de outro commit ou teste não hermético.
- **Rollback:** nenhuma remoção de legado/depreciação enquanto o gate estiver vermelho.

## 8. Waves e gates de promoção

| Wave | Workstreams | Execução | Gate de saída |
|---|---|---|---|
| PRE | baseline, manifest, decisões | root + scouts read-only | G-PRE |
| W-01 | WS-01 e WS-02 | paralelo apenas em worktrees isolados; senão serial | testes RED→GREEN por slice |
| W-02 | WS-03 | serial, integração F0 | G-F0 |
| W-03 | WS-04 | serial; contratos/ADRs primeiro | contrato congelado |
| W-04 | WS-05 | serial; migração | G-F1 |
| W-05 | WS-06 | serial; core | interfaces congeladas |
| W-06 | WS-07 | serial; runtime safety | G-F2 |
| W-07 | WS-08 | serial; depois revisão adversarial paralela | G-F3 |
| W-08 | WS-09 | serial | G-F4 |
| W-09A | WS-10 | serial; code-review e integração | gate individual do perfil |
| W-09B | WS-11 | serial; debugging/documentation | gate individual dos perfis |
| W-09C | WS-12 | análises read-only paralelas; decisão serial | G-F5 |
| W-10 | WS-13 | ambientes isolados em paralelo; síntese serial | G-F6 |

### G-PRE — autorização e baseline

Evidências:

- branch/commit-base/snapshot;
- manifest de tracked e untracked por hash;
- worktree policy;
- completion policy;
- política de risco/produção;
- ratificação de OD-03 e OD-04 antes de qualquer mutação high-risk;
- política mínima de OD-05: evidência local redigida, sem output completo por default;
- mutation sets expandidos para paths exatos, incluindo criações, sem glob/diretório genérico ou colisão não resolvida.

Falha: `requires_owner_decision` ou `blocked`; nenhuma mutação.

### G-F0 — honestidade operacional

Evidências:

- matriz terminal/exit;
- no-diff, dirty tree, staging e crash probes;
- review indisponível/falha honesta;
- gates/resume fail-closed;
- adapters dentro da CI;
- CLI/docs alinhadas.

Falha: F1 não inicia.

### G-F1 — contratos e migração

Evidências:

- corpus de schemas;
- validator runtime;
- PRD dogfood válido;
- migração idempotente;
- restore ensaiado;
- input inválido sem mutação.

Falha: nenhum estado v1 é executado.

### G-F2 — orquestrador experimental

Evidências:

- paridade AUTO/implementation;
- tabela de transições;
- lock/recovery/deadline;
- change guard/budgets;
- inventário determinístico de capabilities e disponibilidade; execução de fallback continua bloqueada até G-F3.

Falha: remover registro experimental; facades e correções F0 permanecem.

### G-F3 — independência

Evidências:

- falsa declaração do executor não conclui;
- AC→evidence completo;
- separação por risco;
- owner gate;
- filtragem de routing/fallback preservando risco, sandbox e independência;
- dois challenge packets refute-first sem finding alto/crítico aberto.

Falha: `blocked` ou `requires_owner_decision`.

### G-F4 — observabilidade e memória

Evidências:

- consulta local responde agente, runner/profile, story, arquivos, comandos observáveis, testes, duração, tentativas, parada e prova;
- redaction e retenção;
- replay consistente;
- projeções regeneráveis;
- migração de lessons sem perda.

Falha: preservar formatos legados; não promover perfis.

### G-F5 — perfis especializados

Evidências por perfil:

- sucesso, falha, bloqueio, cancelamento, limite e agente declarando sucesso falsamente;
- verifier específico;
- facade compatível;
- proveniência.

Falha: retirar apenas o perfil reprovado.

### G-F6 — hardening final

Evidências:

- matriz WSL/Linux/Docker/CI;
- fault injection completa;
- rollback de migração;
- atestação ligada ao commit;
- auditoria independente;
- zero falso sucesso.

Falha: nenhuma release, depreciação ou remoção de legado.

## 9. Matriz mínima de testes bloqueantes

Os comandos abaixo são entregáveis previstos. Um gate permanece vermelho até o arquivo existir, o comando literal ser registrado no TaskPacket e o root confirmar exit, estado e efeitos.

| ID | Wave | Comando previsto | Cenário | Oráculo | Evidência |
|---|---|---|---|---|---|
| TEST-01 | W-01 | `bash tests/behavior/test-auto-terminal.sh delegate_failure` | delegate/verifier falha ou restam pendências | exit não zero, `prd.json` não concluído, sem COMPLETE | exit + PRD + log externo |
| TEST-02 | W-01/W-06 | `bash tests/behavior/test-auto-terminal.sh max_attempts` | story excede tentativas | em F0: failed sem `passes=true` e exit não zero; após F2: estado tipado `max_attempts_reached` | PRD/state diff + events quando disponíveis |
| TEST-03 | W-01 | `bash tests/behavior/test-auto-git-safety.sh dirty_tree` | tracked/untracked preexistentes | bloqueia ou preserva; stage não inclui terceiros | manifest + staged diff |
| TEST-04 | W-01/W-06 | `bash tests/behavior/test-auto-git-safety.sh commit_crash` | crash antes/depois do commit | F0 nunca declara sucesso; F2 reconcilia sem perda/duplicação | Git + estado + journal futuro |
| TEST-05 | W-01 | `bash tests/behavior/test-review-contract.sh missing_reviewer` | review sem reviewer real | blocked/nonzero; nunca zero findings | exit + review state |
| TEST-06 | W-01 | `bash tests/behavior/test-flow-gates.sh resume_mismatch` | gates lib ausente, contexto inválido ou resume obsoleto | flow bloqueia no gate correto | exit + gate evidence |
| TEST-07 | W-02 | `bash scripts/adapters/run-all-tests.sh` | adapter dry-run sem diff | no-diff falha e CI detecta regressão | CI/adapters logs |
| TEST-08 | W-03/04 | `bash tests/contracts/test-prd-migration.sh` | contrato inválido/migração interrompida | nenhuma mutação; restore; segundo run no-op | hashes + validator logs |
| TEST-09 | W-06 | `bash tests/loop/test-recovery.sh` | dois runs, stale lock, SIGINT/TERM, timeout e restart | lock exclusivo; cancelled/recovery persistidos; tentativa concluída não repete | events + process exits |
| TEST-10 | W-07 | `bash tests/verification/test-false-claim.sh` | executor declara sucesso sem AC evidence | juiz rejeita; verifier independente bloqueia | verification/judge packets |
| TEST-11 | W-08 | `bash tests/observability/test-journal.sh` | segredo, evento truncado e replay | segredo redigido; corrupção detectada; projeções consistentes | query + hashes |
| TEST-12 | W-10 | `bash tests/fault-injection/run-matrix.sh` | matriz de falhas/compatibilidade | zero falso sucesso e facades compatíveis | atestação ligada ao commit |
| TEST-13 | W-06 | `bash tests/loop/test-budgets.sh` | excede arquivos, linhas, tempo ou tentativas | nenhuma promoção; estado blocked/max; diff preservado | ResultPacket + diff stats + exit |
| TEST-14 | W-07 | `bash tests/loop/test-routing-policy.sh` | fallback perde sandbox/independência/capability | candidato rejeitado; estado blocked; nenhum dispatch | routing decision + ausência de invoke |
| TEST-15 | G-PRE/W-07 | `bash tests/loop/test-protected-environment.sh` | produção, branch/remoto protegido ou comando destrutivo | bloqueio antes da mutação; owner requerido | manifest inalterado + decision event |
| TEST-16 | W-07 | `bash tests/verification/test-owner-gate.sh` | tentativa de bypass do owner gate | juiz rejeita; estado requires_owner_decision | judge packet + ausência de mutação posterior |

Todo teste bloqueante valida exit code, estado e efeitos. Em F0, `DEVORQ-IR/1` apenas referencia esses sinais legados externos; ele não pressupõe journal ou state machine do produto. Stdout é apenas diagnóstico.

## 10. Lifecycle de uma task

1. Root cria TaskPacket e congela baseline.
2. Scout confirma que a dead-spec cabe no escopo.
3. Root concede mutation lease ao implementer.
4. Implementer aplica a mudança e devolve ResultPacket em `verifying`.
5. Root revoga lease, valida mutation set/budgets e aplica o patch mecanicamente.
6. Root congela o hash da árvore candidata integrada.
7. Independent Verifier executa o plano literal sobre esse hash.
8. Em risco alto/crítico, Adversarial Reviewer tenta refutar a claim sem receber a narrativa do implementer.
9. Finding contraditório ou integração semântica abre nova tentativa; o root não corrige a solução diretamente.
10. Documentation Curator produz patch documental referenciado às evidências verificadas.
11. Root aplica o patch documental mecanicamente e congela o hash final.
12. Verificador independente reexecuta gates de integração e doc-vs-code sobre o hash final.
13. Root reproduz o sinal discriminante e o Final Judge deriva o estado.
14. Somente então a wave pode ser promovida.

O orquestrador não concatena respostas. Ele reduz os ResultPackets para:

```text
estado
claims sobreviventes
evidências verificadas
conflitos resolvidos
decisões pendentes
diff integrado
próxima wave autorizada ou motivo de parada
```

## 11. Retry, cancelamento e rollback

### Retry

- tentativa é consumida e persistida antes do dispatch;
- falha determinística retorna ao planejamento, não repete cegamente;
- falha transitória pode repetir somente dentro do budget predefinido;
- timeout/crash com possível mutação exige reconciliação de processo, diff, manifest e journal;
- agente nunca aumenta o próprio budget;
- budget esgotado resulta `max_attempts_reached`.

### Cancelamento

INT/TERM, owner ou root:

- impedem novos dispatches;
- sinalizam o processo ativo com grace period;
- capturam diff/evidência possível;
- marcam `cancelled`;
- liberam lock/lease;
- não tratam cancelamento como falha recuperável automática.

### Rollback

- calcula patch inverso relativo ao snapshot e aos hashes pré/pós da tentativa;
- aplica automaticamente somente hunks sem sobreposição com mudança preexistente ou posterior;
- sobreposição/conflito preserva ambos os patches e termina `requires_owner_decision`;
- preserva patch, hashes e evidências;
- não usa hard reset;
- não apaga mudanças preexistentes;
- migração tem backup/restore ensaiado;
- perfil experimental pode ser retirado sem remover core/correções anteriores;
- facade legada permanece até o gate final e a janela de depreciação.

## 12. Decisões do owner e momento limite

| Decisão | Default técnico recomendado | Necessária antes de |
|---|---|---|
| OD-01 significado de completed | `verified`; `committed` somente opt-in | WS-01 |
| OD-02 worktree sujo | bloquear; exceção por allowlist+snapshot | WS-01 |
| OD-03 independência | contexto/identidade separados em médio+; crítico com owner | G-PRE para mutação high-risk |
| OD-04 produção/destrutivos | escrita proibida por default | G-PRE |
| OD-05 retenção/privacy | mínimo local redigido no G-PRE; política completa antes de WS-09 | G-PRE/WS-09 |
| OD-06 AUTO guided | facade por pelo menos duas versões menores | WS-06 |
| OD-07 nova CLI | apenas implementation experimental na F2 | WS-06 |

Se não houver ratificação até o momento limite, o estado é `requires_owner_decision`. Waves anteriores que não dependem da decisão podem produzir testes e evidências em leitura, mas não aplicar a escolha.

## 13. Artefatos previstos

O plano não cria antecipadamente esses arquivos; eles pertencem aos workstreams indicados:

```text
docs/architecture/
docs/adr/
schemas/v1/
profiles/
skills/devorq-auto/scripts/loop-auto.sh
skills/devorq-auto/scripts/check-story.sh
skills/devorq-code-review/scripts/review.sh
lib/auto.sh
lib/commit.sh
lib/gates.sh
lib/commands/workflow.sh
lib/contracts.sh
lib/loop.sh
lib/run-state.sh
lib/change-guard.sh
lib/routing.sh
lib/verifier.sh
lib/judge.sh
lib/events.sh
tests/contracts/
tests/loop/
tests/verification/
tests/observability/
tests/profiles/
tests/fault-injection/
.devorq/state/runs/<run_id>/
```

`docs/DEVORQ-LOOP-ENGINEERING-ASSESSMENT.md` continua como diagnóstico. Este documento é o plano detalhado; a futura estrutura `docs/roadmap.md` deve apenas apontar para ele, sem copiar seu conteúdo.

## 14. Runbook da primeira execução

Quando a implementação for explicitamente autorizada:

1. confirmar root, branch, commit-base e worktree;
2. criar `run_id`, snapshot e manifest;
3. ratificar OD-01 a OD-04 e o mínimo seguro de OD-05; sem isso, manter somente coleta read-only;
4. despachar em paralelo dois Scouts read-only para WS-01 e WS-02;
5. materializar TaskPackets com mutation sets exatos e comandos de teste literais;
6. produzir testes RED independentes para cada defeito P1 em worktrees isolados ou serialmente;
7. conceder mutation lease a WS-01 e WS-02 serialmente no mesmo worktree, ou usar worktrees isolados;
8. aplicar patches mecanicamente, congelar o hash integrado e despachar verificadores sem a narrativa dos implementers;
9. aplicar a documentação, congelar novo hash final e reverificar sobre ele;
10. executar TEST-01 a TEST-07 e a suíte completa;
11. somente com G-F0 verde promover WS-04.

Nenhum agente faz commit ou push nessa primeira wave sem autorização literal posterior.

## 15. Critério de conclusão do programa

O programa termina `completed` somente quando:

- G-F0 a G-F6 estão verdes;
- não há finding alto/crítico aberto;
- a matriz final registra zero falso sucesso;
- migração e recovery são idempotentes;
- facades e formatos legados cumprem a janela definida;
- documentação reflete o commit atestado;
- nenhum resultado depende apenas da declaração de um agente;
- o root consegue reproduzir a evidência discriminante de conclusão.

Até lá, o máximo permitido é uma fase ou perfil experimental promovido pelo gate correspondente.

---

**Regra desta etapa:** o plano foi criado; nenhuma mudança de produção, script, versão, commit, push ou release faz parte desta entrega.
