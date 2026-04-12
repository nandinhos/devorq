---
id: SPEC-0008-06-04-2026
title: Correções de Débitos Técnicos DEVORQ — Refinamento e Padronização
domain: refactor
status: implemented
priority: high
owner: team-core
created_at: 2026-04-06
updated_at: 2026-04-06
source: manual
related_tasks:
  - TASK-001
  - TASK-002
  - TASK-003
  - TASK-004
  - TASK-005
  - TASK-006
  - TASK-007
related_files:
  - .mcp.json
  - lib/mcp-fallback.sh
  - bin/spec-index
  - .claude/commands/
  - lib/detect.sh
  - lib/detection.sh
  - docs/archived/
---

# Spec — Correções de Débitos Técnicos DEVORQ

**Data**: 2026-04-06
**Status**: draft
**Autor**: DEVORQ (análise interna)

---

## Objetivo

Aplicar correções de débitos técnicos identificados no relatório de análise para elevar o nível de codificação, padronização e segurança do orquestrador DEVORQ. Todos que utilizarem o DEVORQ se beneficiarão diretamente.

---

## Fora do Escopo

- nenhuma correção citada no relatório está fora do escopo

---

## Débitos Técnicos por Prioridade

### 🔴 Crítico — Correções Imediatas

#### 1. Remover API Key exposta (.mcp.json)

- **Arquivo**: `.mcp.json`
- **Problema**: API key `CONTEXT7_API_KEY` exposta hardcoded (mesma key em 2 servers)
- **Correção**: Substituir por variável de ambiente `CONTEXT7_API_KEY` com valor padrão vazio

#### 2. Adicionar .claude/commands ao versionamento

- **Arquivo**: `.claude/commands/` (20+ arquivos não trackeados)
- **Problema**: Comandos slash não versionados — perda se pasta for recriada
- **Correção**: Adicionar ao .gitignore com exceptions ou trackear os arquivos

---

### 🟠 Alto — Correções Prioritárias

#### 3. Corrigir funções duplicadas (lib/mcp-fallback.sh)

- **Arquivo**: `lib/mcp-fallback.sh`
- **Problema**: 
  - `mcp_fallback_log()` definido nas linhas 18 e 159
  - `mcp_fallback_update_status()` definido nas linhas 30 e 176
- **Correção**: Remover duplicatas, manter apenas uma implementação de cada

#### 4. Integrar spec-index ao CLI principal

- **Arquivo**: `bin/spec-index`
- **Problema**: Script criado mas não integrado ao `./bin/devorq`
- **Correção**: Adicionar comando `spec index` ao CLI ou remover binário e documentar como usar

#### 5. Verificar overlap detect.sh/detection.sh

- **Arquivos**: `lib/detect.sh` e `lib/detection.sh`
- **Problema**: Names similar — possível duplicação de responsabilidades
- **Correção**: Analisar e unificar ou documentar diferença de propósito

---

### 🟡 Médio — Correções de Documentação

#### 6. Arquivar docs obsoletos

- **Arquivos**: 
  - `docs/ideias/inclusao_metodologia.md`
  - `docs/process-refinement/*.md`
- **Problema**: Referências a metodologias antigas, avaliações pós-implementação
- **Correção**: Mover para `docs/archived/` ou remover

#### 7. Consolidar FLUXO_DESENVOLVIMENTO.md + CLAUDE.md

- **Arquivos**: 
  - `FLUXO_DESENVOLVIMENTO.md` (15KB)
  - `CLAUDE.md`
- **Problema**: Possible overlap de conteúdo
- **Correção**: Unificar ou referenciar (não criar documentação duplicada)

---

## Regras de Negócio

1. **Compatibilidade**: Todas as correções devem manter backwards compatibility
2. **Syntax Check**: Todo shell script modificado deve passar em `bash -n`
3. **Zero Breaking**: Não quebrar funcionalidades existentes do CLI
4. **Nomenclatura**: Manter padrão snake_case para funções
5. **Testes**: Após correções, executar `./bin/devorq init` para validar

---

## Estimativa de Artefatos

| Artefato | Ação |
|----------|------|
| `.mcp.json` | Atualizar para usar variável de ambiente |
| `lib/mcp-fallback.sh` | Remover funções duplicadas |
| `bin/spec-index` | Integrar ou remover |
| `lib/detect.sh` | Analisado (pode precisar refatoração) |
| `lib/detection.sh` | Analisado (pode precisar refatoração) |
| `docs/ideias/` | Arquivar ou remover |
| `docs/process-refinement/` | Arquivar ou mover |

---

## Critérios de Aceitação (Done Criteria)

- [ ] `.mcp.json` não contém API keys hardcoded
- [ ] `.claude/commands/` está versionado ou documentado
- [ ] `lib/mcp-fallback.sh` sem funções duplicadas
- [ ] `bin/spec-index` integrado ao CLI ou removido
- [ ] Relatório de overlap detect/detection definido (unificar ou documentar)
- [ ] Docs obsoletos arquivados ou removidos
- [ ] `bash -n` passa em todos os scripts modificados
- [ ] `./bin/devorq init` funciona corretamente após correções