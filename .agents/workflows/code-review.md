---
description: Execute code-review DEVORQ command
---

Executar code review para: $ARGUMENTS

Leia `.devorq/skills/code-review/SKILL.md` para instruções completas.

## Dimensões da Revisão

### 1. Correção
- O código faz o que deveria fazer?
- Trata todos os edge cases?
- Validação de input presente?

### 2. Clareza
- Nomes de variáveis/funções descritivos?
- Lógica complexa tem comentário explicativo?
- Funções com responsabilidade única (SRP)?

### 3. Performance
- Queries N+1?
- Eager loading onde necessário?
- Índices de banco considerados?

### 4. Segurança
- Input sanitizado?
- SQL injection prevenido (ORM/bindings)?
- Sem secrets no código?
- Autorização (policies/gates) presente?

### 5. Arquitetura
- Lógica no lugar certo (Actions/Services, não controllers)?
- Sem lógica de negócio no frontend/blade?
- Dependências mínimas e coesas?

### 6. Testabilidade
- Código é testável sem mocks excessivos?
- Dependências injetáveis?

## Formato do Relatório

```markdown
## Code Review — [arquivo/PR]

### Críticos (bloqueiam merge)
- [arquivo:linha] — [problema] — [sugestão]

### Melhorias (recomendados)
- [arquivo:linha] — [observação]

### Positivos
- [o que está bem feito]

### Veredito: APROVADO / APROVADO COM RESSALVAS / REJEITADO
```
