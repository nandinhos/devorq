# DEVORQ v2.0 — Spec de Evolução

**Data:** 2026-03-31
**Status:** Aprovado (brainstorming completo — 5 seções validadas pelo usuário)
**Versão alvo:** 2.0.0
**Versão atual:** 1.3.1

---

## Contexto

O DEVORQ é um orquestrador Bash de workflow multi-LLM. Esta spec fecha os gaps identificados na análise consolidada de 4 LLMs (Claude, Gemini, MiniMax, Antigravity) e no documento DEV_PROFILE_MASTER.md.

**Problema:** O orquestrador existe mas não funciona ponta-a-ponta. Skills são independentes, lições se perdem entre sessões, e o handoff entre LLMs depende de disciplina manual — gerando 2-3 rounds de fix por entrega.

**Solução:** 4 camadas integradas + 5 gates manuais + pipeline de auto-aprendizado local.

---

## Seção 1 — Arquitetura em Camadas

### As 4 camadas

```
┌─────────────────────────────────────────┐
│  Camada 4: Handoff Multi-LLM            │
│  Spec padronizada que viaja entre LLMs  │
├─────────────────────────────────────────┤
│  Camada 3: Auto-Aprendizado (local)     │
│  captura → Context7 → gate → diff → v   │
├─────────────────────────────────────────┤
│  Camada 2: Skills (LLM-agnóstico)       │
│  SKILL.md executável por qualquer LLM   │
├─────────────────────────────────────────┤
│  Camada 1: Orquestração (Bash)          │
│  estado, fluxo, gates, CLI              │
└─────────────────────────────────────────┘
```

### Os 5 gates manuais

Todo gate para o fluxo e apresenta ao usuário para aprovação explícita. Não há progresso automático.

| Gate | Momento | O usuário aprova |
|------|---------|-----------------|
| Gate 1 | Após /scope-guard | Contrato FAZER/NÃO FAZER/ARQUIVOS/DONE_CRITERIA |
| Gate 2 | Após /pre-flight | Relatório de validação de enums, tipos, schema |
| Gate 3 | Após /quality-gate | Checklist completo antes de commitar |
| Gate 4 | Antes do handoff | Brief completo para o próximo LLM |
| Gate 5 | Pós-sessão | Quais lições salvar para validação |
| Gate 6 | Após Context7 | Relatório de validação das lições |
| Gate 7 | Antes de aplicar | Diff proposto nas skills |

**Princípio:** Gates existem para controle e aprendizado. O usuário entende o que está sendo feito em cada etapa.

---

## Seção 2 — Skills: Gaps e Versioning

### Skills existentes (12)

Todas já implementadas em `.devorq/skills/`:
- scope-guard, pre-flight, env-context, quality-gate, session-audit
- spec-export, tdd, schema-validate, systematic-debugging
- code-review, learned-lesson, brainstorming

**Problema:** learned-lesson não está integrada ao fluxo obrigatório. As demais funcionam independentemente mas não há 3 skills essenciais.

### Skills novas a criar (3)

**1. `/handoff`**
- Objetivo: gerar spec padronizada para transferência entre LLMs sem perda de contexto
- Input: contrato ativo do scope-guard + contexto detectado + estado atual
- Output: `.devorq/state/handoffs/handoff_<timestamp>.md`
- Gate 4 obrigatório antes de salvar

**2. `/constraint-loader`**
- Objetivo: carregar artefatos relevantes por tipo de task antes da implementação
- Input: tipo de task declarado (Feature Livewire, Feature API, Migration, Bugfix)
- Output: enums, models, rotas, schema injetados no contexto
- Chamado automaticamente pelo /pre-flight

**3. `integrity-guardian`**
- Objetivo: validar padrões Livewire/Alpine antes de commitar
- Verifica: `@foreach` sem `wire:key` (erro), Alpine.js duplicado (erro), x-show vs x-if (aviso)
- Integrado como etapa adicional do /quality-gate para stack Laravel/TALL

### Estrutura de versioning

Todas as skills (existentes e novas) migram para:

