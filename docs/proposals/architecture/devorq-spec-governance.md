# Proposta Técnica: Governança de Specs no DEVORQ (Sem Overengineering)

## 1. Contexto

Hoje as specs em `docs/spec/` estão no mesmo nível, com formatos de status diferentes (ou ausentes), o que dificulta:

- leitura rápida do estado real do desenvolvimento;
- priorização do que implementar;
- rastreabilidade entre spec, task e entrega.

## 2. Objetivo

Definir um padrão **mínimo e incremental** para organizar specs no projeto base do DEVORQ, preservando simplicidade operacional.

## 3. Escopo

### Inclui
- padronização de metadados das specs;
- taxonomia curta de categorias;
- enum único de status;
- índice automático de specs (visão executiva).

### Não inclui
- banco de dados para specs;
- painel web dedicado;
- engine complexa de workflow.

## 4. Proposta (MVP)

### 4.1 Metadados obrigatórios em cada spec (front matter)

```yaml
---
id: SPEC-2026-04-04-001
title: UI/UX de Importação com Progresso e Logs
domain: importacao
status: implemented
priority: high
owner: team-core
created_at: 2026-04-04
updated_at: 2026-04-04
source: devorq
related_tasks:
  - TASK-017
related_files:
  - app/Livewire/SuperAdmin/SystemInit.php
---
```

### 4.2 Enum de status único (canônico)

- `draft` (ideia inicial)
- `planning` (desenho técnico em andamento)
- `approved` (aprovada para execução)
- `in_progress` (implementação em curso)
- `implemented` (implementado)
- `validated` (implementado e validado)
- `blocked` (impedida por dependência/risco)
- `archived` (encerrada/substituída)

### 4.3 Categorias (domínios) enxutas

- `importacao`
- `ui_ux`
- `refactor`
- `arquitetura`
- `seguranca`
- `operacao`

## 5. Estrutura recomendada (fase inicial)

Manter tudo em `docs/spec/` no início para evitar migração disruptiva:

```text
docs/spec/
  2026-04-04-ui-ux-importacao-progresso-logs.md
  2026-04-04-validacao-duplicidade-importacao.md
  ...
  _index.md
```

> A separação em subpastas por categoria só deve acontecer quando houver volume alto (ex.: > 50 specs ativas).

## 6. Índice automático (`docs/spec/_index.md`)

Gerar um índice único com:

1. resumo por status (contagem);
2. resumo por categoria;
3. tabela com: ID, título, domínio, status, prioridade, última atualização;
4. alertas de inconsistência (spec sem front matter ou status inválido).

## 7. Integração DEVORQ (mínima)

### 7.1 Ajustes no fluxo `/spec`

- sempre criar spec já com front matter canônico;
- validar `status` e `domain` no momento da geração;
- bloquear saída sem metadado obrigatório.

### 7.2 Ajustes no `/devorq-audit`

Adicionar checagens leves:
- specs sem `updated_at` recente;
- specs com `status=implemented` sem evidência de validação;
- specs `blocked` sem motivo explícito.

## 8. Plano de implementação incremental

### Fase 1 — Normalização (rápida)
- criar padrão de front matter;
- atualizar specs existentes com `status/domain/id`;
- não mover arquivos.

### Fase 2 — Índice automatizado
- criar script simples (bash/php) para gerar `docs/spec/_index.md`;
- adicionar comando no DEVORQ base: `./bin/devorq spec index`.

### Fase 3 — Governança operacional
- incluir validação de metadados no `/devorq-audit`;
- opcional: falhar quality gate quando houver spec crítica sem status canônico.

## 9. Guardrails anti-overengineering

- usar apenas Markdown + script local;
- sem novo serviço, sem dashboard dedicado;
- sem modelagem relacional para specs;
- sem regras avançadas de estado (workflow engine).

## 10. Critérios de sucesso

- 100% das specs com front matter canônico;
- `_index.md` gerado automaticamente com contagens consistentes;
- qualquer pessoa identificar, em menos de 2 minutos, o que está:
  - pronto para executar (`approved`);
  - em execução (`in_progress`);
  - implementado e validado (`validated`);
  - bloqueado (`blocked`).

## 11. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Adoção parcial do padrão | médio | validar no `/devorq-audit` |
| Status desatualizado | alto | exigir `updated_at` e revisão semanal |
| Taxonomia crescer demais | médio | limitar domínios canônicos e revisar trimestralmente |

## 12. Recomendação final

Implementar a proposta em **duas entregas pequenas** (normalização + índice automático).  
Isso resolve a confusão atual com baixo custo, melhora governança do DEVORQ e evita acoplamento prematuro a soluções complexas.

