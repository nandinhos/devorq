# Story 1 - E2E Revival - Deliverable

> **Story:** 1 do sprint v3.8.5 dogfooding
> **Data:** 2026-06-04
> **Sessão:** mvs_88735aa5b1b44a27b8b774734d23738e
> **Branch:** main (HEAD: `b39472e`)

---

## 1. Summary

A suite E2E em `e2e-tests/` (Playwright + bash) estava estagnada desde 2026-05-12 (v3.6.0, 35% reportado) e nunca foi re-rodada. A Story 1 reviveu a suite, instalou as dependências, criou baseline CI com `FASE 5.6` em `scripts/ci-test.sh`, `GATE-E2E` em `lib/gates.sh` e workflow `.github/workflows/e2e.yml`. **Resultado: 77/77 (100%) no estado pré-refactor, 68/77 (88.3%) durante o refactor story-003 em curso** — acima da meta de 80%.

---

## 2. % Final

| Cenário | Passou | Total | % |
|---------|--------|-------|---|
| **Baseline pré-refactor story-003** (2026-06-04 22:24) | 77 | 77 | **100%** |
| **Estado atual com regressão story-003** (2026-06-04 22:52) | 68 | 77 | **88.3%** |
| Meta acceptance criteria | — | — | >=80% |
| **Status** | — | — | **ATINGIDA** |

**As 9 falhas restantes são todas da mesma causa raiz:** o refactor de `lib/lessons.sh` em `lib/lessons/{crud,search,sync}.sh` (peer session `mvs_58c21b6fd9534f54bb76c5f3d5e03f53`, story-003) deixou `devorq::sanitize_input` sem definição, quebrando 9 testes que dependem de `lessons::capture`. `lib/lessons*` é `files_prohibited` para story-001, então a regressão foi documentada mas não corrigida nesta story.

---

## 3. Lista de Fixes (categoria infra/ambiente)

Nenhuma correção de lógica de teste foi necessária. A suite já estava alinhada com a v3.8.4 — o que faltava era execução contínua e integração na CI. Ações executadas, todas na categoria **infra**:

1. **`npm install` em `e2e-tests/`** — instalou `@playwright/test@1.52`, `@types/node@22` e `typescript@5.8` (deps nunca instaladas desde a criação).
2. **`npx playwright install chromium`** — browsers já estavam cacheados (Chromium 1217/1223); comando executado para reprodutibilidade.
3. **`FASE 5.6` em `scripts/ci-test.sh`** — wrapper que detecta `node_modules` ausente, instala deps sob demanda e roda a suite com `npx playwright test`. Não bloqueante no dev; reportando.
4. **`GATE-E2E` em `lib/gates.sh`** — gate informativo (não-bloqueante) que delega para a FASE 5.6. Retorna 0 sempre, mas imprime status para o `devorq verify`.
5. **Workflow `.github/workflows/e2e.yml`** — job Playwright em `ubuntu-latest`, instala deps + Chromium, roda a suite, upload de artifacts. Não bloqueia PRs (workflow separado do `ci.yml`).

---

## 4. Arquivos Modificados / Criados

| Arquivo | Tipo | LOC delta | Commit |
|---------|------|-----------|--------|
| `scripts/ci-test.sh` | modified | +60 | `f38f1d0` |
| `lib/gates.sh` | modified | +63 | `accd257` |
| `.github/workflows/e2e.yml` | created | +57 | `1986e89` |
| `e2e-tests/RESULTADOS_TESTES.md` | modified | +225 / -140 | `b39472e` |
| `e2e-tests/node_modules/` | generated | (não commitado) | — |
| `e2e-tests/package-lock.json` | generated | (não commitado — gitignored) | — |

**Fora de escopo desta story (NÃO modificados):** `bin/devorq`, `lib/lessons.sh`, `lib/lessons/*.sh`, `tests/`.

---

## 5. Lista de Commits (4 commits, escopo `test(playwright)` / `ci(playwright)`)

```
b39472e test(playwright): atualiza RESULTADOS_TESTES.md com baseline 2026-06-04
1986e89 ci(playwright): cria .github/workflows/e2e.yml (job Playwright)
accd257 test(playwright): adiciona GATE-E2E ao lib/gates.sh (nao-bloqueante)
f38f1d0 test(playwright): adiciona FASE 5.6 ao ci-test.sh (suite E2E, nao-bloqueante no dev)
```

