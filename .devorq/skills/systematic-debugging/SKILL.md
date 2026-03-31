---
name: systematic-debugging
description: Investigar bugs com processo estruturado de 4 fases
triggers:
  - "debug"
  - "bug"
  - "erro"
  - "não funciona"
globs:
  - "**/*.php"
  - "**/*.js"
  - "**/*.log"
---

# systematic-debugging - Investigação de Bugs

> **Regra de Ouro**: Não chute, prove

## Fases

### Phase 1: REPRODUCE
1. Descrever o bug claramente
2. Identificar passos exatos para reproduzir
3. Confirmar que bug existe consistentemente
4. Isolar o ambiente (mesma versão, mesmo estado)

### Phase 2: ISOLATE
1. Binary search no código (comment half, test, repeat)
2. Identificar a linha/classe específica que causa
3. Minimizar reprodução ao mínimo viável
4. Descartar variáveis não relacionadas

### Phase 3: ROOT CAUSE (5 Whys)
```
Por que falhou? [resposta 1]
Por que isso aconteceu? [resposta 2]
Por que isso? [resposta 3]
...
Perguntar 5 vezes até chegar na causa raiz real
```

### Phase 4: FIX & PREVENT
1. Implementar correção mínima
2. Verificar que bug não existe mais
3. Adicionar teste para evitar regressão
4. Documentar em /learned-lesson

## Ferramentas

```bash
# PHP/Laravel
php artisan tinker
tail -f storage/logs/laravel.log
php -d xdebug.mode=debug ...

# JS/Node
node --inspect
console.log (minimal)
```

---

> **Regra**: Usar /learned-lesson para documentar bugs recorrentes