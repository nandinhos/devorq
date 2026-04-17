---
id: SPEC-0071-16-04-2026
title: Hook Post-Commit para Captura de Lição Aprendida após SPEC Implementada
domain: arquitetura
status: implemented
priority: medium
owner: team-core
created_at: 2026-04-16
updated_at: 2026-04-17
source: manual
related_tasks: []
related_files:
  - .devorq/hooks/post-commit
  - lib/lessons.sh
---

# Spec — Hook Post-Commit para Captura de Lição Aprendida

**Data**: 2026-04-16
**Status**: draft
**Autor**: Sessão de brainstorming DEVORQ (Nando + MiniMax-M2.7)

---

## Objetivo

Implementar captura de lição aprendida no momento em que uma SPEC é completada (movida para `implemented/`), via hook post-commit. O processo é **não-bloqueante** e permite que a validação ocorra imediatamente ou em momento separado.

---

## Trigger

Commit que move uma SPEC para `docs/specs/implemented/` (detecta via análise do commit mais recente no post-commit hook).

---

## Fluxo Completo

```
[git commit move SPEC → implemented/]
              │
              ▼
[post-commit hook detecta: SPEC com status: implemented]
              │
              ▼
[Pergunta: "Capturar lição aprendida desta SPEC?"]
              │
         S ─────── N
         │       │
         ▼       ▼
[Cria skeleton em lessons-pending/]   [sai silencioso]
              │
              ▼
[Pergunta: "Analisar/agendar validação AGORA ou DEPOIS?"]
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
[Agora]            [Depois]
(Context7 val)      (Fica pending)
    │                   │
    ▼                   ▼
[Gate 6 validação]  [Processo SEPARADO]
    │                   │
    ▼                   ▼
[Gate 7 destino]
    │
    ├── [1] Skill existente
    ├── [2] Nova skill
    ├── [3] Global user
    └── [4] Memória local
              │
              ▼
[Commit da lição se aplicável]
```

---

## Regras de Negócio

1. **Commit nunca é bloqueado** — o hook sempre permite o commit proseguir
2. **Lição é sempre criada em `lessons-pending/` primeiro** — nunca vai direto para validated/applied
3. **Validação pode ser imediata ou adiada** — escolha do usuário no momento do trigger
4. **Processo de validação SEPARADO** — não conflita com ciclo de commit
5. **Detecção via git diff do último commit** — post-commit examina o que acabou de ser commitado

---

## Estrutura da Lição Capturada (Skeleton)

```yaml
---
id: LESSON-NNNN-DD-MM-YYYY
title: <titulo da SPEC original>
domain: <domain da SPEC original>
status: pending
priority: medium
owner: team-core
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
source: spec-completion
related_tasks: []
related_files: []
applied_to: ""
spec_origin: SPEC-XXXX-DD-MM-YYYY
---

# Lição Aprendida — LESSON-NNNN-DD-MM-YYYY

## O QUE FOI IMPLEMENTADO

[Breve descrição do que a SPEC entregou]

## DESAFIOS ENCONTRADOS

[Principais dificuldades durante a implementação]

## DOCUMENTAÇÃO DE REFERÊNCIA

[Links, comandos, recursos consultados]

## LIÇÕES PRINCIPAIS

- [ ]
- [ ]

## PRÓXIMOS PASSOS (se aplicável)

[O que poderia ser feito a partir daqui]
```

---

## Componentes / Artefatos Afetados

| Artefato | Tipo | Ação |
|----------|------|------|
| `.devorq/hooks/post-commit` | hook | Criar — detecção + guard de interatividade + fluxo de perguntas |
| `.devorq/skills/spec/SKILL.md` | skill | Adicionar referência ao novo fluxo |
| `.devorq/skills/learned-lesson/SKILL.md` | skill | Adicionar `spec-completion` como source válido |

