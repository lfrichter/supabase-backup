#!/bin/bash

# ==============================================================================
# Script Mestre: Executa backup de todos os projetos configurados em projects/
# Uso: ./scripts/backup_all.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECTS_DIR="$ROOT_DIR/projects"

echo "================================================================================"
echo "🚀 Iniciando rotina de backups Supabase em $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================================"

# Procura todos os arquivos .env em projects/, exceto os que terminam em .example
shopt -s nullglob
PROJECT_FILES=("$PROJECTS_DIR"/*.env)
shopt -u nullglob

if [ ${#PROJECT_FILES[@]} -eq 0 ]; then
  echo "⚠️ Nenhum projeto (.env) encontrado em $PROJECTS_DIR."
  echo "Crie um arquivo de configuração a partir de $PROJECTS_DIR/.env.example"
  exit 0
fi

TOTAL=0
SUCCESS=0
FAILED=0

for ENV_FILE in "${PROJECT_FILES[@]}"; do
  # Ignora arquivos de exemplo
  if [[ "$ENV_FILE" == *".example"* ]]; then
    continue
  fi

  TOTAL=$((TOTAL + 1))
  PROJ_NAME="$(basename "$ENV_FILE" .env)"
  echo ""
  echo "▶️ [${TOTAL}] Processando projeto: $PROJ_NAME..."

  /bin/bash "$SCRIPT_DIR/backup_project.sh" "$ENV_FILE"
  STATUS=$?

  if [ $STATUS -eq 0 ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "================================================================================"
echo "🏁 Resumo da execução em $(date '+%Y-%m-%d %H:%M:%S'):"
echo "Total de projetos processados: $TOTAL"
echo "✅ Sucessos/Ignorados (já realizados hoje): $SUCCESS"
if [ $FAILED -gt 0 ]; then
  echo "❌ Falhas: $FAILED"
fi
echo "================================================================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi

exit 0
