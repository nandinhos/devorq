---
id: SPEC-0022-08-04-2026
title: Alinhamento Slash Commands v2.1
domain: arquitetura
status: draft
priority: medium
owner: team-core
created_at: 2026-04-08
updated_at: 2026-04-08
source: manual
related_tasks: []
related_files: []
---

# Alinhamento Slash Commands v2.1

## Objetivo

Integrar e padronizar os novos comandos do DEVORQ v2.1 (`info`, `skills`, `upgrade`) como Slash Commands (workflows) para facilitar a gestão, monitoramento e atualização do orquestrador pelo desenvolvedor.

## Fora do Escopo

- Alterar o código-fonte do binário `./bin/devorq` ou de suas bibliotecas.
- Realizar atualizações de projetos ou outras tarefas que não estejam discriminadas neste escopo de infraestrutura de comandos.
- Modificar o comportamento fundamental do comando `upgrade` no shell.

## Interfaces / Workflows

| Nome | Descrição | Comportamento Esperado |
|------|-----------|-----------|
| `.agents/workflows/devorq-info.md` | Exibe estado e versão do projeto. | Executa `./bin/devorq info`. |
| `.agents/workflows/devorq-skills.md` | Lista skills e versões. | Executa `./bin/devorq skills`. |
| `.agents/workflows/devorq-upgrade.md` | Atualiza o orquestrador. | **Interativo**: pergunta ao usuário antes de agir; recomenda atualização para performance. |
| `SLASH_COMMANDS.md` | Documentação central de comandos. | Tabela atualizada com os 3 novos comandos. |

## Regras de Negócio

1. **Interatividade no Upgrade**: O workflow `/devorq-upgrade` não deve executar a atualização silenciosamente; deve sempre solicitar confirmação explícita do usuário após verificar a versão.
2. **Sugerir no Início**: O comando de upgrade deve ser sugerido em fluxos iniciais (como `/devorq-start`) quando houver indicação de melhor performance ou versão defasada em relação ao `origin/main`.
3. **Consulta Remota**: O workflow de upgrade deve buscar a versão de referência em `https://github.com/nandinhos/devorq.git` ou via `git fetch` para comparar com o `VERSION` local.
4. **Invocação de Binário**: Todos os workflows devem priorizar o uso do binário local `./bin/devorq` para garantir que a versão core v2.1 seja utilizada.
5. **Alinhamento de Nomenclatura**: O comando de atualização deve ser estritamente `/devorq-upgrade`, mantendo o padrão do repositório base.

## Entidades

- **Workflow**: Arquivos markdown em `.agents/workflows/` que definem as instruções para a LLM.
- **SlashCommand**: A entrada documentada no `SLASH_COMMANDS.md` que o usuário utiliza no terminal.
- **Binário**: O script shell `./bin/devorq` que executa a lógica real dos comandos core.
