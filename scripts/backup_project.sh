#!/bin/bash

# ==============================================================================
# Script de Backup Individual por Projeto Supabase
# Uso: ./scripts/backup_project.sh <caminho_ou_nome_do_projeto>
# Exemplo: ./scripts/backup_project.sh canaoaves
#          ./scripts/backup_project.sh projects/forroja.env
# ==============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# --- 1. RESOLVER ARQUIVO DE CONFIGURAÇÃO DO PROJETO ---
if [ -z "$1" ]; then
  echo "❌ Erro: Nenhum projeto informado."
  echo "Uso: $0 <nome_do_projeto_ou_arquivo_env>"
  exit 1
fi

PROJECT_INPUT="$1"
ENV_FILE=""

if [ -f "$PROJECT_INPUT" ]; then
  ENV_FILE="$PROJECT_INPUT"
elif [ -f "$ROOT_DIR/projects/$PROJECT_INPUT" ]; then
  ENV_FILE="$ROOT_DIR/projects/$PROJECT_INPUT"
elif [ -f "$ROOT_DIR/projects/${PROJECT_INPUT}.env" ]; then
  ENV_FILE="$ROOT_DIR/projects/${PROJECT_INPUT}.env"
else
  echo "❌ Erro: Arquivo de configuração do projeto '$PROJECT_INPUT' não foi encontrado em $ROOT_DIR/projects/"
  exit 1
fi

# Carregar variáveis do projeto
source "$ENV_FILE"

# Validações básicas
if [ -z "$PROJECT_NAME" ]; then
  # Se PROJECT_NAME não estiver definido, infere a partir do nome do arquivo
  PROJECT_NAME="$(basename "$ENV_FILE" .env)"
fi

PROJECT_LABEL="${PROJECT_LABEL:-$PROJECT_NAME}"
RETENTION_DAYS="${RETENTION_DAYS:-15}"

if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_USER" ] || [ -z "$DB_NAME" ] || [ -z "$PGPASSWORD" ]; then
  echo "❌ Erro: Variáveis obrigatórias ausentes em $ENV_FILE (DB_HOST, DB_PORT, DB_USER, DB_NAME, PGPASSWORD)."
  exit 1
fi

export PGPASSWORD

# --- 2. CONFIGURAR DIRETÓRIOS E NOMES ---
BACKUP_DIR="$ROOT_DIR/files/$PROJECT_NAME"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
TODAY=$(date +%Y-%m-%d)
FILENAME="backup_${PROJECT_NAME}_$DATE.sql"

mkdir -p "$BACKUP_DIR"

# --- 3. VERIFICAÇÃO DE DUPLICIDADE DIÁRIA ---
if ls "$BACKUP_DIR/backup_${PROJECT_NAME}_$TODAY"* >/dev/null 2>&1; then
  echo "[$PROJECT_LABEL] ✅ Backup para hoje ($TODAY) já existe em $BACKUP_DIR. Ignorando."
  exit 0
fi

echo "==================================================="
echo "[$PROJECT_LABEL] Iniciando backup em $(date '+%Y-%m-%d %H:%M:%S')..."

# --- 4. BLINDAGEM DE REDE (Netcat) ---
MAX_RETRIES=12
RETRY_COUNT=0

echo "[$PROJECT_LABEL] Aguardando conectividade com $DB_HOST:$DB_PORT..."
until nc -zv "$DB_HOST" "$DB_PORT" >/dev/null 2>&1; do
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "[$PROJECT_LABEL] ❌ Erro: Não foi possível conectar ao host $DB_HOST:$DB_PORT após 2 minutos. Abortando."
    osascript -e "display notification \"Não foi possível conectar ao banco de $PROJECT_LABEL.\" with title \"⚠️ Falha de Conexão: $PROJECT_LABEL\"" 2>/dev/null || true
    exit 1
  fi
  echo "[$PROJECT_LABEL] Aguardando conexão... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

echo "[$PROJECT_LABEL] ✅ Rede e porta acessíveis!"

# --- 5. LOCALIZAR BINÁRIO PG_DUMP ---
PG_DUMP_BIN="/opt/homebrew/opt/postgresql@17/bin/pg_dump"
if [ ! -x "$PG_DUMP_BIN" ]; then
  PG_DUMP_BIN=$(command -v pg_dump || true)
fi

if [ -z "$PG_DUMP_BIN" ] || [ ! -x "$PG_DUMP_BIN" ]; then
  echo "[$PROJECT_LABEL] ❌ Erro: pg_dump não encontrado no sistema."
  exit 1
fi

# --- 6. EXECUTAR PG_DUMP ---
echo "[$PROJECT_LABEL] Executando pg_dump para $BACKUP_DIR/$FILENAME..."

"$PG_DUMP_BIN" \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --schema="public" \
  --schema="auth" \
  --schema="storage" \
  --clean \
  --if-exists \
  --quote-all-identifiers \
  --no-owner \
  --no-acl \
  --exclude-table-data 'storage.objects' \
  --file "$BACKUP_DIR/$FILENAME"

DUMP_EXIT_CODE=$?

# --- 7. TRATAMENTO DO RESULTADO ---
if [ $DUMP_EXIT_CODE -eq 0 ] && [ -s "$BACKUP_DIR/$FILENAME" ]; then
  FILE_SIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
  echo "[$PROJECT_LABEL] ✅ Sucesso! Arquivo criado: $BACKUP_DIR/$FILENAME ($FILE_SIZE)"

  # Notificação macOS
  osascript -e "display notification \"Backup de $PROJECT_LABEL concluído com sucesso ($FILE_SIZE)!\" with title \"💾 Backup OK: $PROJECT_LABEL\"" 2>/dev/null || true

  # Limpeza de backups antigos conforme RETENTION_DAYS
  find "$BACKUP_DIR" -name "backup_${PROJECT_NAME}_*.sql" -type f -mtime +"$RETENTION_DAYS" -delete
  echo "[$PROJECT_LABEL] 🧹 Limpeza de backups antigos (> $RETENTION_DAYS dias) concluída."
  exit 0
else
  echo "[$PROJECT_LABEL] ❌ Erro ao realizar o backup no pg_dump (Código de saída: $DUMP_EXIT_CODE)."

  # Notificação macOS de Erro
  osascript -e "display notification \"Ocorreu um erro no backup de $PROJECT_LABEL. Verifique o log!\" with title \"⚠️ Falha no Backup: $PROJECT_LABEL\"" 2>/dev/null || true

  # Remove arquivo corrompido / vazio
  rm -f "$BACKUP_DIR/$FILENAME"
  echo "[$PROJECT_LABEL] 🗑️ Arquivo parcial removido para permitir nova tentativa pelo cron."
  exit 1
fi
