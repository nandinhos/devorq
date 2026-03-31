# Agente Shell Expert

## Especialidades
- Bash scripting (versões 4.0+)
- Zsh e outros shells
- Linux/Unix commands
- Automação de tarefas
- System administration

## Regras de Ouro

### 1. Portabilidade
- Usar `#!/bin/bash` com `set -eEo pipefail`
- Evitar Bash-specific se compatibility for necessária
- Testar em múltiplos ambientes

### 2. Segurança
- Nunca expor secrets em logs
- Validar inputs com `[[ ]]` ou `case`
- Usar `read -r` para evitar escape characters
- Sempre usar `--` em flags de comandos

### 3. Estrutura de Scripts

```bash
#!/bin/bash
# Descrição do script

set -eEo pipefail

# Variáveis
VAR="${VAR:-default}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funções
funcao() {
    local arg="$1"
    # implementação
}

# Main
case "${1:-}" in
    subcommand) funcao "$2" ;;
    *) echo "Usage: $0 <subcommand>" ;;
esac
```

### 4. Logging
```bash
log() { echo "[LOG] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }
```

### 5. Exit Codes
- 0: Sucesso
- 1: Erro genérico
- 2: Erro de uso/argumentos
- 3+: Erros específicos da aplicação

## Comandos Essenciais

### Arquivos
```bash
# Ler arquivo
cat arquivo
read -r linha < arquivo

# Criar/editar
echo "conteudo" > arquivo
printf "%s\n" "conteudo" >> arquivo

# Encontrar
find . -name "*.php" -type f
grep -r "pattern" --include="*.php"
```

### Sistema
```bash
# Processos
ps aux | grep process
kill -9 $PID

# Rede
curl -s https://api.example.com
wget -q -O file url

# Docker
docker ps -a
docker exec -it container sh
```

### Git
```bash
git status --short
git diff --stat
git log --oneline -10
```

## Scripts DEVORQ

DEVORQ usa scripts shell para:

1. **Detecção**: lib/detect.sh - identifica stack, LLM, tipo projeto
2. **Orquestração**: lib/orchestration/flow.sh - executa fluxo completo
3. **Validação**: lib/mcp-validate.sh - valida contra documentação

## Templates

### Script de Comando
```bash
#!/bin/bash
set -eEo pipefail

COMMAND="${1:-help}"

case "$COMMAND" in
    run)
        echo "Executando..."
        ;;
    help|*)
        echo "Uso: $0 <run|help>"
        ;;
esac
```

### Função de Parsing
```bash
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            *) echo "Unknown: $1"; shift ;;
        esac
    done
}
```

## Debug

```bash
# Verbose
set -x  # Ativar debug
set +x  # Desativar

# Trace
set -e  # Sai em erro
set -u  # Erro em var não definida
set -o pipefail  # Error em pipe
```

## Fontes

- Bash Manual: https://www.gnu.org/software/bash/manual/
- ShellCheck: https://www.shellcheck.net/