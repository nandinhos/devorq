# DEVORQ - Desenvolvimento Orquestrador

> Framework de orquestração orientada a skills para desenvolvimento profissional.

---

## O que é?

DEVORQ é um sistema de workflow que transforma qualquer LLM em um desenvolvedor disciplinado através de:

- **Contratos Canônicos** - /scope-guard para bloquear over-engineering
- **Validação Preemptiva** - /pre-flight, /schema-validate antes de codar
- **Contexto Automático** - /env-context detecta stack e ambiente
- **Quality Gates** - /quality-gate antes de qualquer commit
- **Checkpoint** - Continuidade mesmo com rate limit
- **Auditoria** - /session-audit para métricas de eficiência

---

## Stacks Suportadas

| Stack | Agente | Regras |
|-------|--------|--------|
| **Laravel (TALL)** | `.devorq/agents/laravel/` | `.devorq/rules/stack/laravel-tall.md` |
| **Filament** | `.devorq/agents/filament/` | Herda do Laravel |
| **PHP Puro** | `.devorq/agents/php/` | `.devorq/rules/stack/php.md` |
| **Python** | `.devorq/agents/python/` | `.devorq/rules/stack/python.md` |
| **General** | `.devorq/agents/general/` | Orquestrador |

---

## Skills DEVORQ

| Skill | Propósito | Quando Usar |
|-------|-----------|-------------|
| `/scope-guard` | Contrato de escopo explícito | **OBRIGATÓRIO** antes de qualquer código |
| `/pre-flight` | Validar schema/enums antes do código | Antes de criar migrations/models |
| `/env-context` | Detectar stack e ambiente automaticamente | Primeira mensagem de toda sessão |
| `/schema-validate` | Validar banco e constraints | Antes de operações de dados |
| `/quality-gate` | Checklist pré-commit | Após qualquer implementação |
| `/session-audit` | Classificar eficiência da sessão | Final de toda sessão |
| `/spec-export` | Exportar contexto para handoff | Quando muda de LLM |
| `tdd` | RED → GREEN → REFACTOR | Implementação de código |
| `systematic-debugging` | Investigar bugs com processo | Quando algo não funciona |
| `code-review` | Revisão de qualidade | Antes de PR |

---

## Fluxo DEVORQ

```
Nova Sessão:
  devorq init → Detectar stack, tipo, LLM

Task:
  devorq flow "implementar feature X"

Durante:
  /env-context → /scope-guard → /pre-flight → tdd → /quality-gate → /session-audit
```

---

## Instalação

```bash
# Clone
git clone https://github.com/nandinhos/devorq.git

# Copie para seu projeto
cp -r .devorq/ /seu-projeto/
cp -r bin/ /seu-projeto/
cp lib/detect.sh /seu-projeto/lib/
```

Consulte `INSTALL.md` para métodos completos de instalação.

---

## Configuração MCP

Para validação de documentação oficial:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

---

## Comandos CLI

| Comando | Descrição |
|---------|-----------|
| `devorq init` | Inicializar projeto |
| `devorq flow "task"` | Executar fluxo completo |
| `devorq agent` | Modo agente |
| `devorq context` | Ver contexto atual |
| `devorq checkpoint` | Criar checkpoint |

---

## Documentação

- [INSTALL.md](INSTALL.md) - Instalação completa
- [FLUXO_DESENVOLVIMENTO.md](FLUXO_DESENVOLVIMENTO.md) - Fluxo detalhado