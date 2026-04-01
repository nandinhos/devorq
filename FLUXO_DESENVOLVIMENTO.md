# FLUXO DE DESENVOLVIMENTO DEVORQ

> Do intent do usuário até a feature completa - mapeamento completo de capabilities

---

## VISÃO GERAL DO FLUXO

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FLUXO DEVORQ COMPLETO                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                │
│  │   INTENT     │───▶│   CONTEXT    │───▶│   SCOPE      │                │
│  │  DO USUÁRIO  │    │  DETECTION   │    │   GUARD      │                │
│  └──────────────┘    └──────────────┘    └──────────────┘                │
│        │                    │                    │                       │
│        ▼                    ▼                    ▼                       │
│  "criar feature X"    /env-context         /scope-guard                    │
│                       detecta stack       contrato escopo                 │
│                       identifica LLM      define FAZER/NÃO FAZER          │
│                       detecta tipo       lista ARQUIVOS                  │
│                                            DONE_CRITERIA                   │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                │
│  │  PRE-FLIGHT  │───▶│  IMPLEMENT   │───▶│  QUALITY     │                │
│  │  & SCHEMA    │    │    (TDD)     │    │   GATE       │                │
│  └──────────────┘    └──────────────┘    └──────────────┘                │
│        │                    │                    │                       │
│        ▼                    ▼                    ▼                       │
│  /pre-flight            RED → GREEN          /quality-gate                │
│  /schema-validate       REFACTOR             checkpoint                  │
│  valida enums           testes passam        lint passou                 │
│  valida schema          código implementado  escopo respeitado           │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐                                  │
│  │  SESSION     │───▶│   COMPLETE    │                                  │
│  │   AUDIT      │    │               │                                  │
│  └──────────────┘    └──────────────┘                                  │
│        │                                                                │
│        ▼                                                                │
│  /session-audit      métricas eficiência                              │
│  /spec-export       contexto para próxima sessão                       │
│  checkpoint         continuidade se rate limit                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## FASE 1: INTENT E CONTEXT DETECTION

### 1.1 Usuário发出 Intent

**Exemplo de input:**
```
"Preciso adicionar autenticação OAuth2 com Google no sistema de login."
```

### 1.2 /env-context (Automático)

**O que acontece:**
```
=== DEVORQ ENVIRONMENT CONTEXT ===

Project: gacpac-ti
Stack: Laravel 12, PHP 8.4, MySQL 8.4
Runtime: Docker (Sail)
Commands: vendor/bin/sail [comando]
Ports: 80->8080, 3306->3306
GOTCHAS: [
  - PERMISSÃO: WWWUSER=1000 no .env
  - VITE: sempre npm run build após assets
  - DB: local=MySQL, prod=PostgreSQL (não usar SQLite)
]
LLM Atual: Antigravity
===
```

**O que detecta automaticamente:**
| Item | Como Detecta | Resultado |
|------|-------------|-----------|
| **Stack** | `composer.json` | Laravel |
| **Versão PHP** | `php -v` | 8.4 |
| **Banco** | `.env` | MySQL 8.4 |
| **Runtime** | `docker-compose.yml` | Docker/Sail |
| **LLM** | Variáveis de ambiente | Antigravity |
| **Tipo Projeto** | `vendor/` existe? | Brownfield |

---

## FASE 2: CONTRATO DE ESCOPO

### 2.1 /scope-guard (OBRIGATÓRIO)

**IA gera contrato:**

```markdown
# CONTRATO DE ESCOPO - OAuth2 Google Login

## IDENTIFICAÇÃO
- Task: Login Google OAuth2
- Tipo: feature
- Complexidade: média
- Estimativa: 2h

## FAZER
1. Implementar login via Google OAuth2
2. Criar tabela oauth_providers (se não existir)
3. Adicionar botão "Entrar com Google" na view de login
4. Salvar access_token e refresh_token
5. Criar rota callback
6. Implementar logout (revogar token)

## NÃO FAZER
- NÃO implementar OAuth Facebook/GitHub
- NÃO criar registro manual (email/senha)
- NÃO modificar User table existente
- NÃO implementar 2FA
- NÃO criar login social para admin

## ARQUIVOS
- `app/Http/Controllers/Auth/OAuthController.php` (novo)
- `app/Models/OAuthProvider.php` (novo)
- `routes/auth.php`
- `resources/views/auth/login.blade.php`
- `config/services.php`
- `database/migrations/2026_03_31_create_oauth_providers_table.php` (novo)

## ARQUIVOS PROIBIDOS
- `app/Models/User.php`
- `app/Http/Controllers/Auth/LoginController.php`

## DONE_CRITERIA
- [ ] Usuário consegue fazer login via Google
- [ ] Token armazenado no banco com encryption
- [ ] Redirect para /dashboard após login
- [ ] Logout funciona (revoga token)
- [ ] Testes passando (min 3 novos)
- [ ] Pint passou
```

### 2.2 Validação de Contrato

