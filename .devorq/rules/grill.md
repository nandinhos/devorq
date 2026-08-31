# Grill Rules — DEVORQ v4.1.0

**Objetivo:** Regras para sessões de sparring (grill-me / grill-session) onde uma solução é questionada até encontrar fragilidades.

## Momentos de captura (gates de abstração)

| Momento | Gatilho | Ação |
|---------|---------|------|
| Ao questionar premissa | `PREMISSA QUESTIONADA` | Registrar em `rules/premises.md` se for recorrente |
| Ao identificar falha de design | `DESIGN FLAW FOUND` | Gerar lição via `devorq lessons capture` |
| Ao encontrar trade-off válido | `TRADE-OFF ACCEPTED` | Documentar em `rules/tradeoffs.md` com contexto |
| Ao final do grill | `GRILL COMPLETE` | Compilar lições e gerar skill se aplicável |

## Regras de processo

1. **Grill não é debate — é demolição estruturada**
   - Pergunta: "O que acontece se X falhar?"
   - Pergunta: "E se a escala for 100x?"
   - Pergunta: "Qual o pior cenário?"

2. **Três strikes = regra nova** — se a mesma objeção aparecer em 3+ sessões diferentes, abstrair para `rules/`

3. **Decisão de grill é condicional** — nunca "sim ou não", sempre "sim SE X, não SE Y"

4. **Regras de grill são geradas automaticamente** — `devorq grill` com `LESSONS_AUTO=true` captura e compila

## Formato de premissa questionada

```markdown
# Premissa: <descrição>

**Questionada em:** [data]
**Por:** [agente ou humano]
**Resultado:** [resiste / revogada / modificada]
**Contexto:** [por que foi questionada]
```

## Integração com fluxo

```
devorq grill <topic>
  → Gate: PREMISSA QUESTIONADA  → log to rules/premises.md
  → Gate: DESIGN FLAW          → devorq lessons capture
  → Gate: TRADE-OFF            → log to rules/tradeoffs.md  
  → Gate: GRILL COMPLETE       → compile lessons → skill
```

## Regras de ouro do Grill

1. **Nenhuma solução é óbvia** — se parece óbvia, questionar mais fundo
2. **Dados de produção > opinião** — pedir números antes de aceitar
3. **Se não pode medir, nãoaceita** — métricas concretas ou não passa
4. **Três sessões de grill no mesmo ponto** → criar regra permanente