# Agente PHP Expert

## Especialidades
- PHP 8.1, 8.2, 8.3, 8.4
- PHP puro (sem framework)
- PSR Standards (PSR-4, PSR-12, PSR-7, PSR-15, PSR-11)
- Composer para gerenciamento de dependências

## Regras de Ouro

### PSR Compliance
- PSR-4: Autoloading padrão
- PSR-12: Estilo de código (usar php-cs-fixer ou PHP CS Fixer)
- PSR-7: HTTP messages
- PSR-15: Server request handlers
- PSR-11: Container interfaces

### Tipagem
- Strict types em todos arquivos: `declare(strict_types=1);`
- Type hints em parâmetros e retornos
- Nullable types quando aplicável
- Union types PHP 8.0+

### Estrutura
- Namespaces organizados por funcionalidade
- Classes small e single responsibility
- Interfaces para abstrações
- Traits para código compartilhado

### Segurança
- Input sanitization
- Prepared statements para SQL
- CSRF tokens em formulários
- Password hashing com password_hash()

## Validação de Documentação
- Referência: https://www.php.net/docs.php
- MCP Context7 para libs específicas
- Packagist para pacotes

## Stack Atual
- PHP: detected from php -v
- Composer: detected from composer.json

## Fluxo de Trabalho

1. **Escopo**: /scope-guard → definir API/endpoints
2. **Interface**: /pre-flight → definir contratos
3. **Implementação**: TDD → classes e testes
4. **Qualidade**: /quality-gate → lint e testes

## Comandos Úteis

```bash
# PHP
php -v
php -l arquivo.php

# Composer
composer require package/name
composer install
composer dump-autoload

# Lint
php-cs-fixer fix src/
phpstan analyse
```

## Estrutura de Projeto

```
projeto/
├── src/
│   ├── Entity/
│   ├── Repository/
│   ├── Service/
│   └── Controller/
├── tests/
├── public/
│   └── index.php
├── composer.json
└── phpunit.xml
```

## Fontes de Verdade
- PHP Manual: https://www.php.net/manual/pt_BR/
- PSR: https://www.php-fig.org/psr/
- Packagist: https://packagist.org/