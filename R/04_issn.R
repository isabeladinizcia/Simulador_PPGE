# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(DBI) # Interface para trabalhar com bancos de dados.
library(RSQLite) # Permite utilizar SQLite no R.
library(dplyr) # Selecionar, filtrar e transformar dados.
library(tidyr) # Separar um ISSN por linha.
library(stringr) # Limpar o texto dos ISSNs.

# ============================================================
# 2. CONECTAR AO BANCO E LER OS PERIÓDICOS
# ============================================================

con <- dbConnect(
  SQLite(),
  file.path("dados/limpos", "simulador_ppge.sqlite")
)

periodicos <- dbReadTable(con, "periodicos")

# ============================================================
# 3. OLHAR COMO O ISSN VEM NO SCIMAGO
# ============================================================

# Pode vir um ISSN, dois ISSNs separados por vírgula, ou "-"
# quando a revista não tem ISSN.
periodicos |>
  select(Title, Issn) |>
  head(10)

# ============================================================
# 4. CRIAR A TABELA ISSN -> REVISTA
# ============================================================

issn_revista <- periodicos |>
  select(Sourceid, Title, Issn) |>
  # Um ISSN por linha (como fizemos com as categorias no 01)
  separate_longer_delim(Issn, delim = ",") |>
  mutate(
    # Deixa só números e X (ex.: " 0007-9235" -> "00079235")
    issn = str_to_upper(str_remove_all(Issn, "[^0-9Xx]"))
  ) |>
  # ISSN válido tem 8 caracteres (isso também descarta o "-")
  filter(nchar(issn) == 8) |>
  # A mesma revista aparece em vários anos: fica uma linha só
  distinct(issn, Sourceid, .keep_all = TRUE) |>
  select(issn, Sourceid, Title)

# Quantidade de ISSNs
nrow(issn_revista)

# Conferência: algum ISSN aponta para mais de uma revista?
issn_revista |>
  count(issn) |>
  filter(n > 1) |>
  nrow()

# ============================================================
# 5. EXEMPLO: BUSCAR UMA REVISTA PELO ISSN
# ============================================================

# No Lattes o ISSN vem com hífen. Limpamos do mesmo jeito.
issn_lattes <- "0101-3157"

issn_limpo <- str_remove_all(issn_lattes, "[^0-9Xx]")

issn_revista |>
  filter(issn == issn_limpo)

# ============================================================
# 6. GRAVAR NO BANCO
# ============================================================

dbWriteTable(
  con,
  "issn_revista",
  issn_revista,
  overwrite = TRUE
)

dbListTables(con)

# ============================================================
# 7. ENCERRAR A CONEXÃO
# ============================================================

dbDisconnect(con)
