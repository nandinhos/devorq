---
id: SPEC-0065-16-04-2026-code-review-tech-debt
title: Code Review DEVORQ — Correção de Débitos Técnicos e CI/CD
domain: qualidade
status: draft
priority: high
author: Nando Dev
owner: team-core
created_at: 2026-04-16
updated_at: 2026-04-16
source: code-review-2026-04-16
related_tasks: []
related_files:
  - .github/workflows/quality-gate.yml
  - tests/e2e.bats
  - docs/specs/draft/SPEC-0064-15-04-2026-teste-template-canonico-sprint4.md
  - .claude/commands/
  - .opencode/commands/
  - conductor/plan-fix-cli-bugs.md
---

# SPEC-0065: Code Review DEVORQ — Correção de Débitos Técnicos e CI/CD

## Contexto

Análise técnica profunda do repositório DEVORQ identificou 11 itens de dívida técnica,
sendo 2 críticos (CI/CD quebrado + testes falhando). Este documento consolida todas as
correções necessárias em um plano acionável.

---

## Problemas Identificados

### 🔴 CRÍTICO 1: GitHub Actions — Job Detect Sem Outputs

**Localização:** `.github/workflows/quality-gate.yml:29-101`

**Problema:** O job `detect` não define `outputs`, mas os jobs `quality-laravel`,
`quality-python` e `quality-generic` dependem de `needs.detect.outputs.stack`.
Resultado: esses jobs **nunca executam** — o `if` sempre falha porque `outputs.stack` está vazio.

**Impacto:** Quality gates para Laravel, Python e projetos específicos não funcionam.
Emails de falha de ciclo são recebidos apenas pelos testes bats quebrados.

**Solução:**

```yaml
detect:
  runs-on: ubuntu-latest
  outputs:
    stack: ${{ steps.detect.outputs.stack }}
  steps:
    - uses: actions/checkout@v5
    - name: Detect Stack
      id: detect
      run: |
        if [ -f "composer.json" ] && grep -q "laravel" composer.json; then
          echo "stack=laravel" >> $GITHUB_OUTPUT
        elif [ -f "package.json" ]; then
          echo "stack=node" >> $GITHUB_OUTPUT
        elif [ -f "requirements.txt" ]; then
          echo "stack=python" >> $GITHUB_OUTPUT
        else
          echo "stack=generic" >> $GITHUB_OUTPUT
        fi
        echo "Detected: ${{ steps.detect.outputs.stack }}"
```

---

### 🔴 CRÍTICO 2: Testes E2E Quebrados

**Localização:** `tests/e2e.bats`

**Problema:** Suite de testes E2E assume que roda em projeto novo vazio.
Testa `devorq init`, `devorq flow` no contexto do próprio repositório DEVORQ.
Todos os testes falham com `[ -d ".devorq" ]` failed.

**Impacto:** CI nunca passa. Feedback de regressão inexistente.

**Solução Opção A (Recomendada):** Criar diretório `tests/fixtures/` com projetos
temporários para teste, ou marcar esses testes como "integration" e skip no CI normal.

```bash
# Em tests/e2e.bats, usar setup/teardown com diretório temporário
setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
}

teardown() {
    rm -rf "$TEST_DIR"
}
```

**Solução Opção B:** Desabilitar testes E2E do CI temporariamente e criar task
separada para corrigir.

```yaml
- name: Bats — suite completa
  run: bats tests/ --filter-tags ~e2e  # skip e2e tests
```

---

### 🟠 ALTO 1: SPEC-0064 Invalida no Repositório

**Localização:** `docs/specs/draft/SPEC-0064-15-04-2026-teste-template-canonico-sprint4.md`

**Problema:** Spec de "teste" vazia com 29 bytes - claramente artefato de
desenvolvimento esquecido. Não deveria estar no repositório.

**Impacto:** Polui o índice de specs, viola a própria governança do framework.

**Solução:**
```bash
rm docs/specs/draft/SPEC-0064-15-04-2026-teste-template-canonico-sprint4.md
rmdir docs/specs/draft/ 2>/dev/null || true
```

---

### 🟠 ALTO 2: Comandos Duplicados — .claude e .opencode

**Localização:** `.claude/commands/` e `.opencode/commands/`

**Problema:** 20 arquivos idênticos duplicados entre `.claude/` e `.opencode/`.
Isso triplica a manutenção e causa confusão sobre qual usar.

**Impacto:** Mudanças precisam ser feitas em 2 lugares. Histórico git poluído.
Desordem cognitiva para novos contribuidores.

**Solução:**

Opção A (Recomendada - menor mudança):
```bash
# Remover .claude/commands e criar symlink
rm -rf .claude/commands
ln -s ../.opencode/commands .claude/commands
```

Opção B (mais limpo):
```bash
# Unificar em .devorq/commands/ e fazer os agentes referenciarem de lá
# Manter apenas .opencode/commands
rm -rf .claude/commands
```

---

### 🟡 MÉDIO 1: Pasta Conductor Órfã

**Localização:** `conductor/plan-fix-cli-bugs.md`

**Problema:** Plano de correção de bugs de CLI sem evidência de ter sido executado.
Arquivo órfão de uma sessão anterior.

