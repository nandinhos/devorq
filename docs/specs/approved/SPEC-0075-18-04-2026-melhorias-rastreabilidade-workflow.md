---
id: SPEC-0075-18-04-2026-melhorias-rastreabilidade-workflow
title: Melhorias de Rastreabilidade e Robustez do Workflow DEVORQ
domain: arquitetura
status: approved
priority: medium
owner: nando-dev
source: proposta-interna + code-review-hermes
created_at: 2026-04-18
updated_at: 2026-04-18
related_tasks: []
related_files:
  - docs/proposals/architecture/PROPOSTA-MELHORIA-DEVORQ-v1.0.md
  - docs/proposals/code-review/code-review-hermes.md
  - .devorq/skills/spec/SKILL.md
  - .devorq/skills/quality-gate/SKILL.md
  - .github/workflows/quality-gate.yml
  - bin/devorq
---

# SPEC-0075 — Melhorias de Rastreabilidade e Robustez do Workflow DEVORQ

**Data**: 2026-04-18
**Status**: draft
**Autor**: Nando Dev / Claude Code
**Fontes**: PROPOSTA-MELHORIA-DEVORQ-v1.0.md + code-review-hermes.md

---

## 1. Objetivo

Aplicar melhorias cirúrgicas ao orquestrador DEVORQ v2.1 em cinco frentes:

1. Tornar a SPEC um documento vivo com rastreabilidade de bugs via seção "RESOLUÇÕES DE PANES"
2. Instalar um git pre-commit hook lightweight que previne commits com erros de sintaxe Bash
3. Preencher o job `quality-generic` do CI (atualmente placeholder vazio)
4. Formalizar o trigger do `/systematic-debugging` quando testes falham no quality-gate
5. Formalizar o `/code-review` como pré-requisito do Gate 3

---

## 2. Contexto e Análise de Viabilidade

### 2.1 Problema Observado

Duas fontes identificaram os mesmos padrões de desvio:

| Problema | Fonte | Status Real |
|---|---|---|
| Bugs durante desenvolvimento não rastreados na SPEC | Proposta interna | Confirmado — template sem seção dedicada |
| Git hooks ausentes | Code review Hermes | Confirmado — apenas `.sample` no `.git/hooks/` |
| CI/CD ausente | Code review Hermes | **Incorreto** — já existe `quality-gate.yml`, mas `quality-generic` é placeholder vazio |
| systematic-debugging não integrada | Code review Hermes | Confirmado — skill completa, sem trigger formal |
| code-review não integrada | Code review Hermes | Confirmado — skill completa, sem posição formal no fluxo |
| Pipeline de lições ausente | Proposta interna | **Já implementado** (SPEC-0070, gates 5-7) — fora do escopo |

### 2.2 Causa Raiz por Item

**Seção RESOLUÇÕES DE PANES:**
O template da skill `/spec` define apenas: Objetivo, Fora do Escopo, Páginas/Telas, Regras de Negócio, Estimativa de Modelos. Não há campo para rastrear bugs que surgem durante o desenvolvimento da feature, criando um gap entre a SPEC como documento de planejamento e a realidade da execução.

**Git hook ausente:**
A quality-gate é interativa (Etapas 9 e 10 exigem resposta humana: `OK|BUG|N/A` e `A|E|R`). Por isso não pode ir num hook automático. O gap é a ausência de um hook lightweight que bloqueia erros de sintaxe Bash antes do commit, independentemente do fluxo manual.

**CI quality-generic vazio:**
O job existe mas contém apenas `echo "Generic stack - no additional gates defined"`. A ausência de verificações concretas significa que qualquer mudança em arquivos de configuração, skills ou hooks passa pelo CI sem validação estrutural.

**systematic-debugging sem trigger:**
A skill está implementada e completa (4 fases: REPRODUCE → ISOLATE → ROOT CAUSE → FIX & PREVENT), mas o quality-gate não menciona quando invocá-la. O developer pode tentar corrigir um teste falho sem análise de causa raiz.

**code-review sem posição no fluxo:**
A skill está implementada e completa (7 fases com auto-detecção de stack), mas não há posição formal no fluxo. O FLUXO_DESENVOLVIMENTO.md menciona code-review, mas o quality-gate não referencia quando executá-la.

---

## 3. Escopo

### 3.1 Escopo Positivo (o que SERÁ feito)

- [ ] Adicionar seção `## RESOLUÇÕES DE PANES` ao template canônico em `.devorq/skills/spec/SKILL.md`
- [ ] Criar `.devorq/hooks/pre-commit` — hook lightweight (bash -n + shellcheck se disponível)
- [ ] Adicionar subcomando `./bin/devorq hooks install` ao CLI para instalar o hook
- [ ] Preencher job `quality-generic` em `.github/workflows/quality-gate.yml` com validações reais
- [ ] Adicionar instrução no quality-gate: invocar `/systematic-debugging` quando Gate 1 (testes) falha
- [ ] Adicionar instrução no quality-gate: executar `/code-review` antes do checklist se houver mudanças de lógica/arquitetura
- [ ] Atualizar `docs/specs/_index.md` com esta SPEC

