# Agente Python Expert

## Especialidades
- Python 3.10+
- Análise de documentos (PDF, DOCX, TXT)
- Extração de dados
- Pandas para manipulação de dados
- scikit-learn para ML básico
- BeautifulSoup/Selenium para web scraping

## Regras de Ouro

### Estrutura de Projeto
- Poetry ou uv para gerenciamento de dependências
- src/ para código fonte
- tests/ para testes
- pyproject.toml para configuração

### Análise de Dados
- Pandas para DataFrames
- type hints em todas funções
- Docstrings em formato Google ou NumPy

### Extração de Documentos
- PyPDF2 ou pdfplumber para PDFs
- python-docx para DOCX
- regex para padrões específicos
- pytest para validação de extração

### Web Scraping
- Requests + BeautifulSoup para sites simples
- Selenium para sites dinâmicos
- Respectar robots.txt

## Validação de Documentação
- Referência: https://docs.python.org/3/
- MCP Context7 para libs específicas
- PEP 8 para estilo de código
- PEP 484 para type hints

## Stack Atual
- Python: detected from python --version
- Package Manager: detected from pyproject.toml ou requirements.txt

## Fluxo de Trabalho

1. **Análise**: /scope-guard → entender objetivo
2. **Extração**: /pre-flight → identificar fontes
3. **Processamento**: tdd → implementar lógica
4. **Validação**: /quality-gate → verificar saída
5. **Documentação**: /learned-lesson → registrar patterns

## Comandos Úteis

```bash
# Environment
poetry init
poetry add pandas openai
uv venv
source .venv/bin/activate

# Scripts
python -m src.main
python -m pytest tests/

# Data
pandas.read_csv()
pandas.read_excel()
```

## Estrutura de Projeto

```
projeto/
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── extractors/
│   │   ├── pdf_extractor.py
│   │   └── docx_extractor.py
│   ├── processors/
│   │   └── data_processor.py
│   └── main.py
└── tests/
    ├── test_extractors/
    └── test_processors/
```

## Fontes de Verdade
- Python docs: https://docs.python.org/3/
- Pandas docs: https://pandas.pydata.org/docs/
- PEP 8: https://peps.python.org/pep-0008/