# DEVORQ — Commit Manual + Verificação Visual + Debug Sistemático

**Versão:** 1.0.2
**Data:** 2026-05-21
**Autor:** Fernando Dos Santos (Nando)
**Versão DEVORQ:** 3.7.0
**Status:** IMPLEMENTADO v3.7.0 — refactoring modular completo

---

## Resumo das Validações (2026-05-21)

| # | Pergunta | Resposta |
|---|----------|----------|
| 1 | Escopo das mudanças | **Global** — DEVORQ core em `~/projects/devorq_v3/`, afeta **todos os projetos** |
| 2 | Playwright em todos os projetos? | **SIM** — todos os projetos novos terão Playwright configurado |
| 3 | Formato de commit | **tipo(escopo): descrição (detalhamento)** — Conventional Commits, sem emojis, sem co-autoria, pt-BR |

---

## 1. Resumo Executivo

O DEVORQ AUTO mode atual realiza commit automático após cada story verificada (apenas via `devorq build`). Isso é insuficiente para projetos que exigem **verificação visual real** (não só `200 OK`). Este documento especifica:

1. Remoção do commit automático do AUTO mode
2. Gate de verificação visual obrigatório (Playwright)
3. **Trigger automático do systematic-debugging quando teste falha (vermelho)**
4. Commit manual seguindo convenção `tipo(escopo): descrição (detalhamento)`
5. Integração com Context7 para validação técnica
6. Captura de lições aprendidas para a SPEC do projeto
7. Entrega no nível **Senior Engineer / Profissional Sênior**

---

## 2. Diagnóstico — Problema Atual

### 2.1 Fluxo Atual (PROBLEMÁTICO)

```
delegate_task story → implementa → devorq build (200 OK)
→ devorq::auto::git_commit("feat(story_id): story_title") ← AUTOMÁTICO
→ mark_pass
```

**Problemas identificados:**

| # | Problema | Consequência |
|---|----------|--------------|
| 1 | Commit automático sem validação visual | Erros silenciosos passam (500 internal, logs não inspecionados) |
| 2 | `devorq build` não verifica tela | API retorna 200 mas front pode estar quebrado |
| 3 | Múltiplos commits durante tarefa | Código fica quebrado entre commits, histórico poluído |
| 4 | Formato de commit não segue convenção | `feat(story_id): story_title` não tem scope nem detail |
| 5 | Sem processo de debug quando falha | Falha visual não gera lição documentada |

### 2.2 O que funciona hoje

- ✅ Story tracking via `prd.json`
- ✅ `devorq build` executa gates 1-7
- ✅ `devorq auto` marca story como done após verificação
- ✅ `devorq lessons` captura e aprova lições
- ✅ `systematic-debugging` skill existe e é robusto

---

## 3. Decisões de Design

### 3.1 Remoção do Commit Automático

**ANTES:**
```bash
# lib/auto.sh:319
devorq::auto::git_commit "$project" "$story_id" "$story_title"
```

**DEPOIS:**
```bash
# Remove linha 319 — commit manual após verificação visual
# Substituir por hint interativo:
devorq::auto::suggest_commit "$project" "$story_id" "$story_title"
```

O commit automático é **removido completamente**. O developer decide quando commitar.

### 3.2 Gate de Verificação Visual

**ANTES:**
```
verify() → devorq build (apenas gates) → commit
```

**DEPOIS:**
```
verify() → devorq build (gates)
        → VERIFICAÇÃO VISUAL (Playwright ou manual)
        → COMMITTED ✓ ou DEBUG FLUXO
```

Verificação visual é **obrigatória** antes do commit. Não é opcional.

### 3.3 Convenção de Commit

**Novo formato:**
```
tipo(escopo): descrição (detalhamento)
```

| Elemento | Significado | Exemplo |
|----------|-------------|---------|
| `escopo` | Domínio afetado (core, bdd, gates, etc.) | `core`, `models`, `services`, `livewire` |
| `fase` | Fase DEVORQ (impl, test, docs, unify) | `impl`, `test`, `unify`, `debug` |
| `descrição` | Verbo no imperative + o que foi feito | `adiciona validação BDD Given/When/Then` |
| `(detalhamento)` | Contexto técnico ou decisão | `(migra spec.sh para lib/)` |

