# PROPOSTA DE MELHORIA CONTÍNUA — DEVORQ

**Documento Técnico v1.0**
**Data:** 18/04/2026
**Versão do Documento:** 1.0
**Autor:** Nand0Dev / Devorq Team
**Assunto:** Mitigação de desvios no processo de desenvolvimento e captura de lições aprendidas

---

## RESUMO EXECUTIVO

Esta proposta visa aprimorar o framework Devorq através de três pilares fundamentais:

1. **Prevenção** — Impedir desvios antes que ocorram via gates e checkpoints
2. **Detecção** — Identificar desvios em tempo real durante o desenvolvimento
3. **Rastreabilidade** — Documentar panes, decisões e lições aprendidas de forma concentrada

O objetivo é evoluir o Devorq para um processo cada vez mais **inteligente e robusto**, sem criar complexidade desnecessária.

---

## 1. CONTEXTUALIZAÇÃO

### 1.1 Problema Observado

Durante sessões de desenvolvimento, identificamos um padrão recorrente de **correações emergenciais** que fugiam do fluxo estruturado do Devorq:

| Sintoma | Descrição |
|---------|-----------|
| Dívida técnica acumulada | Correções temporárias sem refatoração posterior |
| Regressões | Alterações que quebram funcionalidades existentes |
| Inconsistência | Código segue padrões diferentes entre sessões |
| Falta de rastreabilidade | Decisões técnicas não documentadas |
| Patches espalhados | Correções de panes não concentradas nos documentos adequados |

### 1.2 Análise de Causa Raiz

O fluxo Devorq determina:
```
BRAINSTORMING → SPEC → PLANO → TDD → IMPLEMENT → REVIEW → VERIFY
```

No entanto, pressões por resultados imediatos levam a:
- Pular fases de planejamento quando problemas parecem "simples"
- Ignorar systematic-debugging ao encontrar erros
- Implementar antes de documentar quando "é só um ajuste"

### 1.3 O Ciclo Natural de uma Tarefa/Feature

```
┌─────────────────────────────────────────────────────────────────┐
│                    CICLO DE VIDA DA TAREFA                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────┐     ┌──────────┐     ┌──────────────────────┐  │
│   │ CONCEPCÃO│────▶│PLANEJAMENTO│────▶│    EXECUÇÃO          │  │
│   └──────────┘     └──────────┘     ├──────────────────────┤  │
│         │                │           │ desenvolvimento      │  │
│         │                │           │ Resoluçao de Pane    │  │
│         │                │           │ Testes               │  │
│         │                │           └──────────────────────┘  │
│         │                │                       │               │
│         ▼                ▼                       ▼               │
│   ┌──────────┐     ┌──────────┐     ┌──────────────────────┐  │
│   │ LIÇÕES   │◀────│ CONSOLIDA│◀────│      REVISÃO         │  │
│   │ APRENDIDAS│     │ DADES   │     │  Code Review          │  │
│   └──────────┘     └──────────┘     └──────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Ponto-chave:** As **Lições Aprendidas** são capturadas ao final do ciclo, mas她们的 origem (as panes) precisam estar **concentradas e rastreáveis** dentro da SPEC durante todo o processo.

---

## 2. FLUXO ESTRUTURADO DE DESENVOLVIMENTO

### 2.1 Fluxo Principal (Workflow)

```
┌─────────────────────────────────────────────────────────────────┐
│                     ENFORCED WORKFLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   USER INPUT                                                     │
│        │                                                         │
│        ▼                                                         │
│   ┌─────────────────┐                                           │
│   │ SKILL CHECK     │                                           │
│   │ "Might any      │ ─── If relevant ───► INVOKE SKILL        │
│   │  skill apply?"  │                                           │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐                                           │
│   │ PLANEJAMENTO    │                                           │
│   │ (Plan Mode)     │ ─── If complex ────► REQUIRE SPEC        │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐                                           │
│   │ IMPLEMENTAÇÃO   │ ─── Only after plan approved ───► CODE    │
│   │                 │                                           │
│   │  RED → GREEN    │                                           │
│   │  → REFACTOR     │                                           │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐                                           │
│   │ VERIFICAÇÃO    │ ─── Before commit ────► VERIFY + REVIEW   │
│   └─────────────────┘                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Gates de Qualidade (Quality Gates)

