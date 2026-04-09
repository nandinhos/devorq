---
id: SPEC-2026-04-09-002
title: Padronização de Arquivos de Governança Local (AGENTS.md, GEMINI.md, CLAUDE.md)
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-09
updated_at: 2026-04-09
source: manual
related_tasks: ["TASK-GOVERNANCE-FILES"]
related_files: ["CLAUDE.md", "AGENTS.md", "GEMINI.md", ".devorq/rules/project.md"]
---

# Spec: Padronização de Arquivos de Governança Local

## 1. Problema
Atualmente, as regras de governança (especialmente a obrigatoriedade do Front Matter canônico e o uso de Gates) estão documentadas em specs isoladas, mas não estão centralizadas nos arquivos que os LLMs leem primeiro ao entrar no projeto (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`). Isso pode levar a desvios de padrão (bypass) por novos modelos que não leram o histórico de specs.

## 2. Objetivo
Unificar a "Constituição" do projeto na raiz, garantindo que qualquer LLM (Tier 1, 2 ou 3) identifique imediatamente seu papel e os contratos obrigatórios do DEVORQ v2.1.

## 3. Requisitos de Implementação

### 3.1. Criação do `AGENTS.md`
- Definir os Tiers de operação (Arquiteto, Implementador, Revisor).
- Mapear quais skills devem ser carregadas por padrão em cada Tier.
- Estabelecer a regra de que "Nenhuma implementação ocorre sem uma SPEC aprovada (Gate 1)".

### 3.2. Criação do `GEMINI.md` na Raiz
- Espelhar o rigor do `CLAUDE.md`, mas adaptado para as ferramentas do Gemini CLI.
- Incluir as restrições críticas contra a criação de campos de Front Matter fora do enum.

### 3.3. Atualização do `CLAUDE.md`
- Incluir referência direta à `SPEC-2026-04-05-001` (Governança de Specs).
- Reforçar que alterações de arquitetura exigem atualização do índice via `./bin/spec-index`.

### 3.4. Refatoração de `.devorq/rules/project.md`
- Remover templates genéricos ("Greenfield", "MVC").
- Inserir as diretrizes reais do framework (Bash puro, orquestração multi-LLM).

## 4. Critérios de Aceite
- [ ] Criação dos arquivos `AGENTS.md` e `GEMINI.md`.
- [ ] Atualização do `CLAUDE.md` e `.devorq/rules/project.md`.
- [ ] Execução do `./bin/spec-index` sem erros "N/A".
- [ ] **Validação Manual do Usuário:** Nenhuma alteração será feita até que esta SPEC seja marcada como `approved`.

## 5. Plano de Validação (Gate 1)
1. O usuário revisa o conteúdo proposto para cada arquivo.
2. O usuário aprova a SPEC alterando seu status para `approved`.
3. Somente após a aprovação, a implementação será iniciada.
