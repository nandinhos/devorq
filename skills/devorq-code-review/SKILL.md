---
name: devorq-code-review
description: DEVORQ-CODE-REVIEW v1.0.0 — Review autônomo multi-agente com confidence scoring. Segue o padrão UltraReview/Claude Code: eligibility → contexto → 5 review agents paralelo → scoring 0-100 → filtro ≥80 → approval gate → output no chat (NÃO publica no PR automaticamente — você decide). Integra com systematic-debugging para issues identificadas e devorq-auto para verificação de cada story. Modelo-agnóstico: o agente escolhe o melhor modelo disponível para cada fase.
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, code-review, multi-agent, confidence-scoring, parallel-review, systematic-debugging, devorq-auto]
    related_skills: [systematic-debugging, devorq-auto, verification-before-completion, github-code-review]
    stack: [bash, jq, git, delegate_task]
---

# DEVORQ-CODE-REVIEW v1.0.0

## Visão Geral

Sistema de code review autônomo em 9 fases. Multi-agente paralelo com confiança quantificada. Identifica issues, quantifica certeza, filtra ruído, integra debug quando necessário — mas **nunca publica no PR sem sua aprovação explícita**.

Modelo-agnóstico: o agente detecta quais LLMs estão disponíveis (MiniMax, Claude, GPT, Gemini) e escolhe o melhor para cada fase — Haiku-level para eligibility/scoring (barato), Sonnet-level para review profundo.

## Arquitetura de Fases

```
┌──────────────────────────────────────────────────────────────────┐
│                    9-FASE REVIEW PIPELINE                         │
│                                                                   │
│  [0] ELIGIBILITY    → Haiku-level: para cedo se não precisa      │
│  [1] CONTEXT        → 2 agentes //: CLAUDE.md + diff summary     │
│  [2] REVIEW //      → 5 agentes //: 5 dimensões especializadas   │
│  [3] SCORING        → N agentes //: 0-100 por issue             │
│  [4] FILTER         → Descarta issues < 80                       │
│  [5] DEBUG          → systematic-debugging SE issues > 0         │
│  [6] APPROVAL       → VOCÊ valida antes de qualquer ação         │
│  [7] REPORT         → Output formatado no chat                   │
│                                                                   │
│  Resultado: JSON estruturado → você decide o que fazer           │
└──────────────────────────────────────────────────────────────────┘
```

## Quando Usar

- Após cada story implementada no `devorq-auto`
- Antes de abrir PR ou solicitar review humano
- Como gate de quality em `verification-before-completion`
- Após correções de bugs identificados
- Antes de merge em branches importantes

**Trigger:** `code review`, `review this`, `analisar código`, `devorq review`

## Step-by-Step (Fase a Fase)

---

### FASE 0: ELIGIBILITY CHECK

**Objetivo:** Parar cedo se não precisa de review.

```
Pergunta ao agente (Haiku-level ou modelo mais barato disponível):
  "This PR is eligible for code review if:
   - NOT closed
   - NOT draft
   - NOT trivial (not just formatting/linting/typos)
   - NOT already reviewed by this agent in this session

   Check: PR state, diff size, file count.
   If NOT eligible → STOP, return {eligible: false, reason: "..."}
   If eligible → proceed to Phase 1"
```

**Critérios de elegibilidade:**
- PR fechada? → não revisar
- É draft? → não revisar
- Só mudou 1-2 arquivos com mudanças triviais (indent, typos, comments)? → não revisar
- É automated (dependabot, renovate, etc)? → não revisar
- É merge de main em hotfix? → review mínimo

**Exit:** Se não elegível → reportar motivo e parar.

---

### FASE 1: CONTEXT COLLECTION

**Objetivo:** Alimentar os review agents com informação relevante.

Dois agentes em paralelo:

**Agente A — SPEC/CLAUDE.md hunting:**
```
Find ALL relevant guidance files:
- ./SPEC.md (DEVORQ spec do projeto)
- ./CLAUDE.md (regras do projeto para IA)
- ./claude.md
- ./docs/*.md (policies, conventions)
- Any file in modified directories named *CLAUDE.md or *SPEC.md

Return a LIST of files found with their paths.
Do NOT read the contents — just list the paths.
```

**Agente B — PR/Diff Summary:**
```
Summarize what this PR/branch changes:
- Overall purpose (1-2 sentences)
- List of modified files
- Lines added/deleted per file
- Any test files modified?
- Any new dependencies?

Get this from: git diff main...HEAD --stat
Or if PR: gh pr diff --name-only + summary
```

**Exit:** Duas listas: `guidance_files[]` e `diff_summary`.

