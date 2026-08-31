# Arquitetura agnóstica LLM — DEVORQ v4.1.0

**Princípio:** `rules/` é a única fonte canônica. Adaptadores (Cursor, Claude, AGENTS.md, DeepSeek Harness) são **gerados** por `devorq rules export` (ou pelo installer do preset DSH) — nunca editados em paralelo no repo DEVORQ.

## Camadas

```
rules/*.md                    ← fonte canônica (versionada)
    ↓ devorq rules bootstrap
.devorq/rules/                ← projeto local após init
    ↓ devorq rules export <alvo>
.cursor/rules/  CLAUDE.md  AGENTS.md   ← adaptadores opt-in (locais)
    ↓ install-dsh-preset.sh
~/.dsh/ (skill + preset)      ← camada DeepSeek Harness (DSH)
```

## Uso por ferramenta

| Ferramenta | Comando | Saída |
|------------|---------|-------|
| Qualquer LLM | `devorq init` + ler `.devorq/rules/` | Regras no projeto |
| Telegram / orquestrador | `devorq scope lite`, gates, verify | CLI bash |
| Cursor | `devorq rules export cursor` | `.cursor/rules/devorq-discipline.mdc` |
| Claude Code | `devorq rules export claude` | `CLAUDE.md` |
| Multi-tool | `devorq rules export agents` | `AGENTS.md` |
| DeepSeek Harness (DSH) | `bash scripts/install-dsh-preset.sh` | skill `~/.dsh/skills/devorq/` + preset `~/.dsh/.agent-presets/devorq/` |

`.cursor/` está no `.gitignore` — cada desenvolvedor gera localmente.

## Camada DeepSeek Harness (DSH)

O DEVORQ roda como **agent preset** no [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness): a metodologia (persona + gates + disciplina de commit) é montada sobre o agente de código completo do harness.

- **Skill canônica:** `skills/devorq/SKILL.md` → instalada em `~/.dsh/skills/devorq/` (root user-dsh, rank 400 — auto-descoberta pelo provider `dsh-skill-filesystem`).
- **Preset:** `config/dsh/devorq/` (templates) → `~/.dsh/.agent-presets/devorq/` (`agent.cordis.yml` + `preset.yml`).
- **Instalação idempotente:** `bash scripts/install-dsh-preset.sh` (`--dry-run` só mostra o plano).
- **Recarga:** a composição do preset é gerada por sessão (mtime/size do `agent.cordis.yml`) — após editar o preset/skill, **abra uma nova sessão DSH**.

> Por que a skill não fica no preset: o provider `dsh-skill-filesystem` não varre o diretório do preset (só roots fixos). No user-dsh ela é auto-descoberta e sobrevive à cópia do preset (`customSkillDirs` hardcodaria o id e quebraria).

## Orquestrador Telegram

1. Carregar `.devorq/rules/agent-discipline.md` no prompt do agente
2. Antes de codar: `devorq scope lite "<intent>"`
3. Commits via `devorq commit` — nunca append `Co-Authored-By`
4. Regenerar adaptadores após atualizar DEVORQ: `devorq rules export <alvo>`

## Prevenção de coautoria

- Hook `commit-msg` rejeita `Co-Authored-By`
- `scripts/validate-rules.sh` falha se histórico contiver coautoria
- Convenção em `rules/commit-convention.md`

## Histórico Git (v3.8.5)

O histórico `main` foi reorganizado por release (2026-05-23). Re-clone recomendado após force-push de tags.
