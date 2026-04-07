---
id: SPEC-2026-04-06-002
title: "Correção de 15 Débitos Técnicos — Code Review DEVORQ"
domain: refactor
status: draft
priority: high
owner: team-core
created_at: 2026-04-06
updated_at: 2026-04-06
source: manual
related_tasks: []
related_files:
  - lib/orchestration/flow.sh
  - lib/mcp-health-check.sh
  - lib/core.sh
  - lib/mcp-fallback.sh
  - bin/devorq
---

# Spec — Correção de 15 Débitos Técnicos — Code Review DEVORQ

**Data**: 2026-04-06 | **Status**: rascunho

---

## Objetivo

Corrigir os 15 débitos técnicos identificados no code review profundo de 2026-04-06, organizados em 3 sprints por prioridade de risco. O objetivo é eliminar falhas de corretude no fluxo principal, endurecer segurança no manejo de `.env`, aumentar cobertura de testes do próprio código Bash, e melhorar portabilidade e manutenibilidade — sem overengineering.

## Usuários / Contexto de Uso

- Engenheiros que instalam e operam o DEVORQ em projetos reais (Linux/macOS)
- LLMs que consomem o CLI para orquestrar fluxos de desenvolvimento
- Pipeline de CI/CD que executa quality-gate no repositório

---

## Fora do Escopo

- Reescrita da arquitetura de módulos (achado 11 — será aplicado apenas `shellcheck` + extração mínima onde há duplicação óbvia)
- Adição de novos comandos ou features ao CLI
- Mudanças em skills `.devorq/skills/`
- Alterações em agentes `.devorq/agents/`

---

## Sprint 1 — Corretude e Risco Alto (itens 1, 2, 5, 12, 13)

### Achado 1 — Heredoc sem quoting em `flow.sh`
**Arquivo**: `lib/orchestration/flow.sh:280`
**Problema**: `<< EOF` com crases no conteúdo executa caminhos Markdown como comandos Bash.
**Solução**: Trocar para `<< 'EOF'` (heredoc literal) e interpolar apenas variáveis necessárias de forma explícita.

### Achado 2 — Captura poluída por logs em `run_full_flow`
**Arquivo**: `lib/orchestration/flow.sh:33-65` e `:373-376`
**Problema**: `phase1_detection` escreve logs no stdout; `context=$(phase1_detection)` captura logs + payload misturados; `cut -d:` opera sobre múltiplas linhas.
**Solução**: Redirecionar todos os `log_*` para stderr (`>&2`); manter stdout apenas para payload estruturado.

### Achado 5 — Path incorreto em `mcp_health_all`
**Arquivo**: `lib/mcp-health-check.sh:189`
**Problema**: `source ".devorq/lib/stack-detector.sh"` — arquivo não existe nesse caminho (está em `lib/`).
**Solução**: Usar path absoluto derivado de `$DEVORQ_ROOT` com fallback explícito.

### Achado 12 — CI não cobre o próprio código Bash do DEVORQ
**Arquivo**: `.github/workflows/quality-gate.yml`
**Problema**: O workflow cobre stacks downstream (Laravel/Python/Node) mas não executa `shellcheck` nem `bats` no próprio código Bash do DEVORQ.
**Solução**: Adicionar job `quality-bash` que execute: `shellcheck bin/devorq lib/*.sh lib/**/*.sh` + `bats tests/` com cobertura dos fluxos críticos.

### Achado 13 — Testes cobrem estrutura, não comportamento
**Arquivo**: `tests/skills.bats`, `tests/paths.bats`, `tests/sourcing.bats`
**Problema**: Predominam asserts de existência de arquivo/grep; `flow`, `handoff update`, `spec update`, parsing de estado sem cobertura funcional.
**Solução**: Adicionar testes comportamentais de ponta-a-ponta com fixtures temporárias (`mktemp -d`) para os 3 fluxos críticos: `flow`, `handoff`, `spec`.

---

## Sprint 2 — Segurança e Robustez (itens 6, 7, 15, 14)

### Achado 6 — Regex injection em `set_env_value`
**Arquivo**: `lib/core.sh:355-357`
**Problema**: `grep "^$key="` e `sed "s|^$key=.*|...|"` sem escaping de metacaracteres regex.
**Solução**: Validar chave com `[[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]]`; escapar valor para `sed` com `printf '%s\n' "$value" | sed 's/[[\.*^$()+?{|]/\\&/g'`.

### Achado 7 — Parsing frágil de `.env`
**Arquivo**: `lib/core.sh:331-341`
**Problema**: `IFS='=' read -r key value` + `xargs` no key pode truncar/alterar valores válidos com `=` no conteúdo (`JWT=aaa=bbb`) e strings com espaços. Conforme documentação oficial Bash (§3.6.5), a forma correta é preservar tudo após o primeiro `=`.
**Solução**: Substituir por parser que preserve conteúdo após o primeiro `=` sem `xargs` destrutivo:
```bash
while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="${key// /}"
    export "$key"="$value"
done < "$env_file"
```

### Achado 15 — `.devorq/logs/` sem entry no `.gitignore`
**Arquivo**: `.gitignore`
**Problema**: `mcp-fallback.sh` cria `.devorq/logs/mcp-fallback.log` mas `.devorq/logs/` não está coberto no `.gitignore`.
**Solução**: Adicionar `.devorq/logs/` ao `.gitignore`.