---

### FASE 2: PARALLEL REVIEW (5 AGENTES)

**Objetivo:** Análise profunda em 5 dimensões, cada agente focado em uma.

Todos os agentes rodam **em paralelo** via `delegate_task` (até 3 simultâneos — respeitando o teto de concorrência do projeto).

**Agente 1 — SPEC/CLAUDE.md Compliance:**
```
You are a compliance auditor. Check if the changes in this PR/branch
adhere to the project's own rules defined in SPEC.md and CLAUDE.md files.

Rules to check (from CLAUDE.md / SPEC.md):
- [LISTA DE REGRAS DOS ARQUIVOS ENCONTRADOS NA FASE 1]

Changes (diff):
- [O DIFF COMPLETO OU RESUMO DOS ARQUIVOS MODIFICADOS]

Check:
- Are any CLAUDE.md rules being violated?
- Are SPEC.md acceptance criteria being met?
- Are there explicit rules in docs that are being ignored?

Return ONLY valid JSON:
{
  "issues": [
    {
      "file": "path/to/file.ext",
      "line": 42,
      "rule": "rule name from CLAUDE.md",
      "description": "what was found",
      "evidence": "code snippet from the change"
    }
  ],
  "passed": true/false
}
```

**Agente 2 — Bug Scan (só nas mudanças):**
```
You are a bug detection specialist. Focus ONLY on the changes,
NOT on the existing code.

Shallow scan for OBVIOUS bugs:
- Logic errors (wrong conditionals, wrong operators)
- Missing null checks / empty state handling
- Unhandled exceptions in new code
- Resource leaks (unclosed files, connections)
- Race conditions in concurrent code
- Security vulnerabilities in new code

DO NOT flag:
- Style issues
- Missing tests (unless explicitly required in CLAUDE.md)
- Pre-existing bugs
- Issues a linter/typechecker would catch

Changes:
- [O DIFF OU LISTA DE ARQUIVOS MODIFICADOS]

Return ONLY valid JSON:
{
  "issues": [
    {
      "file": "path",
      "line": 42,
      "type": "logic_error|security|null_check|resource_leak|race_condition",
      "description": "what the bug is",
      "why_real": "why this is actually a bug and not a false positive"
    }
  ],
  "passed": true/false
}
```

**Agente 3 — Git History Context:**
```
You are a historical context analyst. Use git blame and history
to understand WHY the code was written a certain way.

For the modified files:
1. git log --oneline -10 -- <file>  → recent history
2. git blame <file>  → who wrote what
3. Look for patterns: repeated bug fixes, architectural constraints,
   commented-out code, TODO explanations

Check if the changes might break something that was intentionally
done a specific way because of past issues.

Changes:
- [LISTA DE ARQUIVOS MODIFICADOS + DIFF RESUMIDO]

Return ONLY valid JSON:
{
  "issues": [
    {
      "file": "path",
      "line": 42,
      "historical_context": "what the history shows about this code",
      "risk": "how the change might violate that context"
    }
  ],
  "passed": true/false
}
```

**Agente 4 — PR History (comentários passados):**
```
You are a PR history analyst. Look for patterns in past PRs.

For modified files, check:
- git log --oneline -20 -- <files>
- Look for PRs that touched these files
- Check if there were PR comments, discussions, or decisions
  that should apply to this PR

Common patterns:
- "We don't do X because Y" comments in past PRs
- Architectural decisions in previous commits
- Comments from reviewers that should be addressed

Changes:
- [LISTA DE ARQUIVOS MODIFICADOS]

Return ONLY valid JSON:
{
  "issues": [
    {
      "file": "path",
      "past_pr": "PR number or commit that established the pattern",
      "decision": "what was decided in that PR",
      "violation": "how this PR violates that decision"
    }
  ],
  "passed": true/false
}
```

**Agente 5 — Code Comments Compliance:**
```
You are a code comment auditor. The code has comments that
explain WHY things are done a certain way.

Check:
- Do the changes respect existing comments in the code?
- Does the code contradict an explanatory comment?
- Are new comments added to explain non-obvious choices?
- Are TODO/FIXME/HACK comments still relevant after the change?

Changes:
- [O DIFF COMPLETO]

Return ONLY valid JSON:
{
  "issues": [
    {
      "file": "path",
      "line": 42,
      "comment": "the existing comment",
      "violation": "how the change contradicts it"
    }
  ],
  "passed": true/false
}
```

---

### FASE 3: CONFIDENCE SCORING

**Objetivo:** Quantificar a certeza de cada issue (0-100).

