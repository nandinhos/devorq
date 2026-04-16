---
id: SPEC-2026-04-07-upgrade-multiproject
title: Upgrade Multi-Projeto DEVORQ v2.1
domain: arquitetura
status: draft
priority: medium
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: []
related_files: []
---

# Upgrade Multi-Projeto DEVORQ v2.1

## Objetivo

Padronizar, estabilizar e atualizar todos os projetos que utilizam o orquestrador DEVORQ, garantindo que utilizem a versão estável mais recente (v2.1) e as skills atualizadas (como code-review v2.0), mantendo a paridade total com o repositório base.

## Fora do Escopo

- Criação de especificações (`/spec`) para as funcionalidades das aplicações finais.
- Alteração de código-fonte, regras de negócio ou lógica das aplicações hospedadas nos projetos.
- Modificação de arquivos que não pertençam à estrutura do DEVORQ (`bin/`, `lib/`, `.devorq/`).

## Componentes Envolvidos

| Nome | Tipo | Descrição |
|------|-----------|----------------|
| **Core CLI** | Binário | Arquivo `bin/devorq` e `bin/devorq-prompt`. |
| **Módulos Shell** | Bibliotecas | Todos os scripts em `lib/*.sh` e `lib/orchestration/*.sh`. |
| **Skills** | Instruções/Prompts | Diretório `.devorq/skills/*` contendo a lógica das skills. |
| **Versão Global** | Metadados | Arquivo `VERSION` na raiz do projeto. |

## Regras de Negócio Críticas

1. **Paridade Total**: O destino deve refletir exatamente a estrutura e conteúdo do repositório base para os componentes citados.
2. **Agnosticidade**: Manter o suporte a múltiplos LLMs (Antigravity, Gemini, Claude, etc.) sem configurações hardcoded.
3. **Integridade de Sessão**: Não interferir nos estados de sessão (`.devorq/state/`) ou regras de projeto preexistentes (`.devorq/rules/project.md`).
4. **Executabilidade**: Garantir permissões de execução (`chmod +x`) para os binários atualizados.

## Projetos Alvo (Gatekeepers)

- `eventos-control`
- `qrcodexxx`
- `transcriptor`
- `nandorag`
- `qrxxx`

## Modelos de Dados

- **Session State** — JSON contendo a versão atual e metadados de detecção de stack.
- **Skill Definition** — Estrutura de diretório contendo `SKILL.md` e `CHANGELOG.md`.
