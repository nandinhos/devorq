# HANDOFF PACKAGE — Bloco A: Fechar Worktree e Commitar Documentação

## METADADOS

- **Tarefa**: Bloco A — Finalizar e mergear trabalho em andamento
- **Data**: 2026-04-02
- **Arquiteto**: Nando Dev + Claude Code Sonnet 4.6 (Tier 1)
- **Executor**: Tier 2 — qualquer modelo disponível (Gemini, Antigravity, OpenCode)
- **Fallback**: qualquer outro modelo Tier 2 com este mesmo pacote
- **Estimativa**: 0 arquivos novos, 2 commits, 1 merge
- **Complexidade**: baixa — sem código novo, só validar e commitar

---

## 1. SNAPSHOT DO PROJETO

**O que é**: DEVORQ é um meta-framework de orquestração de desenvolvimento
assistido por LLM. Implementado em Bash puro, sem dependências além de
`git` e `jq`. Roda como CLI (`./bin/devorq`) e como conjunto de skills
Markdown (`.devorq/skills/`).

**Stack**: Bash 4.0+ / Markdown / BATS (testes)

**Repositório**: `/home/nandodev/projects/devorq`

**Último commit em main**:
`abe3d2a fix(lib): corrigir bugs críticos e preparar para implementação da metodologia`

**Estado atual — dois contextos abertos**:

```
main (branch principal):
  → 5 arquivos de documentação criados, não commitados ainda:
    - docs/adr/ADR-001-llm-agnostic-architecture.md
    - docs/spec/2026-04-02-fluxo-multi-llm.md
    - docs/templates/handoff-package.md
    - docs/contracts/2026-04-02-implementacao-metodologia.md
    - .devorq/rules/multi-llm.md

worktree feat/metodologia-spec-break-thin-client:
  → Localizado em: /home/nandodev/projects/devorq/.worktrees/feat-metodologia
  → 7 mudanças prontas para commit:
    - .devorq/skills/spec/       (novo — skill /spec)
    - .devorq/skills/break/      (novo — skill /break)
    - tests/skills.bats          (novo — 18 testes)
    - .devorq/skills/constraint-loader/SKILL.md  (modificado — Step 0)
    - .devorq/rules/stack/laravel-tall.md        (modificado — regra 9)
    - .devorq/rules/project.md                   (modificado — thin client)
    - prompts/claude.md                          (modificado — novo fluxo)
```

---

## 2. CONTRATO DE ESCOPO

### FAZER

1. No **worktree** (`.worktrees/feat-metodologia`):
   rodar suite de testes, commitar as mudanças, mergear em `main`

2. No **main**:
   commitar os 5 arquivos de documentação já criados

### NÃO FAZER

- Não modificar nenhum arquivo além dos listados abaixo
- Não corrigir nada que pareça "estar errado" durante a execução
- Não criar arquivos novos
- Não rodar `./bin/devorq init` nem qualquer comando de fluxo
- Não alterar mensagens de commit sugeridas neste pacote

### ARQUIVOS AUTORIZADOS

**Worktree** (commitar):
- `.devorq/skills/spec/SKILL.md`
- `.devorq/skills/spec/CHANGELOG.md`
- `.devorq/skills/spec/VERSIONS/v1.0.0.md`
- `.devorq/skills/break/SKILL.md`
- `.devorq/skills/break/CHANGELOG.md`
- `.devorq/skills/break/VERSIONS/v1.0.0.md`
- `tests/skills.bats`
- `.devorq/skills/constraint-loader/SKILL.md`
- `.devorq/rules/stack/laravel-tall.md`
- `.devorq/rules/project.md`
- `prompts/claude.md`

**Main** (commitar):
- `docs/adr/ADR-001-llm-agnostic-architecture.md`
- `docs/spec/2026-04-02-fluxo-multi-llm.md`
- `docs/templates/handoff-package.md`
- `docs/contracts/2026-04-02-implementacao-metodologia.md`
- `.devorq/rules/multi-llm.md`

### ARQUIVOS PROIBIDOS

- Todos os demais — se não estiver na lista acima, não tocar

---

## 3. TASK BRIEF

### Sub-task A1 — Commitar documentação em `main`

**Diretório de trabalho**: `/home/nandodev/projects/devorq` (branch `main`)

**Passo 1**: verificar que os arquivos existem
```bash
ls docs/adr/ADR-001-llm-agnostic-architecture.md
ls docs/spec/2026-04-02-fluxo-multi-llm.md
ls docs/templates/handoff-package.md
ls docs/contracts/2026-04-02-implementacao-metodologia.md
ls .devorq/rules/multi-llm.md
```
Todos devem existir. Se algum não existir: PARAR e reportar.

**Passo 2**: adicionar ao stage
```bash
git add docs/adr/ADR-001-llm-agnostic-architecture.md \
        docs/spec/2026-04-02-fluxo-multi-llm.md \
        docs/templates/handoff-package.md \
        docs/contracts/2026-04-02-implementacao-metodologia.md \
        .devorq/rules/multi-llm.md
```

**Passo 3**: commitar
```bash
git commit -m "docs(arquitetura): adicionar ADR-001, spec multi-llm e template de handoff

Adiciona arquivos de documentação:
- ADR-001: decisão formal de arquitetura LLM-agnostic
- spec fluxo multi-llm: tiers de execução e protocolo de handoff
- template handoff-package: formato universal para transferência entre LLMs
- rules/multi-llm: regras operacionais de orquestração
- contracts: contrato de escopo para implementação da metodologia v2.1"
```

---

### Sub-task A2 — Commitar e mergear o worktree

**Diretório de trabalho**: `/home/nandodev/projects/devorq/.worktrees/feat-metodologia`