### 3.2 Escopo Negativo (o que NÃO será feito)

- Dashboard de métricas (overengineering — separar em SPEC própria se necessário)
- Context-mode size limit (separar em SPEC própria)
- Refatoração das skills systematic-debugging ou code-review (estão completas)
- Qualquer mudança no pipeline de lições (gates 5-7 — implementado e funcionando via SPEC-0070)
- Integração automática das skills ao CLI (skills são invocadas pelo LLM, não pelo Bash)
- Quality-gate interativa como git hook (incompatível com automação — requer resposta humana)

---

## 4. Mudanças Técnicas Detalhadas

### Mudança 1 — Seção RESOLUÇÕES DE PANES no template de SPEC

**Arquivo**: `.devorq/skills/spec/SKILL.md`

Adicionar ao final do template canônico (após `## Estimativa de Modelos`):

```markdown
## RESOLUÇÕES DE PANES

> Preencher durante o desenvolvimento sempre que um bug bloquear o progresso desta SPEC.

### Pane #001
- **Data:** DD/MM/YYYY HH:MM
- **Sintoma:** [O que foi reportado / o que o usuário viu]
- **Causa Raiz:** [Por que ocorreu — usar /systematic-debugging]
- **Localização:** [Arquivo:linha ou componente]
- **Decisão Técnica:** [Como foi corrigido e por quê]
- **Lição Aprendida:** [Conhecimento extraído — candidato para /learned-lesson]
- **Referência:** [Commit hash ou N/A]
- **Status:** Resolvido | Em análise | Pendente
```

**Impacto**: Toda SPEC gerada via `/spec` terá espaço estruturado para rastrear bugs durante o desenvolvimento. Os campos "Causa Raiz" e "Lição Aprendida" criam ponte direta para `/systematic-debugging` e `/learned-lesson`.

---

### Mudança 2 — Git pre-commit hook lightweight

**Arquivo a criar**: `.devorq/hooks/pre-commit`

```bash
#!/usr/bin/env bash
# DEVORQ pre-commit hook — syntax check lightweight
# Instalar via: ./bin/devorq hooks install

set -euo pipefail

DEVORQ_ROOT="$(git rev-parse --show-toplevel)"

echo "[DEVORQ hook] Verificando sintaxe Bash..."

# Syntax check obrigatório
bash -n "${DEVORQ_ROOT}/bin/devorq" || {
    echo "[DEVORQ hook] ERRO: bin/devorq tem erro de sintaxe. Commit bloqueado."
    exit 1
}

for f in "${DEVORQ_ROOT}"/lib/*.sh "${DEVORQ_ROOT}"/lib/**/*.sh 2>/dev/null; do
    [[ -f "$f" ]] || continue
    bash -n "$f" || {
        echo "[DEVORQ hook] ERRO: $f tem erro de sintaxe. Commit bloqueado."
        exit 1
    }
done

# Shellcheck opcional (se disponível)
if command -v shellcheck &>/dev/null; then
    echo "[DEVORQ hook] Rodando shellcheck..."
    shellcheck --severity=error "${DEVORQ_ROOT}/bin/devorq" || exit 1
    shellcheck --severity=error "${DEVORQ_ROOT}"/lib/*.sh || exit 1
fi

echo "[DEVORQ hook] OK — sintaxe Bash válida."
```

**Comando de instalação** a adicionar ao CLI (`./bin/devorq hooks install`):

```bash
# Copia .devorq/hooks/pre-commit → .git/hooks/pre-commit
# chmod +x .git/hooks/pre-commit
# Verifica que hook existe antes de sobrescrever (aviso)
```

**Por que NÃO incluir quality-gate completa no hook:**
As Etapas 9 e 10 do quality-gate exigem resposta humana (`OK|BUG|N/A` e `A|E|R`). Um hook automático não pode aguardar input interativo de forma confiável em todos os ambientes (GUI clients, rebase automático, etc.). O hook lightweight cobre o gap mais crítico: sintaxe inválida commitada.

---

### Mudança 3 — CI job quality-generic preenchido

**Arquivo**: `.github/workflows/quality-gate.yml`

Substituir o job `quality-generic` por:

```yaml
quality-generic:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v5

    - name: Install shellcheck
      run: |
        sudo apt-get update -qq
        sudo apt-get install -y shellcheck

    - name: Bash syntax check — todos os scripts
      run: |
        bash -n bin/devorq
        for f in lib/*.sh lib/**/*.sh; do
          [[ -f "$f" ]] && bash -n "$f"
        done

    - name: Shellcheck — severity warning (não-erro)
      run: |
        shellcheck --severity=warning bin/devorq || true
        shellcheck --severity=warning lib/*.sh || true

    - name: Validar estrutura de skills
      run: |
        for skill_dir in .devorq/skills/*/; do
          skill_name=$(basename "$skill_dir")
          if [[ ! -f "${skill_dir}SKILL.md" ]]; then
            echo "ERRO: skill '$skill_name' sem SKILL.md"
            exit 1
          fi
          if [[ ! -f "${skill_dir}CHANGELOG.md" ]]; then
            echo "AVISO: skill '$skill_name' sem CHANGELOG.md"
          fi
        done
        echo "Estrutura de skills OK"
```