**Exemplos:**
```
feat(bdd): adiciona validação BDD Given/When/Then (lib/spec.sh migrado)
fix(livewire): corrige Alpine duplicado em x-data (remove CDN inline)
refactor(core): extrai devorq::auto::verify para lib/visual.sh
docs(gates): documenta GATE-6 manual verification gate
chore(tests): adiciona Playwright para verificação visual
```

**Regras:**
- Sem emojis
- Sem Co-Authored-By
- Em português do Brasil
- Scope deve ser um dos escopos válidos
- Fase deve ser uma das fases válidas

### 3.4 Escopos e Fases Válidos

**Escopos:**
```
core | models | services | livewire | notifications | routes | config |
database | migrations | tests | bdd | gates | unify | docs | debug |
spec | lessons | compact | vps | hub | context
```

**Fases:**
```
impl | test | verify | docs | unify | debug | fix | refactor
```

---

## 4. Novo Fluxo — AUTO Mode com Verificação Visual

### 4.1 Diagrama de Fluxo

```
┌─────────────────────────────────────────────────────────┐
│  devorq auto [N]                                         │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  GATE-0: Environment detect                             │
│  (devorq env, stack detected)                           │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  Para cada story no prd.json                            │
│  (pending)                                              │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  STORY: devorq flow <story_id>                          │
│  → implementa manualmente                              │
│  → devorq build (gates 1-7)                             │
│  → devorq verify (Playwright ou manual)                 │
│     ├─ SUCESSO → registrar commit hint                  │
│     └─ FALHA  → systematic-debugging → lessons → SPEC   │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  COMMIT MANUAL (obrigatório)                             │
│  devorq commit --story <id>                             │
│  → formata commit com convenção                          │
│  → git add -A + git commit -m "..."                    │
│  → git push (se remote configurado)                     │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  mark_pass (story marcada como done)                    │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Interações do Fluxo

| Etapa | Automático? | Interação | Responsável |
|-------|-------------|-----------|-------------|
| GATE-0 env detect | ✅ | Nenhuma | Sistema |
| Story implementation | ❌ | Manual | Developer |
| devorq build | ✅ | Nenhuma | Sistema |
| Verificação visual | ❌ | **Obrigatória** | Developer |
| Commit | ❌ | **Obrigatório** | Developer |
| mark_pass | ✅ | Nenhuma | Sistema |

---

## 5. Fluxo de Debug Sistemático — Trigger Automático

### 5.0 Princípio Fundamental

> **Quando qualquer teste (Playwright E2E, Unit, Feature) retorna VERMELHO, o systematic-debugging entra EM AÇÃO AUTOMATICAMENTE e resolve o problema com validação via Context7, entregando feature no nível Senior Engineer.**

### 5.1 Trigger Automático

O fluxo de debug sistemático é **automático** — não é opcional, não é manual:

```
Playwright E2E falha (vermelho)
    │
    ├──→ devorq::debug::auto_run()
    │       │
    │       ▼
    │    ┌─────────────────────────────────────────────────┐
    │    │  SYSTEMATIC DEBUGGING TRIGGERED                 │
    │    │  "Teste falhou — debug sistemático iniciando"   │
    │    └─────────────────────────────────────────────────┘
    │
    ▼
PHASE 1: Root Cause Investigation (automático)
    → Ler erros do Playwright / logs do browser
    → Identificar padrão (CAT A/B/C/D)
    → Classificar: E2E cascade | app bug | test stale | infra
    → Se CAT A (cascade) → identificar root page
    │
    ▼
PHASE 2: Pattern Analysis (automático)
    → Encontrar exemplos similares no código
    → Comparar com systematic-debugging skill (Hermes)
    → Identificar diferenças
    → Se Alpine/Livewire → verificar x-data, CDN, script order
    │
    ▼
PHASE 3: Context7 Validation (automático)
    → Consultar documentação oficial do stack
    → mcp_context7_resolve_library_id(libraryName="laravel")
    → mcp_context7_query_docs(libraryId, query=problema)
    → Validar hipótese contra docs oficiais
    → NUNCA aplicar correção sem validar contra docs
    │
    ▼
PHASE 4: Implementation (automático)
    → Criar teste de regressão (RED)
    → Implementar correção (ROOT CAUSE, não sintoma)
    → Verificar: todos os testes passam (GREEN)
    → Refatorar se necessário (REFACTOR)
    │
    ▼
