Decompor tarefa complexa em subtarefas atômicas: $ARGUMENTS

Leia `.devorq/skills/break/SKILL.md` para instruções completas.

**Pré-requisito**: `/spec` deve ter sido aprovado no Gate 1.

## Critérios de Decomposição

Quebrar quando a task tiver:
- 3+ arquivos modificados
- Estimativa > 60 minutos
- Múltiplas camadas (model + controller + view + test)
- Dependências entre partes (A precisa existir para B funcionar)

## Formato das Subtarefas

```markdown
# Task List — [nome da feature]

## Subtarefa 1: [nome curto]
- Arquivos: [lista exata]
- Dependências: [nenhuma / subtarefa N]
- FAZER: [lista]
- NÃO FAZER: [lista]
- Done criteria: [ ] item

## Subtarefa 2: [nome curto]
...
```

## Regras

- Cada subtarefa deve ser executável de forma independente
- Ordenar por dependência (sem bloqueios entre elas)
- Máximo 3 arquivos por subtarefa
- Cada subtarefa tem seu próprio Done Criteria

## Output

Salvar em `.devorq/state/tasklist/[nome]-tasks.md` e apresentar para aprovação.
