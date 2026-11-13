# ============================================================
# 1. CARREGAR AS FUNÇÕES
# ============================================================

# As funções de leitura do Lattes ficam em funcoes_simulador.R,
# porque o app também usa as mesmas funções.
source("R/funcoes_simulador.R")

# ============================================================
# 2. LER O CURRÍCULO
# ============================================================

# Currículo fictício de exemplo. Para testar outro currículo,
# troque o caminho: pode ser o .zip ou o .xml baixado do Lattes,
# ou o HTML salvo do navegador.
arquivo <- "dados/exemplo/curriculo_ficticio.xml"

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
# 3. CONFERIR O CRUZAMENTO COM O SCIMAGO
# ============================================================

con <- dbConnect(
  SQLite(),
  file.path("dados/limpos", "simulador_ppge.sqlite")
)

# Os artigos vão para uma tabela TEMPORÁRIA, que some quando a
# conexão fecha. Assim os dados do docente não ficam guardados
# no banco.
dbWriteTable(
  con,
  "artigos_docente",
  artigos_docente,
  temporary = TRUE,
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

