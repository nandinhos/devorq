---
name: test-driven-development
description: Implementar código com ciclo RED → GREEN → REFACTOR
triggers:
  - "tdd"
  - "teste primeiro"
  - "RED GREEN REFACTOR"
globs:
  - "tests/**/*.php"
  - "tests/**/*.js"
---

# TDD - Test-Driven Development

> **Regra de Ouro**: Nunca escreva código sem teste primeiro

## Ciclo

### RED (Teste Falha)
1. Escrever teste descrevendo comportamento desejado
2. Teste falha porque código não existe ainda
3. **NUNCA** pular para código sem teste

### GREEN (Código Passa)
1. Implementar código mínimo para teste passar
2. Não otimizar, não melhorar - só fazer passar
3. Pode ter código "feio" - será refatorado depois

### REFACTOR (Melhorar)
1. Agora com testes passando, código pode ser melhorado
2. Sem mudar comportamento, apenas qualidade
3. Testes continuam passando

## Processo

```
1.Receber task → /scope-guard
2.Identificar o que testar → /pre-flight (se banco)
3.Escrever teste (RED) → test fail
4.Implementar código mínimo (GREEN) → test pass
5.Refatorar (REFACTOR) → tests still pass
6./quality-gate → commit
```

## Regras

- **1 tarefa = 1 teste** ou conjunto de testes relacionados
- **Nomes descritivos**: test_can_do_action, not test1
- **Arrange-Act-Assert** claro
- **Um assertion por teste** quando possível
- **Isolar** dependências externas (mocks)

---

> **Débito que previne**: D8 (TDD declarado mas não praticado)