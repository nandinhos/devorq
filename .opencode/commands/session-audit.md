Executar auditoria da sessão de desenvolvimento atual.

Leia `.devorq/skills/session-audit/SKILL.md` para instruções completas.

Analise toda a conversa/sessão atual e classifique:

## Classificação

| Resultado | Critério |
|-----------|----------|
| **EFICIENTE** | Feature completa + testes ok + escopo respeitado |
| **ACEITÁVEL** | Progresso real + ajustes esperados |
| **DESPERDIÇADA** | Fora do escopo / over-engineering / debugging evitável |

## Causas Raiz (se aplicável)

- `SPEC_VAGA` — escopo indefinido causou retrabalho
- `OVER_ENGINEERING` — implementou além do necessário
- `ENV_DEBUG` — ambiente/Docker/infra consumiu tempo
- `SCHEMA_ERRO` — tipos/enums errados geraram rounds extras
- `INTERROMPIDA` — fator externo (rate limit, usuário)
- `REGRESSÃO` — teste existente quebrado

## Gerar Relatório

Salvar em `.devorq/state/session-audits/YYYY-MM-DD-HH-MM.md`:

```markdown
# SESSION AUDIT — [data hora]

## Dados
- Task: [descrição]
- Arquivos modificados: [lista]
- Commits: [n]

## Classificação: EFICIENTE / ACEITÁVEL / DESPERDIÇADA

## Métricas
- Fix rounds: [n]
- Gates executados: [lista]
- Testes: [n/total]

## Causa Raiz: [se não EFICIENTE]

## Próxima Sessão
- Próximo passo: [ação imediata]
- Atenções: [riscos]
```

## Obrigatório Após

Executar `/learned-lesson` para capturar ao menos uma lição.
