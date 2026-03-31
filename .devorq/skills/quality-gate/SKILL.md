---
name: quality-gate
description: Checklist obrigatório antes de qualquer commit
triggers:
  - "quality-gate"
  - "checklist"
  - "pronto para commit"
globs:
  - "**/*.php"
  - "**/*.js"
---

# /quality-gate - Verificação Pré-Commit

> **Regra de Ouro**: Se não passou no quality gate, não faz commit

## Quando Usar

**OBRIGATÓRIO** após qualquer implementação, ANTES de commit

## Checklist

```
## QUALITY GATE

### 1. Testes
- [ ] Todos passando
- [ ] Novos testes adicionados
- [ ] Sem regressão

### 2. Lint
- [ ] Pint/ESLint passou
- [ ] Code style padrão

### 3. Escopo (/scope-guard)
- [ ] Apenas arquivos autorizados modificados
- [ ] NÃO FAZER respeitado

### 4. DONE_CRITERIA
- [ ] Todos critérios atingidos

### 5. Segurança
- [ ] Sem secrets expostas
- [ ] Input validation presente
- [ ] SQL injection prevenido

### 6. Performance
- [ ] Sem N+1 query novo
- [ ] Eager loading usado

### 7. Arquitetura
- [ ] Lógica em Actions/Services
- [ ] Form Requests para validação
```

## Resultado
- **APROVADO**: Pode fazer commit
- **REJEITADO**: Corrigir antes de commit

---

> **Débito que previne**: D13 (Ausência de gates automáticos)