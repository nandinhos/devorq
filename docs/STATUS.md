# Status do DEVORQ

**Versão:** 4.1.0  
**Atualizado:** 2026-07-13

## Estado atual

O DEVORQ mantém Bash+jq como núcleo local e fail-closed. AUTO, gates e adapters
multi-runner continuam suportados. O novo perfil `implementation` está disponível por
opt-in em `devorq loop implementation --experimental`.

| Área | Estado | Evidência principal |
|---|---|---|
| AUTO | ativo, com estados terminais explícitos | `skills/devorq-auto/scripts/loop-auto.sh` |
| Loop Engineering | experimental, somente `implementation` | `lib/loop.sh`, `scripts/loop-implementation.sh` |
| Contratos | v1, validação Bash+jq fail-closed | `lib/contracts.sh`, `schemas/*.v1.schema.json` |
| Verificação | executor, verifier e juiz separados por papel | `lib/loop.sh:devorq::loop::judge_implementation` |
| Persistência | eventos e evidências locais por run | `.devorq/state/runs/<run_id>/` |

Perfis `code-review`, `debugging`, `documentation`, `migration`, `import-audit`, `release` e
`custom` ainda não são comandos `loop`: exigem verifier e gates específicos antes de exposição.

Detalhes: [arquitetura](architecture/LOOP-ENGINEERING.md), [ADR-001](adr/ADR-001-loop-engineering-minimo.md), [release v4.1.0](releases/4.1.0.md).
