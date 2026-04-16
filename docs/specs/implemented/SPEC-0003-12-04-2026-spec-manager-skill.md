---
id: SPEC-0003-12-04-2026-spec-manager-skill
title: Estrutura de Specs com Subpastas por Status
domain: arquitetura
status: implemented
priority: high
created_at: 2026-04-12
updated_at: 2026-04-12
author: Nando Dev
related_files: ["bin/spec-index", "bin/devorq", ".devorq/hooks/pre-commit", "AGENTS.md", "GEMINI.md", "README.md"]
owner: team-core
source: manual
related_tasks: []
---

# SPEC-0003-12-04-2026-spec-manager-skill: Estrutura de Specs com Subpastas por Status

## Contexto

O DEVORQ usa `docs/specs/` como diretório canônico de specs. O sistema atual:
- Todas as specs ficam na raiz de `docs/specs/`
- `bin/spec-index` gera `_index.md` com visão agregada (não recursivo)
- Não suporta `backlog` nem `proposal` como status
- Superpowers salva specs em `docs/superpowers/specs/` — local alternativo

**Problema:** Sem estrutura de subpastas, não há indicação visual do status. Arquivos "voam" soltos, e o índice é a única forma de saber o estado.

## Decisões

### 1. Estrutura de Subpastas

Cada spec vive fisicamente na pasta correspondente ao seu `status`:

```
docs/specs/
├── _index.md
├── backlog/          # Ideias brutas (texto, imagens, anotações)
├── brainstorming/   # Specs em estruturação
├── draft/           # Rascunhos prontos para aprovação
├── approved/        # Aprovadas, aguardando implementação
├── planning/        # Em planejamento
├── in_progress/     # Em execução
├── validated/       # Validadas
├── implemented/     # Implementadas
├── blocked/         # Bloqueadas
└── archived/        # Arquivadas
```

### 2. Enum de Status (Completo)

```bash
status_enum=(backlog brainstorming draft approved planning in_progress validated implemented blocked archived)
```

### 3. Movimentação Automática

**Regra:** Quando `status` muda no front matter, o arquivo é movido para a subpasta correspondente.

**Comando `devorq spec move`:**
```bash
./bin/devorq spec move <id> <novo_status>
```
- Lê front matter do arquivo
- Move fisicamente para `docs/specs/<novo_status>/`
- Atualiza `updated_at` no front matter

### 4. Nome dos Arquivos

```
SPEC-NUM-DD-MM-AAAA-TITLE.md
LESSON-NUM-DD-MM-AAAA-TITLE.md
```

Onde:
- `NUM` = número sequencial global (001, 002... — NÃO reinicia diariamente)
- `DD-MM-AAAA` = data de criação
- `TITLE` = título em kebab-case

**Exemplos:**
- `SPEC-001-12-04-2026-estrutura-specs-subpastas-status.md`
- `SPEC-017-15-04-2026-autenticacao-oauth.md`
- `LESSON-003-10-04-2026-bash-source-guard.md`

**Justificativa:** Numeração global permite rastrear historicamente quando cada spec foi criada e a sequência de desenvolvimento do projeto.

## Fluxo de Vida de uma Spec

```
backlog/          (ideia bruta)
    ↓ brainstorming/
    ↓ draft/
    ↓ approved/
    ↓ planning/
    ↓ in_progress/
    ↓ validated/
    ↓ implemented/
```

## Arquivos a Modificar

| Arquivo | Modificação |
|---------|-------------|
| `bin/spec-index` | Glob recursivo `**/*.md`, enum completo |
| `bin/devorq` | Novo subcomando `spec move` |
| `.devorq/hooks/pre-commit` | Executa `spec move` se status mudou |
| Superpowers config | Altera default path para `docs/specs/` |
| `AGENTS.md` | Atualiza ref de path |
| `GEMINI.md` | Atualiza ref de path |
| `README.md` | Atualiza documentação |

## Backward Compatibility

- Specs existentes na raiz são migradas opcionalmente via script
- Arquivos sem front matter válido são ignorados pelo index
- `_index.md` continua sendo gerado automaticamente

## Critérios de Aceite

- [ ] `bin/spec-index` busca recursivamente em subpastas
- [ ] Enum inclui todos os 10 status
- [ ] `devorq spec move <id> <novo_status>` move arquivo corretamente
- [ ] Hook pre-commit detecta mudança de status e move arquivo
- [ ] Superpowers salva specs direto em `docs/specs/` (não em subdir do Superpowers)
- [ ] `_index.md` é gerado sem erros com specs em subpastas
