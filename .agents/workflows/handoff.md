---
description: Execute handoff DEVORQ command
---

Gerar spec de handoff para transferência de contexto para outro LLM.

Leia `.devorq/skills/handoff/SKILL.md` para instruções completas.

Ou executar via CLI:
```bash
./bin/devorq handoff generate
```

## Template do Handoff (preencher manualmente se CLI indisponível)

```markdown
# HANDOFF DEVORQ — [timestamp]
## Destinatário: [Gemini CLI / Claude / OpenCode / Antigravity]
## Gerado por: Claude
## Projeto: [nome]

### CONTEXTO
- Stack: [detectado]
- Branch: [git branch atual]
- Último commit: [git log --oneline -1]
- Status: [o que foi feito até aqui]

### TAREFA
[Descrição completa extraída do contrato /spec]

### CONSTRAINTS OBRIGATÓRIOS
- Runtime: [ex: vendor/bin/sail artisan]
- Portas: app=[porta] | db=[porta]
- Variáveis: [ex: WWWUSER=1000]
- NUNCA fazer: [gotchas conhecidos]

### ENUMS E TIPOS VÁLIDOS
[Copiar textualmente do código — NUNCA inferir]

### ARQUIVOS PERMITIDOS
[Lista exata do contrato]

### ARQUIVOS PROIBIDOS
[Lista exata — não tocar]

### DONE CRITERIA
- [ ] item 1
- [ ] item 2

### DECISÕES JÁ TOMADAS
[Evita redecisão pelo próximo LLM]

### ANTI-PATTERNS
[O que não fazer — armadilhas identificadas]
```

## Gate 4

Apresentar o handoff ao usuário e aguardar aprovação antes de salvar.
Salvar em `.devorq/state/handoffs/handoff_<timestamp>.md` somente após aprovação.