| Gate | Trigger | Validação | Bloqueante |
|------|---------|-----------|------------|
| **G1** | Antes de codificar | SPEC documentada e aprovada | Sim |
| **G2** | Antes de implementar | Teste RED escrito | Sim |
| **G3** | Após implementar | Código passa lint + typecheck | Sim |
| **G4** | Antes de commitar | Code review com checklist | Sim |
| **G5** | Após commitar | Testes automatizados passando | Automático |

---

## 3. GESTÃO DE PANES DURANTE O DESENVOLVIMENTO

### 3.1 Princípio Fundamental

> **"Toda pane que ocorre durante o desenvolvimento de uma SPEC deve ser documentada dentro da própria SPEC, em uma sessão dedicada."**

### 3.2 Fluxo de Resposta a Pane

```
┌─────────────────────────────────────────────────────────────────┐
│              FLUXO DE RESOLUÇÃO DE PANES                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Pane Detectada                                                  │
│       │                                                           │
│       ▼                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Está em uma SPEC ativa?                    │                │
│  │                                             │                │
│  │   └─► SIM ──► Adicionar sessão RESOLUÇÕES  │                │
│  │           │ Respeitar estrutura da SPEC    │                │
│  │           │ Manter histórico agrupado        │                │
│  │           │ Respeitar lifecycle da task     │                │
│  │                                             │                │
│  └─────────────────────────────────────────────┘                │
│       │                                                           │
│       │ NÃO                                                       │
│       ▼                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Criar SPEC nova?                           │                │
│  │ (Sempre evitável - planeje antes)          │                │
│  └─────────────────────────────────────────────┘                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Estrutura da Sessão de Resoluções de Pane

A sessão deve ser adicionada como seção dentro da SPEC ativa, com a seguinte estrutura:

```markdown
## RESOLUÇÕES DE PANES

### Pane #001
- **Data:** DD/MM/YYYY HH:MM
- **Sintoma:** [Descrição do problema reportado pelo usuário]
- **Causa Raiz:** [Análise sistemática do porquê ocorreu]
- **Localização:** [Arquivo/Componente/Classe onde foi encontrado]
- **Decisão Técnica:** [Como foi corrigido e por quê]
- **Lição Aprendida:** [Conhecimento extraído para futuro]
- **Referência:** [Commits, decisões relacionadas]
- **Status:** [Resolvido | Em análise | Pendente]

### Pane #002
[... seguir mesmo formato ...]
```

### 3.4 Exemplo Prático

```markdown
## RESOLUÇÕES DE PANES

### Pane #001 — Erro ao criar convidado no formulário Promoter
- **Data:** 18/04/2026 14:30
- **Sintoma:** Ao tentar criar convidado, Select de setores mostrava "no_options_message"
- **Causa Raiz:** PromoterPermission com sector_id=NULL não estava sendo tratado no formulário
- **Localização:** `app/Filament/Promoter/Resources/Guests/Schemas/GuestForm.php:43-70`
- **Decisão Técnica:** Adicionada lógica para listar todos os setores quando sector_id é NULL
- **Lição Aprendida:** Validações de formulário devem tratar casos onde relações são NULL
- **Referência:** Commit a1b2c3d, SPEC-0004
- **Status:** Resolvido

### Pane #002 — Widget Quota não mostrava setores discriminados
- **Data:** 18/04/2026 16:45
- **Sintoma:** Card mostrava "Geral" em vez de listar cada setor separadamente
- **Causa Raiz:** Loop não iterava sobre setores quando permission.sector_id era NULL
- **Localização:** `app/Filament/Promoter/Widgets/PromoterQuotaOverview.php:25-43`
- **Decisão Técnica:** Refatorado para listar cada setor com sua quota individual
- **Lição Aprendida:** Widgets de quota precisam ser discriminados por setor para utilidade
- **Referência:** Commit e4f5g6h, SPEC-0004
- **Status:** Resolvido
```

---

## 4. CHECKLISTS OPERACIONAIS

### 4.1 Checklist de Correção de Bug

```
┌─────────────────────────────────────────────────────────────────┐
│              SYSTEMATIC DEBUGGING CHECKLIST                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  □ 1. Invoke systematic-debugging skill                           │
│  □ 2. Identificar sintoma (o que usuário reportou)              │
│  □ 3. Identificar causa raiz (por que ocorreu)                  │
│  □ 4. Verificar se está em SPEC ativa                           │
│  □ 5. Adicionar entrada na sessão RESOLUÇÕES DE PANES           │
│  □ 6. Escrever teste que reproduz o bug (RED)                   │
│  □ 7. Implementar correção (GREEN)                               │
│  □ 8. Refatorar se necessário (REFACTOR)                        │
│  □ 9. Verificar que outros testes ainda passam                  │
│  □ 10. Atualizar sessão RESOLUÇÕES DE PANES com resultado       │
│  □ 11. Identificar Lições Aprendidas para capturar              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Checklist de Nova Funcionalidade

