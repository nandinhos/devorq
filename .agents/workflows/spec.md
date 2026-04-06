---
description: Execute spec DEVORQ command
---

Gerar especificação formal para: $ARGUMENTS

Leia `.devorq/skills/spec/SKILL.md` para instruções completas.

## Processo

Faça as seguintes perguntas ao usuário, **uma por vez**, aguardando resposta:

1. Qual é o objetivo principal? (o que resolve)
2. Quem são os usuários? (contexto de uso)
3. Quais páginas/telas/endpoints estão envolvidos?
4. Quais são as regras de negócio críticas?
5. O que está FORA do escopo agora?
6. Quais modelos/entidades estão envolvidos?

## Documento Gerado

Após respostas, criar `docs/spec/YYYY-MM-DD-[nome-kebab].md`:

```markdown
# Spec — [Nome]
**Data**: YYYY-MM-DD | **Status**: rascunho

## Objetivo
[descrição clara]

## Fora do Escopo
- [item 1]

## Páginas / Endpoints
| Nome | Descrição | Comportamentos |
|------|-----------|----------------|

## Regras de Negócio
1. [regra sempre verdadeira]

## Modelos de Dados
- `Modelo` — campos e relacionamentos
```

## Gate 1

Apresentar documento ao usuário e aguardar aprovação explícita antes de prosseguir para `/break`.