**Impacto**: O CI agora valida: syntax check de todos os scripts + shellcheck warnings + estrutura obrigatória de skills.

---

### Mudança 4 — Trigger de systematic-debugging no quality-gate

**Arquivo**: `.devorq/skills/quality-gate/SKILL.md`

Adicionar instrução na Etapa 1 (Testes):

```markdown
### 1. Testes
- [ ] Todos passando
- [ ] Novos testes adicionados
- [ ] Sem regressão

> **Se testes falham**: Invocar `/systematic-debugging` ANTES de tentar corrigir.
> Nunca corrigir um teste falhando sem identificar a causa raiz.
```

**Impacto**: Formaliza o trigger para a skill que já existe. Previne o padrão de "tentar corrigir antes de entender".

---

### Mudança 5 — code-review como pré-requisito do Gate 3

**Arquivo**: `.devorq/skills/quality-gate/SKILL.md`

Adicionar bloco de pré-requisito antes do checklist:

```markdown
## Pré-requisito — Code Review

Se as mudanças incluem:
- Novas funções ou módulos
- Alteração de arquitetura ou fluxo
- Mudanças em mais de 3 arquivos

→ Executar `/code-review` antes deste checklist.
→ Registrar resultado (Aprovado | Pendências resolvidas) antes de prosseguir.

Para mudanças mínimas (typo, comentário, config de 1 linha): pode pular.
```

**Impacto**: O code-review passa a ter posição formal e critérios claros de quando é obrigatório vs. opcional.

---

## 5. Critérios de Aceite

- [ ] `./bin/devorq spec` gera template com seção `## RESOLUÇÕES DE PANES`
- [ ] `./bin/devorq hooks install` cria `.git/hooks/pre-commit` executável
- [ ] Hook bloqueia commit quando `bin/devorq` tem erro de sintaxe intencional
- [ ] Hook passa normalmente quando todos os scripts estão válidos
- [ ] Job `quality-generic` no CI executa sem erro em push para main
- [ ] Job `quality-generic` falha se skill sem `SKILL.md` for criada
- [ ] `/quality-gate` apresenta instrução de invocar `/systematic-debugging` quando Gate 1 falha
- [ ] `/quality-gate` apresenta instrução de `/code-review` como pré-requisito em mudanças de arquitetura

---

## 6. Dependências

- `bin/devorq` atual (nenhuma dependência nova — shellcheck é opcional no hook)
- `.devorq/skills/systematic-debugging/SKILL.md` — já existe e está completa
- `.devorq/skills/code-review/SKILL.md` — já existe e está completa
- `shellcheck` — já instalado no CI, opcional localmente

---

## 7. Riscos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Hook conflita com hooks existentes de outros projetos que instalam o DEVORQ | Baixa | `hooks install` verifica se hook já existe e pede confirmação antes de sobrescrever |
| `quality-generic` falha em branches com skills em desenvolvimento (sem CHANGELOG.md) | Média | Tratar ausência de CHANGELOG.md como AVISO, não erro bloqueante |
| Template de SPEC com RESOLUÇÕES DE PANES aumenta tamanho médio dos arquivos | Baixa | Seção é opcional no preenchimento, obrigatória apenas quando há pane |

---

## 8. RESOLUÇÕES DE PANES

> Preencher durante o desenvolvimento desta SPEC.

*(Nenhuma pane registrada durante a análise e criação da SPEC.)*

---

## 9. Estimativa de Esforço

| Mudança | Arquivos | Esforço |
|---|---|---|
| Template RESOLUÇÕES DE PANES | 1 (`spec/SKILL.md`) | 15 min |
| Hook pre-commit + CLI `hooks install` | 2 (novo hook + `bin/devorq`) | 45 min |
| CI quality-generic | 1 (`quality-gate.yml`) | 20 min |
| Trigger systematic-debugging | 1 (`quality-gate/SKILL.md`) | 10 min |
| code-review pré-requisito | 1 (`quality-gate/SKILL.md`) | 10 min |
| **Total** | **5-6 arquivos** | **~100 min** |

---

## 10. Encerramento

- **Aprovação necessária**: Gate 1 — revisar e confirmar escopo antes de implementar
- **Próximo passo após aprovação**: `/break` para decomposição em tarefas atômicas, seguido de implementação por task
- **Sessão de implementação**: Separada desta — SPEC entra em `approved/` após Gate 1
