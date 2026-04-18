# HANDOFF DEVORQ — 20260418_053242

**Destinatário**: MiniMax
**Gerado por**: Claude Code (Sonnet 4.6)
**Projeto**: DEVORQ — Meta-framework de orquestração Multi-LLM
**Gate**: 4 — Transferência para implementação

---

## CONTEXTO

- **Stack**: Shell/Bash puro (4.0+) — sem dependências além de `git` e `jq`
- **Branch**: `main`
- **Último commit**: `132d91e chore: deletar 12 specs de teste vazias (draft/) e limpar configuracoes`
- **Versão DEVORQ**: v2.1
- **Status**: Planejamento completo — SPEC aprovada no Gate 1, /break concluído. Aguardando implementação.

### O que foi feito nesta sessão (Claude Code)

1. Análise das duas fontes de entrada:
   - `docs/proposals/architecture/PROPOSTA-MELHORIA-DEVORQ-v1.0.md` — proposta de rastreabilidade de bugs em SPECs
   - `docs/proposals/code-review/code-review-hermes.md` — code review externo do agente Hermes
2. Verificação de viabilidade de cada item proposto contra o estado real do repositório
3. Criação da SPEC formal: `docs/specs/draft/SPEC-0075-18-04-2026-melhorias-rastreabilidade-workflow.md`
4. Decomposição em task list: `.devorq/state/tasklist/spec-0075-melhorias-rastreabilidade-workflow-tasks.md`

---

## TAREFA

Implementar **5 mudanças cirúrgicas** no orquestrador DEVORQ, conforme SPEC-0075. Todas as mudanças são em arquivos de configuração/script — não há lógica de negócio complexa.

### Visão geral das 5 tasks

| Task | Arquivo | Natureza |
|------|---------|---------|
| T1 | `.devorq/skills/spec/SKILL.md` | Adicionar seção RESOLUÇÕES DE PANES ao template |
| T2 | `.devorq/skills/quality-gate/SKILL.md` | Formalizar triggers de systematic-debugging e code-review |
| T3 | `.github/workflows/quality-gate.yml` | Preencher job quality-generic (atualmente placeholder vazio) |
| T4 | `.devorq/hooks/pre-commit` (novo) | Criar hook Bash lightweight |
| T5 | `bin/devorq` | Adicionar subcomando `hooks install/status/uninstall` |

**Ordem**: T1, T2, T3, T4 são independentes entre si (podem ser executadas em qualquer ordem). T5 depende de T4 estar completa.

---

## ARTEFATOS DE PLANEJAMENTO

Leia obrigatoriamente antes de implementar:

1. **SPEC completa**: `docs/specs/draft/SPEC-0075-18-04-2026-melhorias-rastreabilidade-workflow.md`
   - Contém: contexto, análise de viabilidade, detalhes técnicos de cada mudança com código exato, critérios de aceite, riscos

2. **Task list detalhada**: `.devorq/state/tasklist/spec-0075-melhorias-rastreabilidade-workflow-tasks.md`
   - Contém: FAZER/NÃO FAZER/Done Criteria por task + comandos de verificação final

---

## CONSTRAINTS OBRIGATÓRIOS

- **Runtime**: Bash 5.x — scripts devem passar `bash -n` e `shellcheck --severity=error`
- **Padrão dual-use**: Todo script Bash que pode ser `source`d deve usar o guard:
  ```bash
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
  ```
- **`set -eEo pipefail` NUNCA no nível global** de scripts que serão `source`d — sempre dentro de `main()`
- **`jq`** é a única dependência externa além de `git` — não introduzir outras
- **`shellcheck`** é opcional (verificar disponibilidade com `command -v shellcheck`) — nunca falhar se ausente

---

## NUNCA FAZER

- ❌ Não invocar `quality-gate` completa em git hooks automáticos — as Etapas 9 e 10 são interativas (exigem `OK|BUG|N/A` e `A|E|R` do usuário)
- ❌ Não alterar o pipeline de lições (gates 5-7) — já implementado em SPEC-0070, funcionando
- ❌ Não alterar as Etapas 1-10 do quality-gate existente — apenas adicionar pré-requisito ANTES do checklist e instrução na Etapa 1
- ❌ Não hardcodar caminhos absolutos — sempre usar `DEVORQ_ROOT` ou `git rev-parse --show-toplevel`
- ❌ Não tornar shellcheck bloqueante no `quality-generic` do CI — já é bloqueante no `quality-bash`
- ❌ Não criar novos gates numerados no quality-gate — manter 1-10 intactos
- ❌ Não modificar nenhum outro `cmd_*` além de criar `cmd_hooks()` em `bin/devorq`

---

## ARQUIVOS PERMITIDOS (modificar)

```
.devorq/skills/spec/SKILL.md                          ← T1
.devorq/skills/quality-gate/SKILL.md                  ← T2
.github/workflows/quality-gate.yml                    ← T3
.devorq/hooks/pre-commit                              ← T4 (criar novo)
bin/devorq                                            ← T5
docs/specs/draft/SPEC-0075-*.md                       ← atualizar status se aprovado
docs/specs/_index.md                                  ← atualizar status para 'approved'
```

## ARQUIVOS PROIBIDOS (não tocar)

```
.devorq/skills/systematic-debugging/SKILL.md          ← skill completa, não alterar
.devorq/skills/code-review/SKILL.md                   ← skill completa, não alterar
.devorq/skills/learned-lesson/SKILL.md                ← pipeline de lições — não tocar
lib/*.sh                                              ← módulos core — não alterar nesta SPEC
tests/                                                ← não alterar testes existentes
.git/hooks/                                           ← não criar diretamente; usar cmd_hooks install
```

