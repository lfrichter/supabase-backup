# Supabase Backup Automático (Smart Retry)

Este projeto contém um script robusto para realizar backups diários de bancos de dados Supabase (PostgreSQL) com lógica de tentativa automática e prevenção de duplicidade.

## 🚀 Como Funciona

O sistema foi desenhado para ser resiliente a falhas de rede e desligamento da máquina local.

### 1. O Script (`scripts/backup_semanal.sh`)
O script possui uma "camada de inteligência" que realiza os seguintes passos:
- **Verificação de Duplicidade:** Antes de iniciar o download, ele checa na pasta `files/` se já existe um backup concluído para o dia atual. Se sim, ele encerra a execução para economizar recursos.
- **Blindagem de Rede:** Utiliza o `nc` (Netcat) para validar se o host do Supabase está acessível antes de tentar o `pg_dump`.
- **Limpeza de Falhas:** Caso o backup seja interrompido ou falhe, o script remove o arquivo parcial `.sql` corrompido, permitindo que a próxima execução do Cron tente novamente do zero.
- **Retenção:** Remove automaticamente backups com mais de 15 dias para economizar espaço em disco.

### 2. Agendamento (Cron)
Para garantir que o backup ocorra mesmo que o computador não esteja ligado em um horário fixo, o Cron está configurado para tentar a execução de hora em hora em uma janela estendida.

**Configuração atual:**
```cron
0 8-23 * * * /bin/bash $HOME/supabase-backups/scripts/backup_semanal.sh >> $HOME/supabase-backups/backup.log 2>&1
```
*Isso significa que o sistema tenta realizar o backup às 08:00, 09:00, ..., até as 23:00. Assim que a primeira execução do dia tem sucesso, as demais apenas validam a existência do arquivo e encerram.*

## 📂 Estrutura do Projeto

```text
supabase-backups/
├── scripts/
│   └── backup_semanal.sh  # Script principal de backup
├── files/                 # Onde os arquivos .sql são armazenados (ignorado pelo Git)
├── backup.log             # Logs de execução (ignorado pelo Git)
└── README.md              # Esta documentação
```

## 🛠️ Comandos Úteis

### Executar manualmente
Se precisar forçar um backup agora:
```bash
./scripts/backup_semanal.sh
```

### Ver logs de execução
Para acompanhar o que aconteceu nas últimas tentativas:
```bash
tail -f backup.log
```

### Verificar agendamento atual
```bash
crontab -l
```

## ⚠️ Segurança
- Os arquivos `.sql` e logs de erro estão no `.gitignore` por conterem informações sensíveis ou serem volumosos.
- As credenciais do banco estão injetadas diretamente no script (ajuste para variáveis de ambiente se o repositório for tornar-se público).