| Etapa | Ação |
|-------|------|
| 1 | IA apresenta contrato ao usuário |
| 2 | Usuário aprova ou modifica |
| 3 | Se não resposta em 30s → prosseguir com melhor interpretação |
| 4 | Contrato aprovado → seguir para próxima fase |

---

## FASE 3: VALIDAÇÃO PRÉ-IMPLEMENTAÇÃO

### 3.1 /pre-flight

**Executa verificação de tipos/enums:**

```markdown
## PRE-FLIGHT REPORT

### Enum UserProvider (se existir)
- Valores atuais: ['google', 'facebook']
- Status: ✅ VÁLIDO

### Table: users
- Colunas: id, name, email, password, created_at, updated_at
- Status: ✅ VÁLIDO

### Operation: CREATE oauth_providers
- Status: ✅ PERMITIDO - tabela não existe, pode criar
```

### 3.2 /schema-validate

**Valida operações de banco:**

```markdown
## SCHEMA VALIDATION

### Tabela: oauth_providers
- Colunas planejadas: id, user_id, provider, provider_id, access_token, refresh_token, expires_at
- Tipo: InnoDB,utf8mb4
- Status: ✅ VÁLIDO

### Foreign Keys
- oauth_providers.user_id → users.id
- Status: ✅ VÁLIDO (users.id existe)
```

### 3.3 Bloqueio se Inválido

```
🛑 PRE-FLIGHT FALHOU!
- Problema: Enum UserProvider não existe
- Ação: PARAR - perguntar se cria novo enum ou usa existente
```

---

## FASE 4: IMPLEMENTAÇÃO (TDD)

### 4.1 Ciclo RED → GREEN → REFACTOR

**RED (Teste Falha):**
```php
// tests/Feature/OAuthLoginTest.php
public function test_user_can_login_with_google(): void
{
    // Este teste falha porque OAuth não existe ainda
    $this->get('/auth/google/redirect')
        ->assertRedirectContains('accounts.google.com');
}
```

**GREEN (Código Mínimo):**
```php
// Implementação mínima para teste passar
class OAuthController extends Controller
{
    public function redirect()
    {
        // Simples redirect para Google
        return redirect('https://accounts.google.com/oauth/...');
    }
}
```

**REFACTOR (Melhorar):**
```php
// Após teste passar, refatorar com código limpo
class OAuthController extends Controller
{
    protected OAuthService $oauth;

    public function __construct(OAuthService $oauth)
    {
        $this->oauth = $oauth;
    }

    public function redirect(): RedirectResponse
    {
        return $this->oauth->getAuthorizationUrl();
    }
}
```

### 4.2 Verificação Contínua de Escopo

A cada 3-5 arquivos modificados:

```
CHECKPOINT ESCOPO:
- Modificados: OAuthController.php, routes/auth.php
- Dentro do ARQUIVOS? ✅
- Dentro do FAZER? ✅
- Algo do NÃO FAZER? ❌ (não.modifiquei User.php)
```

---

## FASE 5: QUALITY GATE

### 5.1 /quality-gate (OBRIGATÓRIO)

**Checklist executado:**

```markdown
## QUALITY GATE CHECKLIST

### 1. Testes
- [✅] Todos os testes passando (45/45)
- [✅] Novos testes adicionados (3 novos)
- [✅] Sem regressão

### 2. Lint
- [✅] Pint passou (zero errors)
- [✅] Code style aderido

### 3. Escopo
- [✅] Apenas arquivos autorizados modificados
- [✅] NÃO FAZER respeitado

### 4. DONE_CRITERIA
- [✅] Usuário consegue fazer login via Google
- [✅] Token armazenado no banco
- [✅] Redirect para /dashboard
- [✅] Logout funciona

### 5. Segurança
- [✅] Sem secrets expostas
- [✅] Input validation presente
- [✅] SQL injection prevenido (bindings)

### 6. Performance
- [✅] Sem N+1 query novo
- [✅] Eager loading usado

### 7. Arquitetura
- [✅] Lógica em Services (OAuthService)
- [✅] Form Requests para validação

### Resultado: ✅ APROVADO
```

### 5.2 Se REJEITADO

```
🛑 QUALITY GATE REJEITADO!
- Item: N+1 query detectado em OAuthProviderController
- Ação: Corrigir antes de commit
```

---

## FASE 6: ENCERRAMENTO

### 6.1 /session-audit

```markdown
# SESSION AUDIT - 2026-03-31 14:30

## Dados
- Duração: 2h15min
- Task: OAuth2 Google Login
- Files: 8 modificados

## Classificação: EFICIENTE ✅

## Métricas
- Fix rounds: 1 (erro de enum corrigido no pre-flight)
- Checkpoints: 2
- Testes: 48 passing (3 novos)

## Causa Raiz: N/A (não houve problemas significativos)

## Próxima Sessão
- Continuar de: N/A (task concluída)
- Atenção: N/A
```

### 6.2 /spec-export (se necessário handoff)

