---
name: handoff
description: Gerar spec padronizada para transferência de contexto entre LLMs sem perda de constraints
triggers:
  - "handoff"
  - "trocar LLM"
  - "passar para Gemini"
  - "passar para MiniMax"
  - "handoff generate"
globs:
  - ".devorq/state/context.json"
  - ".devorq/state/contracts/"
---

# /handoff — Transferência Multi-LLM

> **Regra de Ouro**: Todo handoff entre LLMs passa por este gate. Sem brief padronizado = sem handoff.

## Quando Usar

Antes de transferir a continuação de uma tarefa para outro LLM (Gemini CLI, MiniMax, OpenCode, Antigravity).
Também usado quando a sessão atual atingiu o limite de contexto e precisa continuar em nova sessão.

## Como Gerar

```bash
./bin/devorq handoff generate
```

Ou manualmente: preencher o template abaixo com base no contrato ativo do /scope-guard e no contexto detectado.

## Template do Handoff File

O LLM deve gerar o seguinte documento e apresentar ao usuário antes de salvar (Gate 4):

```markdown
# HANDOFF DEVORQ — [timestamp]
## Destinatário: [Gemini CLI / MiniMax / OpenCode / Antigravity]
## Gerado por: [LLM atual]
## Projeto: [nome do projeto]

### CONTEXTO
- Stack: [detectado pelo /env-context]
- Branch: [branch atual]
- Último commit: [hash abreviado + mensagem]
- Status: [o que foi feito até aqui]

### TAREFA
[Descrição completa do que precisa ser implementado — extraída do contrato /scope-guard]

### CONSTRAINTS OBRIGATÓRIOS
- Runtime: [comando base, ex: vendor/bin/sail artisan]
- Portas: app=[porta] | db=[porta]
- Binaries disponíveis: [lista — ex: PDO sim, mysql binary não]
- Variáveis de ambiente obrigatórias: [ex: WWWUSER=1000]
- NUNCA fazer: [lista de gotchas conhecidos]

### ENUMS E TIPOS VÁLIDOS
[Copiar textualmente do código — não inferir, não inventar]
Ex:
- CashflowType: ENTRADA | SAIDA | TRANSFERENCIA
- ContractStatus: PENDING | ACTIVE | COMPLETED

### ARQUIVOS PERMITIDOS
[Lista exata do contrato /scope-guard]

### ARQUIVOS PROIBIDOS
[Lista exata do contrato /scope-guard — não tocar]

### CRITÉRIO DE DONE
[Checklist do contrato /scope-guard]
- [ ] item 1
- [ ] item 2

### DECISÕES JÁ TOMADAS
[Decisões arquiteturais tomadas nesta sessão — evita redecisão]

### ANTI-PATTERNS
[O que não fazer — armadilhas identificadas nesta ou em sessões anteriores]
```

## Gate 4 — Aprovação Obrigatória

Após gerar o handoff file, apresentar ao usuário e aguardar aprovação explícita antes de salvar.

```
[Gate 4] Handoff gerado. Revisar antes de passar para o próximo LLM:
→ [exibir conteúdo]

Confirmar? (s/n)
```

Só salvar em `.devorq/state/handoffs/handoff_<timestamp>.md` após aprovação.

## Rastreamento de Status

```bash
./bin/devorq handoff status   # Em andamento / Aguardando merge / Concluído
./bin/devorq handoff list     # Histórico de handoffs da sessão
```

## Instruções para o LLM Receptor

O LLM que receber o handoff deve:
1. Ler o handoff file como **primeira ação** da sessão
2. Confirmar que entendeu constraints e arquivos proibidos
3. Executar `/pre-flight` para validar enums e tipos antes de implementar
4. Nunca ignorar a seção ARQUIVOS PROIBIDOS

---

> **Débito que previne**: Perda de constraints no handoff multi-LLM, 2-3 rounds de fix por context não comunicado
