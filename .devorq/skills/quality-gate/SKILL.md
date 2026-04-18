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
  - "**/*.sh"
depends_on:
  - systematic-debugging
  - code-review
---

# /quality-gate - Verificação Pré-Commit

> **Regra de Ouro**: Se não passou no quality gate, não faz commit

## Quando Usar

**OBRIGATÓRIO** após qualquer implementação, ANTES de commit

## Pré-requisito — Code Review

Se as mudanças incluem:
- Novas funções ou módulos
- Alteração de arquitetura ou fluxo
- Mudanças em mais de 3 arquivos

→ Executar `/code-review` antes deste checklist.
→ Registrar resultado (Aprovado | Pendências resolvidas) antes de prosseguir.

Para mudanças mínimas (typo, comentário, config de 1 linha): pode pular.

## Checklist

```
## QUALITY GATE

### 1. Testes
- [ ] Todos passando
- [ ] Novos testes adicionados
- [ ] Sem regressão

> **Se testes falham**: Invocar `/systematic-debugging` ANTES de tentar corrigir.
> Nunca corrigir um teste falhando sem identificar a causa raiz.

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

### 8. Bash (Dual-use Scripts)
- [ ] Scripts Bash que funcionam como biblioteca e executável contêm o guard `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` antes da lógica de execução.
- [ ] `set -eEo pipefail` está dentro de `main()`, nunca no nível global — evita alterar o shell que faz `source` (ex: bats, outros scripts)
- [ ] Source guard usa forma `if/fi`, não `[[ cond ]] && cmd` — forma `if` não propaga exit code da condição falsa em contexto de `set -e`
  ```bash
  # Correto para scripts dual-use:
  main() {
      set -eEo pipefail
      ...
  }
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
  ```

### 9. Validação Manual da Feature
- [ ] Instruções de teste manual apresentadas ao usuário
- [ ] Resposta recebida: OK | BUG: <desc> | N/A

### 10. Preview do Commit
- [ ] Mensagem de commit apresentada (sem executar)
- [ ] Lista de arquivos staged apresentada
- [ ] Diff resumido apresentado
- [ ] Aprovação literal recebida: A | Aprovado | E: <nova msg> | R
```

## Gate 3 v2 — Validação Manual e Preview de Commit

### Etapa 9 — Validação Manual da Feature

```
[GATE 3 — Etapa 9: Validação Manual da Feature]

Para validar manualmente:
- URL: <se aplicável>
- Comandos: <comandos de teste>
- Fluxo esperado: <passo a passo>
- Resultado esperado: <o que deve acontecer>

Aguardando resposta:
  OK              → feature funcionou, prosseguir para Etapa 10
  BUG: <desc>     → feature quebrou, voltar a corrigir
  N/A             → mudança sem feature visível (refactor/fix CI/etc)
```

**Regras**:
- `OK` → prossegue para Etapa 10
- `BUG: <desc>` → volta a corrigir, não pode commitar
- `N/A` → apenas para mudanças sem feature visível (refactor interno, fix de CI)
- Sem `OK` ou `N/A`, o gate não avança

### Etapa 10 — Preview do Commit

```
[GATE 3 — Etapa 10: Preview do Commit]

Mensagem proposta:
─────────────────────────────────────────
<prefixo> (<escopo>): <descrição em pt-BR, ≤72 chars>

<corpo opcional>
─────────────────────────────────────────

Arquivos staged:
  M bin/devorq
  M lib/foo.sh

Diff resumido:
  +12 -3 linhas em 2 arquivos

Aguardando resposta:
  A                       → executar git commit
  E: <nova mensagem>      → substituir mensagem e reapresentar
  R                       → cancelar commit
```

**Regras**:
- Apenas `A` ou `Aprovado` (case-insensitive) significa aprovação
- `E: <nova mensagem>` substitui e re-apresenta
- `R` cancela o fluxo, nada é commitado
- Após `A`/`Aprovado`: executar `git commit` e depois `git push` (se aplicável)
- Aprovação para `git push` é separada, exceto se usuário disser "aprovado e push"

## Resultado
- **APROVADO**: Pode fazer commit (após OK/N/A Etapa 9 + A/Aprovado Etapa 10)
- **REJEITADO**: Corrigir antes de commit

---

> **Débito que previne**: D13 (Ausência de gates automáticos)