> **Nota**: `.devorq/hooks/pre-commit` **não é modificado**. O hook post-commit funciona automaticamente se `core.hooksPath` já aponta para `.devorq/hooks/` (configurado pelo `devorq init`). Quem não tem `core.hooksPath` configurado já não tem o pre-commit ativo — o problema de instalação é anterior a esta SPEC.

---

## Fora do Escopo

- Validação Context7 automática — inicia o fluxo existente
- Instalação nativa em `.git/hooks/` via git template
- Migration de lições existentes para o novo fluxo
- Processos de validação em lote (múltiplas lições pendentes)

---

## Plano de Implementação

### Passo 1 — Criar hook post-commit

Criar `.devorq/hooks/post-commit` com:

```bash
#!/usr/bin/env bash
# Guard obrigatório — sai silenciosamente em ambientes não-interativos
# (CI, IDEs, scripts automatizados). Nunca bloqueia o commit.
[ -t 1 ] || exit 0
```

Seguido de:

1. `git diff --name-status HEAD~1..HEAD` para detectar arquivos modificados
2. Filtrar por arquivos `.md` que entraram em `docs/specs/implemented/` vindo de outro diretório
3. Se detectado → iniciar fluxo de perguntas interativo
4. Guard para primeiro commit do repo (sem `HEAD~1`): `git rev-parse HEAD~1 2>/dev/null || exit 0`

### Passo 2 — Atualizar skill learned-lesson

Adicionar `spec-completion` como source válido no front matter.

### Passo 3 — Tests

Criar `tests/post-commit.bats` com duas estratégias distintas:

**Testes sem stdin (detecção + criação de skeleton):**
- Chamar diretamente as funções internas do hook (via source)
- Verificar criação do arquivo em `lessons-pending/` com front matter correto
- Verificar campo `spec_origin` populado com ID da SPEC

**Testes com stdin mockado (fluxo interativo):**
```bash
# Fluxo "Sim → Depois"
echo -e "S\nD" | bash .devorq/hooks/post-commit

# Fluxo "Não"
echo "N" | bash .devorq/hooks/post-commit
```
- Verificar que "N" não cria arquivo em `lessons-pending/`
- Verificar que "S\nD" cria skeleton e sai sem iniciar Gate 6
- Ambiente não-interativo: chamar sem terminal e verificar exit 0 sem efeito colateral

---

## Critérios de Aceitação

- [ ] Post-commit hook detecta commit que move SPEC para `implemented/`
- [ ] Pergunta interativa funciona no terminal ("Capturar lição?")
- [ ] Lição skeleton criada em `lessons-pending/` com front matter correto
- [ ] Fluxo "agora" inicia `/learned-lesson` interativo
- [ ] Fluxo "depois" deixa lição em pending sem bloquear
- [ ] Hook não bloqueia commit em nenhum momento
- [ ] `tests/post-commit.bats` cobre cenário principal
- [ ] Shellcheck limpo no novo hook
- [ ] `HOME=/tmp/no-devorq bats tests/` continua 100% verde

---

## Riscos e Mitigação

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Commit feito via IDE ou CI (sem terminal interativo) | alto | Guard `[ -t 1 ] \|\| exit 0` no início do hook — sai silenciosamente sem bloquear |
| `git diff HEAD~1` falha no primeiro commit do repo (sem HEAD~1) | médio | Guard `git rev-parse HEAD~1 2>/dev/null \|\| exit 0` antes da detecção |
| `core.hooksPath` não aponta para `.devorq/hooks/` | médio | Usuário que não rodou `devorq init` não tem nenhum hook ativo — problema anterior a esta SPEC, não endereçado aqui |
| Usuário responde "S" mas não completa a lição | baixo | Lição fica em pending para processo separado |
| Múltiplas SPECs commitadas em sequência | baixo | Hook processa apenas a última (MVP aceitável) |

---

## Dependências

- `lib/lessons.sh` com `capture_lesson` funcionando (já existe)
- Hook pre-commit existente (já existe)
- Skill `/learned-lesson` com Gate 6/7 (já existe após SPEC-0070)