```
┌─────────────────────────────────────────────────────────────────┐
│                 NEW FEATURE CHECKLIST                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  □ 1. Invoke brainstorming skill                                 │
│  □ 2. Criar/Atualizar SPEC com escopo e dependências           │
│  □ 3. Identificar tasks e suas dependências                     │
│  □ 4. Escrever testes para cada critério de aceite (TDD)       │
│  □ 5. Implementar funcionalidades                               │
│  □ 6. Documentar panes em RESOLUÇÕES DE PANES se ocorrerem     │
│  □ 7. Code review com checklist de segurança/performance        │
│  □ 8. Verificação final contra SPEC                              │
│  □ 9. Consolidar Lições Aprendidas da SPEC                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Checklist de Qualidade Pré-Commit

```
┌─────────────────────────────────────────────────────────────────┐
│                  PRE-COMMIT CHECKLIST                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  □ 1. SPEC atualizada com todas as alterações?                 │
│  □ 2. RESOLUÇÕES DE PANES documentadas se houve panes?          │
│  □ 3. Testes implementados (RED → GREEN)?                       │
│  □ 4. Lint passando?                                             │
│  □ 5. Typecheck passando?                                        │
│  □ 6. Code review realizado?                                    │
│  □ 7. Lições Aprendidas identificadas?                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. CICLO DE CAPTURA DE LIÇÕES APRENDIDAS

### 5.1 Fluxo do Ciclo

