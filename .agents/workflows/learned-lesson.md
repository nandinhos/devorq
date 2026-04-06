---
description: Execute learned-lesson DEVORQ command
---

Documentar lição aprendida desta sessão.

Leia `.devorq/skills/learned-lesson/SKILL.md` para instruções completas.

**Regra**: Toda sessão termina com ao menos uma lição documentada.

## Processo

1. Identificar o problema ou insight mais relevante da sessão
2. Gerar documento estruturado
3. Apresentar ao usuário para aprovação (Gate 5)
4. Salvar em `.devorq/state/lessons-pending/YYYY-MM-[titulo-kebab].md`

## Template

```markdown
# Lição — [Título Descritivo]

## Contexto
- Quando: [data]
- Onde: [arquivo/componente/skill]
- Tipo: bug | erro-implementação | melhoria-processo

## Problema
[O que aconteceu — descrever claramente]

## Causa Raiz
[Por que aconteceu — não sintomas, a causa real]

## Solução
[Como foi resolvido]

## Prevenção
[Como evitar que aconteça novamente]
- [ ] Adicionar regra no /quality-gate
- [ ] Criar teste específico
- [ ] Validar no /pre-flight
```

## Gate 5

Apresentar a lição e perguntar:
- "Esta lição deve ser salva para sessões futuras?"
- "Deve ser incorporada a alguma skill? (`lessons apply <skill-name>`)"

Aguardar decisão do usuário antes de salvar.

## Pipeline de Aprendizado

Após Gate 5 → `./bin/devorq lessons validate` → Gate 6 → `./bin/devorq lessons apply <skill>` → Gate 7
