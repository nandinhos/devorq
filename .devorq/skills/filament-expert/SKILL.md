---
name: filament-expert
description: Motor de regras arquiteturais para projetos Filament PHP v3+ — anti-patterns e mandatos técnicos derivados de bugs reais
triggers:
  - "filament"
  - "filament-expert"
  - "admin panel"
  - "filament resource"
globs:
  - "**/*.php"
---

# Skill: filament-expert

> **Esta skill complementa o agente `filament/`**. O agente define o *modo de operação*. Esta skill define o *que é proibido e o que é obrigatório*.

## Quando Usar

**OBRIGATÓRIO** para qualquer projeto Filament v3+ quando:
- Criando Pages customizadas com actions
- Implementando botões de navegação/voltar
- Construindo tabelas com layout customizado

## Mandatos Técnicos (Obrigatórios)

### Mandato 1 — Despacho Canônico de Ações

**Proibido:**
- `window.confirm()` em código Filament/Livewire
- `onclick` JS direto em elementos de ação
- Disparadores desincronizados

**Obrigatório:**
- Usar interface `HasActions` + trait `InteractsWithActions` em Pages customizadas
- Actions declaradas via método `getActions()` ou trait

**Motivo:** Estado do modal gerenciado pelo servidor (Livewire) permite validações complexas impossíveis com JS puro. O `window.confirm` é anti-padrão em aplicações Livewire modernas.

**Referência:** Filament Docs > Actions > Custom Pages

---

### Mandato 2 — Resiliência de Navegação Cross-Contextual

**Proibido:**
- `$this->getPreviousUrl()` em botões de retorno customizados
- Métodos proprietários do Filament para navegação anterior

**Obrigatório:**
- Usar `url()->previous()` (helper Laravel nativo)

**Motivo:** `getPreviousUrl()` falha em deep links e navegações diretas. Gera `BadMethodCallException` e navegação para null em contextos específicos.

**Referência:** Laravel Docs > URL Generation > previous()

---

### Mandato 3 — Integridade Estrutural de Tabelas

**Proibido:**
- `Split` e `Stack` na raiz de tabelas horizontais (layout desktop)
- Usar componentes de Layout como colunas de tabela

**Obrigatório:**
- `Split`/`Stack` apenas dentro de transformações Mobile-First (`->visibleFrom('md')` ou similar)
- Manter `table-layout: auto` para visualização desktop

**Motivo:** Componentes de Layout na raiz de tabelas corrompe `table-layout: auto` e quebra visualização desktop legível.

**Referência:** Filament Docs > Tables > Layout

---

## Anti-Patterns Proibidos

| Pattern | Problema | Solução |
|---------|----------|---------|
| `window.confirm('Tem certeza?')` | Bloqueio JS síncrono, não valida no servidor | Usar Action com modal de confirmação Filament |
| `$this->getPreviousUrl()` | Falha em deep links | `url()->previous()` |
| `Split` na raiz de table | Quebra layout desktop | Usar só em `visibleFrom('md')` |
| `Stack` como column | Componente de layout usado como dado | Remover da definição de columns |

---

## Recomendações (Não Bloqueantes)

### Internacionalização via Enum

**Preferido:** Tradução via Enums com `HasLabel` interface
```php
enum Status: string
{
    use HasLabel;
    
    case ACTIVE = 'active';
    case INACTIVE = 'inactive';
    
    public function getLabel(): string
    {
        return match($this) {
            self::ACTIVE => 'Ativo',
            self::INACTIVE => 'Inativo',
        };
    }
}
```

**Evitar:** Arrays de tradução dispersos em múltiplos arquivos JSON para enums.

---

## Checklist de Validação (/pre-flight)

Antes de任何 código Filament ser commitado, verificar:

- [ ] Nenhum `window.confirm()` encontrado em arquivos Filament
- [ ] Nenhum `$this->getPreviousUrl()` encontrado
- [ ] `Split`/`Stack` só aparecem com `visibleFrom()` ou similar
- [ ] Pages com actions declaram `HasActions` ou `InteractsWithActions`
- [ ] Usa `url()->previous()` para botões de voltar customizados

---

## Fontes de Verdade

- Filament Docs: https://filamentphp.com/docs/3.x/actions
- Laravel Docs: https://laravel.com/docs/11.x/urls#retrieving-the-previous-url
- Filament Tables: https://filamentphp.com/docs/3.x/tables/layout