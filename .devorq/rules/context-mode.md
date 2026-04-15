# Context-Mode — Modo Monstro

## Ativação

Ativado automaticamente quando `detect_context_mode()` retorna `active:HASH:SIZE`.

## Regras de Ouro

1. **ctx_search PRIMEIRO**: Antes de ler arquivos, tente busca no índice
2. **Hierarquia de ferramentas**: ctx_search > ctx_execute > ctx_batch_execute > Read/grep
3. **Auto-indexing**: Outputs grandes são indexados automaticamente
4. **Handoff indexing**: Outputs de handoff são indexados para próximo LLM

## Critérios de Indexação

| Tipo | Mínimo | Exemplo |
|------|--------|---------|
| File read | 5KB+ | Read app/Models/Contract.php |
| Command output | 100 chars | bash ls -la |
| grep/search | qualquer | grep "function" |

## Quando NÃO usar ctx_search

- Busca exata de arquivo已知 (use Read direto)
- Operações de escrita/criação
- Comandos interativos

## Comandos

```bash
devorq context-mode status   # Verificar modo monstro
devorq context-mode stats     # Estatísticas do DB
devorq context-mode doctor   # Diagnóstico do ctx
devorq context-mode init     # Inicializar sessão
devorq context-mode index    # Re-indexar projeto
devorq context-mode search "<query>"  # Buscar no índice
```

## Métricas

- Redução média: ~45%
- Tempo salvo: +35min/sessão
- Break-even: ~7 sessões (240min ÷ 35min/sessão)
- ROI break-even: ~4h implementação ÷ 35min/sessão ≈ 7 sessões

## Filosofia

O Modo Monstro existe para eliminar trabalho redundante:
- Re-indexação de 400+ arquivos a cada sessão = LIXO
- Tokens desperdiçados em contexto redundante = LIXO
- Rate limits por falta de cache = LIXO

Com ctx_search, o contexto já está indexado. Próximo LLM recebe instantly o que precisa.

## Status do Sistema

O status é verificado automaticamente pelo `devorq init` eShown no `devorq info`.