```markdown
# SPEC EXPORT - OAuth2 Implementation

## Estado
- Status: Completo ✅
- Última atividade: Quality gate aprovado

## Escopo (copy do /scope-guard)
- FAZER: 6 itens
- NÃO FAZER: 5 itens
- ARQUIVOS: 6 arquivos

## Contexto Técnico
- Stack: Laravel 12, PHP 8.4, MySQL 8.4
- Artefatos: OAuthProvider model, OAuthService

## Decisões Tomadas
- Usar Socialite package
- Encrypt tokens antes de salvar
- Refresh token automático

## Próximos Passos: N/A
```

### 6.3 Checkpoint (se rate limit)

```
Checkpoint criado: cp_20260331_143000.md
Inclui:
- Git status (8 arquivos modificados)
- Stack: laravel
- Tipo: brownfield
```

---

## MAPA DE CAPABILITIES ATUAIS

### ✅ FUNCIONANDO

| Capability | Status | Descrição |
|------------|--------|-----------|
| Detecção de Stack | ✅ | Laravel/Node/Python/Go/Generic |
| Detecção de LLM | ✅ | Antigravity/Gemini/Claude/MiniMax |
| Detecção Greenfield/Brownfield | ✅ | Baseado em vendor/node_modules |
| /scope-guard | ✅ | Contrato canônico completo |
| /pre-flight | ✅ | Validação de tipos/enums |
| /env-context | ✅ | Contexto automático na sessão |
| /schema-validate | ✅ | Validação de banco |
| /quality-gate | ✅ | Checklist pré-commit |
| /session-audit | ✅ | Métricas de eficiência |
| /spec-export | ✅ | Handoff entre LLMs |
| TDD cycle | ✅ | RED→GREEN→REFACTOR |
| checkpoint | ✅ | Continuidade se rate limit |
| CLI minimal | ✅ | Comandos essenciais |

### ✅ RESOLVIDO EM v2.0

| Capability | Status | Descrição |
|------------|--------|-----------|
| /learned-lesson | ✅ | Integrada ao fluxo obrigatório pós session-audit |
| /handoff | ✅ | Skill criada + comandos CLI (generate/status/list) |
| /constraint-loader | ✅ | Skill criada, integrada ao /pre-flight |
| integrity-guardian | ✅ | Skill criada, integrada ao /quality-gate para TALL |
| Versionamento de skills | ✅ | SKILL.md + CHANGELOG.md + VERSIONS/ com semver |
| Pipeline auto-aprendizado | ✅ | Gates 5-7 + lessons list/validate/apply |
| skill rollback | ✅ | Comando `devorq skill rollback <nome> <versao>` |
| Prompts multi-LLM | ✅ | claude.md, gemini.md, antigravity.md atualizados |

### ⚠️ PARCIAL/FALTANDO

| Capability | Status | Descrição |
|------------|--------|-----------|
| systematic-debugging | ⚠️ | Skill existe mas não integrada em workflow |
| code-review | ⚠️ | Skill existe mas não integrada em workflow |
| MCP Context7 automático | ⚠️ | Presente no pipeline mas requer chamada manual |

### ❌ NÃO IMPLEMENTADO (fora do escopo v2.0)

| Capability | Descrição |
|------------|-----------|
| the-logic-extractor | Extrair lógica para Actions/Services |
| the-preflight-physician | Saúde Docker: permissões, links |
| Gate automático no git hooks | Pint/pre-commit antes de commit |
| CI/CD pipeline | GitHub Actions automático |
| Dashboard de métricas | Visualização de efficiency |
| Hub VPS de memória global | Repositório semântico externo (sistema separado) |

---

## GAPS IDENTIFICADOS

### Críticos (bloqueiam workflow)
1. **Sem agentes de orquestração** - Quem coordena as skills?
2. **Sem integração com git hooks** - Quality gate não é obrigatório
3. **Sem CI/CD** - Não bloqueia merge se quality gate falhar

### Médios (limitam eficiência)
4. **MCP não está no fluxo** - Não usa contexto7/serena automaticamente
5. **Skills não estão conectadas** - Cada skill é independente
6. **Sem persistência de estado** - Session não persiste entre sessões

### Baixa Prioridade
7. Dashboard de métricas
8. /learned-lesson integrado
9. the-integrity-guardian

---

## RECOMENDAÇÕES DE AJUSTE

### Imediato (Fase 1)
1. **Criar orquestrador simples** - Script que coordena skills em sequência
2. **Integrar quality gate no git hooks** - Pre-commit hook com /quality-gate
3. **Adicionar persistência de estado** - Salvar session.json entre sessões

### Curto prazo (Fase 2)
4. **Reconectar MCP ao fluxo** - Usar context7 para /pre-flight
5. **Criar agentes essenciais** - orchestrator, architect, qa
6. **Adicionar /handoff** - Automatic spec-export ao trocar LLM

### Médio prazo (Fase 3)
7. **Dashboard de métricas** - Visualizar efficiency trends
8. **CI/CD automático** - GitHub Actions com gates
9. **the-integrity-guardian** - Validações específicas Laravel

---

> Este documento serve como baseline para evolução do DEVORQ. Atualizar conforme capacidades são implementadas.