> **Nota sobre o scope:** o hook `commit-msg` exige `^[a-z]+\([a-z]+\):$` (apenas letras), então `e2e` (com dígito) não é aceito. Usei `playwright` como fase. Isso é a interpretação técnica mais próxima do pedido da spec "escopo test(e2e)".

### Hashes completos (para verificação)

```
b39472e58db99fec4cd73f556a4f82a54f1da6f3
1986e89480bf25d7c61e7ce84437db951b8dd91f
accd257bd85219438f80b354db02ab8ddb14e454
f38f1d0bd3bf27b48ff2b264ba211cff63c191e0
```

---

## 6. Validação Local (acceptance criteria)

| Critério | Resultado |
|----------|-----------|
| `bash -n scripts/ci-test.sh` retorna 0 | OK |
| `bash -n lib/gates.sh` retorna 0 | OK |
| `bash -n bin/devorq` retorna 0 | OK (não modificado, mas revalidado) |
| `shellcheck -S error scripts/ci-test.sh` retorna 0 errors | OK |
| `shellcheck -S error lib/gates.sh` retorna 0 errors | OK |
| `npx playwright test` passa >= 80% | **OK — 88.3%** (100% pré-refactor) |
| Mensagem de commit no formato `tipo(escopo): descricao` | OK (4/4 commits) |
| Sem `Co-Authored-By` (hook bloqueia) | OK (4/4 commits) |
| Sem refatoração fora do escopo | OK (apenas files_allowed tocados) |
| Comportamento idêntico antes e depois (suite não regrediu) | PARCIAL — 100% → 88.3%, mas regressão é do peer (story-003) |

---

## 7. Acceptance Criteria da Spec — Status

- [x] Todos os testes em `e2e-tests/tests/*.ts` rodam sem erro de infra
- [x] Minimo 80% dos testes passam (88.3% > 80%)
- [x] `RESULTADOS_TESTES.md` reflete a % real pos-fix (atualizado para 2026-06-04)
- [x] `scripts/ci-test.sh` executa e2e como step (FASE 5.6 adicionada)
- [x] `devorq verify` reporta status de e2e (GATE-E2E em lib/gates.sh)

---

## 8. Notas para o Verifier

1. **Regressão story-003 (NÃO relacionada a esta story):** As 9 falhas em `lessons::capture` decorrem do refactor de `lib/lessons.sh` em curso pelo peer session `mvs_58c21b6fd9534f54bb76c5f3d5e03f53`. Quando story-003 estabilizar, a suite deve voltar a 100%. A infra E2E desta story (FASE 5.6, GATE-E2E, workflow) está correta e captura o status corretamente.

2. **Como rodar localmente:**
   ```bash
   cd /home/nandodev/projects/devorq/e2e-tests
   npm install
   npx playwright test                 # 77 testes
   # ou via CI wrapper:
   cd /home/nandodev/projects/devorq
   bash scripts/ci-test.sh             # FASE 1-5.6 (inclui E2E)
   ```

3. **Modo strict (promove E2E a bloqueante):**
   ```bash
   DEVORQ_E2E_STRICT=1 bash scripts/ci-test.sh
   ```

4. **GATE-E2E em `devorq verify`:** rodar `gate_e2e` ou `gate_8` (alias). Por design é não-bloqueante; promoção fica para v3.8.7+.

5. **Workflow CI:** `.github/workflows/e2e.yml` é separado do `ci.yml` para observabilidade. Não bloqueia PRs. Promoção a required check em v3.8.7+ (após 2-3 sprints de estabilidade).

6. **Conflito de coordenação observado:** peer story-002 (refactor `bin/devorq`) e peer story-003 (refactor `lib/lessons.sh`) estão ativos em paralelo. Esta story (story-001) tocou apenas os 4 arquivos em `files_allowed` e respeitou `files_prohibited` (`bin/devorq`, `lib/lessons*`).

---

**Origem:** Story 1 do sprint v3.8.5 dogfooding
**Mantido por:** Nando (nandinhos) + DEVORQ agent (coder / branch session)
**Workflow DEVORQ:** GATE-0 → GATE-0.5 → GATE-1 (revival) → GATE-E2E (novo)
