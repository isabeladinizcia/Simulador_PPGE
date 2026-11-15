# ============================================================
# 07 - BANCO MENOR SÓ PARA O APP
# ============================================================

# O banco completo (simulador_ppge.sqlite) tem tabelas que o app
# não usa, como a "periodicos". Para publicar o app na nuvem,
# criamos uma cópia só com o que ele precisa:
#   - percentil_revista_ano (pontuação dos artigos)
#   - issn_revista          (achar a revista pelo ISSN)
#   - categorias            (histórico por área, na Simulação)
#
# Rode este script depois do 01 ao 04, e de novo sempre que o
# banco completo for atualizado (por exemplo, ano novo do SCImago).
#
# IMPORTANTE: feche o app (botão Stop no RStudio) antes de rodar.
# Com o app aberto, o banco fica em uso e não pode ser alterado.

# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(DBI) # Interface para trabalhar com bancos de dados.
library(RSQLite) # Permite utilizar SQLite no R.

# ============================================================
# 2. DEFINIR CAMINHOS
# ============================================================

banco_completo <- file.path("dados/limpos", "simulador_ppge.sqlite")
banco_app <- file.path("dados/limpos", "simulador_ppge_app.sqlite")

# ============================================================
# 3. COPIAR AS TABELAS USADAS PELO APP
# ============================================================

origem <- dbConnect(SQLite(), banco_completo)
destino <- dbConnect(SQLite(), banco_app)

tabelas_app <- c("percentil_revista_ano", "issn_revista", "categorias")

# overwrite = TRUE substitui a tabela se ela já existir, então o
# script pode ser rodado de novo sem apagar o arquivo do banco
for (tabela in tabelas_app) {
  dbWriteTable(destino, tabela, dbReadTable(origem, tabela), overwrite = TRUE)
}

dbDisconnect(origem)

# ============================================================
# 4. ÍNDICES
# ============================================================

# Índices funcionam como o índice de um livro: o banco acha as
# linhas sem ler a tabela inteira. Deixam o app mais rápido.
# IF NOT EXISTS: não dá erro se o índice já existir
dbExecute(destino, "CREATE INDEX IF NOT EXISTS idx_issn ON issn_revista (issn)")
dbExecute(destino, "CREATE INDEX IF NOT EXISTS idx_percentil ON percentil_revista_ano (Sourceid, ano)")
dbExecute(destino, "CREATE INDEX IF NOT EXISTS idx_categoria ON categorias (categoria)")

# VACUUM reorganiza o arquivo e libera o espaço que sobrou
dbExecute(destino, "VACUUM")

# ============================================================
# 5. CONFERIR
# ============================================================

dbListTables(destino)

for (tabela in tabelas_app) {
  print(dbGetQuery(destino, paste("SELECT COUNT(*) AS", tabela, "FROM", tabela)))
}

dbDisconnect(destino)

# Tamanho dos dois bancos, em MB
round(file.size(c(banco_completo, banco_app)) / 1024^2)
