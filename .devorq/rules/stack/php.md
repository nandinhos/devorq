# Regras de Desenvolvimento - PHP Puro

## Stack
- **PHP**: 8.1, 8.2, 8.3, 8.4
- **Package Manager**: Composer
- **Testing**: PHPUnit
- **Type Checking**: PHPStan

## Regras de Ouro

### 1. Strict Types
```php
<?php

declare(strict_types=1);

namespace App\Entity;
```

### 2. PSR Compliance
- PSR-4: Autoloading
- PSR-12: Code style (PHP-CS-Fixer)
- PSR-7: HTTP Messages
- PSR-15: Middleware
- PSR-11: Container

### 3. Type Hints
```php
public function process(int $id, string $name, ?array $options): User
```

### 4. Estrutura
```
src/
├── Entity/
├── Repository/
├── Service/
├── Controller/
├── Middleware/
└── index.php
```

### 5. Segurança
- Prepared statements (PDO)
- CSRF tokens
- Input sanitization
- Password hashing: password_hash()

### 6. Tratamento de Erros
- Exceções personalizadas
- Logging com Monolog
- Respostas JSON padronizadas

## Checklist Pré-Commit

- [ ] declare(strict_types=1) em todos arquivos
- [ ] type hints em todos parâmetros e retornos
- [ ] PSR-12 compliant (php-cs-fixer)
- [ ] PHPStan passou (nível 5)
- [ ] testes passando
- [ ] sem SQL injection
- [ ] senhas hashed (não plain)

## Comandos de Verificação

```bash
# Lint
php-cs-fixer fix src/
php-cs-fixer fix --rules=@PSR12 src/

# Type check
phpstan analyse --level=5

# Testes
./vendor/bin/phpunit
```

## Fontes de Verdade

- PHP: https://www.php.net/manual/pt_BR/
- PSR: https://www.php-fig.org/psr/
- Packagist: https://packagist.org/