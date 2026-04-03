# activation.md — Metodologia DEVORQ v2.1

> Documentação universal. Agnóstica de plataforma LLM.

---

## Filosofia Arquitetural

### Thin Client vs Fat Server

O DEVORQ adota o padrão **Thin Client**:
- A IA receptora executa como cliente leve, delegando operações pesadas ao servidor (Laravel Boost, Django, Context7)
- MCPs condicionais são acionados apenas quando frameworks específicos são detectados
- O executor não precisa saber internals do backend — apenas segue o fluxo padronizado

###mentalidade Fat Server evita:
- Execução de código de infraestrutura no contexto da conversa
- Acúmulo de dependências específicas por ferramenta
- Atrasos por fallbacks não mapeados

---

## Estrutura de Handoff (7 Blocos)

Todo pacote de transferência entre LLMs deve conter estas 7 seções:

| # | Seção | Propósito |
|---|-------|-----------|
| 1 | Metadados | Timestamps, autor, executor recomendado |
| 2 | Snapshot do Projeto | Stack, estado atual, branch |
| 3 | Contrato de Escopo | FAZER / NÃO FAZER / ARQUIVOS |
| 4 | Task Brief | Sub-tasks numeradas com verificação de gates |
| 5 | Padrões Obrigatórios | TDD, commit único, idioma |
| 6 | Done Criteria | Checklist de aceite |
| 7 | Retorno | Formato de resposta padronizado |

---

## Gatilhos: `/spec` e `/break`

### `/spec` — Geração de Especificação

Usado **obrigatoriamente** antes de qualquer implementação significativa.

Aciona o pipeline:
1. Detecta contexto via `/env-context` (automático)
2. Gera contrato de escopo (FAZER/NÃO FAZER/ARQUIVOS/DONE_CRITERIA)
3. Pausa para Gate 1 — aprovação do contrato

**Quando usar**:
- Nova feature
- Refatoração de módulo
- Correção de bug que demande mudanças em múltiplos arquivos
- Qualquer tarefa que requer mais de 15 minutos de implementação

### `/break` — Decomposição de Tarefa

Usado quando uma task é complexa demais para ser executada de uma vez.

Aciona:
1. Quebra a task em subtarefas manejáveis
2. Registra cada subtarefa em `.devorq/state/tasklist/`
3. Permite execução incremental com checkpoints

**Quando usar**:
- Tarefa com +5 arquivos modificados
- Worktree isolation necessária
- Necessidade de validação intermediária antes de prosseguir

---

## Fluxo Obrigatório v2.1

```
1. /env-context          → Detectar stack e constraints (automático)
2. /spec                 → Gerar contrato detalhado → [Gate 1]
3. /break                → Decompor se complexo → [opcional]
4. /pre-flight           → Validar tipos, enums, dependências → [Gate 2]
5. handoff generate      → Spec para próximo LLM → [Gate 4] (se trocar LLM)
6. tdd                   → RED → GREEN → REFACTOR
7. /quality-gate         → Checklist pré-commit (OBRIGATÓRIO) → [Gate 3]
8. /session-audit        → Métricas de eficiência (OBRIGATÓRIO)
9. /learned-lesson       → Capturar lições (OBRIGATÓRIO) → [Gate 5]
10. checkpoint           → Para continuidade
```

---

## Pipes de Aprovação (Gates)

| Gate | Trigger | Pausa | Ação |
|------|---------|-------|------|
| 1 | `/spec` | ✅ | Aprovar contrato de escopo |
| 2 | `/pre-flight` | ✅ | Aprovar validação de tipos |
| 3 | `/quality-gate` | ✅ | Aprovar checklist pré-commit |
| 4 | `handoff generate` | ✅ | Aprovar spec para próximo LLM |
| 5-7 | `/learned-lesson` | ✅ | Decidir lições a salvar |

---

## Skills Disponíveis

O DEVORQ oferece 17 skills de workflow:

1. **scope-guard** — Contrato de escopo
2. **pre-flight** — Validação de tipos e enums
3. **env-context** — Detecção de stack
4. **quality-gate** — Checklist pré-commit
5. **session-audit** — Métricas de eficiência
6. **tdd** — Ciclo RED → GREEN → REFACTOR
7. **schema-validate** — Integridade de schema
8. **spec** — Geração de especificação
9. **break** — Decomposição de tarefas
10. **systematic-debugging** — Investigação de bugs
11. **code-review** — Revisão baseada em Clean Code
12. **brainstorming** — Fase de design
13. **learned-lesson** — Captura de lições
14. **handoff** — Transferência multi-LLM
15. **constraint-loader** — Carregamento de artefatos
16. **integrity-guardian** — Validação de padrões
17. **verification** — Verificação pré-completion

---

> Esta documentação é o pilar central do DEVORQ. Qualquer implementação deve respeitar esta metodologia.