Para CADA issue encontrada nas 5 fases acima, lançar um agente (Haiku-level ou modelo mais barato):

```
You are a confidence scorer. Rate this issue from 0-100.

ISSUE:
- File: {file}
- Line: {line}
- Type: {type}
- Description: {description}
- Evidence: {evidence}

GUIDANCE FILES (for CLAUDE.md compliance issues):
- [LISTA DE CONTEÚDO DOS ARQUIVOS DE REGRAS]

SCORING RUBRIC (follow EXACTLY):
  0  = FALSE POSITIVE obvious. Doesn't hold up to scrutiny.
       Pre-existing issue, or doesn't actually violate anything.
  25 = MAYBE real. Might be a bug but might be a false positive.
       Could not verify. Stylistic issue not in CLAUDE.md.
  50 = REAL but minor. Confirmed real issue but nitpick.
       Unlikely to happen in practice. Low importance.
  75 = HIGHLY CONFIDENT. Very likely real and important.
       Verified. Will impact functionality.
       OR explicitly mentioned in CLAUDE.md.
 100 = ABSOLUTELY CERTAIN. Confirmed real, happens frequently.
       Direct evidence. No doubt.

FALSE POSITIVES (do NOT score high):
- Pre-existing issues (not introduced by this PR)
- Issues a linter/typechecker/compiler would catch
- Nitpicks a senior engineer wouldn't call out
- Style issues not in CLAUDE.md
- Intentional changes related to the PR purpose
- Lines the author did NOT modify
- Issues silenced by lint-ignore comments

Return ONLY valid JSON:
{
  "issue_hash": "unique hash of this issue",
  "score": 0-100,
  "reasoning": "1-2 sentences why this score"
}
```

---

### FASE 4: FILTER (THRESHOLD ≥ 80)

**Objetivo:** Descartar ruído — só issues com score ≥ 80 seguem.

```python
# Pseudocode
all_issues = phase2_issues_flattened
scored_issues = phase3_results  # [(issue, score)]

final_issues = []
for issue, score in scored_issues:
    if score >= 80:
        issue.confidence = score
        final_issues.append(issue)
    else:
        # Logged as filtered: score, reason
        pass

if final_issues is empty:
    review_result = CLEAN  # No issues above threshold
else:
    review_result = ISSUES_FOUND  # Proceed to Phase 5
```

---

### FASE 5: SYSTEMATIC DEBUGGING (SE ISSUES > 0)

**Objetivo:** Para cada issue ≥ 80, investigar root cause ANTES de propor fix.

**Carregar skill:** `systematic-debugging`

Para cada issue:

```
[LOAD SYSTEMATIC_DEBUGGING SKILL]

Issue: {issue_description}
File: {file}:{line}

Before proposing ANY fix, follow Phase 1-3 of systematic-debugging:
1. Reproduce: Can you trigger this bug? What are exact steps?
2. Gather evidence: git blame, git log, related code
3. Trace: Where does the bad value originate? Upstream?
4. Root cause: WHY is this happening?

REPORT: Root cause only. DO NOT fix yet.
If root cause is unclear → escalate to user.
```

**Importante:** Esta fase NÃO tenta corrigir — só investiga. Fix vem depois, na FASE 6 (usuário decide).

**Se NÃO há issues (FASE 4 clean):** Pular FASE 5 e ir direto para FASE 7 (REPORT).

---

### FASE 6: MANUAL APPROVAL GATE ⛔

**Objetivo:** VOCÊ valida antes de qualquer ação.

Apresentar o report formatado e perguntar:

```
═══════════════════════════════════════════════════════════
⛔  MANUAL APPROVAL REQUIRED
═══════════════════════════════════════════════════════════

{REPORT COMPLETO - ver formato abaixo}

AÇÕES DISPONÍVEIS:

[A]  Tudo OK — prosseguir (git commit, PR, etc)
[B]  Corrigir issues identificadas — dispatch fix agent
[C]  Ver details de uma issue específica
[D]  Ignorar issue X (aceitar risco manualmente)
[E]  Abortar review — nenhuma ação

Escolha: _
═══════════════════════════════════════════════════════════
```

**Você pode pedir:** details, root cause explanation, ou escolher uma das ações.

---

### FASE 7: REPORT (OUTPUT FORMATADO)

**Objetivo:** Report claro no chat para sua decisão.

