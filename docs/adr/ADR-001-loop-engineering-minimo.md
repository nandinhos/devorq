# ADR 001 — Loop Engineering mínimo e experimental

> One decision of record per file. Truth type: **decision**. Verified for currency
> (superseded ones are marked) and consistency with the code. An accepted ADR the code
> contradicts is **flagged for human resolution** — neither the doc nor the code auto-wins.

- **Status:** accepted
- **Date:** `2026-07-13`
- **Owner:** owner do DEVORQ

## Context

O [assessment](../DEVORQ-LOOP-ENGINEERING-ASSESSMENT.md) comprovou que o DEVORQ já possui
AUTO, adapters, gates e verificadores, mas ainda permite falsos sucessos e mantém estado em
fontes concorrentes. O [plano de execução](../DEVORQ-LOOP-ENGINEERING-EXECUTION-PLAN.md)
determina corrigir F0, formalizar contratos em F1 e só então experimentar um loop comum com
`implementation`. O [contrato de escopo](../DEVORQ-LOOP-ENGINEERING-SCOPE.md) proíbe
reescrita, serviço externo, banco, broker, plugin loader, DAG genérico e quebra das facades
existentes.

O baseline relevante permanece `lib/commands/auto.sh:devorq::cmd_auto`,
`skills/devorq-auto/scripts/loop-auto.sh:main`,
`skills/devorq-auto/scripts/check-story.sh:main` e `scripts/adapters/delegate.sh`.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **A — Corrigir apenas o AUTO atual** | menor diff imediato; nenhuma superfície nova | mantém lifecycle, estado e autoridade acoplados; cada perfil futuro repetiria o problema |
| **B — Core mínimo Bash+jq com um profile experimental** | cria seams para estado, execução, verificação e juiz; reutiliza adapters; permite rollback da CLI | exige contratos e migração antes do piloto; mantém facade durante a transição |
| **C — Framework genérico com DAG/plugins/persistência externa** | extensibilidade ampla desde o início | complexidade sem consumidor atual, nova operação e contratos prematuros |

## Decision

Adotar a opção **B** conforme o desenho em
[Loop Engineering mínimo e experimental](../architecture/LOOP-ENGINEERING.md):

1. implementar uma state machine linear Bash+jq, inicialmente apenas para
   `implementation`;
2. adotar os contratos v1 Story, Loop, Execution, Verification e Evidence, além dos contratos
   independentes Failure, Lesson e Handoff, com validação runtime fail-closed e JSON Schema
   completo na CI; extensões de risk, Judge, AC→evidence e observabilidade só se tornam
   garantias nos gates de seus consumidores;
3. manter `passes` somente como projeção de compatibilidade e aceitar legado apenas por
   migração explícita;
4. separar executor, verificador e juiz em WS-08/G-F3, elevando independência e owner gate de
   forma proporcional ao risco; os campos de ator/verifier de F1 não constituem essa prova;
5. introduzir em WS-07/WS-09 persistência local em
   `.devorq/state/runs/<run_id>/events.jsonl`, com artefatos de evidência endereçados por
   ID/hash e demais arquivos como projeções;
6. reutilizar `DEVORQ_DELEGATE_FN` e `scripts/adapters/`; o loop envolve exit/journal em
   `Execution v1`, sem exigir ResultPacket do adapter nem duplicar lógica por runner no core;
7. manter `devorq auto` como facade e expor `devorq loop implementation --experimental`
   somente depois dos gates de contratos, migração e paridade.

A decisão congela as fronteiras e invariantes, não nomes de funções internas, códigos não
zero específicos, fornecedor de runner ou formato de projeções. Essas escolhas são
reversíveis atrás dos contratos.

## Consequences

Positivas:

- somente o juiz pode concluir um run;
- contratos inválidos, evidência ausente e fallback incompatível falham fechados;
- adapters atuais continuam sendo o único ponto de lógica comercial por runner;
- recovery e auditoria podem evoluir sem banco ou reescrita do lifecycle;
- o experimento pode ser removido sem desfazer correções F0 ou migrações válidas.

Custos e restrições:

- F2 não começa antes de G-F1;
- a facade legada permanece durante pelo menos duas versões menores após estabilidade;
- risco médio ou maior custa uma identidade/contexto de verificação separados;
- somente um writer opera por worktree;
- profiles além de `implementation` ficam bloqueados até terem casos reais, verifier próprio
  e threat model;
- produção, push, release e comandos destrutivos continuam fora da autoridade implícita do
  loop.

## Trigger to revisit

Revisar esta decisão quando qualquer condição ocorrer:

1. `implementation`, `code-review` e ao menos um de `debugging`/`documentation` passarem
   seus gates e demonstrarem duas variações reais que o core atual não acomoda sem duplicação;
2. dois hosts precisarem coordenar o mesmo projeto ou o replay local superar p95 de 2 s em
   100 mil eventos — avaliar outra persistência atrás do seam de state/events;
3. uma capability obrigatória de sandbox/telemetria não puder ser expressa pelo contrato
   atual de adapters em dois casos reais — evoluir o contrato sem duplicar runners;
4. G-F6 estiver verde, duas versões menores de depreciação tiverem passado e não houver
   consumidor conhecido do guided/legado — avaliar remover a facade correspondente.

Owner dos gatilhos: maintainer do runtime DEVORQ, com evidência nos gates e nova ADR antes de
qualquer extração.