### Achado 14 — `jq` assumido disponível sem política clara
**Arquivo**: `lib/mcp-fallback.sh`, `README.md`
**Problema**: `jq` é usado sem fallback validado em vários módulos; README não declara como dependência obrigatória.
**Solução**: Definir `jq` como dependência obrigatória; adicionar check no bootstrap do CLI com mensagem de erro clara e instrução de instalação.

---

## Sprint 3 — Manutenibilidade e Portabilidade (itens 3, 8, 9, 10, 11)

### Achado 3 — Duplicação em `mcp-fallback.sh`
**Arquivo**: `lib/mcp-fallback.sh:18-52` e `:159-201`
**Problema**: Duas versões de `_mcp_fallback_log`/`mcp_fallback_log` e `_mcp_fallback_update_status`/`mcp_fallback_update_status` com lógica idêntica.
**Solução**: Manter apenas a versão pública (`mcp_fallback_*`) removendo as privadas (`_mcp_fallback_*`); ajustar chamadas internas.

### Achado 8 — Word-splitting em loops de arquivo
**Arquivo**: `bin/devorq:315,373`, `lib/handoff.sh:162`
**Problema**: `for f in $file_list` e `for f in $(ls ...)` quebram com espaços/caracteres especiais em paths.
**Solução**: Substituir por globs nativos (`for f in "$dir"/*.md`) ou `while IFS= read -r f`.

### Achado 9 — `sed -i` sem compatibilidade BSD/macOS
**Arquivo**: `bin/devorq:385-386`, `lib/handoff.sh:194`, `lib/feature-lifecycle.sh:322,358,393,449,540`
**Problema**: `sed -i` GNU sem extensão falha em BSD sed (macOS).
**Solução**: Criar helper `sed_inplace()` em `lib/core.sh` que detecte GNU/BSD e aplique flags corretas:
```bash
sed_inplace() {
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}
```

### Achado 10 — Versão inconsistente
**Arquivo**: `README.md`, `bin/devorq`, `VERSION`
**Problema**: README=v2.1, `VERSION`=1.3.1, CLI ainda por verificar. Três declarações conflitantes.
**Solução**: Definir versão canônica como **2.1** em `VERSION`; CLI lê `VERSION` em runtime; README referencia sempre `VERSION`.

### Achado 11 — God files (manutenibilidade)
**Arquivo**: `lib/feature-lifecycle.sh` (1047 linhas), `lib/orchestration.sh` (732), `lib/state.sh` (652), `bin/devorq` (612)
**Abordagem**: Sem reescrita arquitetural. Aplicar apenas:
- `shellcheck` em todos os módulos (já coberto pelo achado 12)
- Remover duplicações óbvias (coberto pelo achado 3)
- Mínimo: verificar se há funções órfãs/mortas e removê-las

---

## Regras de Negócio Críticas

1. **Nenhuma mudança de comportamento externo** — todos os comandos CLI devem produzir o mesmo output observável após os fixes
2. **Testes existentes devem continuar passando** — `bats tests/` verde antes e depois de cada sprint
3. **Sem dependências novas** — apenas `bash`, `git`, `jq` (já assumido) e `shellcheck` (apenas CI)
4. **Versão canônica = 2.1** — prevalece sobre qualquer outra declaração no repo
5. **Heredocs literais** (`<< 'EOF'`) sempre que o conteúdo não exige interpolação de variáveis Bash

---

## Arquivos Modificados

### Sprint 1
- `lib/orchestration/flow.sh` — heredoc + stderr
- `lib/mcp-health-check.sh` — path fix
- `.github/workflows/quality-gate.yml` — job bash
- `tests/` — novos testes comportamentais

### Sprint 2
- `lib/core.sh` — `set_env_value` + `load_env`
- `.gitignore` — `.devorq/logs/`
- `bin/devorq` (bootstrap) — check `jq`

### Sprint 3
- `lib/mcp-fallback.sh` — remover duplicação
- `bin/devorq:315,373` — word-splitting
- `lib/handoff.sh:162` — word-splitting
- `lib/feature-lifecycle.sh` — sed_inplace
- `lib/handoff.sh` — sed_inplace
- `bin/devorq` — sed_inplace + lê VERSION
- `VERSION` — valor 2.1
- `lib/core.sh` — helper sed_inplace

---

## Done Criteria

- [ ] `bash -n bin/devorq lib/*.sh lib/**/*.sh` sem erros
- [ ] `shellcheck bin/devorq lib/*.sh lib/**/*.sh` sem warnings
- [ ] `bats tests/` 100% verde (existentes + novos)
- [ ] `./bin/devorq flow "teste"` executa sem erros de substituição de comando
- [ ] `./bin/devorq --version` exibe `2.1`
- [ ] `VERSION` contém `2.1`
- [ ] CI passa com job `quality-bash`
- [ ] `.devorq/logs/` ignorado pelo git
- [ ] `set_env_value "KEY" "val=com=igual"` preserva valor corretamente
- [ ] `load_env` preserva valores com espaços e `=` no conteúdo
