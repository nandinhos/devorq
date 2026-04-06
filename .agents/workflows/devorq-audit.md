---
description: Execute devorq-audit DEVORQ command
---

Executar auditoria da sessão atual DEVORQ.

Analise toda a sessão e gere o relatório de eficiência:

## Classificação

| Classificação | Critérios |
|---------------|-----------|
| **EFICIENTE** | Feature completa + testes passando + escopo respeitado |
| **ACEITÁVEL** | Feature parcial + ajustes esperados dentro do escopo |
| **DESPERDIÇADA** | Saiu do escopo / over-engineering / debugging evitável |

## Causas Raiz

Identificar se aplicável:
- `SPEC_VAGA` — escopo indefinido no início
- `OVER_ENGINEERING` — implementou além do FAZER
- `ENV_DEBUG` — tempo perdido com Docker/infra/ambiente
- `SCHEMA_ERRO` — tipos ou enums errados consumiram rounds
- `INTERROMPIDA` — fator externo
- `REGRESSÃO` — teste existente quebrado inadvertidamente

## Gerar Report

```markdown
# SESSION AUDIT — [data hora]

## Dados
- Duração estimada: [tempo]
- Task principal: [descrição]
- Arquivos modificados: [lista]
- Commits criados: [n]

## Classificação: [EFICIENTE / ACEITÁVEL / DESPERDIÇADA]

## Métricas
- Rounds de fix: [n]
- Gates executados: [lista]
- Testes: [n passando / n total]
- Desvios do escopo: [sim/não — detalhar]

## Causa Raiz (se não EFICIENTE)
- [causa]: [o que aconteceu]

## Próxima Sessão
- Continuar de: [próximo passo exato]
- Atenção para: [riscos/dependências]
```

## Após o Relatório

Obrigatoriamente executar `/learned-lesson` para capturar ao menos uma lição desta sessão.
