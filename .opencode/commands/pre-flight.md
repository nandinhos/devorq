Executar validação pré-implementação (pre-flight check).

Leia `.devorq/skills/pre-flight/SKILL.md` para instruções completas.

## Validações Obrigatórias

### 1. Enums e Tipos
- Identificar todos os enums usados na task
- Verificar valores válidos diretamente no código (NUNCA inferir)
- Confirmar que os valores usados no código novo batem com os definidos

### 2. Dependências
- Listar packages necessários
- Verificar se estão em `composer.json` / `package.json` / `requirements.txt`
- Confirmar versões compatíveis

### 3. Schema de Banco
- Listar colunas usadas
- Verificar se migrations existem
- Confirmar tipos de coluna (string vs int vs enum vs json)

### 4. Contratos de API
- Se consumir API externa: verificar endpoint, payload esperado
- Se for API interna: verificar Form Request existente

## Relatório

```markdown
# PRE-FLIGHT — [task]

## Enums Validados
| Enum | Valores Válidos | Status |
|------|-----------------|--------|
| [nome] | [v1, v2] | ✅ OK |

## Dependências
| Package | Versão | Status |
|---------|--------|--------|
| [nome] | [x.y] | ✅ instalado |

## Schema
| Tabela | Coluna | Tipo | Status |
|--------|--------|------|--------|
| [nome] | [col] | [tipo] | ✅ OK |

## Bloqueadores
- [ ] nenhum / [lista de itens a resolver]
```

## Gate 2

Apresentar relatório e aguardar aprovação antes de iniciar TDD.
