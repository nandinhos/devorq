---
name: break
description: Decompor documento de spec em tasks atômicas ordenadas — protótipo visual sempre antes de comportamento
triggers:
  - "break"
  - "/break"
  - "decompor spec"
  - "quebrar em tasks"
  - "criar issues"
globs:
  - "docs/spec/*.md"
---

# /break — Decomposição de Spec em Tasks

> **Regra de Ouro**: Uma task = uma coisa verificável. Protótipo visual antes de comportamento.

## Quando Usar

**OBRIGATÓRIO** após aprovação do `/spec`. Não executar sem spec aprovada.

## Por Que Isso Importa

LLMs perdem qualidade de entrega quando uma task é grande demais. Com contexto lotado, o modelo começa a adivinhar, duplicar código e perder coerência entre arquivos. Decompor em tasks atômicas mantém o contexto focado e verificável.

Além disso, implementar comportamento em uma tela que o usuário ainda não aprovou é desperdício garantido — o chamado "cobertor de pobre": cobre um lado, descobre o outro. Protótipo aprovado antes de lógica elimina esse ciclo de retrabalho.

## Regras de Decomposição

1. **Máximo 5 arquivos por task** — se precisar de mais, é sinal de que a task deve ser dividida
2. **Protótipo sempre primeiro** — para cada página, criar task visual antes de qualquer comportamento
3. **Um comportamento por task** — cada task de comportamento implementa uma única ação do usuário
4. **Dependência explícita** — informar se uma task depende de outra antes de poder ser iniciada
5. **Critério verificável** — sem "quando ficar bom"; critério deve ser testável objetivamente

## Processo

### Step 1: Ler a Spec

```bash
cat docs/spec/YYYY-MM-DD-[nome].md
```

Identificar: páginas/telas, comportamentos por página, regras de negócio, modelos de dados.

### Step 2: Gerar Task List

Para cada página listada na spec:
1. Criar uma task de **protótipo visual** (sem lógica)
2. Criar uma task por **comportamento** descrito na spec (após o protótipo)

Ordenar: todos os protótipos antes dos comportamentos dependentes.

### Step 3: Formato de Output

Usar o seguinte template para cada task:

```markdown
## TASK-001: [Página X] — Protótipo Visual
- **Tipo**: `prototype`
- **Página**: [nome da página]
- **FAZER**: Criar tela visual sem lógica (HTML/Blade/Livewire layout)
- **NÃO FAZER**: Nenhuma lógica de backend, sem queries, sem wire:model funcional
- **Arquivos**: [lista máx. 5 arquivos]
- **Critério**: Tela renderiza sem erro 500. Visual aprovado pelo usuário.
- **Depende de**: nenhuma

## TASK-002: [Página X] — Comportamento: [ação do usuário]
- **Tipo**: `behavior`
- **Página**: [nome da página]
- **FAZER**: Implementar [ação específica e única]
- **NÃO FAZER**: [o que não toca nesta task]
- **Arquivos**: [lista máx. 5 arquivos]
- **Critério**: [verificação objetiva e testável]
- **Depende de**: TASK-001
```

### Step 4: Salvar Task List

Salvar em `.devorq/state/tasklist/YYYY-MM-DD-[nome].md` dentro do projeto alvo.

Exemplo: `.devorq/state/tasklist/2026-04-02-autenticacao-oauth.md`

### Step 5: Apresentar e Aguardar Confirmação

Apresentar a task list completa ao usuário com a pergunta:

```
Task list gerada e salva em .devorq/state/tasklist/[arquivo].md

Revise a ordem e granularidade:
- Alguma task está grande demais ou pequena demais?
- A ordem faz sentido para o seu fluxo de trabalho?
- Posso iniciar pela TASK-001?

[AGUARDANDO CONFIRMAÇÃO]
```

**PARAR e aguardar confirmação explícita antes de iniciar qualquer task.**

## Fluxo de Execução por Task

Para cada task aprovada da lista, seguir obrigatoriamente:

```
/scope-guard → /pre-flight → tdd → /quality-gate → commit
```

Nunca iniciar a próxima task sem commit da anterior aprovado pelo quality-gate.

---

> **Débito que previne**: Contexto explodido, código duplicado por falta de visibilidade, comportamento implementado em tela não aprovada
