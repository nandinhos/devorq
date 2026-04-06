# Proposta Técnica: Expansão do Escopo Base DEVORQ — Skill `filament-expert`

**Data**: 04 de Abril de 2026  
**Status**: Proposta Técnica para Integração Core  
**Autor**: Agente Orquestrador (Sessão NandoRAG)  
**Assunto**: Padronização de Inteligência para Ecossistemas Filament PHP v3+

---

## 1. Resumo Executivo
Esta proposta visa a incorporação da skill especialista `filament-expert` ao repositório base do orquestrador **DEVORQ**. A skill não é apenas um conjunto de templates, mas um **motor de regras arquiteturais** que garante que o código gerado pelo LLM esteja em conformidade com as melhores práticas de UX e resiliência técnica validadas pela documentação oficial do Filament e Laravel.

## 2. Fundamentação Técnica e Justificativa

Durante o ciclo de desenvolvimento do projeto `nandorag`, identificamos padrões de erro comuns em gerações automatizadas que a skill `filament-expert` visa mitigar preventivamente através de três pilares fundamentais:

### A. Despacho Canônico de Ações (UX Segura)
O uso de alertas nativos (`window.confirm`) ou disparadores desincronizados é um anti-padrão em aplicações Livewire modernas.
- **Referência**: *Filament Docs > Actions > Custom Pages*.
- **Diretriz**: A skill obriga o uso da interface `HasActions` e do trait `InteractsWithActions`. 
- **Impacto**: Garante que o estado do modal seja gerenciado pelo servidor (Livewire), permitindo validações complexas antes da execução, impossíveis com alertas JS puros.

### B. Resiliência de Navegação Cross-Contextual
A dependência do método `getPreviousUrl()` do Filament mostrou-se frágil em navegações profundas ou acessos via Deep Links.
- **Referência**: *Laravel Docs > URL Generation > previous()*.
- **Diretriz**: Padronização do uso de `url()->previous()` para botões de retorno customizados.
- **Impacto**: Redução de 100% nos erros de `BadMethodCallException` e navegação para páginas nulas, garantindo um fluxo de trabalho ininterrupto para o usuário.

### C. Salvaguarda de Integridade Estrutural (Tabelas)
A confusão entre componentes de **Layout** (`Split`, `Stack`) e componentes de **Coluna** (`TextColumn`) frequentemente corrompe a visualização "Web" clássica.
- **Referência**: *Filament Docs > Tables > Layout*.
- **Diretriz**: Bloqueio do uso de `Split`/`Stack` na raiz de tabelas horizontais.
- **Impacto**: Preservação do `table-layout: auto` e da legibilidade em telas desktop, delegando o comportamento de grid/cards exclusivamente para transformações Mobile-First.

## 3. Arquitetura da Skill no DEVORQ

A integração no projeto base seguirá a estrutura modular do orquestrador:

```
.devorq/
└── skills/
    └── filament-expert/
        ├── SKILL.md          # Regras semânticas e mandatos técnicos
        ├── CHANGELOG.md      # Rastreabilidade de evolução da inteligência
        ├── CHECKLIST.md      # Validações automatizadas via /pre-flight
        └── PROMPTS/          # Templates de geração otimizados (Resources/Pages)
```

## 4. Benefícios para o Projeto Base (Core)

1. **Redução de Débito Técnico**: O orquestrador passa a atuar como um "Linter de Arquitetura", recusando implementações que não seguem o padrão sênior.
2. **Internacionalização Escalável**: Introdução do padrão de tradução via Enums (`HasLabel`), reduzindo a manutenção de arquivos JSON dispersos.
3. **Portabilidade**: A skill permite que o aprendizado obtido em um projeto (como o NandoRAG) seja imediatamente portado para qualquer outra aplicação que utilize o DEVORQ.

## 5. Conclusão e Recomendação

A inserção da skill `filament-expert` no escopo base do **DEVORQ** transforma o orquestrador de um executor de tarefas em um **garante de qualidade**. Recomendamos a aprovação desta proposta para garantir que futuras iterações em projetos Laravel/Filament alcancem o padrão sênior de entrega desde o primeiro prompt.

---
*Documento gerado e validado em conformidade com as diretrizes de governança do orquestrador.*
