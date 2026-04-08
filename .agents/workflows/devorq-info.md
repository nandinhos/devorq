---
description: Execute devorq-info DEVORQ command
---

Exibir informações de estado, versão e caminhos do projeto DEVORQ.

## Execução

Inspecionar o contexto local e remoto:

```bash
# Contexto Local
./bin/devorq info
# Comparar com GitHub (Referência v2.1+)
git fetch origin main && git show origin/main:VERSION
```

## Próximos Passos

- Se local < remoto: Marque o projeto como **DEFASADO** e sugira `/devorq-upgrade`.
- Se local == remoto: Confirme que o sistema está em **Day Zero Stability**.
- Se as skills não estiverem listadas, sugira `/devorq-skills`.
