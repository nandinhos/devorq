---
description: Execute quality-gate DEVORQ command
---

Executar checklist de qualidade pré-commit (Quality Gate).

Leia `.devorq/skills/quality-gate/SKILL.md` para instruções completas.

**Regra de Ouro**: Se não passou no quality gate, NÃO faz commit.

## Checklist Obrigatório

Execute e marque cada item:

```
QUALITY GATE — [task]

### 1. Testes
- [ ] Todos os testes passando (sem failures, sem errors)
- [ ] Novos testes adicionados para o código novo
- [ ] Nenhuma regressão introduzida

### 2. Lint / Code Style
- [ ] Pint / ESLint / flake8 sem erros
- [ ] Formatação consistente com o projeto

### 3. Escopo (/scope-guard)
- [ ] Apenas arquivos autorizados modificados
- [ ] Nenhum item do NÃO FAZER violado

### 4. Done Criteria
- [ ] Todos os itens do contrato /spec atingidos

### 5. Segurança
- [ ] Sem secrets ou credenciais expostas
- [ ] Input validation presente onde necessário
- [ ] Sem SQL injection (usar ORM/bindings)

### 6. Performance
- [ ] Sem novo N+1 query introduzido
- [ ] Eager loading em relacionamentos usados
- [ ] Índices necessários criados nas migrations

### 7. Arquitetura
- [ ] Lógica de negócio em Actions/Services (não no controller/componente)
- [ ] Validação via Form Requests (não inline)
```

## Resultado

- **APROVADO** → pode criar commit
- **REJEITADO** → listar itens pendentes e corrigir antes de commitar

## Gate 3

Aguardar aprovação explícita do usuário antes de criar o commit.
