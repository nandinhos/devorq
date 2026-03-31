---
name: code-review
description: Revisão de código antes de merge
triggers:
  - "code-review"
  - "revisar"
  - "review"
globs:
  - "**/*.php"
  - "**/*.js"
---

# code-review - Revisão de Qualidade

## Quando Usar
Antes de PR/merge, após /quality-gate passar

## Checklist de Revisão

### Funcionalidade
- [ ] Código faz o que deveria?
- [ ] Casos de borda tratados?
- [ ] Erros tratados?

### Código
- [ ] DRY (não repetido?)
- [ ] Nomes descritivos?
- [ ] Funções pequenas (max 30 linhas)?
- [ ] Sem código morto?

### Segurança
- [ ] Input validado?
- [ ] Queries parametrizadas?
- [ ] Sem secrets no código?
- [ ] CSRF token?

### Performance
- [ ] Sem N+1 queries?
- [ ] Eager loading onde preciso?
- [ ] Caching apropriado?

### Testes
- [ ] Testes cobrem a funcionalidade?
- [ ] Casos importantes testados?

## Resultado

| Status | Significado |
|--------|-------------|
| APPROVED | Pode fazer merge |
| CHANGES_REQUESTED | Corrigir antes de merge |
| COMMENT | Observações, não bloqueante |

---

> **Débito que previne**: D13 (Ausência de gates automáticos)