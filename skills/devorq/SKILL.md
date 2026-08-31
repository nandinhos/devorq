---
name: devorq
description: Metodologia DEVORQ de desenvolvimento sistemático — gates bloqueantes, lições aprendidas, handoffs e disciplina de commit. Use ao começar qualquer trabalho em um projeto DEVORQ, ao capturar ou buscar lições aprendidas, ao encerrar uma sessão com handoff, ou antes de fazer commit.
whenToUse: Início de trabalho em projeto DEVORQ, captura/busca de lições, handoff de sessão, ou antes de commit.
metadata:
  version: 4.1.0
  author: Fernando Dos Santos (Nando)
  source: framework DEVORQ (github.com/nandinhos/devorq)
---

# DEVORQ — metodologia de desenvolvimento sistemático

Framework de disciplina inspirado em <https://github.com/nandinhos/devorq>. Combate o ciclo: contexto saturado → próximo agente perde informação → decisões duplicadas → mesmas falhas se repetem.

## Princípio

**Vermelho = para e corrige. Verde = segue em frente.** Nada avança sem verificação.

## Gates bloqueantes

| Gate | Nome | Critério |
|------|------|----------|
| G-1 | Spec | existe especificação/objetivo claro e escrito? |
| G-2 | Tests | os testes passam? |
| G-3 | Contexto | o estado do trabalho está documentado? |
| G-4 | Lições | lições relevantes foram revisadas? |
| G-5 | Handoff | handoff consistente foi gerado? |
| G-6 | Docs | documentação relevante foi consultada (Context7)? |
| G-7 | Debug | em caso de erro, investigou sistematicamente primeiro? |

> Numeração de referência do código (`lib/gates.sh`): GATE-0 (DDD/contexto), GATE-0.5 (foundation), GATE-1..7, GATE-5.5 (unify), GATE-E2E (Playwright).

## Comandos

Interface CLI (router `devorq <comando>`):

| Objetivo | Comando |
|----------|---------|
| Inicializar projeto (.devorq/) | `devorq init` |
| Criar 5W2H, premissas, riscos, requisitos, restrições | `devorq foundation` |
| Fluxo completo (gates 0→7) | `devorq flow "<intent>"` |
| Gate específico (0-7) | `devorq gate [N]` |
| Contrato mínimo FAZER/NÃO FAZER/VERIFICAR | `devorq scope lite "<intent>"` |
| Contexto do projeto | `devorq context get\|set\|merge` |
| Capturar lição | `devorq lessons capture` |
| Listar/buscar lições | `devorq lessons list\|search` |
| Validar/aprovar/compilar lições | `devorq lessons validate\|approve\|compile` |
| Gerar handoff | `devorq compact` |
| Verificação visual / E2E pré-commit | `devorq verify` (roda `devorq build`, gates 1-7) |
| Commit manual (convenção `tipo(escopo)`) | `devorq commit --story <id>` |
| Modo AUTO (Ralph/delegação) | `devorq auto [N\|--guided\|--continue]` |
| Loop engineering experimental | `devorq loop implementation --experimental` |
| Exportar regras (claude/cursor/project/agents) | `devorq rules export <cli\|cursor\|project\|agents>` |
| Teste de estrutura | `devorq test` |
| Versão | `devorq version` |

> Rodar `devorq help` para a lista completa e `devorq <cmd> --help` por comando.

## Fluxo recomendado

1. Escreva/valide a especificação (G-1). Use `devorq scope lite "<intent>"`; preencha `.devorq/state/context.json` (`devorq context set intent` / `success_criteria`).
2. Verifique os testes (G-2): `devorq test`.
3. Documente o contexto (G-3): `devorq context get`.
4. Revise lições (G-4): `devorq lessons search`.
5. Implemente.
6. Em erro, debug sistemático (G-7): `devorq debug`.
7. Gere o handoff (G-5): `devorq compact`.
8. Verifique antes do commit (G-2/G-6): `devorq build` + `devorq verify`.
9. Só commite após `devorq verify` verde **e** autorização explícita — `devorq commit` (nunca automático sem pedido).

## Lições aprendidas

Ao encontrar um erro ou descoberta não óbvia, registre uma lição:

```json
{
  "title": "resumo curto",
  "problem": "o que aconteceu",
  "solution": "como resolveu",
  "stack": ["bash", "docker"],
  "tags": ["docker", "jq"]
}
```

Antes de começar qualquer trabalho, revise as lições existentes do projeto para não repetir erros.

## Handoff

Ao encerrar uma sessão, documente: o que foi feito, o que falta, decisões tomadas e por quê, e próximos passos. O próximo agente continua de onde você parou, sem re-descobrir.

## Convenção de commit

`tipo(escopo): descrição`

- `tipo` ∈ `feat|fix|refactor|docs|test|style|perf|chore`; `escopo` = área (tabela em `rules/commit-convention.md`).
- `tipo` e `escopo` somente minúsculas — sem espaço, dígito ou hífen.
- Exemplos: `fix(gates): corrige contagem`, `feat(agents): contrato documentado`.
- IDs vão no fim da descrição, nunca no escopo: `fix(gates): corrige contagem (DQ-028)`.
- Sem `Co-Authored-By`.
- Mensagens em português do Brasil.
- **Nunca** commitar (`git commit`) antes de: trabalho 100% verificado (`devorq verify` verde), autorização explícita do dono, e commit com `devorq commit` (o hook `commit-msg` valida `^[a-z]+\([a-z]+\):`).

## Proibições

- Sem refatoração fora do escopo pedido.
- Sem features especulativas.
- Sem alterar o que não foi solicitado.
- Sem `Co-Authored-By` em commits.

## Referências do framework

- Repo: <https://github.com/nandinhos/devorq>
- `rules/` = fonte canônica de regras (agent-discipline, commit-convention, manual-commit, visual-verification).
- Skills operacionais no repo: `devorq-auto`, `devorq-code-review`, `devorq-mode`, `scope-guard`, `grill-with-docs`, `project-foundation`, `env-context`, `ddd-deep-domain`, `security-hardening`.
