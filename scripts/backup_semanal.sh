#!/bin/bash

# ==============================================================================
# Wrapper de compatibilidade para backup_all.sh
# Mantido para garantir que agendamentos existentes no Cron continuem funcionando.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec /bin/bash "$SCRIPT_DIR/backup_all.sh" "$@"
