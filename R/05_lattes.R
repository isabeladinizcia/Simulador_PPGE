# ============================================================
# 1. CARREGAR AS FUNÇÕES
# ============================================================

# As funções de leitura do Lattes ficam em funcoes_simulador.R,
# porque o app também usa as mesmas funções.
source("R/funcoes_simulador.R")

# ============================================================
# 2. TESTAR COM O CURRÍCULO DE EXEMPLO
# ============================================================

# Coloque o currículo em dados/brutos. Pode ser o .zip ou o .xml
# baixado do Lattes, ou o HTML salvo do navegador.
arquivo <- list.files(
  "dados/brutos",
  pattern = "[.](zip|xml|html?)$",
  full.names = TRUE
)[1]

# ler_artigos_lattes() descobre o formato sozinha
artigos_docente <- ler_artigos_lattes(arquivo)

# Quantos artigos foram encontrados
nrow(artigos_docente)

artigos_docente |>
  select(ano, issn, revista, titulo)

# Conferência: artigos sem ISSN ou sem ano
artigos_docente |>
  filter(is.na(issn) | is.na(ano)) |>
  select(ano, issn, referencia)

# ============================================================
# 3. GRAVAR NO BANCO E CONFERIR O CRUZAMENTO COM O SCIMAGO
# ============================================================

con <- dbConnect(
  SQLite(),
  file.path("dados/limpos", "simulador_ppge.sqlite")
)

dbWriteTable(
  con,
  "artigos_docente",
  artigos_docente,
  overwrite = TRUE
)

# Quantos artigos encontram a revista no SCImago pelo ISSN
dbGetQuery(con, "
  SELECT COUNT(*) AS artigos,
         COUNT(i.Sourceid) AS encontrados_no_scimago
  FROM artigos_docente AS a
  LEFT JOIN issn_revista AS i ON i.issn = a.issn
")

# ============================================================
# 4. ENCERRAR A CONEXÃO
# ============================================================

dbDisconnect(con)