**Passo 1**: rodar suite de testes
```bash
bats /home/nandodev/projects/devorq/.worktrees/feat-metodologia/tests/
```
Resultado esperado:
```
1..44
ok 1 ...
...
ok 44 ...
```
Se qualquer teste falhar: PARAR e reportar qual falhou.

**Passo 2**: smoke test do CLI
```bash
/home/nandodev/projects/devorq/.worktrees/feat-metodologia/bin/devorq skills
```
Resultado esperado: lista com **17 skills** incluindo `spec` e `break`.
Se não tiver 17: PARAR e reportar.

**Passo 3**: adicionar arquivos ao stage (dentro do worktree)
```bash
cd /home/nandodev/projects/devorq/.worktrees/feat-metodologia && \
git add .devorq/skills/spec/ \
        .devorq/skills/break/ \
        tests/skills.bats \
        .devorq/skills/constraint-loader/SKILL.md \
        .devorq/rules/stack/laravel-tall.md \
        .devorq/rules/project.md \
        prompts/claude.md
```

**Passo 4**: commitar no worktree
```bash
git commit -m "feat(skills): adicionar /spec e /break, regra thin-client e reuse search

Adiciona novas skills e atualiza arquivos existentes:
- skill /spec: especificação formal antes de iniciar desenvolvimento
- skill /break: decomposição de spec em tasks (protótipo visual primeiro)
- constraint-loader: Step 0 de busca de código reutilizável
- laravel-tall.md: regra 9 Thin Client Fat Server com exemplos PHP
- prompts/claude.md: fluxo atualizado com /spec e /break para projetos grandes
- tests/skills.bats: 18 testes de estrutura e conteúdo das novas skills"
```

**Passo 5**: voltar para `main` e mergear
```bash
cd /home/nandodev/projects/devorq && \
git merge feat/metodologia-spec-break-thin-client --no-ff \
  -m "merge(feat): incorporar skills /spec e /break + correções multi-llm"
```

**Passo 6**: remover o worktree
```bash
git worktree remove /home/nandodev/projects/devorq/.worktrees/feat-metodologia
```

---

## 4. VERIFICAÇÃO

Após concluir A1 e A2, rodar em `/home/nandodev/projects/devorq`:

```bash
bats tests/
```
**Output esperado**: todos os testes passando — mínimo 44/44 ok, zero not ok.

```bash
./bin/devorq skills
```
**Output esperado** (17 skills em ordem alfabética):
```
Skills DEVORQ (17 skills):
  - brainstorming v1.0.0
  - break v1.0.0
  - code-review v1.0.0
  - constraint-loader v1.0.0
  - env-context v1.0.0
  - handoff v1.0.0
  - integrity-guardian v1.0.0
  - learned-lesson v1.0.0
  - pre-flight v1.0.0
  - quality-gate v1.0.0
  - schema-validate v1.0.0
  - scope-guard v1.0.0
  - session-audit v1.1.0
  - spec v1.0.0
  - spec-export v1.0.0
  - systematic-debugging v1.0.0
  - tdd v1.0.0
```

```bash
git log --oneline -4
```
**Output esperado**: 4 commits recentes visíveis, os 2 mais novos sendo os
commits de A1 e A2 acima.

---

## 5. PADRÕES OBRIGATÓRIOS PARA ESTA TASK

- Commits usam **Conventional Commits em pt-BR** (`feat`, `fix`, `docs`, `merge`)
- `git add` com arquivos **explícitos** — nunca `git add .` ou `git add -A`
- Se qualquer teste falhar: **PARAR** e reportar — não tentar corrigir
- Se o número de skills for diferente de 17: **PARAR** e reportar
- Merge com `--no-ff` para preservar histórico do branch

---

## 6. DONE CRITERIA

- [ ] `bats tests/` → 44/44 ok (zero falhas)
- [ ] `./bin/devorq skills` → exatamente 17 skills na lista
- [ ] `git log --oneline -1` mostra o commit de merge do feat
- [ ] `git worktree list` não mostra mais o worktree `feat-metodologia`
- [ ] `git log --oneline -4` mostra 2 novos commits (docs + feat)
- [ ] Nenhum arquivo fora da lista autorizada foi modificado

---

## 7. RETORNO ESPERADO

Ao concluir, retornar ao arquiteto neste formato exato:

```markdown
# RETORNO — Bloco A: Fechar Worktree

- **SHA commit docs (A1)**: [hash]
- **SHA commit feat (A2)**: [hash]
- **SHA commit merge**: [hash]
- **Testes**: [N/44 passando]
- **Skills listadas**: [N skills]
- **Worktree removido**: sim / não
- **Desvios do plano**: nenhum | [descrição]
- **Erros encontrados**: nenhum | [descrição]
```

---

## NOTAS DO ARQUITETO

Este é o **primeiro handoff real** do processo multi-LLM do DEVORQ.
O objetivo além de executar a tarefa é **validar o formato do handoff**.

Se qualquer parte deste pacote estiver confusa, incompleta ou ambígua:
reportar no campo "Desvios do plano" do retorno — isso é dado de melhoria
para o próximo handoff.

A tarefa em si é baixo risco: nenhum código novo, só commitar e mergear
trabalho já validado com testes. Se os testes passarem, tudo certo.

### REGRA GLOBAL DE COMMITS

Todos os handoffs devem seguir esta estrutura de commit:

- **Formato**: tipo(especialização): descrição detalhada
- **Idioma**: português do Brasil
- **Sem emojis**: usar texto puro
- **Sem Co-Authorship**: remover linhas de co-authored-by
- **Corpo detalhado**: cada item em linha própria, indentado com 2 espaços
