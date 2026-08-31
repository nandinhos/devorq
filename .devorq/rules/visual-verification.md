# Verificação Visual — DEVORQ v4.1.0

## Conceito

A **verificação visual** é um gate obrigatório que executa APÓS `devorq build` (gates 1-7) e ANTES do commit manual. O objetivo é garantir que a feature funciona não só no nível de API (`200 OK`) mas também na interface real do usuário.

---

## Fluxo

```
devorq auto
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Implementação (devorq flow)                            │
│  → developer implementa story manualmente              │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  devorq build (gates 1-7)                               │
│  → verifica estrutura, código, testes                   │
│  → retorna 0 se todos gates passam                      │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  devorq verify                                          │
│  → Playwright E2E (preferencial)                        │
│  → ou manual (fallback)                                 │
│  → retorna 0 se verificação passa                        │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  devorq commit --story <id>                            │
│  → commit manual com convenção                          │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  devorq auto --continue                                 │
│  → mark_pass + próxima story                            │
└─────────────────────────────────────────────────────────┘
```

---

## Métodos de Verificação

### Playwright (Preferencial)

O Playwright executa testes E2E que simulam o usuário real:

1. **Verifica tela abre** (HTTP 200 + DOM renderizado)
2. **Verifica dados exibidos** (conteúdo real na página)
3. **Verifica não há erros no console** (erros JS, exceções)
4. **Verifica interações funcionam** (cliques, formulários, navegação)

**Configuração em cada projeto:**
```bash
# Criar diretório de testes
mkdir -p playwright_tests

# Instalar Playwright
npm init -y
npm install @playwright/test
npx playwright install chromium

# Configurar playwright.config.js
```

**Exemplo de teste:**
```js
// playwright_tests/example.spec.js
const { test, expect } = require('@playwright/test');

test('feature X opens correctly', async ({ page }) => {
  await page.goto('/feature-x');
  await expect(page.locator('h1')).toContainText('Feature X');
  // Verificar elementos específicos da feature
});
```

### Manual (Fallback)

Quando Playwright não está configurado:

1. O developer abre a aplicação no browser
2. Navega até a tela da feature
3. Verifica manualmente os 4 pontos:
   - A tela abre sem erros
   - Os dados são exibidos corretamente
   - Não há erros no console do browser
   - A funcionalidade está operacional
4. Confirma com `Y` no prompt

---

## Trigger Automático de Debug

Quando `devorq verify` falha (Playwright ou manual):

1. **Systematic-debugging entra em ação automaticamente**
2. Executa as 4 fases (ver `scripts/debug-systematic.sh`)
3. Identifica root cause
4. Valida contra Context7 (documentação oficial)
5. Aplica correção
6. Cria teste de regressão
7. Captura lição aprendida
8. Atualiza SPEC.md

### Fluxo de Debug Automático

```
Teste falha (vermelho)
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 0: Classify Failure Mode                         │
│  CAT A: E2E cascade (página de erro cobre tudo)          │
│  CAT B: App bug (teste correto, código errado)          │
│  CAT C: Test stale (UI mudou, teste não atualizou)      │
│  CAT D: Infra issue (auth, storage, network)           │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 1: Root Cause Investigation                      │
│  → Ler erros do Playwright / logs                       │
│  → Reproduzir o erro                                   │
│  → Verificar changes recentes                          │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 2: Pattern Analysis                              │
│  → Encontrar exemplos similares                        │
│  → Consultar systematic-debugging skill                │
│  → Identificar diferenças                              │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 3: Context7 Validation                           │
│  → Consultar documentação oficial                       │
│  → Validar hipótese contra docs                        │
│  → NUNCA aplicar correção sem validação                │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  PHASE 4: Implementation                                │
│  → Criar teste de regressão (RED)                      │
│  → Implementar correção (root cause)                   │
│  → Verificar todos os testes passam (GREEN)           │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  CAPTURA LIÇÃO                                          │
│  → devorq lessons capture                              │
│  → approved: true                                       │
│  → Compilar skill se necessário                        │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  ATUALIZAR SPEC.md                                      │
│  → Documentar root cause e solução                      │
│  → Marcar como resolved com data                       │
└────────────┬────────────────────────────────────────────┘
             ▼
┌─────────────────────────────────────────────────────────┐
│  RE-VERIFICAR                                           │
│  → devorq verify                                       │
│  → Se 100% verde → devorq commit                       │
│  → Se falhar → voltar para PHASE 1                     │
└─────────────────────────────────────────────────────────┘
```

---

## Regra de Ouro

> **NÃO HÁ COMMIT ATÉ QUE A SUITE ESTEJA 100% VERDE.**

O developer NÃO commita com teste vermelho. O systematic-debugging resolve ANTES do commit.

---

## Comandos

### `devorq verify`

Executa verificação visual.

```bash
devorq verify                    # Auto (Playwright ou manual)
devorq verify --playwright       # Força Playwright
devorq verify --manual           # Modo manual
devorq verify --story feat-001  # Story específica
```

### `devorq commit`

Executa commit manual com convenção.

```bash
devorq commit --story feat-001   # Interativo com story
devorq commit --scope models --phase fix  # Forçar scope/phase
devorq commit --push              # Commit + push
```

### `devorq auto --continue`

Continua da última story (após commit manual).

---

## Logs

Logs de debug sistemático salvos em:
```
.devorq/state/logs/debug-trigger.log
```

---

*Documento criado em 2026-05-21 — DEVORQ v4.1.0*