CAPTURA LIÇÃO (automático após resolução)
    → devorq lessons capture
    → Título: tech + problema + solução
    → Tags: stack (laravel, livewire, playwright, etc)
    → Solução documentada com root cause
    → approved: true
    │
    ▼
ATUALIZAR SPEC.md (automático)
    → Adicionar "known issue" se não resolvido
    → Documentar decisão técnica
    → Marcar como "resolved" com data
    │
    ▼
RE-VERIFICAR (automático)
    → Executar suite completa (Playwright E2E + tests)
    → Se 100% verde →阜commit manual
    → Se ainda vermelho → voltar para PHASE 1

```

### 5.2 Trigger Points (QUANDO ativa)

| Contexto | Trigger | Ferramenta |
|----------|---------|------------|
| Playwright E2E | `npx playwright test` retorna falha | Playwright + Hermes Agent |
| PHPUnit/Pest Unit | `php artisan test` retorna failure | Artisan + Hermes Agent |
| Playwright retorna vermelho | `page.evaluate()` ou `expect()` falha | Playwright + systematic-debugging |
| `devorq build` falha em gate | qualquer gate vermelho | `devorq build` + systematic-debugging |
| `devorq verify --playwright` falha | exit code != 0 | `devorq verify` + systematic-debugging |

### 5.3 O Que O Fluxo Entrega (Nível Senior Engineer)

Quando systematic-debugging completa o fluxo, o resultado é:

| Aspecto | O que acontece |
|---------|----------------|
| **Root cause** | Identificado com precisão (não sintoma) |
| **Fix** | Aplicado com validação Context7 (docs oficiais) |
| **Test** | Criado para prevenir regressão |
| **Lição** | Capturada e aprovada (skill gerada) |
| **SPEC** | Atualizada com decisão técnica |
| **Verificação** | Suite completa passa (100% verde) |

### 5.5 Integração com Skill Systematic-Debugging

O fluxo segue exatamente o `systematic-debugging` skill do Hermes:
- **Phase 0**: Classify failure mode (CAT A/B/C/D)
- **Phase 1**: Root cause investigation
- **Phase 2**: Pattern analysis
- **Phase 3**: Hypothesis and testing
- **Phase 4**: Implementation

A **captura de lição** acontece após Phase 4 (implementação), para documentar o aprendizado.

---

## 6. Especificação de Comandos

### 6.1 `devorq verify`

**Antes:** Não existia. `devorq build` fazia verificação.

**Depois:**
```bash
devorq verify [--playwright|--manual] [--story <id>]
```

| Flag | Comportamento |
|------|---------------|
| `--playwright` | Executa suite E2E do projeto |
| `--manual` | Aguarda input do developer confirmar que tela abriu |
| `--story <id>` | Verifica apenas a story específica |
| (nenhum) | Usa o método padrão do projeto |

**Comportamento:**
1. Executa `devorq build` primeiro (gates 1-7)
2. Se gates passam → executa verificação visual
3. Se verificação passa → retorna `0` com hint de commit
4. Se verificação falha → retorna `1` e mostra instruções de debug

### 6.2 `devorq commit`

**Novo comando (não existia antes):**
```bash
devorq commit [--story <id>] [--scope <scope>] [--type <tipo>] [--message <msg>]
```

| Flag | Comportamento |
|------|---------------|
| `--story <id>` | Usa título e description da story do prd.json |
| `--scope <scope>` | Sobrescreve escopo (default: detecta do path) |
| `--type <tipo>` | Tipo convencional: feat/fix/refactor/docs/test/style/perf/chore (default: `feat`) |
| `--phase <phase>` | Deprecado — alias de `--type` (emite aviso) |
| `--message <msg>` | Mensagem customizada (sem convenção) |
| (nenhum) | Abre prompt interativo |

**Formato gerado:**
```
<scope>(<phase>): <description> (<detail>)
```

**Exemplo interativo:**
```
devorq commit --story feat-001

Story: feat-001 — Adicionar validação BDD
Scope: [bdd] > 
Phase: [impl] > 
Description: [adiciona validação BDD Given/When/Then]
Detail: (lib/spec.sh migrado para bdd/) > 

Preview:
  feat(bdd): adiciona validação BDD Given/When/Then (lib/spec.sh migrado para bdd/)

