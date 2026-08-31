# Brainstorm Rules — DEVORQ v4.1.0

**Objetivo:** Durante brainstorming, capturar decisões, trade-offs e padrões emergentes como regras abstratas.

## Gates de captura

| Momento | Gatilho | Regra a gerar |
|---------|---------|---------------|
| Após definir escopo | `SCOPE DEFINED` em `devorq brainstorm` | Gerar `scope-guard` com whitelist de deliverables |
| Após identificar entidades | `ENTITIES IDENTIFIED` | Gerar `ddd-deep-domain` com glossário |
| Após levantar risks | `RISKS RAISED` | Criar `rules/risks.md` se risk recorrente |
| Após decisão de stack | `STACK DECIDED` | Documentar em `rules/stack.md` se padrão novo |
| Ao final do brainstorm | `SESSION COMPLETE` | Compilar lições via `devorq lessons capture` |

## Regras de processo

1. **Nunca adotar decisão no calor da discussão** — esperar 5min após último argumento antes de abstrair
2. **Regra sem exemplo concreto = não criar** — toda regra precisa de caso de uso validado
3. **Regras recorrentes em 3+ sessões** → migrar para `rules/<nome>.md` global
4. **Regras locais vivem em `.devorq/rules/`** do projeto, não no DEVORQ core

## Formato de regra gerada

```markdown
# Regra: <nome>

**Contexto:** Quando [situação]
**Regra:** Então [comportamento esperado]
**Exemplo:** [caso concreto que gerou a regra]
**Revisitar:** [trigger para reavaliar]
```

## Integração com fluxo

```
devorq brainstorm
  → Gate: SCOPE DEFINED    → trigger: generate scope rule
  → Gate: ENTITIES        → trigger: generate domain rule  
  → Gate: RISKS           → trigger: log to rules/risks.md
  → Gate: SESSION COMPLETE → trigger: lessons capture prompt
```