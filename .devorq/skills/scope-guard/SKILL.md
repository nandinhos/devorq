---
name: scope-guard
description: Contrato de escopo explícito que bloqueia over-engineering antes de qualquer implementação
triggers:
  - "scope-guard"
  - "contrato de escopo"
  - "FAZER"
  - "NÃO FAZER"
  - "arquivos"
  - "done_when"
globs:
  - "**/*.md"
---

# /scope-guard - Contrato de Escopo Canônico

> **Regra de Ouro**: Sem contrato de escopo = sem código

## Quando Usar

**OBRIGATÓRIO** - antes de escrever QUALQUER código, sem exceção.
- Nova feature
- Bug fix
- Refatoração
- Documentação
- Qualquer tarefa nova

## Propósito

1. **Bloquear over-engineering**: Impedir que o modelo "melhore" o que não foi pedido
2. **Definir limites claros**: Arquivos específicos que PODEM ser modificados
3. **Criar critérios objetivos**: DONE_WHEN verificável, não subjetivo
4. **Prevent spec vaga**: Contract força especificidade

## Estrutura do Contrato

```markdown
# CONTRATO DE ESCOPO - [Nome da Task]

## IDENTIFICAÇÃO
- **Task**: [nome resumido]
- **Tipo**: [feature|bugfix|refactor|docs]
- **Complexidade**: [baixa|média|alta]
- **Estimativa**: [tempo estimado]

## FAZER (Lista branca - SÓ o que está aqui é permitido)
1. [Funcionalidade específica 1]
2. [Funcionalidade específica 2]
3. [Funcionalidade específica N]

## NÃO FAZER (Lista negra - NUNCA fazer)
1. [Funcionalidade explícita que NÃO fazer]
2. [Funcionalidade explícita que NÃO fazer]

## ARQUIVOS (Lista branca - SÓ esses arquivos podem ser modificados)
- `caminho/arquivo1.php`
- `caminho/arquivo2.js`
- `database/migrations/YYYY_MM_DD_*.php`

## ARQUIVOS PROIBIDOS (NUNCA modificar)
- `app/Models/User.php` (exemplo)
- `config/auth.php` (exemplo)

## DEPENDÊNCIAS
- [Dependência externa 1]
- [Dependência externa 2]

## DONE_CRITERIA (Objetivos e verificáveis)
- [Critério 1 verificável]
- [Critério 2 verificável]
- [Critério 3 verificável]

## RISCO_IDENTIFICADO
- [Riscos conhecidos da task]
```

## Processo de Execução

### Step 1: Solicitar Contrato
Quando usuário faz uma solicitação:
```
Entendi. Antes de implementar, preciso do contrato de escopo.

# Contrato de Escopo - [resumo da task]

## FAZER
- [ Liste cada funcionalidade específica ]

## NÃO FAZER
- [ Liste o que NÃO fazer ]

## ARQUIVOS
- [ Liste arquivos que podem ser modificados ]

## DONE_CRITERIA
- [ Liste critérios verificáveis ]
```

### Step 2: Aguardar Aprovação
- Se usuário não responder em 30s → prosseguir com melhor interpretação
- Se usuário completar contrato → VALIDAR antes de proceed

### Step 3: Verificação Contínua
A cada 3-5 arquivos modificados:
```
CHECKPOINT ESCOPO:
- Modificados até agora: [lista]
- Dentro do ARQUIVOS? ✅/❌
- Dentro do FAZER? ✅/❌
- Algo do NÃO FAZER? ✅/❌
```

### Step 4: Bloqueio
Se detected escape from scope:
```
🛑 ESCOPO VIOLADO!
- Detectado: [o que fugiu do escopo]
- Contrato: [ref]
- Ação: PARAR eperguntar se pode incluir
```

## Anti-Patterns

| Errado | Certo |
|--------|-------|
| Começar a codar sem contrato | Contrato primeiro |
| "Vou melhorar X enquanto estou aqui" | NÃO FAZER bloqueia |
| Modificar arquivo não listado | ARQUIVOS é lista branca |
| "Done quando ficar bom" | Critérios objetivos |

## Exemplo Completo

### Input do Usuário:
"Adicionar autenticação OAuth2"

### Output (Contrato):
```markdown
# CONTRATO DE ESCOPO - Autenticação OAuth2

## IDENTIFICAÇÃO
- **Task**: Login Google OAuth2
- **Tipo**: feature
- **Complexidade**: média
- **Estimativa**: 2h

## FAZER
1. Implementar login via Google OAuth2
2. Criar tabela oauth_providers (se não existir)
3. Adicionar botão "Entrar com Google" na view de login
4. Salvar access_token e refresh_token
5. Criar rota callback

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

---

> **Débito que previne**: D16 (Especificações vagas → over-engineering)  
> **Referência**: Perfil do Desenvolvedor - Sprint 1 /scope-guard