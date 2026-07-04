# Estratégia de Testes DEVORQ

## Visão Geral

Sistema de testes em camadas com systematic-debugging quando falhas ocorrem.

## Camadas de Testes

```
┌─────────────────────────────────────────────────────────┐
│                    E2E Tests (Playwright)                 │
│   Fluxos completos: init → capture → gate → compact     │
├─────────────────────────────────────────────────────────┤
│                  Integration Tests (bash)                │
│   VPS sync, Context7, Skills loading                    │
├─────────────────────────────────────────────────────────┤
│                   Security Tests (bash)                 │
│   Input validation, path traversal, SQL injection        │
├─────────────────────────────────────────────────────────┤
│                   Unit Tests (bash)                      │
│   Funções isoladas: gates, lessons, context             │
└─────────────────────────────────────────────────────────┘
```

## Systematic Debugging Workflow

Quando um teste falha:

```
1. ISOLAR
   └─ Qual teste/componente falhou?
   └─ Qual foi a entrada que causou a falha?

2. CAUSA RAIZ
   └─ Por que falhou?
   └─ Onde no código?

3. SOLUÇÃO
   └─ Como corrigir?
   └─ Implementar correção

4. VALIDAÇÃO OFICIAL (Context7)
   └─ Consultar documentação oficial
   └─ Verificar se correção está alinhada

5. DOCUMENTAR
   └─ Criar lesson se bug recorrente
   └─ Adicionar teste de regressão

6. VERIFICAR
   └─ Rodar todos os testes
   └─ 100% verde antes de continuar
```

## Testes a Implementar

### 1. Unit Tests — Gates (gates.spec.ts extensão)

| Test | Descrição | Cenário Sucesso | Cenário Falha |
|------|-----------|-----------------|---------------|
| gate_1 | SPEC.md existe | retorna 0 | retorna 1 + mensagem |
| gate_1_empty | SPEC.md vazio | retorna 1 | - |
| gate_2 | Tests pass | executa shellcheck OK | falha se syntax error |
| gate_3 | Context documented | context.json válido | contexto inválido |
| gate_4 | Lessons reviewed | lista lessons OK | 0 lessons = warn |
| gate_5 | Handoff ready | JSON válido | JSON inválido |
| gate_6 | Context7 checked | API OK ou warn | - |
| gate_7 | Debug available | lib/debug.sh OK | lib não existe |

### 2. Unit Tests — Lessons

| Test | Descrição |
|------|-----------|
| lessons_capture_valid | Capture com title/problem/solution válido |
| lessons_capture_empty_title | Erro se title vazio |
| lessons_search_query | Search retorna resultados |
| lessons_validate_json | Valida schema JSON |
| lessons_approve_flow | Aprova e move para approved/ |
| lessons_compile_skill | Gera SKILL.md válido |

### 3. Security Tests

| Test | Descrição | Attack Vector |
|------|-----------|---------------|
| input_sanitize_dangerous | Caracteres perigosos removidos | `; & \| \` $ ( )` |
| path_traversal_blocked | Paths fora de base bloqueados | `../../../etc/passwd` |
| path_traversal_allowed | Paths dentro de base permitidos | `./valid/path` |
| sql_injection_blocked | SQL injection detectado | `' OR 1=1 --` |
| ssh_host_validation | Host inválido rejeitado | `host=""; rm -rf /` |
| ssh_strict_check | StrictHostKeyChecking ativo | - |

### 4. Integration Tests

| Test | Descrição |
|------|-----------|
| vps_check_connection | Testa SSH para VPS |
| vps_exec_command | Executa comando via SSH |
| context7_api_check | Verifica API Context7 |
| skills_load_valid | Carrega skill com SKILL.md |
| skills_missing_skill | Erro se skill não existe |

### 5. E2E Tests (Playwright)

| Test | Descrição |
|------|-----------|
| devorq_init_full | Init + estrutura completa criada |
| devorq_lessons_workflow | capture → validate → approve → compile |
| devorq_gates_pipeline | flow executa todos os gates |
| devorq_context_workflow | set → get → merge → clear |

## Comandos de Teste

```bash
# Todos os testes
bash scripts/ci-test.sh

# Apenas unit tests
bash scripts/ci-test.sh --unit

# Apenas security tests
bash scripts/ci-test.sh --security

# Apenas E2E (Playwright)
cd e2e-tests && npm test

# Com coverage
bash scripts/ci-test.sh --coverage

# Pipeline completo
bash scripts/ci-test.sh && cd e2e-tests && npm test
```

## Exit Codes

| Code | Significado |
|------|-------------|
| 0 | Todos os testes passaram |
| 1 | Algum teste falhou |
| 2 | Erro de sintaxe |
| 3 | Dependência faltando |

## Checklist Antes de Commit

- [ ] Todos os unit tests passam
- [ ] Todos os security tests passam
- [ ] Todos os E2E tests passam
- [ ] shellcheck 0 errors
- [ ] Coverage > 80%
- [ ] Lessons documentadas se bug encontrado

## Coverage Alvo

| Módulo | Atual | Meta |
|--------|-------|------|
| lib/gates.sh | ~40% | 80% |
| lib/lessons.sh | ~50% | 85% |
| lib/context.sh | ~30% | 80% |
| lib/vps.sh | ~60% | 90% |
| lib/commands/*.sh | ~25% | 75% |
| **TOTAL** | ~40% | **80%** |

---

**Última atualização:** 2026-05-21
