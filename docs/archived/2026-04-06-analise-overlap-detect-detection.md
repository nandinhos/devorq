# Análise de Overlap — detect.sh vs detection.sh

**Data**: 2026-04-06

## Conclusão: Sobrecarga Intencional (não bug)

### Funções que existem em ambos:

| Função | detect.sh | detection.sh | Propósito |
|--------|-----------|---------------|-----------|
| `detect_stack()` | ✅ | ✅ | Detectar stack do projeto |
| `detect_runtime()` | ✅ | ✅ | Detectar runtime (docker/local) |

### Análise

**detect.sh** (11 funções):
- Focado em detecção para o CLI principal
- Usado por `./bin/devorq init`
- Retorna valores simples (strings)

**detection.sh** (14 funções):
- Focado em análise mais profunda do projeto
- Usado em workflows de análise
- Pode retornar estruturas JSON mais complexas

### Recomendação

Manter ambos separados. são APIs com propósitos diferentes:
- `detect.sh` → CLI quick checks
- `detection.sh` → análise profunda

Verificar se há chamadas redundantes e normalizar se necessário em refatoração futura.

---

## DONE_CRITERIA — TASK-005

- [x] Análise concluída
- [x] Recomendação documentada
- [x] Não é bug, é design intencional