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
| `brainstorming` | Explorar ideias antes do plano | Novas features |
| `tdd` | RED → GREEN → REFACTOR | Implementação de código |
| `systematic-debugging` | Investigar bugs com processo | Quando algo não funciona |
| `code-review` | Revisão de qualidade | Antes de PR |

---

## Fluxo DEVORQ

```
Nova Sessão:
  /env-context → Detectar stack/ambiente

Antes de Codar:
  /scope-guard → /pre-flight → /schema-validate

Durante Implementação:
  tdd (RED → GREEN → REFACTOR)

Antes de Commit:
  /quality-gate → APROVADO?

Encerramento:
  /spec-export → /session-audit → checkpoint
```

---

## Instalação

```bash
# Copiar para seu projeto
cp -r .aidev/ /seu-projeto/
```

---

## Configuração MCP

Editar `.mcp.json` com as chaves das ferramentas:

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

## Credits

- Base: aidev-superpowers-v3 (fork com limpeza)
- Customização: DEVORQ based on developer profile