---
description: Execute brainstorming DEVORQ command
---

Iniciar sessão de brainstorming para: $ARGUMENTS

Leia `.devorq/skills/brainstorming/SKILL.md` para instruções completas.

**Usar antes** de decisões de arquitetura ou features complexas. **Não** produz código — produz decisões.

## Processo

### Fase 1 — Entender o Problema
- Qual é o problema real que estamos resolvendo?
- Quais são as restrições (tempo, tecnologia, equipe)?
- O que já foi tentado antes?

### Fase 2 — Gerar Opções (sem filtrar)
Listar 3-5 abordagens possíveis, incluindo as não-óbvias:
```
Opção A: [nome] — [descrição em 1 linha]
Opção B: [nome] — [descrição em 1 linha]
Opção C: [nome] — [descrição em 1 linha]
```

### Fase 3 — Avaliar Trade-offs
Para cada opção:
| Critério | Opção A | Opção B | Opção C |
|----------|---------|---------|---------|
| Complexidade | baixa/média/alta | | |
| Tempo impl. | horas/dias | | |
| Manutenibilidade | boa/regular | | |
| Riscos | [lista] | | |

### Fase 4 — Recomendação
Apresentar a opção recomendada com justificativa:
- Por que esta opção?
- Quais riscos aceitar?
- O que fica fora do escopo agora?

## Output

Após brainstorming aprovado → executar `/spec` para formalizar a decisão escolhida.
