# CI Gating — DEVORQ

Status atual dos workflows de CI e como a E2E foi promovida a **required check**.

---

## Estado atual (v3.8.5, pós commit `569e660`)

| Workflow | Trigger | Bloqueia PR? | É required check? |
|----------|---------|--------------|-------------------|
| `ci.yml` (`CI`) | push + pull_request | ✅ via shellcheck `--severity=error` | Não configurado |
| `e2e.yml` (`E2E`) | push + pull_request + merge_group + workflow_dispatch | ✅ via exit code do Playwright (≠0 em falha) | ✅ **SIM** (`Playwright E2E`) |

**O que "bloqueia PR" significa:** o workflow roda no PR e, se falhar, o status check fica vermelho — mas só impede merge se o branch protection listar explicitamente esse check.

**O que "required check" significa:** o branch protection no GitHub Settings exige que o check passe antes do botão "Merge" ficar habilitado. Configurado para `main`.

---

## Config aplicada via API (`569e660`)

Em `2026-06-28`, configurei branch protection na `main` via GitHub REST API
(autenticado com `gh` CLI, permissão `admin: true` confirmada).

```http
PUT /repos/nandinhos/devorq/branches/main/protection
Content-Type: application/json

{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Playwright E2E"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
```

**Comandos gh CLI equivalentes:**
```bash
gh api -X PUT repos/nandinhos/devorq/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input protect.json
```

(`protect.json` no formato acima.)

**Efeito:**
- PR para `main` exige `Playwright E2E` passando.
- `strict: true` → branch do PR precisa estar up-to-date com `main` antes do merge (evita E2E em código desatualizado).
- `enforce_admins: true` → admins (você) também precisam do check passando.
- `allow_force_pushes: false` e `allow_deletions: false` → proteção contra accidents.
- **Não toquei** em `required_pull_request_reviews` (code review) nem `restrictions` (push allowed) — decisão sua.

---

## Como verificar que está ativo

```bash
gh api repos/nandinhos/devorq/branches/main | jq '.protected'
# esperado: true

gh api repos/nandinhos/devorq/branches/main/protection/required_status_checks | jq
# esperado: contexts inclui "Playwright E2E"
```

---

## Triggers suportados pelo `e2e.yml`

| Evento | Quando dispara | Por que |
|--------|----------------|---------|
| `push` (main/dev/master) | push direto na branch | validação pós-merge |
| `pull_request` (main/dev/master) | PR aberto/sincronizado | feedback pré-merge |
| `merge_group` | merge queue | suporte a merge queues |
| `workflow_dispatch` | trigger manual | debug / reprodutibilidade |

`concurrency` está configurado para cancelar runs antigos do mesmo `pull_request` quando há force-push, economizando minutos de CI.

---

## Por que NÃO mover E2E para dentro de `ci.yml`

Considerado e descartado:

| Opção | Por que não |
|-------|-------------|
| Unificar tudo em `ci.yml` | E2E é pesado (~5 min) — desacoplar permite feedback mais rápido de lint/tests |
| Job dependente no `ci.yml` (`needs: e2e`) | GitHub Actions cross-workflow `needs` é instável; melhor manter workflow próprio |

A arquitetura atual (workflows separados, ambos rodando em paralelo no PR) é a correta para DEVORQ.

---

## Próximos passos opcionais (não bloqueantes)

1. **Adicionar `CI` (workflow `ci.yml`) também como required check** — atualmente só E2E está gated. Útil se você quiser unit tests + shellcheck blocking antes de merge.
2. **Adicionar `required_pull_request_reviews`** — forçar N approvals antes do merge.
3. **Replicar para branch `dev`** se quiser a mesma proteção lá.
4. **Substituir o push direto para `main` por PR-based workflow** (mais alinhado com o branch protection agora que está ativo).

---

## Critério de saída da Fase 5

> Workflow E2E verde e bloqueante; suites de segurança/sync no CI propagando exit code; ShellCheck bloqueia merge; fonte única de gates consumida por flow e self-build com labels fiéis; construtos GNU-only encapsulados.

Checklist:
- ✅ E2E workflow verde (77/77 Playwright)
- ✅ E2E **gating** (required check ativo, `strict`, admins inclusos)
- ✅ Security tests (36 corretos, 0 falhas — `c4bafc9`)
- 🟡 Security/sync no CI (não estão em ci.yml ainda — fora do escopo desta rodada)
- ✅ ShellCheck `--severity=error` bloqueia merge em ci.yml
- ✅ Fonte única de gates via `DEVORQ_GATE_SEQUENCE` (DQ-028)
- ✅ `sed_inplace` portável GNU/BSD (DQ-029)

**Fase 5 fechada para o subset DEVORQ-E2E-CI.** Restam security/sync no CI (escopo separado, mencionado no Apêndice D da auditoria).