**Impacto:** Confusão sobre o estado atual do CLI. Possível conhecimento perdido.

**Solução:**
1. Verificar se os bugs ainda existem no código
2. Se bugs existem: executar o plano e commitar a correção
3. Se bugs resolvidos: mover para `.devorq/state/lessons-learned/` e deletar
4. Se plano obsoleto: deletar diretamente

---

### 🟡 MÉDIO 2: Pastas de Spec Vazias

**Localização:** `docs/specs/brainstorming/`, `docs/specs/approved/`, `docs/specs/validated/`

**Problema:** Pastas de status sem nenhum arquivo. Hollow structure.

**Impacto:** Violação do princípio "pastas devem ter conteúdo ou não existir".

**Solução:**
```bash
rmdir docs/specs/brainstorming/ docs/specs/approved/ docs/specs/validated/ 2>/dev/null || true
```

**NOTA:** Manter `docs/specs/implemented/` e `docs/specs/` (raiz).

---

## Plano de Execução

### Sprint 1 — Crítico (Esta semana)

| # | Task | Local | Effort |
|---|------|-------|--------|
| 1.1 | Corrigir job `detect` no GitHub Actions adicionando `outputs:` | `.github/workflows/quality-gate.yml` | 5 min |
| 1.2 | Corrigir ou desabilitar testes E2E quebrados | `tests/e2e.bats` | 30 min |

### Sprint 2 — Importante (Próximas 2 semanas)

| # | Task | Local | Effort |
|---|------|-------|--------|
| 2.1 | Deletar SPEC-0064 e pasta `draft/` | `docs/specs/draft/` | 2 min |
| 2.2 | Eliminar duplicação .claude/.opencode (symlink) | `.claude/commands/` | 5 min |
| 2.3 | Avaliar e limpar pasta `conductor/` | `conductor/` | 15 min |
| 2.4 | Remover pastas de spec vazias | `docs/specs/` | 2 min |

### Sprint 3 — Melhoria (Backlog)

| # | Task | Local | Effort |
|---|------|-------|--------|
| 3.1 | Verificar se hooks do pre-commit funcionam | `.devorq/hooks/` | 30 min |
| 3.2 | Adicionar testes unitários para funções de lib | `tests/unit/` | 2h |
| 3.3 | Documentar arquitetura de Context Mode | `docs/specs/` | 1h |

---

## Critérios de Aceite

- [ ] CI GitHub Actions passa sem errors
- [ ] Job `detect` executa corretamente e populates `outputs.stack`
- [ ] Jobs `quality-laravel`, `quality-python` executam quando detectam stack correta
- [ ] Testes bats passam (ou estão marcados para skip com justificativa)
- [ ] SPEC-0064 deletada e pasta `draft/` removida
- [ ] Comandos unificados em um único diretório
- [ ] Pasta `conductor/` limpa (deletada ou movida para lessons-learned)
- [ ] Pastas `brainstorming/`, `approved/`, `validated/` removidas (se vazias)

---

## Decisões

1. **Symlink ao invés de deletar .claude**: Manter compatibilidade com agentes que
   esperam `.claude/commands/` mas apontar para `.opencode/commands/`.

2. **E2E tests desabilitados ao invés de corrigidos**: Porque corrigir требу ambiente
   temporário isolado é mais complexo que o valor entregue. Corrigir em task separada.

3. **Pastas vazias removidas ao invés de criadas**: Se uma pasta de status não tem
   specs, não deve existir. Cria-se quando primeira spec for adicionada.

---

## Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Symlink quebra em Windows | Baixa | Média | Apenas Linux/macOS suportado |
| Hooks pre-commit não funcionam | Média | Baixa | Task 3.1 do Sprint 3 |
| Bugs de CLI ainda existem | Desconhecida | Média | Avaliar conductor antes de deletar |

---

## Assumptions

- Apenas ambientes Linux/macOS são suportados
-DEVORQ não precisa rodar em Windows nativamente
- Testes E2E são nice-to-have, não blockers para CI principal

---

## Missing Information

- Não foi verificado se hooks pre-commit funcionam de fato
- Não foi testado se Context Mode está 100% operacional
- Não foi auditado se CLI commands de `spec` funcionam corretamente

---

## Recommendations

1. **Criar task separada** para corrigir testes E2E com fixtures adequados
2. **Adicionar CI step** que verifica se todas as pastas de spec têm pelo menos 1 arquivo
3. **Documentar arquitetura de Context Mode** em SPEC separada
4. **Considerar migrar** todos os arquivos de governance para `.devorq/state/`
   mantendo apenas `docs/specs/implemented/` versionado

---

## Histórico de Alterações

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-04-16 | Nando Dev | Criação desta spec |

---

## Status de Implementação

| Task | Status | Observação |
|------|--------|------------|
| 1.1 | pendente | - |
| 1.2 | pendente | - |
| 2.1 | pendente | - |
| 2.2 | pendente | - |
| 2.3 | pendente | - |
| 2.4 | pendente | - |
| 3.1 | pendente | - |
| 3.2 | pendente | - |
| 3.3 | pendente | - |
