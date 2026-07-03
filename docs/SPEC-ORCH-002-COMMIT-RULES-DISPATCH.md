# SPEC-ORCH-002 — Restaurar commit/verify/rules no CLI v3.7

**Versão:** 1.0.0  
**Data:** 2026-05-23  
**Status:** IMPLEMENTADO v3.7.1  
**Autor:** Nando + Cursor Agent (VPS events.fssdev.com.br)  
**Repo:** github.com/nandinhos/devorq  

---

## 1. Problema

A modularização v3.7.0 (`orch-001`) restaurou `init`, `gate`, `flow`, `auto`, `mode` mas **deixou órfãos**:

| Comando | Código | CLI v3.7.0 |
|---------|--------|------------|
| `devorq commit` | `lib/commit.sh` | ❌ |
| `devorq verify` | `lib/visual.sh` | ❌ |
| `devorq rules` | `lib/rules.sh` | ❌ |

Consequências em projetos (ex.: Events Control):

- Agentes criaram regras Cursor por projeto (fácil esquecer)
- AUTO mode sugeria `feat(FP-001): título` (formato errado)
- Hook `pre-commit` validava mensagem no hook errado (sem acesso ao msg)
- `lib/commit.sh` abortava quando **havia** mudanças (lógica invertida)

---

## 2. Solução (v3.7.1)

### 2.1 Dispatch restaurado (`bin/devorq`)

```bash
commit)  source lib/commands/commit.sh && devorq::cmd_commit_dispatch "$@" ;;
verify)  devorq::cmd_verify "$@" ;;
rules)   source lib/commands/rules.sh && devorq::cmd_rules_dispatch "$@" ;;
```

### 2.2 Enforcement no Git (não no Cursor)

```bash
devorq init              # cria .devorq + bootstrap idempotente
devorq rules bootstrap   # copia regras + instala commit-msg hook
devorq commit --story FP-001   # interativo, formato correto
```

Hook **`commit-msg`** (não pre-commit) valida:

```
escopo(fase): descrição (detalhamento)
```

### 2.3 Bootstrap automático no init

Todo `devorq init` (novo ou existente) executa:

1. Copia `commit-convention.md` + `manual-commit.md` → `.devorq/rules/`
2. Instala `.git/hooks/commit-msg`

### 2.4 CI — verify-dispatch expandido

Smoke tests obrigatórios:

- `devorq commit --help`
- `devorq verify --help`
- `devorq rules list`

---

## 3. Fluxo pós-fix

```
Story implementada
    → devorq verify --story FP-001
    → devorq commit --story FP-001   (confirmação manual Y/n)
    → git commit-msg hook valida formato
    → prd.json passes=true
```

---

## 4. Upgrade em projetos existentes

```bash
cd /seu/projeto
devorq upgrade                    # ou git pull no hub
devorq rules bootstrap
devorq rules check commit-convention
```

Opcional: remover `.cursor/rules/devorq-commits.mdc` redundante — enforcement está no git hook.

---

## 5. Arquivos alterados

| Arquivo | Mudança |
|---------|---------|
| `bin/devorq` | +commit, verify, rules dispatch; v3.7.1 |
| `lib/commands/commit.sh` | Novo wrapper |
| `lib/commands/rules.sh` | Novo wrapper |
| `lib/commit.sh` | Fix diff check |
| `lib/rules.sh` | bootstrap, commit-msg hook, cmd_rules actions |
| `lib/commands/workflow.sh` | init → bootstrap idempotente |
| `skills/devorq-auto/scripts/loop-auto.sh` | Sugestão commit correta |
| `scripts/verify-dispatch.sh` | +3 smoke tests |
| `VERSION` | 3.7.1 |
| `CHANGELOG.md` | Entrada 3.7.1 |
| `prd.json` | Story orch-002 |

---

## 6. Critérios de aceite

- [x] `devorq commit --help` funciona
- [x] `devorq verify --help` funciona
- [x] `devorq rules list` funciona
- [x] `devorq rules bootstrap` instala hook
- [x] Commit com formato errado é rejeitado pelo hook
- [x] `scripts/verify-dispatch.sh` passa
- [x] AUTO mode sugere `devorq commit --story`, não `feat(id):`

---

## 7. Próximos passos (v3.8 opcional)

- `devorq rules export-cursor` — gera `.cursor/rules/` a partir do hub
- `commit_mode` em context.json lido por AUTO mode
- Story `orch-003` — integrar `devorq verify` no loop-auto antes de mark_pass
