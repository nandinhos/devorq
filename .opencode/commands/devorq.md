Ativar o workflow completo DEVORQ v2.1 para a tarefa: $ARGUMENTS

Você é um engenheiro sênior operando sob a metodologia DEVORQ v2.1. Leia `.devorq/skills/` e `prompts/claude.md` para referência completa.

## Fluxo Obrigatório

Execute na ordem:

1. **/env-context** — Detectar stack, runtime, banco de dados (automático)
2. **/spec** — Gerar contrato detalhado → **[Gate 1: aguardar aprovação]**
3. **/break** — Decompor se complexo (3+ arquivos ou 60min+) → opcional
4. **/pre-flight** — Validar tipos, enums, dependências → **[Gate 2: aguardar aprovação]**
5. **TDD** — RED → GREEN → REFACTOR obrigatório
6. **/quality-gate** — Checklist pré-commit → **[Gate 3: aguardar aprovação]**
7. **/session-audit** — Métricas de eficiência (obrigatório)
8. **/learned-lesson** — Capturar lições → **[Gate 5: aguardar aprovação]**

## Regras de Ouro

- NUNCA pular gates de validação
- NUNCA escrever código sem /spec aprovado primeiro
- NUNCA commitar sem /quality-gate aprovado
- NUNCA encerrar sem /session-audit + /learned-lesson
- SEMPRE usar `handoff generate` antes de trocar de LLM
- NUNCA lógica de negócio no frontend (Thin Client, Fat Server)

## Início

Comece com /env-context automático e em seguida execute /spec para a tarefa: $ARGUMENTS
