# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(DBI)
library(RSQLite)
library(readr)

# ============================================================
# 2. DEFINIR CAMINHOS
# ============================================================

pasta_limpos <- "dados/limpos"

arquivo_banco <- file.path(
  pasta_limpos,
  "simulador_ppge.sqlite"
)

# ============================================================
# 3. CONECTAR AO BANCO SQLITE
# ============================================================

con <- dbConnect(
  SQLite(),
  arquivo_banco
)

# ============================================================
# 4. IMPORTAR OS DADOS LIMPOS
# ============================================================

periodicos_historico <- read_csv(
  file.path(pasta_limpos, "periodicos_historico.csv"),
  show_col_types = FALSE
)

categorias_historico <- read_csv(
  file.path(pasta_limpos, "categorias_historico.csv"),
  show_col_types = FALSE
)

# ============================================================
# 5. GRAVAR OS DADOS NO SQLITE
# ============================================================

dbWriteTable(
  con,
  "periodicos",
  periodicos_historico,
  overwrite = TRUE
)

dbWriteTable(
  con,
  "categorias",
  categorias_historico,
  overwrite = TRUE
)

# ============================================================
# 6. CONFERIR AS TABELAS
# ============================================================

dbListTables(con)

# ============================================================
# 7. CONFERIR A QUANTIDADE DE REGISTROS
# ============================================================

dbGetQuery(
  con,
  "SELECT COUNT(*) AS total FROM periodicos"
)

dbGetQuery(
  con,
  "SELECT COUNT(*) AS total FROM categorias"
)

dbGetQuery(
  con,
  "SELECT DISTINCT ano
   FROM periodicos
   ORDER BY ano"
)

# ============================================================
# 8. ENCERRAR A CONEXÃO
# ============================================================

dbDisconnect(con)