```
┌─────────────────────────────────────────────────────────────────┐
│              CICLO DE LIÇÕES APRENDIDAS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   EXECUÇÃO                    CONSOLIDAÇÃO            CAPTURA     │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐      ┌────────────┐ │
│  │ desenvolvimento│──────▶│ Resoluçoes   │────▶│ Lições     │ │
│  │              │         │ de Pane      │      │ Aprendidas │ │
│  │ - Panes      │         │ Concentradas  │      │ Consolidadas│ │
│  │ - Decisões   │         │ na SPEC      │      │             │ │
│  │ - Achados    │         │              │      │             │ │
│  └──────────────┘         └──────────────┘      └────────────┘ │
│        │                        │                      │         │
│        ▼                        ▼                      ▼         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              SELEÇÃO → ORGANIZAÇÃO → CATEGORIZAÇÃO       ││
│  └─────────────────────────────────────────────────────────────┘│
│                                │                                  │
│                                ▼                                  │
│                    ┌──────────────────┐                        │
│                    │ VALIDAÇÃO         │                        │
│                    │ + Encerramento    │                        │
│                    │   do Ciclo       │                        │
│                    └──────────────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Processo de Seleção

| Critério | Descrição |
|----------|-----------|
| Relevância | A lição se aplica a outros projetos/situações? |
| Impacto | Teve impacto significativo no resultado? |
| Reutilização | Pode ser reutilizada em contextos similares? |
| Durabilidade | O conhecimento terá valor futuro? |

### 5.3 Categorização Sugerida

| Categoria | Descrição | Exemplo |
|-----------|-----------|---------|
| **Processo** | Melhorias no fluxo de trabalho | "Sempre usar SPEC antes de codificar" |
| **Técnica** | Decisões técnicas e arquitecturais | "Não usar Grid em namespace errado" |
| **Ferramenta** | Problemas e soluções de ferramentas | "Livewire precisa de view:clear" |
| **Negócio** | Decisões de domínio do problema | "Setores precisam ser discriminados" |

---

## 6. IMPLEMENTAÇÃO RECOMENDADA

### 6.1 Priorização

| Prioridade | Item | Impacto | Esforço | Justificativa |
|------------|------|---------|---------|---------------|
| **P1** | Sessão RESOLUÇÕES DE PANES na SPEC | Alto | Baixo | Estrutura já existe, só formalizar |
| **P1** | Enforce skill loading para debugging | Alto | Médio | Previne correção sem análise |
| **P2** | Quality gates antes de commitar | Alto | Alto | Previne regressões |
| **P2** | Checklist de pré-commit | Médio | Baixo | Disciplina sem tooling |
| **P3** | Template de SPEC padronizado | Médio | Baixo | Facilita adoção |
| **P3** | Sistema de detecção de desvios | Médio | Alto | Automação avançada |

### 6.2 Implementação em Fases

**Fase 1 — Curto Prazo (1 semana):**
- Formalizar sessão RESOLUÇÕES DE PANES no template de SPEC
- Implementar checklist de debugging obrigatório
- Treinar equipe no novo fluxo

**Fase 2 — Médio Prazo (1 mês):**
- Implementar quality gates automatizados (lint, typecheck, tests)
- Desenvolver template padronizado de SPEC
- Estabelecer métricas de acompanhamento

**Fase 3 — Longo Prazo (3 meses):**
- Refinar processo baseado em feedback real
- Automatizar verificação de compliance
- Criar baseline de métricas e KPIs

---

## 7. MÉTRICAS SUGERIDAS

| Métrica | Meta | Coleta |
|---------|------|--------|
| Taxa de bugs por sprint | Redução de 50% | Após cada sprint |
| Tempo médio de resolução | Redução de 30% | A cada bug fechado |
| Dívida técnica acumulada | Zero novas entradas | Revisão mensal |
| Cobertura de testes | +80% em críticas | A cada commit |
| Panes documentadas | 100% rastreadas | Continuo |
| Lições consolidadas | Mínimo 3 por feature | Ao encerrar feature |

---

## 8. CONCLUSÃO

Esta proposta não visa criar complexidade desnecessária, mas sim:

1. **Prevenir** desvios antes que ocorram via gates e checkpoints
2. **Detectar** desvios em tempo real durante o desenvolvimento
3. **Rastrear** panes e decisões de forma concentrada na SPEC
4. **Capturar** lições aprendidas de forma estruturada ao final do ciclo

O ponto central é que **toda pane deve estar concentrada na SPEC** da feature/task, criando um histórico vivo do desenvolvimento que alimentará as lições aprendidas consolidadas.

---

**Aguardamos feedback do desenvolvedor Devorq para refinamento e implementação desta proposta.**

---

## ANEXO A — Template de SPEC com Sessão de Resoluções

```markdown
# SPEC-XXXX — [TÍTULO DA FEATURE]

**Data:** DD/MM/YYYY
**Autor:** [Nome]
**Status:** [Rascunho | Em Desenvolvimento | Completo | Cancelado]

---

## 1. OBJETIVO

[Descrição clara do que esta feature/resolver]

## 2. ESCOPO

### 2.1 Escopo Positivo
- [Item incluso]

### 2.2 Escopo Negativo
- [Item fora do escopo]

## 3. CRITÉRIOS DE ACEITE

- [ ] Critério 1
- [ ] Critério 2

## 4. DEPENDÊNCIAS

- [Dependência 1]
- [Dependência 2]

## 5. DECISÕES TÉCNICAS

- [Decisão e justificativa]

## 6. RESOLUÇÕES DE PANES

### Pane #001
- **Data:** DD/MM/YYYY HH:MM
- **Sintoma:** [O que foi reportado]
- **Causa Raiz:** [Por que ocorreu]
- **Localização:** [Arquivo/componente]
- **Decisão Técnica:** [Como foi corrigido]
- **Lição Aprendida:** [Conhecimento extraído]
- **Referência:** [Commits relacionados]
- **Status:** [Resolvido | Em análise | Pendente]

## 7. LIÇÕES APRENDIDAS

- [Lição 1 — Categoria: Processo/Técnica/Ferramenta/Negócio]
- [Lição 2]

## 8. RESULTADOS OBTIDOS

[Resultados medidos após implementação]

## 9. ENCERRAMENTO

- **Data de Encerramento:** DD/MM/YYYY
- **Revisado por:** [Nome]
- **Próximos Passos:** [Se houver]
```

---

**FIM DO DOCUMENTO**