```
═══════════════════════════════════════════════════════════
🔍 CODE REVIEW REPORT
═══════════════════════════════════════════════════════════

PR/Branch: {branch_name} → main
Files: {n} changed ({adds} / -{dels})
Review Date: {timestamp}

─────────────────────────────────────────
📋 SUMMARY
─────────────────────────────────────────
{summary_sentence}

Issues Found: {n} (threshold: confidence ≥ 80)
  🔴 Critical (90-100): {n}
  🟠 High (80-89):      {n}
  🟡 Filtered (<80):    {n} (excluded)

─────────────────────────────────────────
🔴 ISSUES (sorted by confidence)
─────────────────────────────────────────

1. [CRITICAL] {title}
   File: {file}:{line}
   Confidence: {score}/100
   Type: {type}
   Root Cause: {from_phase5}
   Evidence:
   ```diff
   {code_snippet}
   ```

2. [HIGH] {title}
   ...

─────────────────────────────────────────
✅ COMPLIANCE CHECKS PASSED
─────────────────────────────────────────
- SPEC.md adherence: PASS
- CLAUDE.md rules: PASS
- Git history context: PASS
- Code comments: PASS
- No pre-existing issues flagged

─────────────────────────────────────────
📊 ELIGIBILITY
─────────────────────────────────────────
Status: ELIGIBLE
Reason: Active PR, non-trivial changes, no prior review

═══════════════════════════════════════════════════════════
```

---

### FASE 8: POST-REVIEW (voc decide)

Após sua aprovação:

```
O que deseja fazer?

[A] Gerar script de correção das issues (devorq-auto integra)
[B] Apenas registrar — sem ação (para acompanhamento manual)
[C] Gerar patch diff das correções (para você aplicar manualmente)
[D] Publicar no GitHub PR (recomendado SOMENTE se confiável)
```

**NUNCA publicar no PR automaticamente.** Você é o gate.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Review completo — issues encontradas reportadas |
| 1 | PR/branch não elegível (draft, closed, trivial) |
| 2 | Abortado pelo usuário (FASE 6) |
| 3 | Nenhum diff para revisar (sem mudanças) |
| 4 | Erro de execução (delegate fallhou, etc) |

## Integração com devorq-auto

Usar como **gate de verificação** após cada story implementada:

```bash
# No loop-auto.sh, após delegate e antes de commit:
devorq-code-review/scripts/review.sh "$PROJECT_ROOT" --branch HEAD
# Se exit 0 + issues < threshold → commit
# Se issues ≥ threshold → approval gate
```

Integrar via skill no agent que executa o loop:

```
AFTER delegate_task implementation of a story:
  1. Load devorq-code-review skill
  2. Run phases 0-5
  3. IF issues >= threshold → PAUSE, show report, wait for approval
  4. IF approved → proceed to check-story.sh + commit
  5. IF rejected → systematic-debugging + fix loop
```

## Integração com systematic-debugging

- FASE 5 é o ponto de integração formal
- SE o fix agent da FASE 5/6 encontrar problemas → systematic-debugging entra
- Root cause investigation ANTES de qualquer fix proposto

**Ordem de respeito:**
1. Review identifica issue → FASE 5 investiga
2. Investigação revela root cause → FASE 6 propõe fix
3. Fix introduz novo bug → systematic-debugging skill carregada
4. Ciclo: review → debug → fix → re-review (1 ciclo só)

## False Positives — Lista Autoritativa

**NÃO reporte como issue:**

1. ❌ Pre-existing bugs (não introduzidos por esta PR)
2. ❌ Issues que linter/typechecker/compilador pegaria
3. ❌ Nitpicks que um sênior não chamaria
4. ❌ Falta de tests (a menos que CLAUDE.md exija)
5. ❌ Style issues não em CLAUDE.md
6. ❌ Mudanças intencionais relacionadas ao propósito da PR
7. ❌ Linhas que o autor NÃO modificou
8. ❌ Issues silenciadas por lint-ignore comments
9. ❌ Obvious improvements (sugira, não reporte como bug)
10. ❌ Changes that look different but are functionally equivalent

## Dependências

```bash
git          # diff, blame, log
delegate_task # spawne sub-agentes (nativo Hermes)
jq           # parsing de JSON dos resultados
python3      # script de orquestração (opcional)
gh (opcional) # se interagindo com GitHub PRs
```

## Limitações

- Modelos sem capacidade de reasoning profundo reduzem qualidade do scoring
- Se todos os LLMs disponíveis falham → exit 4 com log do erro
- Issues muito complexas (arquiteturais) → escalar para você diretamente
- Review sem diff concreto (só descrição) → qualidade reduzida

---

**Versão:** 1.0.0
**Criado em:** 2026-04-23
**Padrão:** DEVORQ + UltraReview/Claude Code + Systematic Debugging
