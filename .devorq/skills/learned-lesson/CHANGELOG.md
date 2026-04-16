# CHANGELOG — learned-lesson

## v2.1.0 (2026-04-16)

- Front matter substituído pelo canônico de 12 campos (SPEC-0007): id, title, domain, status, priority, owner, created_at, updated_at, source, related_tasks, related_files, applied_to
- Campo `skill_target` descontinuado em favor de `applied_to`
- Campo `validation_result` removido (classificação Context7 permanece no parecer)
- Campo `diff_proposed` removido (diff é gerado inline no Gate 7)
- Gate 7 expandido para 4 destinos: skill existente, nova skill, memória global, memória local
- ID padronizado para LESSON-NNNN-DD-MM-YYYY (sequencial global)
- Diálogo canônico do Gate 7 documentado
- Referência: SPEC-0070

## v2.0.0 (2026-04-16)

- Pipeline Gates 6/7 implementado
- Front matter com novos campos: skill_target, validation_result, diff_proposed
- Context7 validação automática via MCP
- Diff híbrido: sistema gera, usuário edita
- Snapshot e versionamento de skills
- Estrutura de status: pending → validated → applied

## v1.0.0 (2026-03-31)

- Versão inicial da skill
