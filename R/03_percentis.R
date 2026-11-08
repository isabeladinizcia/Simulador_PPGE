# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(DBI) # Interface para trabalhar com bancos de dados.
library(RSQLite) # Permite utilizar SQLite no R.
library(dplyr) # Selecionar, filtrar e transformar dados.

# ============================================================
# 2. CONECTAR AO BANCO E LER AS CATEGORIAS
# ============================================================

con <- dbConnect(
  SQLite(),
  file.path("dados/limpos", "simulador_ppge.sqlite")
)

# Tabela com uma linha por revista, ano e categoria
categorias <- dbReadTable(con, "categorias")

# ============================================================
# 3. EXEMPLO: UMA CATEGORIA EM UM ANO
# ============================================================

# Vamos entender o percentil olhando só uma categoria.
exemplo <- categorias |>
  filter(
    ano == 2024,
    categoria == "Economics and Econometrics",
    !is.na(SJR) # revistas sem SJR não entram no ranking
  ) |>
  mutate(
    # Fração das revistas da categoria com SJR menor ou igual
    # ao desta revista. A melhor revista fica com 1.
    percentil = cume_dist(SJR)
  ) |>
  arrange(desc(percentil)) |>
  select(Title, SJR, quartil, percentil)

# Quantas revistas tem a categoria
nrow(exemplo)

# As 5 melhores e as 5 piores
head(exemplo, 5)
tail(exemplo, 5)

# ============================================================
# 4. PERCENTIL DE TODAS AS CATEGORIAS E ANOS
# ============================================================

# Mesmo cálculo do exemplo, mas agora o group_by() faz o
# cálculo separadamente para cada combinação de ano e categoria.
percentis_categoria <- categorias |>
  filter(!is.na(SJR)) |>
  group_by(ano, categoria) |>
  mutate(percentil = cume_dist(SJR)) |>
  ungroup() |>
  select(Sourceid, Title, ano, categoria, SJR, quartil, percentil)

# Quantidade de linhas calculadas
nrow(percentis_categoria)

# Conferência: o percentil médio deve diminuir de Q1 para Q4
percentis_categoria |>
  group_by(quartil) |>
  summarise(percentil_medio = mean(percentil))

# Conferência: o exemplo da seção 3 deve dar o mesmo resultado
percentis_categoria |>
  filter(ano == 2024, categoria == "Economics and Econometrics") |>
  arrange(desc(percentil)) |>
  head(3)

# ============================================================
# 5. MAIOR PERCENTIL DE CADA REVISTA EM CADA ANO
# ============================================================

# Uma revista pode estar em várias categorias. Pela regra do
# PPGE vale o maior percentil, então guardamos só a melhor
# categoria de cada revista em cada ano.
percentil_revista_ano <- percentis_categoria |>
  group_by(Sourceid, ano) |>
  slice_max(percentil, n = 1, with_ties = FALSE) |>
  ungroup() |>
  rename(categoria_percentil = categoria)

# Agora deve haver uma linha por revista e ano
nrow(percentil_revista_ano)

# Conferência: nenhuma revista pode aparecer duas vezes no mesmo ano
percentil_revista_ano |>
  count(Sourceid, ano) |>
  filter(n > 1) |>
  nrow()

# Exemplo: uma revista com várias categorias
percentis_categoria |>
  filter(Title == "Brazilian Journal of Political Economy", ano == 2024)

percentil_revista_ano |>
  filter(Title == "Brazilian Journal of Political Economy", ano == 2024)

# ============================================================
# 6. GRAVAR NO BANCO
# ============================================================

# overwrite = TRUE substitui a tabela se ela já existir,
# então o script pode ser rodado mais de uma vez.
dbWriteTable(
  con,
  "percentil_revista_ano",
  percentil_revista_ano,
  overwrite = TRUE
)

# Conferir se a tabela foi criada
dbListTables(con)

dbGetQuery(
  con,
  "SELECT COUNT(*) AS total FROM percentil_revista_ano"
)

# ============================================================
# 7. ENCERRAR A CONEXÃO
# ============================================================

dbDisconnect(con)
