---
id: SPEC-0066-16-04-2026-pipeline-lessons-learned-gates-67
title: Pipeline de Lições Aprendidas — Gates 6 e 7 com Validação Automática
domain: arquitetura
status: draft
priority: high
author: Nando Dev
owner: team-core
created_at: 2026-04-16
updated_at: 2026-04-16
related_tasks: []
related_files:
  - lib/lessons.sh
  - .devorq/skills/learned-lesson/SKILL.md
  - .devorq/state/lessons-pending/
  - .devorq/state/lessons-validated/
  - .devorq/state/lessons-applied/
  - .devorq/state/lessons-learned/
---

# SPEC-0066: Pipeline de Lições Aprendidas — Gates 6 e 7

## Contexto

O sistema de lições aprendidas do DEVORQ (SPEC-0004 Seção 3) foi parcialmente implementado. As lições são capturadas via Gate 5 (`/learned-lesson`), mas o pipeline de Gates 6 e 7 não está completo.

**Problema:** `devorq lessons validate` gera um prompt manual que o usuário precisa copiar e colar. Não há integração automática com Context7, não há geração de diff, e não há fluxo para aplicar lições às skills.

**Solução:** Implementar Gates 6 e 7 completos conforme SPEC-0004 Seção 3.

---

## Arquitetura do Pipeline

### Estrutura de Diretórios

```
.devorq/state/
├── lessons-pending/      ← Gate 5: lições capturadas, aguardando validação
├── lessons-validated/    ← Gate 6: validadas, aguardando aplicação
└── lessons-applied/       ← Gate 7: diff aplicado, aguardando commit manual
```

### Fluxo Completo

```
[Gate 5] /learned-lesson
         │
         ▼
lessons-pending/
         │
         ▼
[Gate 6] devorq lessons validate
         │  1. Chama Context7 via MCP (automático)
         │  2. Classifica: CONFIRMADO | PARCIAL | INCORRETO
         │  3. Gera diff_proposed
         │  4. Aguarda aprovação
         │  5. Move para lessons-validated/
         ▼
lessons-validated/
         │
         ▼
[Gate 7] devorq lessons apply <nome>
         │  1. Exibe diff para edição
         │  2. Aguarda Gate 7 (usuário aprova/edita)
         │  3. Snapshot: cp SKILL.md → VERSIONS/
         │  4. Aplica diff no SKILL.md
         │  5. CHANGELOG atualizado
         │  6. Move para lessons-applied/
         ▼
[CHECAGEM FUNCIONAL MANUAL]
         │
         ▼
[GIT COMMIT MANUAL]
```

---

## Gate 6: Validação Automática — `devorq lessons validate`

### Comando

```bash
devorq lessons validate
```

### Fluxo

```
1. Ler lições de lessons-pending/
2. Para cada lição:
   a. Identificar skill_target (campo SKILL AFETADA)
   b. Consultar Context7 MCP:
      - Query: "documentação oficial da skill {skill_target}"
      - Validar prática da lição contra docs
   c. Classificar resultado:
      - CONFIRMADO: prática validada pelos docs
      - PARCIAL: válida mas não documentada
      - INCORRETO: contraria docs oficiais
   d. Gerar diff_proposed baseado na lição
3. Exibir relatório ao usuário
4. Aguardar Gate 6 (aprovação)
5. Mover lições aprovadas para lessons-validated/
```

### Relatório Gerado

```markdown
=== VALIDAÇÃO DE LIÇÕES ===

### LESSON-0012-07-04-2026-bash-source-guard
Skill Target: quality-gate
Classificação: CONFIRMADO
Detalhes: Prática confirmada pela documentação oficial Bash.

Diff Proposto:
```diff
+ ## Nova Regra: Bash Source Guard
+ Ao criar libs shell, usar guard de sourcing:
+ ```bash
+ [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0
+ ```
+ **Quando:** Criação de qualquer lib em lib/
+ **Verificação:** shellcheck não reporta erros
```
```

### Interação Gate 6

```
[Gate 6] Revisar relatório acima.
  [ENTER] - Mover lições para lessons-validated/
  [q]     - Sair sem aplicar
```

---

## Gate 7: Aplicação Híbrida — `devorq lessons apply <nome>`

### Comando

```bash
devorq lessons apply LESSON-0012
```

### Fluxo

```
1. Ler lição de lessons-validated/
2. Exibir diff_proposed para revisão
3. Aguardar Gate 7:
   - Usuário pode editar o diff no editor
   - [ENTER] aplica o diff conforme está
   - [q] cancela
4. Snapshot: cp SKILL.md → VERSIONS/v<x.y+1.z>.md
5. Aplicar diff no SKILL.md
6. CHANGELOG: entrada >> CHANGELOG.md
7. Version bump: MINOR
8. Mover lição para lessons-applied/
9. Output: instrução de commit manual
```

### Interação Gate 7

