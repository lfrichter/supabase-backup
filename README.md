# Supabase Backup Automático Multi-Projetos (Smart Retry)

Sistema modular e resiliente para realizar backups automatizados de múltiplos bancos de dados Supabase (PostgreSQL) com lógica de tentativa automática, controle de duplicidade diária, blindagem de rede e retenção personalizada por projeto.

---

## 🚀 Como Funciona

- **Multi-Projetos Isolados:** Cada projeto tem seu arquivo de configuração em `projects/<projeto>.env` e seus arquivos `.sql` armazenados em `files/<projeto>/`.
- **Verificação de Duplicidade Independente:** Antes de iniciar o download de um banco, o script checa na pasta do projeto (`files/<projeto>/`) se já existe um backup concluído para o dia atual. Se sim, ele ignora aquele projeto e passa para o próximo.
- **Blindagem de Rede:** Utiliza o `nc` (Netcat) para validar se o host do Supabase está acessível antes de tentar o `pg_dump`.
- **Limpeza de Falhas:** Caso o backup de um banco seja interrompido ou falhe, o arquivo parcial corrompido é removido automaticamente para permitir que a próxima tentativa do Cron execute sem deixar lixo.
- **Retenção Configurável:** Remove automaticamente backups antigos com base na variável `RETENTION_DAYS` de cada projeto (padrão: 15 dias).
- **Notificações macOS:** Notifica o usuário no macOS com o status e tamanho do backup.

---

## 📂 Estrutura do Projeto

```text
supabase-backups/
├── projects/                        # Configurações isoladas de cada projeto
│   ├── .env.example                 # Modelo base com as variáveis
│   ├── canaoaves.env                # Configurações do projeto Canaoaves
│   ├── forroja.env.example          # Modelo para o projeto ForroJá
│   └── ...                          # Novos projetos (.env)
│
├── scripts/
│   ├── backup_project.sh            # Script que executa o backup de 1 projeto específico
│   ├── backup_all.sh                # Script mestre que executa o backup de todos os projetos
│   └── backup_semanal.sh            # Wrapper de compatibilidade com agendamentos anteriores
│
├── files/                           # Destino dos backups organizados por projeto
│   ├── canaoaves/                   # Backups do Canaoaves (ex: backup_canaoaves_2026-09-25_08-00-00.sql)
│   ├── forroja/                     # Backups do ForroJá
│   └── ...
│
├── backup.log                       # Logs de execução consolidados
└── README.md
```

---

## ➕ Como Adicionar um Novo Projeto (ex: ForroJá)

1. Crie um arquivo em `projects/<nome_do_projeto>.env` (você pode duplicar o `projects/.env.example` ou `projects/forroja.env.example`):
   ```bash
   cp projects/.env.example projects/forroja.env
   ```

2. Edite o arquivo com as credenciais do banco Supabase do projeto:
   ```env
   PROJECT_NAME="forroja"
   PROJECT_LABEL="ForroJá"

   DB_HOST="aws-0-sa-east-1.pooler.supabase.com"
   DB_PORT="6543"
   DB_NAME="postgres"
   DB_USER="postgres.seu_project_ref"
   PGPASSWORD="sua-senha-aqui"

   RETENTION_DAYS=15
   ```

3. Pronto! O script mestre (`backup_all.sh`) e o Cron detectarão automaticamente o novo projeto na próxima execução.

---

## 🛠️ Comandos Úteis

### Executar backup de todos os projetos
```bash
./scripts/backup_all.sh
```

### Executar backup de apenas um projeto específico
```bash
./scripts/backup_project.sh canaoaves
# ou
./scripts/backup_project.sh projects/forroja.env
```

### Ver logs de execução
```bash
tail -f backup.log
```

### Verificar o agendamento atual no Cron
```bash
crontab -l
```

---

## ⏰ Agendamento (Cron)

O agendamento executa de hora em hora na janela definida (ex: das 08h às 23h). Cada projeto é verificado individualmente: se o backup do dia já tiver sido feito, ele é ignorado instantaneamente.

```cron
0 8-23 * * * /bin/bash $HOME/supabase-backups/scripts/backup_all.sh >> $HOME/supabase-backups/backup.log 2>&1
```

---

## ⚠️ Segurança
- Todos os arquivos `.env` dentro de `projects/` e na raiz estão no `.gitignore` para não expor credenciais.
- Todos os arquivos de dump `.sql` dentro de `files/` estão no `.gitignore`.