```
.devorq/skills/<nome>/
├── SKILL.md          ← versão ativa (lida pelo LLM)
├── CHANGELOG.md      ← histórico semântico
└── VERSIONS/
    ├── v1.0.0.md     ← snapshot imutável
    └── v1.1.0.md     ← snapshot imutável
```

**Regras semver:**
- `PATCH` (v1.0.x): correção de instrução, erro de redação
- `MINOR` (v1.x.0): novo comportamento incorporado de lição aprendida
- `MAJOR` (vx.0.0): reescrita completa de abordagem

**Rollback:**
```bash
./bin/devorq skill rollback scope-guard v1.1.0
```

---

## Seção 3 — Pipeline de Auto-Aprendizado

### Fluxo completo

```
SESSÃO ATIVA — evento ocorre
    │
    ▼
/learned-lesson  (skill existente — integrada ao fluxo)
Captura estruturada:
  SINTOMA: o que aconteceu
  CAUSA:   por que aconteceu
  FIX:     o que resolveu
  SKILL:   qual skill deveria prevenir isso
    │
    ▼
[Gate 5] "Salvar esta lição para validação?"
    │ usuário aprova
    ▼
.devorq/state/lessons-pending/lesson_<timestamp>.md

    ─── (processamento em batch, quando o usuário quiser) ───

./bin/devorq lessons validate
    │
    ▼
MCP Context7 consulta documentação oficial
Resultado por lição:
  ✅ CONFIRMADO  — bate com docs oficiais
  ⚠️ PARCIAL     — válido mas não documentado
  ❌ INCORRETO   — contraria docs oficiais

[Gate 6] Usuário aprova relatório de validação
    │
    ▼
DEVORQ propõe diff para skill afetada:
  "Adicionar regra X em scope-guard"
  "Adicionar ao checklist de quality-gate"

[Gate 7] "Aplicar este diff?"
    │ usuário aprova
    ▼
Sistema aplica:
  SKILL.md ← atualizado (MINOR bump)
  CHANGELOG.md ← nova entrada
  VERSIONS/v<novo>.md ← snapshot imutável
  git commit: "feat(skills): incorporar lição aprendida — <skill> v<novo>"
```

### Armazenamento

Tudo local em `.devorq/state/`:
```
.devorq/state/
├── lessons-pending/    ← aguardando validação
├── lessons-validated/  ← validadas pelo Context7
└── lessons-applied/    ← incorporadas nas skills
```

Sem VPS. Hub global fica para fase futura separada.

---

## Seção 4 — Handoff Multi-LLM

### Problema

Claude analisa → passa para Gemini → Gemini não sabe sobre enums válidos, restrições de ambiente, arquivos proibidos. Resultado: 2-3 rounds de fix por constraint não comunicada.

### Solução: spec padronizada

```bash
./bin/devorq handoff generate
```

Gera `.devorq/state/handoffs/handoff_<timestamp>.md`:

```markdown
# HANDOFF DEVORQ — <timestamp>
## Destinatário: <LLM alvo>
## Projeto: <nome>

### CONTEXTO
Stack: <detectado pelo env-context>
Branch: <git branch atual>
Último commit: <hash + mensagem>

### TAREFA
<descrição da implementação — do scope-guard>

### CONSTRAINTS OBRIGATÓRIOS
Runtime: <comando base>
Portas: <app/db>
Binaries disponíveis: <lista>
NUNCA fazer: <lista de gotchas>

### ENUMS VÁLIDOS
<copiados textualmente do código>

### ARQUIVOS PERMITIDOS
<lista do contrato scope-guard>

### ARQUIVOS PROIBIDOS
<lista do contrato scope-guard>

### CRITERIO DE DONE
<checklist do contrato scope-guard>

### DECISÕES JÁ TOMADAS
<decisões registradas na sessão>

### ANTI-PATTERNS
<o que não fazer — armadilhas conhecidas>
```

### Rastreamento

```bash
./bin/devorq handoff status   # Em andamento / Aguardando merge / Concluído
./bin/devorq handoff list     # Histórico de handoffs
```

Gate 4 (manual): usuário revisa e aprova o handoff antes de passar para o próximo LLM.

---

## Seção 5 — Fluxo Ponta-a-Ponta

