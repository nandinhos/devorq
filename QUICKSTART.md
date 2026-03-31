# DEVORQ Prompt Activation

> Simplesmente copie e cole este prompt no início de qualquer conversa com IA para ativar o fluxo DEVORQ.

---

## 🚀 Ativação Rápida

```
DEVORQ ATIVADO - Modo Orquestrador de Desenvolvimento

Sou um desenvolvedor seguindo o workflow DEVORQ.
Antes de qualquer implementação, execute:

1. /env-context → Detectar contexto (stack, LLM, tipo projeto)
2. /scope-guard → Gerar contrato de escopo
3. /pre-flight → Validar tipos e enums
4. /tdd → Implementar com RED→GREEN→REFACTOR
5. /quality-gate → Checklist pré-commit
6. /session-audit → Métricas de eficiência

Regras:
- Nenhum código sem contrato /scope-guard aprovado
- Nenhum commit sem /quality-gate passar
- Nenhuma sessão sem /session-audit

Stack-alvo: PHP, Laravel (TALL Stack), Filament, Python, Shell

Clique em [Confirmar] para começar com o contexto detectado.
```

---

## 💬 Mensagem Pronta para Cada Situação

### Para Nova Feature
```
[DEVORQ] Criar [DESCREVA_SUA_TASK_AQUI]
```

### Para Laravel
```
[DEVORQ-LARAVEL] Criar componente Livewire para [FEATURE]
```

### Para Python
```
[DEVORQ-PYTHON] Analisar [ARQUIVO/DADOS] e gerar [RELATÓRIO/OUTPUT]
```

### Para Shell
```
[DEVORQ-SHELL] Criar script para [TAREFA]
```

---

## 📋 Template de Contrato (/scope-guard)

Quando ativado, gere este contrato:

```markdown
# CONTRATO DE ESCOPO - [TASK]

## FAZER
1. [Item específico]
2. [Item específico]

## NÃO FAZER
1. [O que NÃO fazer]
2. [O que NÃO fazer]

## ARQUIVOS PERMITIDOS
- [Arquivo 1]
- [Arquivo 2]

## DONE_CRITERIA
- [ ] Critério verificável 1
- [ ] Critério verificável 2
```

---

## 🔧 Checklist /quality-gate

Antes de qualquer commit, verificar:

```markdown
## QUALITY GATE

- [ ] Testes passando
- [ ] Lint passando (Pint/ESLint)
- [ ] Sem regressão
- [ ] Escopo respeitado
- [ ] DONE_CRITERIA atingido
- [ ] Sem N+1 queries
- [ ] Form Requests (Laravel)
- [ ] x-show (Livewire, não @if)
```

---

## 📊 Session Audit (/session-audit)

Ao final de cada sessão:

```markdown
# SESSION AUDIT

## Resultado: [EFICIENTE/ACEITÁVEL/DESPERDIÇADA]

## Métricas:
- Duração: [tempo]
- Fix rounds: [n]
- Checkpoints: [n]

## Causa Raiz (se aplicável):
- [Causa e ação corretiva]
```

---

## 🔄 Atalho para Different Stack

| Atalhos | Stack |
|---------|-------|
| `[DEVORQ]` | Fluxo completo |
| `[DEVORQ-L]` | Laravel/TALL |
| `[DEVORQ-F]` | Filament |
| `[DEVORQ-P]` | Python |
| `[DEVORQ-S]` | Shell |
| `[DEVORQ-PHP]` | PHP Puro |

---

> **使用方法**: Simply copy the relevant template above and paste it at the start of your message to any LLM (Claude, Gemini, OpenCode, Antigravity, etc.) to activate the DEVORQ workflow instantly.