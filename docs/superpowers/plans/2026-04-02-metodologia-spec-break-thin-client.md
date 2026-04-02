# Incorporação da Metodologia: /spec, /break, Thin Client + Reuse Search

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incorporar os padrões da metodologia externa (spec → break → plan → execute) ao DEVORQ, adicionando 2 novas skills (`/spec`, `/break`), a regra "Thin Client, Fat Server", e a etapa de busca de reuso no `constraint-loader` — sem overengineering.

**Architecture:** Cada adição é um arquivo `.devorq/skills/<nome>/SKILL.md` seguindo o padrão existente. O `constraint-loader` recebe um Step 0 de busca de reuso. A regra thin-client é adicionada ao `laravel-tall.md` e ao `rules/project.md`. O `prompts/claude.md` é atualizado com o novo fluxo. Tudo guiado por TDD via BATS.

**Tech Stack:** Bash 4.0+, BATS (Bash Automated Testing System), Markdown

---

## Mapa de Arquivos

| Ação | Arquivo | Responsabilidade |
|------|---------|-----------------|
| Criar | `.devorq/skills/spec/SKILL.md` | Skill de especificação formal de projeto |
| Criar | `.devorq/skills/spec/CHANGELOG.md` | Histórico de versões da skill spec |
| Criar | `.devorq/skills/spec/VERSIONS/v1.0.0.md` | Snapshot v1.0.0 da skill spec |
| Criar | `.devorq/skills/break/SKILL.md` | Skill de decomposição de spec em tasks |
| Criar | `.devorq/skills/break/CHANGELOG.md` | Histórico de versões da skill break |
| Criar | `.devorq/skills/break/VERSIONS/v1.0.0.md` | Snapshot v1.0.0 da skill break |
| Modificar | `.devorq/skills/constraint-loader/SKILL.md` | Adicionar Step 0: busca de reuso |
| Modificar | `.devorq/rules/stack/laravel-tall.md` | Adicionar regra 9: Thin Client, Fat Server |
| Modificar | `.devorq/rules/project.md` | Adicionar regra thin client para projetos genéricos |
| Modificar | `prompts/claude.md` | Atualizar fluxo com /spec e /break |
| Criar | `tests/skills.bats` | Testes de estrutura e conteúdo das skills |

---

## Task 1: Testes RED para as novas skills e regras

**Files:**
- Criar: `tests/skills.bats`

- [ ] **Step 1: Escrever os testes que vão falhar**

Criar o arquivo `tests/skills.bats` com o seguinte conteúdo:

```bash
#!/usr/bin/env bats

# Testes: estrutura e conteúdo das novas skills e regras

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Skill /spec ---

@test "skill spec/SKILL.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md" ]
}

@test "skill spec/SKILL.md contém trigger 'spec'" {
    grep -q "\"spec\"" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/SKILL.md documenta saída em docs/spec/" {
    grep -q "docs/spec/" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/SKILL.md menciona gate de aprovação" {
    grep -qi "aprovação\|gate\|aprovar" "$DEVORQ_ROOT/.devorq/skills/spec/SKILL.md"
}

@test "skill spec/CHANGELOG.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/CHANGELOG.md" ]
}

@test "skill spec/VERSIONS/v1.0.0.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/spec/VERSIONS/v1.0.0.md" ]
}

# --- Skill /break ---

@test "skill break/SKILL.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md" ]
}

@test "skill break/SKILL.md contém trigger 'break'" {
    grep -q "\"break\"" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/SKILL.md menciona protótipo antes de comportamento" {
    grep -qi "protótipo\|prototype" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/SKILL.md documenta saída em .devorq/state/tasklist/" {
    grep -q "tasklist" "$DEVORQ_ROOT/.devorq/skills/break/SKILL.md"
}

@test "skill break/CHANGELOG.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/CHANGELOG.md" ]
}

@test "skill break/VERSIONS/v1.0.0.md existe" {
    [ -f "$DEVORQ_ROOT/.devorq/skills/break/VERSIONS/v1.0.0.md" ]
}

# --- constraint-loader: reuse search ---

@test "constraint-loader menciona busca de código reutilizável" {
    grep -qi "reutiliz\|reuso\|reuse" "$DEVORQ_ROOT/.devorq/skills/constraint-loader/SKILL.md"
}

@test "constraint-loader tem Step 0 antes do Step 1" {
    grep -q "Step 0" "$DEVORQ_ROOT/.devorq/skills/constraint-loader/SKILL.md"
}

# --- Regra thin client ---

@test "laravel-tall.md contém regra Thin Client" {
    grep -qi "thin client\|fat server" "$DEVORQ_ROOT/.devorq/rules/stack/laravel-tall.md"
}

@test "laravel-tall.md proíbe lógica de negócio no frontend" {
    grep -qi "NUNCA.*lógica\|lógica.*frontend\|negócio.*frontend" "$DEVORQ_ROOT/.devorq/rules/stack/laravel-tall.md"
}

# --- prompts/claude.md atualizado ---

@test "prompts/claude.md menciona /spec" {
    grep -q "/spec" "$DEVORQ_ROOT/prompts/claude.md"
}

@test "prompts/claude.md menciona /break" {
    grep -q "/break" "$DEVORQ_ROOT/prompts/claude.md"
}
```