---

## DONE CRITERIA (verificação final)

```bash
# T1 — template SPEC com RESOLUÇÕES DE PANES
grep -c "RESOLUÇÕES DE PANES" .devorq/skills/spec/SKILL.md
# Esperado: >= 1

# T2 — quality-gate com triggers formalizados
grep -c "systematic-debugging" .devorq/skills/quality-gate/SKILL.md
grep -c "code-review" .devorq/skills/quality-gate/SKILL.md
# Esperado: >= 1 cada

# T3 — CI quality-generic preenchido
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/quality-gate.yml')); print('YAML OK')"
grep -c "validar estrutura\|SKILL.md\|bash -n" .github/workflows/quality-gate.yml
# Esperado: >= 2

# T4 — hook pre-commit existe e é válido
bash -n .devorq/hooks/pre-commit
shellcheck .devorq/hooks/pre-commit
ls -la .devorq/hooks/pre-commit
# Esperado: arquivo existe, sem erros

# T5 — subcomando hooks no CLI
bash -n bin/devorq
./bin/devorq hooks status
./bin/devorq help | grep hooks
# Esperado: sem erros, hooks listado no help

# Smoke test do hook (após T4+T5)
./bin/devorq hooks install
ls -la .git/hooks/pre-commit
# Esperado: arquivo instalado com permissão de execução
```

---

## DECISÕES JÁ TOMADAS (não redecisão)

| Decisão | Razão |
|---------|-------|
| Hook é lightweight (bash -n + shellcheck), NÃO quality-gate completa | Etapas 9 e 10 são interativas — hook automático não pode aguardar input humano |
| shellcheck opcional no hook | Nem todo ambiente tem shellcheck instalado localmente |
| shellcheck continua BLOQUEANTE no CI (quality-bash) | CI tem ambiente controlado — já instalado |
| CHANGELOG.md ausente em skill = AVISO, não erro no CI | Skills em criação podem não ter CHANGELOG ainda |
| SKILL.md ausente em skill = ERRO bloqueante no CI | SKILL.md é o contrato mínimo de toda skill |
| `cmd_hooks()` segue padrão das outras funções cmd_* | Consistência arquitetural do CLI |
| Sem automação de invocação de skills (systematic-debugging, code-review) | Skills são invocadas pelo LLM, não pelo Bash — não é responsabilidade do CLI |

---

## ANTI-PATTERNS IDENTIFICADOS

1. **Inserir quality-gate em hook automático**: As etapas 9 e 10 travam aguardando `OK/BUG/N/A` — em GUI clients e rebase automático isso causa deadlock
2. **shellcheck como dependência hard no hook**: Ambientes sem shellcheck instalado bloqueariam todos os commits — usar `command -v shellcheck || return 0`
3. **Sobrescrever hooks sem confirmação**: Se o desenvolvedor instalou outro hook, o `hooks install` deve perguntar antes de sobrescrever
4. **set -eEo pipefail global no hook**: O hook é `source`d pelo git em alguns contextos — seguir a lição LESSON-0014 (set -e global quebra hooks)
5. **Alterar gates 2-10 do quality-gate**: O escopo é adicionar pré-requisito e instrução no gate 1 — não renumerar nem reestruturar o resto

---

## CONTEXTO ARQUITETURAL DO DEVORQ

```
bin/devorq          → CLI público com ~1510 linhas
                      Padrão: cmd_<nome>() { ... } + case no MAIN
lib/                → Módulos Bash reutilizáveis
.devorq/skills/     → 19 skills em SKILL.md + CHANGELOG.md + VERSIONS/
.devorq/hooks/      → Hooks instaláveis (a criar nesta SPEC)
.github/workflows/  → CI com quality-bash (completo) + quality-generic (placeholder)
tests/              → Suite bats com 10 arquivos de teste
```

**Versões de skills relevantes:**
- `quality-gate`: v1.4.0 (última) — adicionar pré-requisito e trigger sem bump obrigatório de versão
- `spec`: verificar versão atual antes de editar com `./bin/devorq skill versions spec`

---

## VERIFICAÇÃO PRÉ-IMPLEMENTAÇÃO (rodar antes de começar)

```bash
# Verificar estado do repositório
git status
bash -n bin/devorq
bash -n lib/*.sh

# Confirmar arquivos de planejamento estão acessíveis
ls docs/specs/draft/SPEC-0075-18-04-2026-melhorias-rastreabilidade-workflow.md
ls .devorq/state/tasklist/spec-0075-melhorias-rastreabilidade-workflow-tasks.md

# Verificar CI atual
cat .github/workflows/quality-gate.yml
```

---

## STATUS FINAL ESPERADO

Após implementação completa:

```
docs/specs/approved/SPEC-0075-18-04-2026-melhorias-rastreabilidade-workflow.md  ← movida de draft/
.devorq/hooks/pre-commit                                                         ← novo arquivo
.devorq/skills/spec/SKILL.md                                                     ← seção PANES adicionada
.devorq/skills/quality-gate/SKILL.md                                             ← triggers formalizados
.github/workflows/quality-gate.yml                                               ← quality-generic preenchido
bin/devorq                                                                       ← cmd_hooks adicionado
```

**Commit esperado (após quality-gate aprovado):**
```
feat (workflow): adiciona rastreabilidade de panes, hook pre-commit e integração formal de skills
```