```
=== APLICAR LIÇÃO: LESSON-0012 ===

Diff proposto para quality-gate:
```diff
+ ## Bash Source Guard
+ Ao criar libs shell, usar guard de sourcing:
+ [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0
```
[ENTER]  - Aplicar diff (com snapshot)
[e]      - Editar diff no editor
[q]      - Cancelar
```

### Output Pós-Aplicação

```
Snapshot criado: .devorq/skills/quality-gate/VERSIONS/v2.1.0.md
Diff aplicado: .devorq/skills/quality-gate/SKILL.md
CHANGELOG atualizado.
Lição movida para: .devorq/state/lessons-applied/

=== PRÓXIMOS PASSOS ===
1. Teste a funcionalidade impacted
2. Verifique que não há regressions
3. Commit manual quando validado:
   git add -A && git commit -m "feat(skill): incorpora lição LESSON-0012 - bash source guard"
```

---

## Estrutura de Lição Atualizada

### Lição em lessons-pending/

```markdown
---
id: LESSON-XXXX
title: Bash Source Guard
skill_target: quality-gate
status: pending
created_at: 2026-04-07
---

## SINTOMA
Libs shell não carregavam via source.

## CAUSA
Guard invertido.

## FIX
[[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0

## SKILL AFETADA
quality-gate
```

### Lição em lessons-validated/

```markdown
---
id: LESSON-XXXX
title: Bash Source Guard
skill_target: quality-gate
status: validated
validation_result: CONFIRMADO
validation_details: Confirmado pela documentação Bash oficial.
diff_proposed: |
  + ## Bash Source Guard
  + Ao criar libs shell, usar guard de sourcing.
  + Verificação: shellcheck passa.
created_at: 2026-04-07
validated_at: 2026-04-16
---

## SINTOMA
[original]

## CAUSA
[original]

## FIX
[original]
```

### Lição em lessons-applied/

```markdown
---
id: LESSON-XXXX
title: Bash Source Guard
skill_target: quality-gate
status: applied
validation_result: CONFIRMADO
diff_applied: true
applied_version: 2.1.0
applied_at: 2026-04-16
skill_snapshot: VERSIONS/v2.1.0.md
---

[conteúdo original]
```

---

## Comandos CLI

### `devorq lessons list`

Lista lições em todos os estágios.

```bash
=== LIÇÕES PENDENTES ===
  [1] LESSON-0012-bash-source-guard
  [2] LESSON-0014-antigravity-handoff
Total pendentes: 2

=== LIÇÕES VALIDADAS ===
  [1] LESSON-0012 (confirmado)
Total validadas: 1

=== LIÇÕES APLICADAS ===
  Nenhuma aplicação pendente de commit.
```

### `devorq lessons validate`

Executa Gate 6 — validação Context7 automática.

### `devorq lessons apply <nome>`

Executa Gate 7 — aplicação de diff.

### `devorq lessons diff <nome>`

Mostra diff sem aplicar (preview).

---

## Implementação em `lib/lessons.sh`

### Funções a Criar/Modificar

| Função | Ação | Descrição |
|--------|------|-----------|
| `lessons_validate()` | Reescrever | Context7 automático + classificação |
| `lessons_generate_diff()` | Criar | Gera diff baseado em lição + skill |
| `lessons_apply()` | Reescrever | Diff editável + snapshot + apply |
| `lessons_move_validated()` | Criar | Move lição após Gate 6 |
| `lessons_get_validation()` | Criar | Chama Context7 via MCP |

### Versionamento de Skill

```bash
# Criar snapshot
cp SKILL.md VERSIONS/v<x.y+1.z>.md

# Atualizar CHANGELOG
echo "## v<x.y+1.z> ($(date +%Y-%m-%d))" >> CHANGELOG.md
echo "- [Descrição da lição incorporada]" >> CHANGELOG.md
```

---

## Skill `learned-lesson` v2

### Atualizações no SKILL.md

1. **Front matter atualizado:**
   ```yaml
   fields:
     - skill_target
     - validation_result
     - diff_proposed
     - status: pending|validated|applied
   ```

2. **Documentação do novo fluxo Gates 6/7**

3. **Exemplos de diff gerado**

---

## Critérios de Aceite

| # | Critério | Verificação |
|---|----------|-------------|
| 1 | `devorq lessons validate` chama Context7 automaticamente | MCP retorna classificação |
| 2 | Relatório mostra classificação e diff | Output formatado |
| 3 | `devorq lessons apply` exibe diff editável | Diff visível antes de aplicar |
| 4 | Snapshot criado antes de modificar | VERSIONS/ contém snapshot |
| 5 | CHANGELOG atualizado com entrada | Entrada visível no arquivo |
| 6 | Lição movida para lessons-applied/ | ls lessons-applied/ |
| 7 | Usuário consegue commitar manualmente | git status shows changes |

---

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Context7 MCP não responde | Baixa | Médio | Fallback: classificação MANUAL |
| Diff quebra skill | Média | Alto | Snapshot + rollback disponíveis |
| Conflito de versão | Baixa | Baixo | Semantic versioning + snapshots |

---

## Tarefas de Implementação

| # | Tarefa | Prioridade |
|---|--------|------------|
| T1 | Atualizar `lib/lessons.sh` com Gates 6/7 | alta |
| T2 | Atualizar skill `learned-lesson` v2 | alta |
| T3 | Criar SPEC de análise das 9 lições | alta |
| T4 | Testar pipeline completo | média |
| T5 | Migração das lições existentes | média |

---

## Decisões

1. **Context7 automático**: Chamado via MCP dentro de `lessons_validate()`
2. **Diff híbrido**: Sistema gera, usuário edita antes de aplicar
3. **Commit manual**: Após checagem funcional do usuário
4. **Semantic versioning**: patch/minor/major conforme lição

---

## Histórico de Alterações

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-04-16 | Nando Dev | Criação desta spec |