- [ ] **Step 2: Rodar os testes e confirmar RED**

```bash
bats tests/skills.bats
```

Resultado esperado: **0 ok, 19 not ok** (todos falham pois os arquivos não existem)

---

## Task 2: Criar a skill `/spec`

**Files:**
- Criar: `.devorq/skills/spec/SKILL.md`
- Criar: `.devorq/skills/spec/CHANGELOG.md`
- Criar: `.devorq/skills/spec/VERSIONS/v1.0.0.md`

- [ ] **Step 1: Criar diretório e SKILL.md**

```bash
mkdir -p .devorq/skills/spec/VERSIONS
```

Criar `.devorq/skills/spec/SKILL.md` com o conteúdo:

```markdown
---
name: spec
description: Criar documento de especificação formal antes de iniciar desenvolvimento de projeto ou feature grande
triggers:
  - "spec"
  - "/spec"
  - "especificação"
  - "PRD"
  - "especificar projeto"
globs:
  - "**/*.md"
---

# /spec — Especificação de Projeto

> **Regra de Ouro**: Sem spec não existe break. Sem break o LLM engasga.

## Quando Usar

**OBRIGATÓRIO** antes de iniciar:
- Projeto novo (greenfield)
- Feature de médio/grande porte (mais de 2 páginas ou 3 comportamentos)

**OPCIONAL** para:
- Bugfixes simples → ir direto para /scope-guard
- Features de 1 página com 1 comportamento → ir direto para /scope-guard

## Propósito

1. **Clareza antes do código**: Mapear tudo antes de começar
2. **Fonte de verdade para /break**: O documento é o input do decompositor
3. **Evitar escopo vago**: O LLM implementa o que está escrito, não o que foi imaginado

## Processo

### Step 1: Capturar Intenção

Perguntar ao usuário (uma pergunta por vez):
1. Qual o objetivo da aplicação ou feature? (uma frase)
2. Quais páginas/telas existem?
3. Para cada página: quais ações o usuário pode realizar?
4. Quais dados são exibidos e quais são capturados?
5. Existem integrações externas (APIs, pagamentos, emails)?
6. O que está FORA do escopo desta fase?

### Step 2: Gerar Documento de Spec

```markdown
# SPEC — [Nome do Projeto/Feature]

**Data**: YYYY-MM-DD
**Versão**: 1.0

## Objetivo
[Uma frase: o que este sistema faz e para quem]

## Fora do Escopo
- [O que NÃO será feito nesta fase — explícito evita over-engineering]

## Páginas

### [Nome da Página] — /rota
**Componentes visuais**:
- [Lista de elementos na tela]

**Comportamentos**:
- Usuário pode [ação 1] → resultado esperado
- Ao clicar em [X], acontece [Y]
- Validação: [regra de validação]

**Dados exibidos**: [campos/informações visíveis]
**Dados capturados**: [inputs do usuário]

