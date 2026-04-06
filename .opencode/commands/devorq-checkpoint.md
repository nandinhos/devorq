Criar checkpoint de continuidade DEVORQ.

Execute:
```bash
./bin/devorq checkpoint
```

Se o CLI não estiver disponível, criar manualmente:

## Checkpoint Manual

Salvar em `.devorq/state/checkpoints/checkpoint_<timestamp>.md`:

```markdown
# Checkpoint — [timestamp]

## Git State
- Branch: [git branch --show-current]
- Último commit: [git log --oneline -1]
- Arquivos pendentes: [git status --short]

## Contexto
- Stack: [do context.json]
- LLM: [atual]
- Task em andamento: [descrição]

## Progresso
- Concluído: [lista]
- Pendente: [lista]
- Próximo passo: [ação imediata ao retomar]

## Warnings
- [Gotchas conhecidos]
- [Dependências externas pendentes]
```

## Quando Usar

- Antes de encerrar sessão (rate limit, fim do dia)
- Antes de trocar de LLM (`handoff generate` + checkpoint)
- Após cada fase do fluxo em tasks complexas

Após criar o checkpoint, confirmar: "Checkpoint salvo. Pode encerrar com segurança."
