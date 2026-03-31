# Regras de Desenvolvimento - Python

## Stack
- **Python**: 3.10, 3.11, 3.12
- **Package Manager**: Poetry ou uv
- **Testing**: pytest
- **Type Checking**: mypy

## Regras de Ouro

### 1. Type Hints Obrigatórios
```python
from typing import Optional, List

def process_data(data: dict) -> list[int]:
    ...
```

### 2. Docstrings em Todas Funções
```python
def extract_text(file_path: str) -> str:
    """Extrai texto de arquivo PDF.
    
    Args:
        file_path: Caminho para o arquivo PDF
        
    Returns:
        Texto extraído como string
    """
    ...
```

### 3. Estrutura de Projeto
```
src/
├── extractors/    # Extração de dados
├── processors/    # Processamento
├── models/        # Classes de domínio
└── main.py        # Entry point
tests/
├── unit/
└── integration/
pyproject.toml
```

### 4. Dependências
- Poetry/uv para gerenciamento
- pyproject.toml com versões fixas
- requirements.txt para produção

### 5. Testes
- pytest para toda testagem
- Fixtures para dados comuns
- Parametrização para casos múltiplos

## Checklist Pré-Commit

- [ ] type hints em todas funções
- [ ] docstrings em todas funções
- [ ] testes passando
- [ ] mypy passou
- [ ] flake8/pylint passou
- [ ] sem secrets no código
- [ ] variáveis de ambiente em .env

## Comandos de Verificação

```bash
# Type check
mypy src/

# Lint
flake8 src/
black src/
isort src/

# Testes
pytest tests/ -v --cov
```

## Fontes de Verdade

- Python: https://docs.python.org/3/
- Pandas: https://pandas.pydata.org/docs/
- PEP 8: https://peps.python.org/pep-0008/

## Casos de Uso Comuns

### Extração de Documentos
```python
# PDF
pdfplumber.open(file).extract_text()

# DOCX
python-docx.Document(file).paragraphs

# Excel
pandas.read_excel(file)
```

### Análise de Dados
```python
import pandas as pd

df = pd.read_csv('data.csv')
df.groupby('column').agg({'value': 'sum'})
```

> **Regra**: Validar libs com MCP Context7 antes de usar