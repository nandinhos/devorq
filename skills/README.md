# Skills — Índice do Framework DEVORQ

**Propósito:** Habilidades do framework DEVORQ versionadas no repo canônico em `DEVORQ_ROOT/skills/`.

## Estrutura

Cada skill segue o formato:
```
skills/<nome>/
├── SKILL.md           # Definição (obrigatório)
├── scripts/           # Scripts bash auxiliares
├── references/        # Documentação complementar
└── approved/          # Lições aprovadas que geraram a skill
```

## Skills Globais (carregadas do DEVORQ_ROOT)

| Skill | Descrição |
|-------|-----------|
| `devorq-mode` | Seletor AUTO vs CLASSIC |
| `devorq-auto` | Loop story-by-story para modo AUTO |
| `devorq-code-review` | Review multi-agente com scoring 0-100 |
| `scope-guard` | GATE-0: contrato de escopo |
| `ddd-deep-domain` | GATE-0: exploração de domínio |
| `env-context` | GATE-0: detecção de ambiente |
| `project-foundation` | Geração de 5 foundation docs |
| `grill-with-docs` | GATE-0: sparring terminológico |
| `security-hardening` | Regras de segurança |

## Hierarquia local > global

Skills locais em `.devorq/skills/<nome>/` do projeto sobrescrevem globais se:
1. Tiverem mesmo nome
2. Lógica não conflitar

Para criar skill local:
```bash
mkdir -p .devorq/skills/<nome>
# Criar .devorq/skills/<nome>/SKILL.md
```

## Auto-melhoria via lições

Fluxo operacional (confirmado em `lib/lessons.sh`):
```
lição validada (Context7) → devorq lessons approve → devorq lessons compile → skill gerada em skills/<nome>/
```

Com `LESSONS_AUTO=true` o fluxo é automático.

## Comandos

```bash
devorq skills list          # Lista skills do framework + geradas
devorq skills load <nome>   # Mostra info de uma skill
skill_view <nome>          # No Hermes: carrega skill completa
```