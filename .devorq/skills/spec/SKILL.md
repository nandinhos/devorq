---
name: spec
description: Criar documento de especificação formal antes de iniciar desenvolvimento de projeto ou feature grande
triggers:
  - "spec"
  - "/spec"
  - "especificação"
  - "PRD"
  - "especificar projeto"
globs:
  - "**/*.md"
---

# /spec — Especificação de Projeto

> **Regra de Ouro**: Sem spec não existe break. Sem break o LLM engasga.

## Quando Usar

**OBRIGATÓRIO** para:
- Projeto novo
- Feature de médio/grande porte (2+ páginas ou 3+ comportamentos)

**OPCIONAL** para:
- Bugfixes simples
- Features de 1 página

## Propósito

1. **Clareza antes do código**: Garantir que todos os envolvidos compartilham o mesmo entendimento antes de qualquer implementação
2. **Fonte de verdade para /break**: A spec é o input que alimenta o /break para decomposição em tarefas atômicas
3. **Evitar escopo vago**: Forçar especificidade sobre o que será construído, eliminando ambiguidade que gera retrabalho

## Processo

### Step 1: Capturar Intenção

Fazer as seguintes perguntas ao usuário, **uma por vez**, aguardando resposta antes de prosseguir:

1. **Qual é o objetivo principal?** — O que este projeto/feature deve resolver?
2. **Quem são os usuários?** — Quem vai usar isso e qual é o contexto de uso?
3. **Quais são as páginas ou telas envolvidas?** — Liste cada interface que precisa existir.
4. **Quais são as regras de negócio críticas?** — O que deve ser verdadeiro sempre?
5. **O que está explicitamente fora do escopo?** — O que NÃO será construído agora?
6. **Quais modelos de dados ou entidades estão envolvidos?** — Estimativa de tabelas/recursos necessários.

### Step 2: Gerar Documento de Spec

Com base nas respostas, gerar o documento no seguinte template:

```markdown
# Spec — [Nome do Projeto/Feature]

**Data**: YYYY-MM-DD
**Status**: rascunho | aprovado
**Autor**: [LLM/Usuário]

## Objetivo

[Descrição clara do que será construído e por quê]

## Fora do Escopo

- [Item 1 que NÃO será feito]
- [Item 2 que NÃO será feito]

## Páginas / Telas

| Página | Descrição | Comportamentos principais |
|--------|-----------|--------------------------|
| [nome] | [o que é] | [lista de comportamentos] |

## Regras de Negócio

1. [Regra 1 — sempre verdadeira]
2. [Regra 2 — sempre verdadeira]
3. [Regra N — sempre verdadeira]

## Estimativa de Modelos

- `[NomeModelo]` — [campos principais e relacionamentos]
- `[NomeModelo]` — [campos principais e relacionamentos]
```

### Step 3: Salvar Documento

Salvar em `docs/spec/YYYY-MM-DD-[nome-kebab-case].md` dentro do projeto alvo.

Exemplo: `docs/spec/2026-04-02-autenticacao-oauth.md`

### Step 4: Gate de Aprovação

Apresentar o documento gerado ao usuário com a pergunta:

```
Spec gerada e salva em docs/spec/[arquivo].md

Revise o documento acima.
- Algo está incorreto ou faltando?
- Posso prosseguir para o /break?

[AGUARDANDO APROVAÇÃO]
```

**PARAR e aguardar confirmação explícita do usuário antes de prosseguir.**

## Próximo Passo

Após aprovação do usuário → executar `/break` com a spec como input para decomposição em tarefas atômicas.

---

> **Débito que previne**: Escopo vago, LLM implementando coisas não pedidas, contexto explodido por tarefa enorme
