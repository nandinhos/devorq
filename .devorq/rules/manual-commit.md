# Regra: Commits Manuais

## Regra Rígida: Aguardar Validação Manual

### ❌ NÃO FAÇA:
- Commits automáticos após implementação
- Commits parciais durante desenvolvimento
- Push sem autorização

### ✅ FAÇA:
1. Implemente a funcionalidade
2. Execute e valide os testes
3. **AGUARDE** confirmação manual
4. **AGUARDE** confirmação para push

## Fluxo Obrigatório

```
[Implementação] → [Testes] → [Solicitar Commit] → [Aguardar OK] → [Commit]
                                                                       ↓
                                                              [Solicitar Push] → [Aguardar OK] → [Push]
```

## Como Solicitar

Antes de fazer commit, pergunte:
```
Posso fazer o commit?
- Tipo: feat(escopo): descrição
```

Antes de fazer push:
```
Posso fazer o push para origin?
```

## Excessões

- Correções de sintaxe óbvias (`bash -n`)
- shellcheck warnings críticos
-Documentação de ajuda (`--help`)

## Exceção: modo AUTO (`DEVORQ_AUTO_COMMIT`)

Esta regra vale para **commits manuais** e para o modo **CLASSIC**. No modo
**AUTO** (`devorq auto` com `DEVORQ_AUTO_COMMIT=1`), o loop faz **commit automático
por story** após o sub-agente implementar e o loop verificar a story (fail-closed:
só marca done/commita se a mudança foi produzida; dry-run/dry-run sem diff não
commita). Precedência:

- `DEVORQ_AUTO_COMMIT=1` → **commit automático por story** (exceção autorizada ao habilitar o modo AUTO).
- Sem a flag, ou modo CLASSIC → **vale esta regra**: aguardar confirmação manual.
- **Push nunca é automático** — mesmo no AUTO, `git push` exige autorização explícita.

## Status

**Ativo desde:** 2026-05-21  
**Responsável:** Fernando Dos Santos (Nando)
