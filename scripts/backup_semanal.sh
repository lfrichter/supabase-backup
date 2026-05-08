#!/bin/bash

# --- CONFIGURAÇÕES ---
export PGPASSWORD='!ha3-2gf7_cRDUg'

# DADOS DO POOLER (IPv4 Estável)
DB_HOST="aws-1-sa-east-1.pooler.supabase.com"
DB_USER="postgres.ugbcqdrslppxgfqollvu"
DB_PORT="6543"
DB_NAME="postgres"

BACKUP_DIR="$HOME/supabase-backups/files"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
TODAY=$(date +%Y-%m-%d)
FILENAME="backup_supabase_full_$DATE.sql"

mkdir -p "$BACKUP_DIR"

# --- 0. VERIFICAÇÃO DE DUPLICIDADE ---
if ls "$BACKUP_DIR/backup_supabase_full_$TODAY"* >/dev/null 2>&1; then
  echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
  echo "✅ Backup para hoje ($TODAY) já existe. Operação ignorada para evitar duplicidade."
  exit 0
fi

echo "---------------------------------------------------"
echo "Iniciando backup em $DATE..."

# --- 1. BLINDAGEM DE REDE (Validação real via Netcat) ---
MAX_RETRIES=12
RETRY_COUNT=0

echo "Aguardando rede e porta do banco..."
# Testa diretamente se a porta de destino está aberta e respondendo
until nc -zv $DB_HOST $DB_PORT >/dev/null 2>&1; do
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "❌ Erro: Não foi possível conectar ao host $DB_HOST na porta $DB_PORT após 2 minutos. Abortando."
    exit 1
  fi
  echo "Rede/Banco ainda não estão prontos. Aguardando 10 segundos... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

echo "✅ Rede e conexão com o banco estabelecidas!"

# --- 2. COMANDO DE BACKUP ---
/opt/homebrew/opt/postgresql@17/bin/pg_dump \
  -h $DB_HOST \
  -p $DB_PORT \
  -U $DB_USER \
  -d $DB_NAME \
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

# Verifica se funcionou
if [ $? -eq 0 ]; then
  echo "✅ Sucesso! Arquivo criado: $BACKUP_DIR/$FILENAME"

  # Limpa backups com mais de 15 dias (já que agora roda diário)
  find "$BACKUP_DIR" -name "backup_supabase_full_*.sql" -type f -mtime +15 -delete
  echo "🧹 Limpeza de backups antigos concluída."
else
  echo "❌ Erro ao realizar o backup no pg_dump."
fi
