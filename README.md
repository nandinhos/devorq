# DEVORQ v3

> **Framework bash puro** para metodologia de desenvolvimento sistemático.
> Captura lições aprendidas, impõe gates bloqueantes, gera handoffs consistentes.
> **Repo:** [github.com/nandinhos/devorq_v3](https://github.com/nandinhos/devorq_v3) | **Autor:** Fernando Dos Santos (Nando)

**Versão:** 4.0.0

> **Última release (2026-07-03):** v4.0.0 — Elite Hardening (breaking). Gates **fail-closed no nível de processo**: `devorq flow` agora retorna exit `!=0` em gate falho (antes: sempre `0`) e `devorq::error` aborta. GATE-2 fail-closed + detecção Node. Convenção de commit unificada em `tipo(escopo)` (o hook rejeita `escopo(fase)`). Modo AUTO robusto (no-diff guard, stop-criteria, flock, headless-safe) + **adapters de delegação multi-runner** (claude/codex/hermes/opencode/agy). Segurança: `jq --arg` no parser de PRD. Migração e detalhes em [`CHANGELOG.md`](CHANGELOG.md), [`docs/REFACTOR-ELITE-PLAN.md`](docs/REFACTOR-ELITE-PLAN.md) e [`docs/CODE_REVIEW_ELITE_2026-07-02.md`](docs/CODE_REVIEW_ELITE_2026-07-02.md).
>
> **Histórico Git (2026-05-23):** `main` reorganizado por release (1 commit/versão). Re-clone recomendado após atualizar.

---

## O Problema que o DEVORQ Resolve

```
Sessão longa → contexto saturado → próximo agente perde informações
              → decisões duplicadas → mesmas falhas se repetem
              → tempo perdido
```

**DEVORQ** é uma CLI bash que impõe disciplina:
- **Gates bloqueantes** — nada avança sem verificação
- **Lições aprendidas** — nunca mais o mesmo erro
- **Handoffs consistentes** — próximo agente começa onde você parou
- **Disciplina do agente** (v3.8+) — regras Karpathy adaptadas via `devorq rules bootstrap`

---

## Quick Start

```bash
# 1. Instalar (repo completo — bin/devorq depende de lib/)
git clone https://github.com/nandinhos/devorq_v3.git ~/projects/devorq_v3
ln -s ~/projects/devorq_v3/bin/devorq ~/bin/devorq   # ~/bin no PATH
# (detalhes e alternativas: INSTALL.md)

# 2. Inicializar projeto
cd /projects/meu-projeto
devorq init

# 3. Workflow completo
devorq flow "implementar feature X"

# 4. Capturar lição aprendida
devorq lessons capture "jq install rootless Docker" \
  --problem "jq binary needed but no apt-get" \
  --solution "curl -L jq-linux64 to ~/bin" \
  --stack bash --tags docker,jq

# 5. Sincronizar com HUB (opcional)
devorq sync push
```

---

## Os Gates (Bloqueantes)

```
┌────────┬──────────────────────────────────────┬───────────────────────────────────────────────┐
│ GATE   │ NOME                                  │ CRITÉRIO                                      │
├────────┼──────────────────────────────────────┼───────────────────────────────────────────────┤
│  G-0   │ Exploration (opcional)               │  env-context + DDD keywords                   │
│  G-0.5 │ Project Foundation (NOVO!)           │  5W2H, Premissas, Riscos, Requisitos OK     │
│  G-1   │ Spec Exists                          │  SPEC.md existe e não vazio                  │
│  G-2   │ Tests Pass                            │  devorq test passa                           │
│  G-3   │ Context Documented                   │  devorq context mostra estado                  │
│  G-4   │ Lessons Reviewed                     │  lições relevantes encontradas                 │
│  G-5   │ Handoff Ready                        │  devorq compact gera JSON válido              │
│  G-6   │ Context7 Checked                      │  docs consultadas (nunca bloqueia)            │
│  G-7   │ Systematic Debug                      │  se erro: devorq debug primeiro              │
└────────┴──────────────────────────────────────┴───────────────────────────────────────────────┘
```

**Regra:** Vermelho = para e corrige. Verde = segue em frente.

### GATE-0.5 — Project Foundation

Antes de qualquer implementação, o DEVORQ valida **5 documentos de contexto de projeto**:

| Doc | Propósito |
|-----|-----------|
| `5w2h.json` | Análise 5W2H completa |
| `premissas.json` | Premissas e suposições |
| `riscos.json` | Riscos com severidade e mitigação |
| `requisitos.json` | Requisitos funcionais/não-funcionais |
| `restricoes.json` | Restrições do projeto |

```bash
devorq foundation status     # Ver status
devorq foundation create    # Criar docs (wizard)
devorq foundation validate  # Validar (GATE-0.5)
```

---

## Modos de Implementação

O DEVORQ oferece **2 modos** para executar o workflow:

### Modo AUTO 🤖 (story-by-story)
Implementação autônoma story por story. Recomendado para features grandes/médias.

O LLM que implementa cada story é plugável via o contrato **`DEVORQ_DELEGATE_FN`**. Um
dispatcher único (`scripts/adapters/delegate.sh` + `DEVORQ_RUNNER`) roda em **5 harnesses
mainstream** — `claude`, `codex`, `hermes`, `opencode`, `agy` — validados end-to-end.
O loop é **fail-closed**: delegate que não produz diff **não** marca a story como `done`;
story que falha persistentemente vira `failed` após `DEVORQ_AUTO_MAX_STORY_FAILURES` (sem
loop infinito); runs concorrentes são bloqueados por `flock`; e é headless-safe
(`DEVORQ_AUTO_YES=1`). Contrato e casos de uso: [`AGENTS.md`](AGENTS.md) · [`docs/DELEGATE-ADAPTERS.md`](docs/DELEGATE-ADAPTERS.md).

```
 Usuario                    Sistema
    │                          │
    │ "vamos implementar X"    │
    │─────────────────────────►│
    │                          │ [1] mode-selector.sh detecta intent
    │                          │ [2] Branching: AUTO
    │                          │ [3] Loop: story-by-story via delegate_task
    │                          │     ┌─ prd-from-spec.sh → prd.json
    │                          │     ├─ check-story.sh → G-1..G-7
    │                          │     └─ devorq-auto skill
    │                          │
    │◄─────────────────────────│
    │    [n stories completadas]
```

### Modo CLASSIC 📝 (gates 1-7 manuais)
Fluxo tradicional gates 1-7 manual. Recomendado para tasks pequenas/rápidas.

### AUTO[N] 🚀 (limitado)
Executa até N stories, depois pausa para review.

---

## Fluxo de Trabalho (Modo CLASSIC)

```
[NOVO PROJETO / NOVA SESSÃO]
         │
         ▼
   ┌───────────┐
   │ devorq    │  Inicializa .devorq/
   │   init    │
   └─────┬─────┘
         │
         ▼
   ┌───────────┐
   │  GATE-1   │  SPEC.md existe?
   └───┬───┬───┘
       │   │
    PASS  FAIL → cria SPEC.md → volta
       │
       ▼
   ┌───────────┐
   │  GATE-2   │  devorq test passa?
   └───┬───┬───┘
       │   │
    PASS  FAIL → corrige estrutura → volta
       │
       ▼
   ┌───────────┐
   │  GATE-3   │  contexto documentado?
   └───┬───┬───┘
       │   │
    PASS  FAIL → devorq context set → volta
       │
       ▼
   ┌───────────┐
   │  GATE-4   │  lições revisadas?
   └───┬───┬───┘
       │   │
    PASS  FAIL → devorq lessons search → volta
       │
       ▼
   ┌───────────┐
   │  GATE-6   │  Context7 consultado?
   └───┬───┬───┘
       │   │
    PASS  WARN →无所谓 (não bloqueia)
       │
       ▼
   ┌─────────────────┐
   │   [WORK]        │  ← Você implementa
   │                 │
   │  lessons capture│  ← Captura lições
   │  lessons search │  ← Busca lições passadas
   └────────┬────────┘
            │
            ▼ (se erro)
   ┌───────────┐
   │  GATE-7   │  devorq debug
   └───────────┘  (investigação sistemática)
            │
            ▼
   ┌───────────┐
   │  GATE-5   │  devorq compact (handoff)
   └───┬───┬───┘
       │   │
    PASS  FAIL → corrige handoff → volta
       │
       ▼
   ┌───────────┐
   │ sync push │  → HUB (opcional)
   └─────┬─────┘
         │
         ▼
   [FIM DA SESSÃO]
```

---

## Skills do Ecossistema DEVORQ

O framework é composto por skills independentes que se integram ao longo do workflow:

```
devorq_v3/
├── skills/
│   ├── devorq/                 # Core — gates 1-7 + comandos CLI
│   ├── devorq-mode/            # Seletor interativo AUTO/CLASSIC/AUTO[N]
│   ├── devorq-auto/            # Loop autônomo story-by-story
│   ├── devorq-code-review/     # Review multi-agente ultra thorough
│   └── grill-with-docs/        # Sparring terminológico — CONTEXT.md + ADRs
└── lib/                        # Bibliotecas bash compartilhadas
```

|| Skill | Descrição ||
|-------|-----------|
| **devorq** | Core framework — gates, lessons, context, compact, debug |
| **devorq-mode** | Seletor interativo — detecta intent e pergunta modo |
| **devorq-auto** | Ralph-style — loop autônomo story-by-story via delegate_task |
| **devorq-code-review** | UltraReview — multi-agent review com gates de aprovação |
| **grill-with-docs** | Sparring terminológico — valida vocabulário contra CONTEXT.md, cria ADRs |

---

## Token Economy — Laravel PAO (Recomendado)

Para máxima economia de tokens em ambientes de agente de IA, recomendamos instalar `laravel/pao`:

```bash
composer require laravel/pao --dev
```

**O que faz:** PAO intercepta automaticamente PHPUnit, Pest, Paratest, PHPStan, Pint e Rector, convertendo output verbose em JSON estruturado.

**Benefício:** Até **99.8% menos tokens** em suites de teste grandes. Output constante independent do número de testes.

**Importante:**
- PAO **NÃO** é dependência do DEVORQ. O DEVORQ funciona **100% sem ele**.
- PAO é uma **recomendação** para quem roda em ambiente de agente (Claude Code, Cursor, Devin, Gemini CLI).
- PAO ativa automaticamente via Composer's autoloader — zero configuração.
- Quando developers rodam ferramentas diretamente no terminal, o output é **idêntico** — sem impacto no workflow humano.

```bash
devorq info   # Mostra status do PAO no ambiente
```

---

## Comandos

### Inicialização
| Comando | Descrição |
|---------|-----------|
| `devorq init` | Inicializar `.devorq/` no projeto |
| `devorq test` | Testar estrutura do projeto |

### Gates
| Comando | Descrição |
|---------|-----------|
| `devorq gate [1-7]` | Executar gate específico |
| `devorq flow "<intent>"` | Workflow completo (gates 1-7) |
| `devorq build` | Self-building: testa + gates (auto-verifica) |

### Lições Aprendidas
| Comando | Descrição |
|---------|-----------|
| `devorq lessons capture "<t>" "<p>" "<s>"` | Capturar lição |
| `devorq lessons search "<q>"` | Buscar lições locais |
| `devorq lessons validate` | Validar com Context7 |
| `devorq lessons apply [id]` | Marcar como aplicada |

### Contexto
| Comando | Descrição |
|---------|-----------|
| `devorq context` | Mostrar contexto atual |
| `devorq context lint` | Validar context.json |
| `devorq context stats` | Tamanho do contexto |
| `devorq context pack` | Comprimir para handoff |
| `devorq context set <key> <val>` | Definir campo |
| `devorq compact` | Gerar handoff JSON |

### HUB Remoto
| Comando | Descrição |
|---------|-----------|
| `devorq sync push` | Enviar lessons → HUB |
| `devorq sync pull` | Receber lessons ← HUB |
| `devorq vps check` | Testar conexão VPS |

### Utilitários
| Comando | Descrição |
|---------|-----------|
| `devorq debug [erro]` | Workflow debug sistemático |
| `devorq stats` | Estatísticas de uso |
| `devorq version` | Versão atual |
| `devorq upgrade` | Atualizar DEVORQ |
| `devorq uninstall` | Remover instalação |

---

## Arquitetura

```
DEVORQ CORE (bash puro — /projects/devorq_v3)
│
├── bin/devorq                  # CLI entry point (source libs)
│
├── lib/
│   ├── lessons.sh             # lessons::capture|search|validate|apply|sync_vps|export
│   ├── gates.sh                # gates::check + 10 gates bloqueantes
│   ├── compact.sh              # compact::run — handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh             # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check|trace + devorq::debug (4-phase)
│   ├── stats.sh                # stats::run — métricas de uso
│   └── vps.sh                  # vps::check|exec|pg_exec — SSH mux
│
├── scripts/
│   ├── sync-push.py            # Sincroniza local → HUB PostgreSQL
│   └── sync-pull.py            # Sincroniza HUB PostgreSQL → local
│
├── skills/
│   ├── devorq/                 # Core skill (gates + lessons)
│   ├── devorq-mode/            # Interactive mode selector
│   ├── devorq-auto/            # Autonomous story loop
│   └── devorq-code-review/    # Multi-agent code review
│
├── .devorq/                    # Estado local (NÃO COMMITEAR)
│   ├── state/
│   │   ├── context.json        # Contexto do projeto atual
│   │   ├── session.json        # Dados da sessão corrente
│   │   └── lessons/            # Lições capturadas localmente
│   └── version
│
├── SPEC.md                     # Esta especificação
├── README.md                   # Visão geral + quick start
├── INSTALL.md                  # Guia de instalação
├── EXTRAS.md                   # Context-Mode, Context7, HUB, Self-Building
└── TROUBLESHOOTING.md          # Problemas comuns + soluções
```

---

## DEV-MEMORY HUB (VPS Remoto)

Repositório separado: **dev-memory-laravel**

```
┌──────────────────────┐      SSH (mux ~0.3s)      ┌──────────────────────┐
│   DEVORQ CORE        │ ◄────────────────────────► │   VPS srv163217       │
│   (máquina local)    │                            │   187.108.197.199:6985│
│                      │                            │                       │
│   .devorq/state/     │                            │   PostgreSQL          │
│   lessons/           │                            │   ┌───────────────┐  │
│                      │                            │   │ devorq.lessons│  │
│                      │                            │   │ devorq.memories│ │ 
│                      │                            │   │ devorq.sessions│ │ 
│                      │                            │   └───────────────┘  │
│                      │                            │                       │
│                      │                            │   dev-memory-laravel │
│                      │                            │   (interface web)    │
└──────────────────────┘                            └──────────────────────┘
```

### Acesso Direto ao HUB

```bash
# SSH
ssh -p 6985 root@187.108.197.199

# PostgreSQL (via docker exec)
docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study

# Tabelas
# devorq.lessons, devorq.memories, devorq.sessions, devorq.handoffs
```

---

## Schema de Lição Aprendida

```json
{
  "id": "lesson_20260422_143000_12345",
  "title": "jq install in rootless Docker",
  "problem": "jq binary needed but no apt-get available",
  "solution": "curl -L jq-linux64 binary to ~/bin and chmod +x",
  "stack": ["bash", "jq", "docker"],
  "tags": ["docker-rootless", "jq", "install"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": true,
  "validated_at": "2026-04-22T14:30:00",
  "applied": false,
  "recurrence_count": 0,
  "metadata": {}
}
```

---

## Convenções de Commit

```
type(scope): description

Types:    feat | fix | docs | style | refactor | test | chore
Scopes:   core | lessons | gates | compact | vps | hub | context | debug | docs | skills
```

**Exemplo:**
```
feat(skills): add devorq-mode — interactive AUTO/CLASSIC/AUTO[N] selector
```

---

## Status do Projeto

```
FASE 1  ████████████████████  100%  ✅  Core bash + gates + lessons
FASE 2a ████████████████████  100%  ✅  PostgreSQL schema devorq.*
FASE 2b ████████████████████  100%  ✅  Sync push/pull Python scripts
FASE 3  ████████████████████  100%  ✅  Context-Mode (lib/context.sh)
FASE 4  ████████████████████  100%  ✅  Context7 integration (lib/context7.sh)
FASE 5  ████████████████████  100%  ✅  Systematic debug (lib/debug.sh)
FASE 6  ████████████████████  100%  ✅  Documentação (README+INSTALL+EXTRAS)
FASE 7  ████████████████████  100%  ✅  Self-building (build+upgrade+uninstall)
FASE 8  ████████████████████  100%  ✅  Meta-stats (devorq stats)
FASE 9  ████████████████████  100%  ✅  Skills ecosystem (devorq-auto, devorq-code-review, devorq-mode)
```

**Zero pendências.**

---

## Documentação

| Arquivo | Conteúdo |
|---------|----------|
| [SPEC.md](SPEC.md) | Especificação completa |
| [EXTRAS.md](EXTRAS.md) | Context-Mode, Context7, HUB, Self-Building |
| [INSTALL.md](INSTALL.md) | Guia de instalação |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problemas e soluções |
| [docs/SYSTEM_LEVANTAMENTO.md](docs/SYSTEM_LEVANTAMENTO.md) | Anexo: levantamento longo (fluxos ASCII, gates, tecnologias) |

Para diagramas, auditoria do sistema ou integração com outra documentação técnica, use o anexo acima; o README e o SPEC cobrem o uso diário e a versão canônica.
