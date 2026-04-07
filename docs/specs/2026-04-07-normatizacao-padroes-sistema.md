---
id: 2026-04-07-001
title: Normatização de Commits e Padronização de Fluxo DEVORQ
status: approved
created_at: 2026-04-07
updated_at: 2026-04-07
author: Gemini CLI (Devorq Agent)
domain: governance
description: Estabelecer e aplicar o padrão canônico de commits e automação de integridade para o ecossistema DEVORQ.
related_files:
  - bin/devorq
  - lib/workflow-commit.sh
  - lib/detect.sh
  - docs/specs/_index.md
  - .git/hooks/prepare-commit-msg
---

# Especificação: Normatização de Commits e Padrões

## 1. Problema
O histórico de commits atual apresenta inconsistências:
- Uso de emojis (proibido pela regra global).
- Metadados de co-autoria (`Co-Authored-By`) gerados por ferramentas externas.
- Mix de idiomas (inglês/português) nos escopos e tipos.
- Formato variando entre `tipo(escopo)` e o desejado `Escopo (Fase): Descrição`.

## 2. Objetivos
- Normalizar os últimos 20 commits para o padrão canônico.
- Corrigir a infraestrutura de detecção de stack (CLI) que apresenta falhas de sourcing.
- Automatizar a higienização de commits para impedir regressões (emojis e co-autoria).

## 3. Padrão Canônico de Commit
**Estrutura**: `Escopo (Fase): Descrição detalhada`
- **Exemplos**:
  - `Governança (Fase 1): Normalizar histórico de commits e remover co-autoria`
  - `CLI (Fase 2): Corrigir sourcing de módulos e detecção de stack`
  - `Automação (Fase 3): Implementar guard de emojis no workflow de commit`

**Restrições**:
- Idioma: Português do Brasil.
- Emojis: Proibidos em qualquer parte da mensagem.
- Co-autoria: Proibida (remover linhas `Co-Authored-By`).

## 4. Plano de Ataque (Phases)

### Fase 1: Correção da Infraestrutura (Health Check)
- Corrigir o sourcing no `bin/devorq` e `lib/detect.sh`.
- Garantir que `devorq context` funcione para extrair o estado atual.

### Fase 2: Normalização do Histórico
- Executar `git rebase -i` para os últimos 20 commits.
- Aplicar o padrão canônico a cada mensagem.
- Higienizar o corpo dos commits (remover emojis e metadados indesejados).

### Fase 3: Automação de Integridade
- Atualizar `lib/workflow-commit.sh` para validar e limpar a mensagem automaticamente.
- Configurar hook de commit para barrar emojis e co-autoria.

## 5. Critérios de Aceite (Done Criteria)
- [ ] `git log` limpo, sem emojis e sem co-autoria nos últimos 20 commits.
- [ ] Todos os títulos seguindo `Escopo (Fase): Descrição`.
- [ ] `devorq context` retornando informações corretas sem erro 127.
- [ ] `./bin/devorq init` executando sem falhas de "command not found".
- [ ] Testes de sourcing passando (`tests/sourcing.bats`).
