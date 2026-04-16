---
id: SPEC-0002-12-04-2026-nomenclatura-sequencial-global
title: Nomenclatura Sequencial Global e Comandos spec new/find
domain: arquitetura
status: implemented
priority: high
created_at: 2026-04-12
updated_at: 2026-04-12
author: Nando Dev
related_files: ["bin/devorq", "bin/spec-index", "bin/upgrade"]
---

# SPEC-0002-12-04-2026: Nomenclatura Sequencial Global e Comandos spec new/find

## Contexto

O DEVORQ implementou estrutura de subpastas por status (SPEC-0001). O próximo passo é padronizar a nomenclatura com numeração sequencial global e criar comandos úteis.

## Decisões

### 1. Nomenclatura Padrão

**Formato:**
```
SPEC-NUM-DD-MM-AAAA-SLUG.md
```

| Componente | Descrição |
|------------|-----------|
| `SPEC-` | Prefixo fixo |
| `NUM` | Número sequencial global (4 dígitos, zero-padded) |
| `DD-MM-AAAA` | Data de criação |
| `SLUG` | Título em kebab-case |

**Exemplo:** `SPEC-0003-12-04-2026-organizacao-specs.md`

### 2. Numeração Sequencial Global

**Regra:** Número é derivado dinamicamente escaneando todas as specs existentes, encontrando o MAX(NUM), e incrementando.

**Regex de extração:** `echo "$filename" | sed -n 's/SPEC-\([0-9]*\)-.*/\1/p'`

**Processo:**
1. Listar todos os arquivos `SPEC-*.md` em `docs/specs/**`
2. Extrair NUM de cada nome
3. Encontrar MAX(NUM)
4. Gerar novo NUM = MAX + 1 (formato 4 dígitos: 0001, 0002, ...)

### 3. Comando `spec new`

```bash
./bin/devorq spec new "título da spec"
```

**Comportamento:**
1. Gerar próximo NUM sequencial
2. Converter título para kebab-case
3. Criar arquivo: `docs/specs/draft/SPEC-NNNN-DD-MM-AAAA-slug.md`
4. Adicionar front matter com:
   - `id: SPEC-NNNN-DD-MM-AAAA-slug`
   - `status: draft`
   - `created_at: DD-MM-AAAA`
   - `updated_at: DD-MM-AAAA`
5. Abrir com `$EDITOR` se configurado

**Exemplo:**
```bash
./bin/devorq spec new "autenticação oauth"
# → docs/specs/draft/SPEC-0003-12-04-2026-autenticacao-oauth.md
```

### 4. Comando `spec find`

```bash
./bin/devorq spec find "busca"
```

**Comportamento:**
1. Busca fuzzy por ID ou título (case-insensitive)
2. Usa `grep -i` para encontrar matches
3. Mostra resultado formatado: ID, título, status, path

**Exemplo:**
```bash
./bin/devorq spec find "kanban"
# → SPEC-0017-11-04-2026-kanban-navegacao.md | draft | docs/specs/draft/
```

### 5. Validação no `upgrade`

Quando `devorq upgrade` detecta desvios de padronização:

**Alertas gerados:**
- Spec com nomenclatura fora do padrão
- Front matter incompleto
- Status não corresponde à pasta atual
- ID não bate com nome do arquivo

**Comportamento:**
```
[DEVORQ] Verificando padronização...
⚠ SPEC-2026-04-10-001.md: Nomenclatura não padronizada
  → Era: SPEC-YYYY-MM-DD-NNN
  → Deve ser: SPEC-NNNN-DD-MM-AAAA-slug

⚠ 3 specs com front matter incompleto

[DEVORQ] Deseja corrigir automaticamente? [y/N]
```

Se usuário escolhe `y`:
- Corrige nomenclatura
- Atualiza front matter
- Atualiza referências internas

Se usuário escolhe `N`:
- Informa comando para corrigir depois:
  ```bash
  ./bin/devorq spec validate --fix
  ```

## Arquivos a Modificar

| Arquivo | Modificação |
|---------|------------|
| `bin/devorq` | Adicionar `cmd_spec_new()` e `cmd_spec_find()` |
| `bin/devorq` | Adicionar `cmd_spec_validate()` para upgrade |
| `bin/spec-index` | Suportar novo regex de validação de ID |
| `bin/upgrade` | Chamar validação e oferecer --fix |

## Critérios de Aceite

- [ ] `devorq spec new "teste"` cria `SPEC-NNNN-...-teste.md` em draft/
- [ ] Numeração é global (não reinicia por dia)
- [ ] `devorq spec find "oauth"` retorna specs com "oauth" no título ou ID
- [ ] `devorq upgrade` detecta specs fora do padrão
- [ ] Opção de correção automática no upgrade funciona
- [ ] Regex de ID: `^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-`
