# DEVORQ Rules — Índice Central

**Propósito:** Regras globais do framework DEVORQ versionadas no repo canônico.

**Hierarquia de carregamento:**
1. `rules/` global em `DEVORQ_ROOT/rules/` — carregado primeiro
2. `.devorq/rules/` local do projeto — carregado **após** e sobrescreve se não conflitar

**Regras disponíveis:**

| Regra | Descrição |
|-------|-----------|
| `agent-discipline.md` | Disciplina do agente (Karpathy adaptado) — always-on via bootstrap |
| `commit-convention.md` | Convenções de commit (Conventional Commits + scopes DEVORQ) |
| `manual-commit.md` | Commits e push só com aprovação humana |
| `visual-verification.md` | Gate de verificação visual antes do commit |
| `brainstorm.md` | Gates de captura durante brainstorming |
| `grill.md` | Regras de sparring estruturado |

**Quando uma regra é aplicada:**

- **agent-discipline**: bootstrap em todo `devorq init` (comportamento do agente)
- **commit-convention**: validação no hook commit-msg + `devorq commit`
- **manual-commit**: antes de commit/push automático
- **brainstorm/**: ao iniciar sessão `devorq brainstorm`
- **grill/**: ao iniciar sessão `devorq grill`

**Como criar regra local (projeto):**
```bash
mkdir -p .devorq/rules
# Criar .devorq/rules/<nome>.md
```

**Como sobrescrever regra global:**
- Regra local em `.devorq/rules/<nome>.md` substitui global se não conflitar
- Conflito = mesma regra com lógica contraditória → usar `devorq rules check` para detectar

**Manutenção:**
- Regras globais são mantidas no repo [nandinhos/devorq_v3](https://github.com/nandinhos/devorq)
- Lições aprendidas podem gerar novas regras via `devorq lessons capture`

## Arquitetura agnóstica (v3.8.5)

- **Fonte canônica:** apenas `rules/` — sem acoplamento a IDE específica
- **Bootstrap:** `devorq rules bootstrap` → `.devorq/rules/`
- **Export sob demanda:**

```bash
devorq rules export project   # .devorq/rules/
devorq rules export cursor    # .cursor/rules/ (gitignored)
devorq rules export claude    # CLAUDE.md
devorq rules export agents    # AGENTS.md no projeto alvo
```

- **Repo DEVORQ:** [`AGENTS.md`](../AGENTS.md) estável + [`docs/ARQUITETURA-AGNOSTICA-LLM.md`](../docs/ARQUITETURA-AGNOSTICA-LLM.md)
- **Nunca commitar** `.cursor/` — gerado localmente por export
