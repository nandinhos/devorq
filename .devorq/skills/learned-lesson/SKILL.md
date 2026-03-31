---
name: learned-lesson
description: Documentar aprendizados para evitar recorrência
triggers:
  - "learned-lesson"
  - "lição"
  - "aprendizado"
globs:
  - "**/*.md"
---

# learned-lesson - Lições Aprendidas

## Quando Usar
**OBRIGATÓRIO** após:
- Bug debugado com sucesso
- Erro de implementação corrigido
- Problema resolvido com solução não óbvia

## Estrutura

```markdown
# Lição Aprendida - [Título Descritivo]

## Contexto
- Quando: [data/sessão]
- Onde: [arquivo/componente]
- Tipo: [bug/erro/improvement]

## Problema
[Descrição clara do que aconteceu]

## Causa Raiz
[Por que aconteceu - não sintomas]

## Solução
[Como foi resolvido]

## Prevenção
[Como evitar que aconteça novamente]
- [ ] Regra em /quality-gate
- [ ] Teste específico
- [ ] Validação em /pre-flight

## Referências
- [Links, documentação, artigos]
```

## Organização
Salvar em: `.aidev/state/lessons-learned/YYYY-MM-[titulo].md`

---

> **Regra**: Revisar lições aprendidas antes de novas implementações