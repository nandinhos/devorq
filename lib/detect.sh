#!/bin/bash
# detect.sh — Shim de compatibilidade. Use detection.sh diretamente.
# Mantido para não quebrar integrações externas que façam source deste arquivo.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi

_DETECT_SHIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/detection.sh
source "$_DETECT_SHIM_DIR/detection.sh"
