---
description: Execute devorq-upgrade DEVORQ command
---

Atualizar a infraestrutura core do DEVORQ (binários e bibliotecas) com base na versão do repositório oficial.

## Verificação de Versão

Antes de qualquer ação, verifique a paridade de versões:

```bash
# Versão Local
cat VERSION
# Versão Remota (GitHub)
git fetch origin main && git show origin/main:VERSION
```

## Regras de Diálogo

> [!IMPORTANT]
> A atualização substitui arquivos em `bin/` e `lib/`. Sempre valide a versão ANTES de sugerir o upgrade.

1.  **Se Local < Remota**: 
    - Informar: "Detectada versão local [Versão Local] defasada em relação à versão remota [Versão Remota]."
    - Perguntar: "Deseja realizar a atualização core do DEVORQ agora? Recomendo a atualização para garantir a melhor performance e acesso às novas funcionalidades."
2.  **Se Local == Remota**:
    - Informar: "Seu orquestrador já está na versão mais atual ([Versão Local])."
    - Pergunta Opcional: "Deseja forçar uma reinstalação da infraestrutura para garantir integridade?"
3.  **Aguardar Aprovação**: Continue apenas se o usuário der consentimento explícito.

## Execução Shell

Execute o comando de upgrade apontando para a raiz do projeto atual:

```bash
./bin/devorq upgrade .
```

## Pós-Execução

- Informe ao usuário que a atualização foi concluída com sucesso.
- Sugira a execução de `/devorq-info` para validar.
