---
id: SPEC-0006-05-04-2026
title: Skill filament-expert — Motor de Regras Arquiteturais Filament v3+
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-05
updated_at: 2026-04-06
source: proposal/skills/skill_expansion_filament_expert.md
related_tasks: []
related_files:
  - .devorq/skills/filament-expert/SKILL.md
  - .devorq/skills/filament-expert/CHANGELOG.md
  - .devorq/skills/filament-expert/VERSIONS/
  - .devorq/agents/filament/SKILL.md
---

# Spec — Skill `filament-expert`

**Data**: 2026-04-05
**Status**: approved
**Autor**: Arquiteto (sessão devorq)

---

## Objetivo

Criar a skill `filament-expert` no repositório base do DEVORQ como **motor de regras arquiteturais** para projetos Filament PHP v3+. A skill não é tutorial — é um conjunto de mandatos técnicos derivados de bugs reais capturados no projeto NandoRAG, que o LLM deve obedecer ao gerar código Filament.

Complementa (não substitui) o `agents/filament/SKILL.md`, que define o *modo de operação*. A skill define o *que é proibido e o que é obrigatório*.

Resolve a lacuna atual: o agente `filament/` é genérico e não tem nenhuma regra de bloqueio. Projetos Filament novos herdam os mesmos bugs estruturais que o NandoRAG sofreu.

---

## Fora do Escopo

- Diretório `PROMPTS/` com templates de geração (sem mecanismo de carregamento automático, seria peso morto)
- Arquivo `CHECKLIST.md` separado (as regras ficam em seção do próprio `SKILL.md`)
- Modificação do `bin/devorq` ou criação de comandos CLI novos
- Cobertura de Filament v2 (foco em v3+)
- Regras de autenticação/autorização (escopo de outra skill)
- Integração com Filament Shield ou plugins de terceiros

---

## Componentes / Artefatos Afetados

| Artefato | Tipo | Ação |
|----------|------|------|
| `.devorq/skills/filament-expert/` | diretório | criar |
| `.devorq/skills/filament-expert/SKILL.md` | skill principal | criar |
| `.devorq/skills/filament-expert/CHANGELOG.md` | rastreabilidade | criar |
| `.devorq/skills/filament-expert/VERSIONS/` | snapshots | criar (estrutura vazia) |
| `.devorq/agents/filament/SKILL.md` | agente existente | atualizar — adicionar seção Anti-Patterns |

---

## Regras de Negócio

### Regra 1 — Despacho Canônico de Ações (obrigatória)
- **Proibido**: `window.confirm()`, `onclick` JS direto, disparadores desincronizados em actions Filament
- **Obrigatório**: `HasActions` interface + `InteractsWithActions` trait em Pages customizadas com actions
- **Motivo**: estado do modal gerenciado pelo servidor (Livewire) permite validações complexas impossíveis com JS puro
- **Referência**: Filament Docs > Actions > Custom Pages

### Regra 2 — Resiliência de Navegação Cross-Contextual (obrigatória)
- **Proibido**: `$this->getPreviousUrl()` em botões de retorno customizados
- **Obrigatório**: `url()->previous()` (helper Laravel nativo)
- **Motivo**: `getPreviousUrl()` falha em deep links e navegações diretas — gera `BadMethodCallException` e navegação para null
- **Referência**: Laravel Docs > URL Generation > previous()

### Regra 3 — Integridade Estrutural de Tabelas (obrigatória)
- **Proibido**: `Split` e `Stack` na raiz de tabelas horizontais (layout desktop)
- **Obrigatório**: `Split`/`Stack` apenas dentro de transformações Mobile-First (`->visibleFrom('md')` ou similar)
- **Motivo**: componentes de Layout na raiz corrompe `table-layout: auto` e quebra visualização desktop
- **Referência**: Filament Docs > Tables > Layout

### Regra 4 — Internacionalização via Enum (recomendada)
- **Preferido**: tradução via Enums com `HasLabel` interface
- **Evitar**: arrays de tradução dispersos em múltiplos arquivos JSON para enums
- **Motivo**: manutenção centralizada, type safety, portabilidade entre projetos

### Regra 5 — Estrutura da skill segue convenção DEVORQ
- A skill deve ter seções: `## Quando Usar`, `## Mandatos (Obrigatórios)`, `## Anti-Patterns`, `## Checklist de Validação`
- Não cria `CHECKLIST.md` separado — checklist fica dentro do `SKILL.md`
- Versiona via `./bin/devorq skill version filament-expert <patch|minor|major>`

---

## Estrutura de Arquivos Alvo

```
.devorq/skills/filament-expert/
  SKILL.md        ← regras, anti-patterns, checklist
  CHANGELOG.md    ← histórico de versões da inteligência
  VERSIONS/       ← snapshots de versões anteriores (vazio no v1.0.0)
```

**Seções obrigatórias do `SKILL.md`:**
```markdown
## Quando Usar
## Mandatos Técnicos (Obrigatórios)
### Mandato 1 — Despacho Canônico de Ações
### Mandato 2 — Navegação Cross-Contextual
### Mandato 3 — Integridade de Tabelas
## Anti-Patterns Proibidos
## Recomendações (Não Bloqueantes)
## Checklist de Validação (/pre-flight)
## Fontes de Verdade
```

**Atualização em `agents/filament/SKILL.md`:**
Adicionar seção `## Anti-Patterns Obrigatórios` com as 3 regras em formato conciso (sem duplicar todo o conteúdo — referenciar a skill).

---

## Critérios de Aceitação (Done Criteria)

- [ ] `.devorq/skills/filament-expert/SKILL.md` existe com as 3 regras obrigatórias documentadas
- [ ] `.devorq/skills/filament-expert/CHANGELOG.md` existe com entrada `v1.0.0`
- [ ] `.devorq/skills/filament-expert/VERSIONS/` existe (pode estar vazio)
- [ ] `.devorq/agents/filament/SKILL.md` tem seção `## Anti-Patterns Obrigatórios` referenciando a skill
- [ ] Nenhum arquivo `CHECKLIST.md` separado foi criado
- [ ] Nenhum diretório `PROMPTS/` foi criado
- [ ] A skill está listada no `CLAUDE.md` ou em `SLASH_COMMANDS.md` se tiver trigger
- [ ] Um projeto Filament real consegue usar a skill como checklist de /pre-flight sem ambiguidade