Confirmar? [Y/n]: Y
```

### 6.3 `devorq auto` — Alterado

**Comportamento novo:**
1. Executa `devorq flow <story_id>` (implementação manual)
2. Executa `devorq build` (gates 1-7)
3. **Pausa** para verificação visual (`devorq verify`)
4. Se verificar → mostra hint de commit (não commita automaticamente)
5. Developer executa `devorq commit` manualmente
6. `devorq auto --continue` marca como done após commit

**Opções:**
```
devorq auto [N]              # Executa N stories (pausa em cada uma)
devorq auto --all            # Todas as pendentes
devorq auto --continue       # Continua da última story (pula implementation, faz verify + commit)
devorq auto --skip-verify    # DEBUG ONLY — pula verificação visual
```

### 6.4 `devorq build` — Alterado

**Comportamento novo:**
- Não faz mais `git commit` dentro do build
- Não faz mais `devorq::auto::git_commit()`
- Apenas executa teste + gates 1-7
- Retorna 0 se todos passarem

---

## 7. Estrutura de Arquivos a Alterar

### 7.1 Arquivos Modificados

| Arquivo | Alteração |
|---------|-----------|
| `lib/auto.sh` | Remove `devorq::auto::git_commit()` das linhas 319 e 400 |
| `bin/devorq` | Remove chamada de commit em `devorq::cmd_build` e `devorq::cmd_auto` |
| `rules/commit-convention.md` | Atualiza formato para `tipo(escopo): descrição (detalhamento)` |
| `CHANGELOG.md` | Entrada v3.6.5 com todas as mudanças |

### 7.2 Arquivos Criados

| Arquivo | Conteúdo |
|---------|----------|
| `lib/visual.sh` | `devorq::verify()` com suporte Playwright + manual |
| `lib/commit.sh` | `devorq::cmd_commit()` interativo com convenção |
| `rules/visual-verification.md` | Documentação do gate de verificação visual |
| `rules/debug-systematic.md` | Referência ao fluxo de debug sistemático |
| `scripts/commit-hint.sh` | Gera hint de commit baseado na story |

### 7.3 Arquivos Removidos

| Arquivo | Razão |
|---------|-------|
| (nenhum) | Não remove arquivos, apenas altera comportamento |

---

## 8. Escopo de Alteração: Global vs Projeto

**Decision:** Alterações no **DEVORQ core global** (`~/projects/devorq_v3/`), não apenas no projeto clickup/clickup.

**Rationale:**
- O problema de commits automáticos afeta todos os projetos
- O fluxo de debug sistemático é aplicável a qualquer stack
- A convenção de commit é útil em todos os projetos DEVORQ
- Funcionalidade nova (`devorq verify`, `devorq commit`) enriquece o framework

**Após implementar no core:**
1. Push para origin/main
2. Tag v3.6.5
3. Release notes
4. Validar em projeto piloto (clickup/clickup)

---

## 9. Validação

### 9.1 Critérios de Sucesso

| # | Critério | Como Verificar |
|---|----------|---------------|
| 1 | `devorq auto` não faz commit automático | Executar `devorq auto` e verificar que não houve `git commit` |
| 2 | `devorq verify --manual` pausa e espera confirmação | Executar e observar que espera Enter |
| 3 | `devorq commit` gera mensagem no formato correto | `devorq commit --story feat-001` e verificar formato |
| 4 | `devorq build` retorna 0 sem fazer commit | Executar `devorq build` e verificar que não houve commit |
| 5 | Fluxo de debug sistemático integrado | Simular falha e verificar que instruções de debug aparecem |
| 6 | 16 projetos testados continuam funcionando | `devorq test` em todos os projetos retorna OK |

### 9.2 Plano de Teste

```
1. Clonar/criar projeto de teste com prd.json
2. Executar devorq auto --story feat-XYZ
3. Implementar mudança simples
4. Executar devorq build → verificar gates
5. Executar devorq verify --manual → confirmar que pausa
6. Executar devorq commit → verificar formato
7. Verificar que git log mostra commit correto
8. Executar devorq auto --continue → verificar mark_pass
```

---

## 10. Dados de Suporte

### 10.1 Contexto atual do clickup/clickup

- **Stack:** Laravel 12 + Livewire 4 + Flux Pro v2.14 + Sail
- **Container:** clickup_app (Docker)
- **Estrutura:** `.devorq/` existe com lições migradas do `.aidev/`
- **Playwright:** NÃO configurado ainda (localização `/home/nandodev/projects/clickup/clickup/playwright_tests/` não existe)
- **SPEC:** `docs/SPEC.md` existente

### 10.2 Skill systematic-debugging

Localização: `~/.hermes/skills/software-development/systematic-debugging/SKILL.md`

Contém:
- Phase 0: Classify failure mode (CAT A/B/C/D)
- Phase 1: Root cause investigation
- Phase 2: Pattern analysis
- Phase 3: Hypothesis + testing
- Phase 4: Implementation

### 10.3 Fluxo lessons atual

- `devorq lessons capture` → `.devorq/state/lessons/captured/*.json`
- `devorq lessons approve` → marca como approved
- `devorq lessons compile` → gera skill em `skills/<name>/`
- `devorq lessons auto-commit` → commit + push (requer confirmação)

---

## 11. Cronograma de Implementação

| Fase | Ação | Prioridade |
|------|------|------------|
| **SPEC** | Criar SPEC.md (este documento) | ✅ |
| **1** | Atualizar `rules/commit-convention.md` com novo formato | Alta |
| **2** | Criar `lib/visual.sh` com `devorq::verify()` | Alta |
| **3** | Criar `lib/commit.sh` com `devorq::cmd_commit()` | Alta |
| **4** | Modificar `lib/auto.sh` — remover git_commit() calls | Alta |
| **5** | Modificar `bin/devorq` — adicionar comando `verify` e `commit` | Alta |
| **6** | Criar `rules/visual-verification.md` | Média |
| **7** | Criar `scripts/commit-hint.sh` | Média |
| **8** | Update `rules/debug-systematic.md` | Baixa |
| **9** | Testar em projeto piloto (clickup/clickup) | Alta |
| **10** | Git commit + push + tag v3.6.5 | Alta |

---

## 12. Histórico de Implementação

| Fase | Ação | Versão | Status |
|------|------|--------|--------|
| SPEC | Criar SPEC.md (este documento) | — | ✅ Validado |
| 1 | Atualizar `rules/commit-convention.md` com novo formato | 3.6.5 | ✅ Entregue |
| 2 | Criar `lib/visual.sh` com `devorq::verify()` | 3.6.5 | ✅ Entregue |
| 3 | Criar `lib/commit.sh` com `devorq::cmd_commit()` | 3.6.5 | ✅ Entregue |
| 4 | Modificar `lib/auto.sh` — remover git_commit() calls | 3.6.5 | ✅ Entregue |
| 5 | Modificar `bin/devorq` — adicionar comando `verify` e `commit` | 3.6.5 | ✅ Entregue |
| 6 | Criar `rules/visual-verification.md` | 3.6.5 | ✅ Entregue |
| 7 | Criar `scripts/commit-hint.sh` | 3.6.5 | ✅ Entregue |
| 8 | Criar `scripts/debug-systematic.sh` | 3.6.5 | ✅ Entregue |
| 9 | Sistema de regras enforced (`lib/rules.sh`) | 3.6.6 | ✅ Entregue |
| 10 | `devorq brainstorm` + brainstorm.sh | 3.6.6 | ✅ Entregue |
| 11 | `devorq grill` + grill.sh | 3.6.6 | ✅ Entregue |
| 12 | Shellcheck 0 errors (`validate-rules.sh`, `e2e-test.sh`) | 3.6.7 | ✅ Entregue |

---

## 13. Referências de Implementação

| Feature | Arquivo | Comando |
|---------|---------|---------|
| Verificação visual | `lib/visual.sh` | `devorq verify` |
| Commit manual | `lib/commit.sh` | `devorq commit --story <id>` |
| Debug sistemático | `scripts/debug-systematic.sh` | (trigger automático em failure) |
| Sistema de regras | `lib/rules.sh` | `devorq rules list` |
| Brainstorm | `lib/commands/brainstorm.sh` | `devorq brainstorm <topic>` |
| Grill | `lib/commands/grill.sh` | `devorq grill <topic>` |

---

*Documento gerado em 2026-05-21 — atualizado 2026-05-21 com status IMPLEMENTADO*