## Regras de Negócio
1. [Regra 1 — quem pode fazer o quê]
2. [Regra 2 — cálculos, permissões, fluxos]

## Estimativa de Modelos
- `[tabela]`: [campos relevantes]
```

### Step 3: Salvar

Salvar em: `docs/spec/YYYY-MM-DD-[nome-kebab-case].md`

### Step 4: Gate de Aprovação

Apresentar o documento ao usuário:
```
Spec gerada em docs/spec/YYYY-MM-DD-[nome].md

Revise e confirme:
- As páginas estão corretas?
- Os comportamentos refletem o que você quer?
- O "Fora do Escopo" está adequado?

Aprovado? (sim/não + ajustes)
```

**AGUARDAR confirmação** antes de qualquer próximo passo.

## Próximo Passo

Após aprovação: executar `/break` passando o caminho da spec.

---

> **Débito que previne**: Escopo vago, LLM implementando coisas não pedidas, contexto explodido por tarefa enorme
```

- [ ] **Step 2: Criar CHANGELOG.md**

Criar `.devorq/skills/spec/CHANGELOG.md`:

```markdown
# CHANGELOG — skill/spec

## v1.0.0 — 2026-04-02
- Criação inicial da skill
- Processo de 4 steps: capturar → gerar → salvar → gate
- Baseado na metodologia: spec antes de break antes de execute
```

