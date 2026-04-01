---
name: brainstorming
description: Explorar ideias antes de criar plano formal
triggers:
  - "brainstorm"
  - "ideia"
  - "explorar"
globs:
  - "**/*.md"
---

# brainstorming - Skill

## Quando Usar
Quando usuário apresenta ideia/solicitação nova que precisa ser explorada antes de virar plano.

## Processo

1. **Entender problema**: O que precisa resolver? Por quê?
2. **Explorar alternativas**: 2-3 abordagens possíveis
3. **Identificar riscos**: O que pode dar errado?
4. **Decisão preliminar**: Qual caminho seguir?
5. **Documentar**: Criar registro em `.aidev/plans/brainstorm/`

## Estrutura

```markdown
# Brainstorm - [Nome]

## Problema
- [Descrição do problema]
- [Por que precisa resolver]

## Alternativas
### Opção 1: [nome]
- Prós: [lista]
- Contras: [lista]

### Opção 2: [nome]
- Prós: [lista]
- Contras: [lista]

## Riscos
- [Risco 1] - Mitigação: [como evitar]
- [Risco 2] - Mitigação: [como evitar]

## Decisão
- Caminho escolhido: [opção X]
- Justificativa: [por quê]
```

---

> **Regra**: Após brainstorm, usar /scope-guard antes de implementar