### Diagrama completo

```
┌──────────────────────────────────────────────────────────────┐
│  FASE 1 — PLANEJAMENTO (Claude Code)                        │
│                                                              │
│  Intent do usuário                                          │
│      → ./bin/devorq init   (detecta stack, ambiente)       │
│      → /env-context        (carrega constraints)            │
│      → /scope-guard        (gera contrato)                  │
│      → [Gate 1]            (usuário aprova contrato)        │
│      → /pre-flight         (valida enums, tipos, schema)    │
│      → /schema-validate    (confirma operações de banco)    │
│      → [Gate 2]            (usuário aprova relatório)       │
│      → handoff generate    (gera spec para próximo LLM)    │
│      → [Gate 4]            (usuário revisa brief)           │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼ handoff_<timestamp>.md
┌──────────────────────────────────────────────────────────────┐
│  FASE 2 — IMPLEMENTAÇÃO (Gemini CLI / MiniMax / OpenCode)   │
│                                                              │
│  Lê handoff file como primeira mensagem                     │
│      → TDD: RED → GREEN → REFACTOR                         │
│      → ./bin/devorq checkpoint  (salva estado parcial)     │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│  FASE 3 — VALIDAÇÃO (qualquer LLM ou manual)                │
│                                                              │
│      → /quality-gate       (testes ✅ lint ✅ escopo ✅)   │
│      → integrity-guardian  (Livewire/Alpine patterns)       │
│      → [Gate 3]            (usuário aprova antes do commit) │
│      → git commit + PR                                      │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│  FASE 4 — APRENDIZADO (pós-sessão)                          │
│                                                              │
│      → /learned-lesson     (captura estruturada)            │
│      → [Gate 5]            (quais lições salvar?)           │
│      → lessons validate    (Context7 confirma)              │
│      → [Gate 6]            (relatório correto?)             │
│      → diff proposto       (mudança nas skills)             │
│      → [Gate 7]            (aplicar diff?)                  │
│      → Skills versionadas  (MINOR bump + CHANGELOG)        │
└──────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────┐
│  FASE 5 — ENCERRAMENTO                                      │
│                                                              │
│      → /session-audit      (métricas da sessão)             │
│      → ./bin/devorq checkpoint  (estado para próxima)      │
└──────────────────────────────────────────────────────────────┘
```

### O que muda vs DEVORQ v1.x

| Antes (v1.x) | Depois (v2.0) |
|-------------|--------------|
| Skills independentes, sem fluxo obrigatório | 5 gates integram as skills no fluxo |
| Handoff manual (copiar e colar) | `./bin/devorq handoff generate` padroniza |
| Lições se perdem após sessão | Pipeline de 3 gates incorpora nas skills |
| Skills estáticas | Skills versionadas com rollback |
| /learned-lesson opcional | /learned-lesson obrigatória pós-sessão |
| Gates dependem de disciplina | Gates implementados no CLI |

---

## Plano de Implementação

Ver `/home/nandodev/.claude/plans/optimized-sparking-castle.md` para os 11 passos detalhados.

**Ordem de execução:**
1. Spec document (este arquivo)
2. Migrar 12 skills para estrutura versionada
3. Integrar /learned-lesson ao fluxo obrigatório
4. Criar skills /handoff, /constraint-loader, integrity-guardian
5. Implementar comandos CLI: lessons, handoff, skill rollback
6. Atualizar prompts LLM-agnósticos
7. Atualizar CLAUDE.md, README.md, FLUXO_DESENVOLVIMENTO.md

---

## Critério de Done

- [ ] 15 skills com estrutura SKILL.md + CHANGELOG.md + VERSIONS/
- [ ] `./bin/devorq lessons list/validate/apply` funcionando
- [ ] `./bin/devorq handoff generate/status/list` funcionando
- [ ] `./bin/devorq skill rollback <nome> <versao>` funcionando
- [ ] /learned-lesson no fluxo obrigatório de session-audit
- [ ] integrity-guardian integrado ao quality-gate
- [ ] bash -n bin/devorq e bash -n lib/*.sh sem erros
- [ ] Prompts de todos os LLMs atualizados com fluxo v2.0