- [ ] **Step 3: Criar snapshot em VERSIONS/**

Copiar o conteúdo de `SKILL.md` para `.devorq/skills/spec/VERSIONS/v1.0.0.md` (conteúdo idêntico).

- [ ] **Step 4: Rodar testes parciais**

```bash
bats tests/skills.bats 2>&1 | grep "spec"
```

Esperado: os 6 testes de spec passam (`ok`)

---

## Task 3: Criar a skill `/break`

**Files:**
- Criar: `.devorq/skills/break/SKILL.md`
- Criar: `.devorq/skills/break/CHANGELOG.md`
- Criar: `.devorq/skills/break/VERSIONS/v1.0.0.md`

- [ ] **Step 1: Criar diretório e SKILL.md**

```bash
mkdir -p .devorq/skills/break/VERSIONS
```

Criar `.devorq/skills/break/SKILL.md`:

```markdown
---
name: break
description: Decompor documento de spec em tasks atômicas ordenadas — protótipo visual sempre antes de comportamento
triggers:
  - "break"
  - "/break"
  - "decompor spec"
  - "quebrar em tasks"
  - "criar issues"
globs:
  - "docs/spec/*.md"
---

# /break — Decomposição de Spec em Tasks

> **Regra de Ouro**: Uma task = uma coisa verificável. Protótipo visual antes de comportamento.

## Quando Usar

Após aprovação do `/spec`, para transformar o documento em tasks executáveis.

## Por Que Isso Importa

O LLM perde qualidade quando a tarefa é grande:
- Tarefa grande → janela de contexto lotada → código bagunçado
- Tarefa pequena → contexto limpo → código focado

Além disso: protótipo visual aprovado pelo usuário antes de qualquer lógica evita o "cobertor de pobre" (implementar comportamento em tela que ainda mudará).

## Regras de Decomposição

1. **Máximo 5 arquivos por task** — se precisar de mais, dividir em 2 tasks
2. **Protótipo sempre primeiro** — para cada página, task visual antes de qualquer comportamento
3. **Um comportamento por task** — não agrupar "salvar + enviar email" numa task só
4. **Dependência explícita** — informar se uma task depende de outra
5. **Critério verificável** — sem "quando ficar bom"; sempre "quando X retornar Y"

## Processo

### Step 1: Ler a Spec

```bash
cat docs/spec/YYYY-MM-DD-[nome].md
```

### Step 2: Gerar Task List

Para cada página da spec, gerar nesta ordem:
1. Task de protótipo visual (apenas HTML/Blade/componentes, sem lógica)
2. Tasks de comportamento (uma por ação do usuário)
3. Tasks de validação (se houver regras de negócio isoláveis)

### Step 3: Formato de Output

```markdown
# TASK LIST — [Nome]
**Spec**: docs/spec/YYYY-MM-DD-[nome].md
**Data**: YYYY-MM-DD

---

## TASK-001: [Página X] — Protótipo Visual
- **Tipo**: `prototype`
- **Página**: [nome da página]
- **FAZER**: Criar tela visual sem lógica (HTML/Blade/Livewire layout)
- **NÃO FAZER**: Nenhuma lógica de backend, sem queries, sem wire:model funcional
- **Arquivos**: [lista máx. 5 arquivos]
- **Critério**: Tela renderiza sem erro 500. Visual aprovado pelo usuário.
- **Depende de**: nenhuma

---

## TASK-002: [Página X] — Comportamento: [ação do usuário]
- **Tipo**: `behavior`
- **Página**: [nome da página]
- **FAZER**: Implementar [ação específica e única]
- **NÃO FAZER**: [o que não toca nesta task]
- **Arquivos**: [lista máx. 5 arquivos]
- **Critério**: [verificação objetiva e testável]
- **Depende de**: TASK-001
```

### Step 4: Salvar

Salvar em: `.devorq/state/tasklist/YYYY-MM-DD-[nome].md`

### Step 5: Apresentar ao Usuário

```
Task list gerada em .devorq/state/tasklist/YYYY-MM-DD-[nome].md

Total: [N] tasks
- [N] protótipos
- [N] comportamentos

Confirma a ordem e granularidade? (sim/ajustar)
```

## Fluxo de Execução por Task

Para cada task da lista, seguir o fluxo padrão DEVORQ:
```
/scope-guard (contrato) → /pre-flight (schema) → tdd → /quality-gate → commit
```

---

> **Débito que previne**: Contexto explodido, código duplicado por falta de visibilidade, comportamento implementado em tela não aprovada
```

- [ ] **Step 2: Criar CHANGELOG.md**

Criar `.devorq/skills/break/CHANGELOG.md`:

```markdown
# CHANGELOG — skill/break

## v1.0.0 — 2026-04-02
- Criação inicial da skill
- Regra: protótipo visual antes de comportamento
- Máximo 5 arquivos por task
- Saída em .devorq/state/tasklist/
```

- [ ] **Step 3: Criar snapshot em VERSIONS/**

Copiar conteúdo de `SKILL.md` para `.devorq/skills/break/VERSIONS/v1.0.0.md`.

- [ ] **Step 4: Rodar testes parciais**

```bash
bats tests/skills.bats 2>&1 | grep "break"
```

Esperado: os 6 testes de break passam (`ok`)

---

## Task 4: Atualizar `constraint-loader` com Step 0 de Reuso

**Files:**
- Modificar: `.devorq/skills/constraint-loader/SKILL.md`

- [ ] **Step 1: Verificar testes RED para constraint-loader**

```bash
bats tests/skills.bats 2>&1 | grep "constraint"
```

Esperado: `not ok constraint-loader menciona busca de código reutilizável` e `not ok constraint-loader tem Step 0`

- [ ] **Step 2: Adicionar Step 0 antes do bloco "Tipos de Task e Artefatos"**

No arquivo `.devorq/skills/constraint-loader/SKILL.md`, logo após a seção `## Quando Usar`, inserir:

```markdown
## Step 0: Buscar Código Reutilizável (SEMPRE PRIMEIRO)

Antes de carregar qualquer artefato, pesquisar no projeto código que pode ser reusado ou adaptado:

```bash
# Buscar componentes/classes similares ao que será implementado
grep -r "[conceito-chave]" app/ --include="*.php" -l
find app/ -name "*[NomeSimilar]*"

# Buscar padrão de implementação existente
grep -r "[método ou padrão]" app/ --include="*.php" -n | head -20
```

Apresentar ao LLM antes de prosseguir:
```
=== REUSE SCAN ===
Encontrado: [X componente/classe/padrão] em [caminho]
Recomendação: [reutilizar | adaptar | criar novo]
=================
```

Se nada encontrado relevante: registrar "Nenhum código reutilizável identificado" e prosseguir.

**Objetivo**: eliminar duplicação antes de começar. Código duplicado = dívida de manutenção.
```

- [ ] **Step 3: Verificar que o bloco foi inserido corretamente**

```bash
grep -n "Step 0" .devorq/skills/constraint-loader/SKILL.md
```

Esperado: linha com `## Step 0:` ou `### Step 0:`

- [ ] **Step 4: Rodar testes parciais**

```bash
bats tests/skills.bats 2>&1 | grep "constraint"
```

Esperado: `ok constraint-loader menciona busca de código reutilizável` e `ok constraint-loader tem Step 0`

---

## Task 5: Adicionar Regra "Thin Client, Fat Server"

**Files:**
- Modificar: `.devorq/rules/stack/laravel-tall.md`
- Modificar: `.devorq/rules/project.md`

- [ ] **Step 1: Verificar testes RED**

```bash
bats tests/skills.bats 2>&1 | grep "thin\|laravel-tall"
```

Esperado: 2 `not ok`

- [ ] **Step 2: Adicionar regra em `laravel-tall.md`**

Inserir ao final da seção de Regras de Ouro (antes do `## Checklist Pré-Commit`):

```markdown
### 9. Thin Client, Fat Server (Segurança Obrigatória)

**Princípio**: O frontend captura a intenção do usuário. O backend valida, processa e responde.

**NUNCA fazer no frontend (JS/Alpine/Blade):**
- Lógica de negócio (cálculos de preço, desconto, permissão)
- Validação de autorização ("se o usuário é admin, mostrar X")
- Queries ou acesso direto a dados sensíveis
- Chaves de API ou secrets (nem em variáveis JS)

**SEMPRE fazer no backend (Actions/Controllers/Services):**
- Toda validação de regras de negócio
- Verificação de permissões (Policies/Gates)
- Cálculos que afetam integridade dos dados
- Decisão sobre o que retornar ao frontend

**Exemplo correto:**
```php
// ✅ Controller decide o que retornar
return response()->json([
    'pode_cancelar' => $policy->cancelar($user, $pedido),
    'valor_liquido' => $pedido->calcularValorLiquido(),
]);

// ❌ NUNCA: Alpine.js decidindo lógica de negócio
// x-show="user.role === 'admin' && pedido.valor > 1000"
```
```

- [ ] **Step 3: Adicionar regra em `rules/project.md`**

Adicionar ao final do arquivo:

```markdown
## Thin Client, Fat Server

Todo projeto DEVORQ segue este princípio de segurança:
- Frontend: captura intenção do usuário, exibe resposta do backend
- Backend: valida, processa, retorna apenas o necessário
- Nunca expor lógica de negócio, permissões ou cálculos no frontend
```

- [ ] **Step 4: Rodar testes parciais**

```bash
bats tests/skills.bats 2>&1 | grep "thin\|laravel-tall\|negócio"
```

Esperado: 2 `ok`

---

## Task 6: Atualizar `prompts/claude.md`

**Files:**
- Modificar: `prompts/claude.md`

- [ ] **Step 1: Verificar testes RED**

```bash
bats tests/skills.bats 2>&1 | grep "prompts"
```

Esperado: `not ok prompts/claude.md menciona /spec` e `not ok prompts/claude.md menciona /break`

- [ ] **Step 2: Atualizar o arquivo**

Substituir o conteúdo atual de `prompts/claude.md` por:

```markdown
# DEVORQ - Claude Code Activation

## Ativar
Use `/devorq` ou cole este prompt no início da conversa.

## Fluxo para Projetos Novos / Features Grandes (2+ páginas)
1. /spec    → documento formal de especificação → aprovação do usuário
2. /break   → lista de tasks (protótipo visual primeiro)
3. Por task → fluxo padrão abaixo

## Fluxo Padrão (por task ou feature pequena)
1. /env-context (automático — detecta stack, runtime, constraints)
2. /scope-guard (obrigatório) → [Gate 1: usuário aprova contrato]
3. /pre-flight + /schema-validate → [Gate 2: usuário aprova relatório]
4. handoff generate → [Gate 4: usuário aprova brief antes de trocar LLM]
5. TDD (RED→GREEN→REFACTOR)
6. /quality-gate (obrigatório) → [Gate 3: usuário aprova antes de commitar]
7. /session-audit (obrigatório)
8. /learned-lesson (obrigatório) → [Gate 5: usuário decide quais lições salvar]

## Rules
- SEMPRE /spec + /break para projetos novos ou features grandes
- SEMPRE /scope-guard antes de qualquer código
- SEMPRE /quality-gate antes de commit
- SEMPRE /session-audit + /learned-lesson no encerramento
- SEMPRE handoff generate antes de trocar para outro LLM
- NUNCA lógica de negócio no frontend (Thin Client, Fat Server)
- NUNCA pular gates
```

- [ ] **Step 3: Rodar testes parciais**

```bash
bats tests/skills.bats 2>&1 | grep "prompts"
```

Esperado: 2 `ok`

---

## Task 7: Validação Final e Commit

**Files:** todos os arquivos criados/modificados

- [ ] **Step 1: Rodar suite completa de testes**

```bash
bats tests/
```

Esperado:
```
1..45
ok 1 ...
...
ok 45 ...
```
Todos os 45 testes passam (26 existentes + 19 novos).

- [ ] **Step 2: Syntax check dos arquivos modificados**

```bash
bash -n bin/devorq && echo "✓ bin/devorq"
bash -n lib/orchestration/flow.sh && echo "✓ flow.sh"
```

- [ ] **Step 3: Smoke test do CLI**

```bash
./bin/devorq skills
```

Esperado: lista com 17 skills (15 existentes + spec + break)

- [ ] **Step 4: Commit**

```bash
git add tests/skills.bats \
        .devorq/skills/spec/ \
        .devorq/skills/break/ \
        .devorq/skills/constraint-loader/SKILL.md \
        .devorq/rules/stack/laravel-tall.md \
        .devorq/rules/project.md \
        prompts/claude.md

git commit -m "feat(skills): adicionar /spec e /break, regra thin-client e reuse search

- skill /spec: especificação formal antes de iniciar desenvolvimento
- skill /break: decomposição de spec em tasks (protótipo visual primeiro)
- constraint-loader: Step 0 de busca de código reutilizável
- laravel-tall.md: regra 9 Thin Client Fat Server com exemplos PHP
- prompts/claude.md: fluxo atualizado com /spec e /break para projetos grandes
- tests/skills.bats: 19 novos testes para as adições acima"
```

---

## Self-Review

### Cobertura da Spec

| Requisito da metodologia | Coberto por |
|---|---|
| Spec formal (páginas, componentes, comportamentos) | Task 2: skill `/spec` |
| Decomposição em tasks pequenas | Task 3: skill `/break` |
| Protótipo visual antes de comportamento | Task 3: regra na skill `/break` |
| Busca de reuso antes de implementar | Task 4: Step 0 no `constraint-loader` |
| Thin Client, Fat Server (segurança) | Task 5: regra em `laravel-tall.md` |
| Atualização do fluxo de ativação | Task 6: `prompts/claude.md` |
| TDD de tudo | Task 1: `tests/skills.bats` com RED→GREEN |

### O que foi EXCLUÍDO (YAGNI)

- **`/plan` como skill separada** — a metodologia tem `/plan` por task, mas isso é exatamente `/scope-guard` + `constraint-loader`. Duplicar seria overengineering.
- **`references/` como pasta nova** — DEVORQ já tem `.devorq/rules/` para documentos de referência. Adicionar pasta paralela seria redundância.
- **Agente de "task runner"** — o `/break` gera uma lista; a execução usa o fluxo normal DEVORQ por task. Não precisamos de um agente novo.
- **Versionamento de spec** — as specs ficam em `docs/spec/` com data no nome. Semver seria overhead para documentos.

### Sem Placeholders

Cada task tem: conteúdo exato dos arquivos, comandos exatos com output esperado, caminhos absolutos.

### Consistência de Tipos

- `tasklist` (kebab-case) usado consistentemente em `/break` SKILL.md e no teste
- `docs/spec/` (com barra) usado consistentemente em `/spec` SKILL.md e no teste
- `Step 0` (maiúsculo) consistente no teste e na instrução de modificação do `constraint-loader`
