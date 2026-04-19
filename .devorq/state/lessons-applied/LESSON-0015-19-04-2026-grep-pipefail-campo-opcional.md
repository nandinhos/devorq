id: LESSON-0015-19-04-2026
title: grep-pipeline-falha-silenciosamente-com-set-e-quando-campo-e-opcional
domain: bash-scripting
status: applied
priority: high
owner: nandodev
created_at: 2026-04-19
updated_at: 2026-04-19
source: session-audit
related_tasks: TD-001
related_files: lib/lessons.sh
applied_to: skill:systematic-debugging

## SINTOMA
`devorq lessons list` abortava após exibir `=== LIÇÕES VALIDADAS ===`, nunca chegando à seção APLICADAS. Exit code 1 sem mensagem de erro visível.

## CAUSA
Pipeline `grep -m1 "^campo:" "$f" | cut -d: -f2 | xargs` retorna exit 1 quando `grep` não encontra o padrão. Com `set -eEo pipefail` ativo, o script encerra imediatamente — mesmo dentro de `for` loop. Bug invisível em bats (não herda `set -e`) mas reproduzível 100% via CLI.

## FIX
```bash
# Antes
valor=$(grep -m1 "^campo:" "$f" | cut -d: -f2 | xargs)

# Depois
valor=$(grep -m1 "^campo:" "$f" | cut -d: -f2 | xargs || true)
```

## SKILL AFETADA
systematic-debugging

## PREVENÇÃO
- Em scripts com `set -eEo pipefail`, pipelines `grep | ...` em campos **opcionais** devem ter `|| true`
- Testes para scripts com `set -e` devem ser executados via CLI (não via `source` em bats) para reproduzir o ambiente real

## VALIDAÇÃO (Gate 6)
validation_result: CONFIRMADO
validation_details: Confirmado pela documentação.
diff_proposed: |
+ ## Nova Regra: LESSON-0015-19-04-2026-grep-pipefail-campo-opcional
+ ```bash # Antes
+ **Skill:** systematic-debugging
validated_at: 2026-04-19T05:47:10-03:00
