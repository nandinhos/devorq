# EXTRAS.md — DEVORQ v3

> Tópicos avançados: Context-Mode, Context7, Superpowers, HUB, Self-Building, e Debug Sistemático.

**Versão:** 4.0.0 | **Repo:** [github.com/nandinhos/devorq_v3](https://github.com/nandinhos/devorq_v3)

---

## Version Sync (sprint v3.8.5+)

O DEVORQ declara a versao em varios pontos (VERSION, bin/devorq, lib/*.sh, CHANGELOG.md, prd.json). Sem disciplina, esses pontos dessincronizam a cada release. O script `sync-version.sh` detecta e opcionalmente corrige o drift.

### Comando

```bash
./scripts/sync-version.sh --check    # CI gate (exit != 0 se drift)
./scripts/sync-version.sh --fix      # atualiza tudo para VERSION
./scripts/sync-version.sh --status   # status detalhado (exit 0 sempre)
./scripts/sync-version.sh --help     # ajuda
```

### Pontos verificados

| Ponto | Regex |
|-------|-------|
| `VERSION` (raiz) | valor canonico |
| `bin/devorq` header | `DEVORQ vX.Y.Z CLI` |
| `bin/devorq` readonly | `DEVORQ_VERSION="X.Y.Z"` |
| `bin/devorq` help | `DEVORQ vX.Y.Z - Framework` |
| `lib/*.sh` headers | `# ... vX.Y.Z` |
| `CHANGELOG.md` | `^## [X.Y.Z]` (header da versao atual) |
| `prd.json` | campo `version` |

### Integracao

Ja integrado em `scripts/ci-test.sh` (FASE 5.5). Toda execucao do CI valida consistencia de versao.

### Workflow recomendado

1. Antes de commit com escopo `release`: rode `--check`
2. Se drift: rode `--fix` antes de commitar
3. Em CI: `--check` e gate obrigatorio

### Origem

Story 4 do sprint v3.8.5 (dogfooding). Detectado em sessao de 2026-06-04 que `bin/devorq=3.8.3` enquanto `VERSION=3.8.4` (drift de 1 minor) - cenario real que motivou a feature.

---
## Context-Mode (Compressão de Contexto)

### O Problema

```
Sessão longa → contexto saturado → próximo agente perde informações
              → decisões duplicadas → mesmas falhas se repetem
```

### A Solução

Monitoramento proativo do tamanho do contexto com compressão antes que sature.

### Comandos

| Comando | Descrição |
|---------|-----------|
| `devorq context lint` | Valida context.json — campos obrigatórios |
| `devorq context stats` | Mostra tamanho em chars/tokens |
| `devorq context pack` | Comprime para handoff minimal |
| `devorq context merge` | Merge de dois contextos |
| `devorq context set <key> <val>` | Define campo |
| `devorq context clear` | Limpa contexto |

### Campos do context.json

```json
{
  "project": "nome-do-projeto",
  "intent": "o que estamos fazendo agora",
  "stack": ["bash", "jq", "postgresql"],
  "gates_completed": [1, 2, 3],
  "pending_gates": [4, 5, 6],
  "last_session": "2026-04-22T04:00:00Z",
  "pending": "implementar fase 4",
  "errors": [],
  "stuck_gates": []
}
```

### Limites de Tamanho

```
┌──────────────────┬─────────────────────────────────────────────┐
│ >60k tokens      │ ctx_pack sugere compressão                 │
│ (240k chars)     │ Alerta amarelo                              │
├──────────────────┼─────────────────────────────────────────────┤
│ >120k tokens     │ Contexto CRÍTICO                            │
│                  │ GATE-3 alerta vermelho                       │
└──────────────────┴─────────────────────────────────────────────┘
```

### GATE-3 Integration

`devorq gate 3` verifica automaticamente:
1. `context.json` existe — se não, cria com `ctx_set`
2. Campos obrigatórios — `ctx_lint` valida
3. Intent preenchido — sem intent = alerta

---

## Context7 Integration

### O Problema

> "Como saber se a documentação oficial recomenda uma abordagem diferente da que planejamos?"

### A Solução

Consultar a documentação oficial via Context7 antes de implementar.

### Configuração

```bash
# Opção 1: via env
export OPENAI_API_KEY=***

# Opção 2: via config file
echo "OPENAI_API_KEY=sk-***" >> ~/.devorq/config
```

### Comandos

| Comando | Descrição |
|---------|-----------|
| `devorq context7 check` | Verifica se API está respondendo |
| `devorq context7 search "<q>"` | Busca docs por query |
| `devorq context7 resolve "<lib>" "<query>"` | Resolve library ID + busca |
| `devorq context7 compare "<a>" "<b>" "<query>"` | Compara 2 libs |

### GATE-6 — Comportamento

```
┌──────────────────────────────────────────────────────────────┐
│  GATE-6: Context7 Checked                                     │
│                                                              │
│  API configurada + respondendo  ──────────────────► PASS ✅  │
│  API key missing                      ──────────────────► WARN ⚠️ │
│  API offline/falhou                    ──────────────────► WARN ⚠️ │
│                                                              │
│  ⚠️  GATE-6 NUNCA BLOQUEIA — É apenas um aviso              │
└──────────────────────────────────────────────────────────────┘
```

### Exemplo de Uso

```bash
# Antes de escolher SQLite vs PostgreSQL para um projeto:
devorq context7 search "postgresql vs sqlite performance"

# Validar lição aprendida contra docs:
devorq context7 resolve "mongodb/mongodb-node" "nodejs driver"

# Comparar libs para uma query:
devorq context7 compare "express" "fastify" "http server framework"
```

---

## Systematic Debugging (GATE-7)

### O Problema

> "Same bug, different day. Why do we keep fixing the same things?"

### A Solução

Workflow 4-fases. **Nenhum fix sem investigação de causa raiz.**

### Fluxo

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: CAPTURE                                           │
│  Coleta evidências: output, logs, estado do sistema          │
│  Ferramenta: debug::check (roda automaticamente em cada gate)  │
├─────────────────────────────────────────────────────────────┤
│  PHASE 2: INVESTIGATE                                       │
│  Identifica causa raiz via devorq debug interativo          │
│  Ferramentas: desk::trace, debug::recent_changes            │
├─────────────────────────────────────────────────────────────┤
│  PHASE 3: HYPOTHESIZE                                       │
│  Formula hipótese: "A hipótese explica TODO o bug?"          │
│  Regra: 3+ fixes falhados = questionar arquitetura          │
├─────────────────────────────────────────────────────────────┤
│  PHASE 4: FIX                                               │
│  Aplica fix mínimo verificado                                │
│  Volta ao gate que falhou                                    │
└─────────────────────────────────────────────────────────────┘
```

### GATE-7 — Comportamento

```
┌──────────────────────────────────────────────────────────────┐
│  GATE-7: Systematic Debug                                    │
│                                                              │
│  Tem erro?  ─────────────────────► executa devorq debug      │
│  Sem erro?  ─────────────────────► IGNORADO (passa direto)    │
│                                                              │
│  GATE-7 é REATIVO — só entra em ação quando há erro         │
└──────────────────────────────────────────────────────────────┘
```

### Uso

```bash
# Debug interativo
devorq debug "jq: command not found"

# trace de erros recentes
devorq debug trace

# ver mudanças recentes
devorq debug recent-changes
```

### Regra de Ouro

> **"NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"**
> Nenhum fix sem investigação de causa raiz primeiro.

---

## DEV-MEMORY HUB (VPS Remoto)

### Arquitetura

```
┌──────────────────────┐      SSH (mux ~0.3s)      ┌──────────────────────┐
│   DEVORQ CORE        │ ◄────────────────────────► │   VPS srv163217       │
│   (máquina local)    │                            │   187.108.197.199:6985│
│                      │                            │                       │
│   .devorq/state/     │                            │   PostgreSQL          │
│   lessons/           │                            │   ┌───────────────┐  │
│                      │                            │   │ devorq.lessons│  │
│                      │                            │   │ devorq.memories│ │
│                      │                            │   └───────────────┘  │
└──────────────────────┘                            └──────────────────────┘
```

### Tabelas

| Tabela | Descrição |
|--------|-----------|
| `devorq.lessons` | Lições aprendidas com embeddings pgvector |
| `devorq.memories` | Memórias de projeto |
| `devorq.sessions` | Histórico de sessões |
| `devorq.handoffs` | Contextos de handoff entre LLMs |

### Comandos

| Comando | Descrição |
|---------|-----------|
| `devorq sync push` | Envia lessons locais → HUB |
| `devorq sync pull` | Recebe lessons do HUB → local |
| `devorq vps check` | Testa conexão SSH |

### Acesso Direto

```bash
# SSH
ssh -p 6985 root@187.108.197.199

# PostgreSQL (via docker exec)
docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study

# Criar extension vector (primeiro acesso)
CREATE EXTENSION vector;

# Ver tabelas
\dt devorq.*
```

---

## Self-Building (Meta-Circular)

### Princípio

> **O DEVORQ constrói a si mesmo.**
> Sistema operacional → usa-se para construir a si mesmo → refina → cresce.

### Comandos

| Comando | Descrição |
|---------|-----------|
| `devorq build` | Executa todos os gates + testes |
| `devorq upgrade` | Pull latest do repo |
| `devorq uninstall` | Remove instalação (preserva lessons) |

### Fluxo de Self-Building

```
devorq build → teste + gates 1-7
     │
     ├── OK → pronto
     │
     └── ERRO → devorq debug → investigação → fix
                                          │
                     ┌────────────────────┘
                     │ (volta ao build)
                     ▼
              OK ←───┘
```

---

## Superpowers Framework

### Compatibilidade

DEVORQ pode carregar skills do Superpowers Framework via `skill_view`.

### Skills Relacionadas

| Skill | Uso |
|-------|-----|
| `systematic-debugging` | GATE-7 workflow |
| `test-driven-development` | Antes de implementar |
| `github-code-review` | Antes de commit |
| `plan` | Decomposição de tasks |
| `subagent-driven-development` | Multi-LLM workflows |

### Carregar Skill

```bash
# Via Hermes Agent:
skill_view(name="systematic-debugging")

# O agente carrega o SKILL.md e segue automaticamente
```

---

## Handoff Multi-LLM

### Problema

> Trocar de LLM no meio de uma sessão perde contexto.

### Solução

Gerar contexto compactado para o próximo agente.

### Geração

```bash
devorq compact            # Gera .devorq/state/handoff.json
devorq gate 5            # Valida que handoff está pronto
```

### Estrutura do Handoff

```json
{
  "handoff": {
    "project": "devorq_v3",
    "intent": "implementar feature X",
    "stack": ["bash", "jq"],
    "gates_completed": [1, 2, 3, 4, 6],
    "pending_gates": [5],
    "untracked_files": [],
    "timestamp": "2026-04-22T14:30:00Z"
  }
}
```

### Recepção

```bash
# No novo agente:
devorq context merge handoff.json
```

---

## Tips & Tricks

### jq Fallback

Se `jq` não estiver disponível, todas as funções usam fallback grep/sed:

```bash
# jq está em ~/bin/jq (instalado sem root)
export PATH="$HOME/bin:$PATH"
```

### Bash Strict Mode

DEVORQ usa `set -euo pipefail` em todos os scripts.

```
-e  : sai ao primeiro erro
-u  : erro em variável não definida
-o pipefail : falha em pipe propaga
```

### Cores (ANSI-free)

```bash
RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
# Compatibilidade máxima — funciona em qualquer terminal
```

### Debugging

```bash
# Modo verbose
devorq -v gate 3

# Ver função
declare -f ctx_lint

# Trace de erros
bash -x bin/devorq gate 3
```

---

## Troubleshooting Rápido

| Sintoma | Solução |
|---------|---------|
| `devorq: command not found` | `cp bin/devorq ~/bin/ && chmod +x ~/bin/devorq` |
| `lib/gates.sh not found` | `DEVORQ_ROOT=/path/to/devorq; export DEVORQ_ROOT` |
| GATE-6 sempre warn | Configurar `OPENAI_API_KEY` em `~/.devorq/config` |
| `context.json` não encontrado | Executar `devorq init` no projeto |
| jq errors | `curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 -o ~/bin/jq && chmod +x ~/bin/jq` |
| SSH "Connection refused" | Verificar VPS online: `ssh -p 6985 -o ConnectTimeout=5 root@187.108.197.199` |
| PostgreSQL connection refused | Verificar container: `docker ps \| grep postgres` |

---

## Arquitetura Detalhada

```
DEVORQ CORE (/projects/devorq_v3)
│
├── bin/devorq                  # CLI — source libs → executa comandos
│
├── lib/
│   ├── lessons.sh             # lessons::capture|search|validate|apply|sync_vps|export
│   ├── gates.sh               # gates::check|g1|g2|g3|g4|g5|g6|g7
│   ├── compact.sh             # compact::run — handoff JSON
│   ├── context.sh             # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh            # ctx7_check|search|resolve|compare
│   ├── debug.sh               # debug::check|trace|recent_changes + devorq::debug
│   ├── stats.sh               # stats::run — métricas de uso
│   └── vps.sh                 # vps::check|exec|pg_exec (SSH mux)
│
├── scripts/
│   ├── sync-push.py           # local → HUB (json.dumps escape)
│   └── sync-pull.py           # HUB → local (downloaded/)
│
└── .devorq/                   # Estado local (NÃO COMMITEAR)
    ├── state/
    │   ├── context.json
    │   ├── session.json
    │   └── lessons/
    └── version
```

---

**Versão:** 4.0.0
**Repo:** https://github.com/nandinhos/devorq_v3
**Última atualização:** 2026-05-22
