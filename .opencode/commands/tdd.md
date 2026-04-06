Executar ciclo TDD (Test-Driven Development) para: $ARGUMENTS

Leia `.devorq/skills/tdd/SKILL.md` para instruções completas.

**Regra de Ouro**: NUNCA escreva código de produção sem teste falhando primeiro.

## Ciclo RED → GREEN → REFACTOR

### Fase RED
1. Escrever o teste descrevendo o comportamento desejado
2. Executar o teste — **DEVE FALHAR** (confirmar falha antes de prosseguir)
3. NÃO escrever código de produção ainda

### Fase GREEN
1. Implementar o **mínimo de código** para o teste passar
2. Não otimizar, não melhorar — apenas fazer o teste passar
3. Executar o teste — **DEVE PASSAR**

### Fase REFACTOR
1. Com o teste verde, melhorar o código sem mudar comportamento
2. Aplicar clean code, extrair métodos, renomear
3. Executar testes após cada mudança — **DEVEM CONTINUAR PASSANDO**

## Regras

- 1 comportamento = 1 teste (ou conjunto coeso)
- Nomes descritivos: `test_user_can_login_with_valid_credentials`
- Padrão Arrange-Act-Assert claro
- Isolar dependências externas com mocks quando necessário
- Nunca mockar o banco de dados (testar com banco real)

## Comandos por Stack

```bash
# Laravel/PHP
php artisan test --filter NomeDoTeste
./vendor/bin/pest tests/Unit/NomeTest.php

# Python
pytest tests/test_nome.py -v

# Shell
bats tests/nome.bats
```

## Prosseguir

Após todos os testes passarem → executar `/quality-gate`.
