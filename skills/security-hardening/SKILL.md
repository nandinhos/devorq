---
name: security-hardening
description: Padroes de seguranca para scripts bash e Python do DEVORQ — credenciais, SSH, validacao de input, paths, exit codes e checklist pre-commit.
whenToUse: Ao criar ou modificar scripts do DEVORQ que acessam arquivos, variaveis de ambiente, servicos externos (SSH, PostgreSQL) ou validam input de usuario.
metadata:
  version: 1.0.0
  author: Code Review - DEVORQ
  source: framework DEVORQ (github.com/nandinhos/devorq)
---

# Security Hardening Skill

## Propósito

Esta skill define padrões de segurança para scripts bash e Python do DEVORQ.

## Quando Usar

Use esta skill quando:
- Criar novos scripts que acessam arquivos
- Acessar variáveis de ambiente
- Conectar a serviços externos (SSH, PostgreSQL)
- Validar inputs de usuário
- Trabalhar com paths/arquivos

## Regras de Segurança

### 1. Credenciais

#### ❌ ERRADO
```bash
# Credenciais em variáveis de ambiente são visíveis em:
# - ps aux
# - /proc/*/environ
# - logs
# - /tmp/*

export OPENAI_API_KEY="sk-xxx..."
export VPS_HOST="187.108.197.199"
ssh "$VPS_USER@$VPS_HOST" "command"
```

#### ✅ CORRETO
```bash
# Usar arquivo de configuração com permissões 600
CONFIG_FILE="$HOME/.config/devorq/config"

# Se arquivo existir, carregar
if [ -f "$CONFIG_FILE" ]; then
    chmod 600 "$CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# Usar keyring quando disponível
# Não exportar variáveis sensíveis
# Remover credenciais de outputs
```

### 2. SSH Seguro

#### ❌ ERRADO
```bash
# Sem validação de host - vulnerável a MITM
ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" "command"
```

#### ✅ CORRETO
```bash
# Com validação de host
ssh -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$HOME/.ssh/known_hosts" \
    -o ConnectTimeout=10 \
    -p "$VPS_PORT" \
    "$VPS_USER@$VPS_HOST" \
    "command"
```

### 3. Validação de Input

#### ❌ ERRADO
```bash
# Input não validado - injeção de comando
grep -r "$query" "$LESSONS_DIR"
rm -rf "$path"
cat "$file"
```

#### ✅ CORRETO
```bash
# Função de sanitização
sanitize_input() {
    local input="$1"
    # Whitelist de caracteres seguros
    echo "$input" | sed 's/[^a-zA-Z0-9._\-\/]//g'
}

# Função de validação de path
validate_path() {
    local path="$1"
    local base_dir="$2"
    
    # Normalizar path
    local real_path
    real_path=$(realpath "$path" 2>/dev/null) || return 1
    
    # Verificar se está dentro de base_dir
    local real_base
    real_base=$(realpath "$base_dir" 2>/dev/null) || return 1
    
    [[ "$real_path" == "$real_base"/* ]] || return 1
}

# Uso
query=$(sanitize_input "$query")
validate_path "$path" "$LESSONS_DIR" || exit 1
```

### 4. Python - Credenciais

#### ❌ ERRADO
```python
import os

# Credenciais visíveis
VPS_HOST = os.environ.get("DEVORQ_VPS_HOST", "...")
# Usado em logs automaticamente
print(f"Connecting to {VPS_HOST}")  # Credencial exposta!
```

#### ✅ CORRETO
```python
import os
import getpass
from pathlib import Path

def load_config():
    """Carrega config de arquivo seguro."""
    config_file = Path.home() / ".config" / "devorq" / "config"
    
    if config_file.exists():
        # Verificar permissões
        if config_file.stat().st_mode & 0o77:
            print("[ERROR] Config file has insecure permissions")
            sys.exit(1)
        
        with open(config_file) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, _, value = line.partition('=')
                    os.environ[key.strip()] = value.strip()

# Remover credenciais de outputs
def sanitize_for_log(value):
    """Remove informações sensíveis para logs."""
    if not value:
        return "***REDACTED***"
    # Mostrar apenas primeiro e último char
    if len(value) > 4:
        return f"{value[0]}***{value[-1]}"
    return "***REDACTED***"
```

### 5. Python - Validação de Input

#### ❌ ERRADO
```python
# SQL injection
sql = f"SELECT * FROM users WHERE name = '{username}'"
# Path traversal
with open(user_path) as f:
    content = f.read()
```

#### ✅ CORRETO
```python
import re
from pathlib import Path

def sanitize_identifier(value):
    """Sanitiza identificadores SQL."""
    if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', value):
        raise ValueError(f"Invalid identifier: {value}")
    return value

def validate_path(path, base_dir):
    """Valida que path está dentro de base_dir."""
    try:
        real_path = Path(path).resolve()
        real_base = Path(base_dir).resolve()
        
        # Verificar se está dentro
        try:
            real_path.relative_to(real_base)
        except ValueError:
            raise ValueError(f"Path {path} is outside {base_dir}")
        
        return real_path
    except Exception as e:
        raise ValueError(f"Invalid path: {e}")

# Uso
validate_path(user_path, base_dir).read_text()
```

## Exit Codes

Usar exit codes consistentes:

| Code | Meaning |
|------|---------|
| 0 | Sucesso |
| 1 | Erro genérico |
| 2 | Argumentos inválidos |
| 3 | Arquivo não encontrado |
| 4 | Validação falhou |
| 5 | Permissão negada |

## Checklist de Segurança

Antes de commitar scripts:

- [ ] Inputs validados?
- [ ] Paths validados?
- [ ] Credenciais não expostas?
- [ ] SSH com StrictHostKeyChecking?
- [ ] shellcheck passa?
- [ ] Testes de segurança escritos?
- [ ] Documentação atualizada?

## Testes de Segurança

```bash
# Teste de injeção
echo "; rm -rf /" | ./script.sh

# Teste de path traversal
echo "../../../etc/passwd" | ./script.sh

# Teste de credenciais
env -i ./script.sh  # Sem variáveis de ambiente
```

## Referências

- CWE-78: OS Command Injection
- CWE-22: Path Traversal
- CWE-312: Exposure of Sensitive Information
- CWE-20: Improper Input Validation

---

*Skill criada via Code Review - 2026-05-13*
