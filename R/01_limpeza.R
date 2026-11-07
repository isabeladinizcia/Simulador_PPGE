# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(purrr)


# ============================================================
# 2. DEFINIR PASTAS
# ============================================================

pasta_brutos <- "dados/brutos"
pasta_limpos <- "dados/limpos"

# ============================================================
# 3. IMPORTAR ARQUIVO SJR DE 2021
# ============================================================

arquivo_2021 <- file.path(
  pasta_brutos,
  "scimagojr 2021.csv"
)

sjr_2021 <- read_delim(
  arquivo_2021,
  delim = ";",
  show_col_types = FALSE
)

# ============================================================
# 4. CONFERIR ESTRUTURA DOS DADOS
# ============================================================

# Verificar os nomes das colunas
names(sjr_2021)

# Verificar os tipos das colunas
glimpse(sjr_2021)

# Conferir as primeiras linhas
head(sjr_2021)

# ============================================================
# 5. CONVERTER SJR PARA NUMÉRICO
# ============================================================

sjr_2021 <- sjr_2021 |>
  mutate(
    SJR = parse_number(
      SJR,
      locale = locale(decimal_mark = ",")
    )
  )

# ============================================================
# 6. SELECIONAR COLUNAS IMPORTANTES
# ============================================================

sjr_2021 <- sjr_2021 |>
  select(
    Sourceid,
    Title,
    Type,
    Issn,
    SJR,
    Categories,
    Areas,
    Publisher...6
  )

# ============================================================
# 7. SEPARAR AS CATEGORIAS CIENTÍFICAS
# ============================================================

sjr_2021_categorias <- sjr_2021 |>
  select(Sourceid, Title, SJR, Categories) |>
  separate_longer_delim(
    Categories,
    delim = ";"
  ) |>
  mutate(
    Categories = str_squish(Categories),
    quartil = str_extract(Categories, "Q[1-4]"),
    categoria = str_remove(
      Categories,
      "\\s*\\(Q[1-4]\\)\\s*$"
    ),
    ano = 2021
  ) |>
  filter(
    !is.na(categoria),
    categoria != ""
  ) |>
  select(
    Sourceid,
    Title,
    ano,
    SJR,
    categoria,
    quartil
  )


# ============================================================
# 8. CONFERIR A SEPARAÇÃO DAS CATEGORIAS
# ============================================================

# Quantidade de periódicos
nrow(sjr_2021)

# Quantidade de registros por categoria
nrow(sjr_2021_categorias)

# Quantidade de categorias científicas distintas
n_distinct(sjr_2021_categorias$categoria)

# Conferir quantas categorias cada periódico possui
sjr_2021_categorias |>
  count(Sourceid) |>
  count(n, name = "quantidade_periodicos")



# ============================================================
# 9. CRIAR FUNÇÃO DE LIMPEZA
# ============================================================

limpar_sjr <- function(arquivo) {
  
  # 1. Identificar o ano pelo nome do arquivo
  ano <- as.integer(
    stringr::str_extract(basename(arquivo), "\\d{4}")
  )
  
  # 2. Importar o arquivo
  dados <- read_delim(
    arquivo,
    delim = ";",
    show_col_types = FALSE
  )
  
  # 3. Converter SJR para numérico
  dados <- dados |>
    mutate(
      SJR = parse_number(
        SJR,
        locale = locale(decimal_mark = ",")
      )
    )
  
  # 4. Selecionar as colunas importantes
  dados <- dados |>
    select(
      Sourceid,
      Title,
      Type,
      Issn,
      SJR,
      Categories,
      Areas,
      all_of("Publisher...6")
    ) |>
    mutate(
      ano = .env$ano
    )
  
  # 5. Separar as categorias científicas
  categorias <- dados |>
    select(Sourceid, Title, SJR, Categories) |>
    separate_longer_delim(
      Categories,
      delim = ";"
    ) |>
    mutate(
      Categories = str_squish(Categories),
      quartil = str_extract(Categories, "Q[1-4]"),
      categoria = str_remove(
        Categories,
        "\\s*\\(Q[1-4]\\)\\s*$"
      ),
      ano = ano
    ) |>
    filter(
      !is.na(categoria),
      categoria != ""
    ) |>
    select(
      Sourceid,
      Title,
      ano,
      SJR,
      categoria,
      quartil
    )
  
  # 6. Retornar os dados organizados
  list(
    periodicos = dados,
    categorias = categorias
  )
}

# ============================================================
# 10. TESTAR A FUNÇÃO COM O ANO DE 2021
# ============================================================

resultado_2021 <- limpar_sjr(
  file.path(pasta_brutos, "scimagojr 2021.csv")
)

nrow(resultado_2021$periodicos)

nrow(resultado_2021$categorias)


# ============================================================
# 12. LISTAR OS ARQUIVOS SJR
# ============================================================

arquivos_sjr <- list.files(
  pasta_brutos,
  pattern = "^scimagojr \\d{4}\\.csv$",
  full.names = TRUE
)

arquivos_sjr

# ============================================================
# 13. APLICAR A LIMPEZA A TODOS OS ANOS
# ============================================================

resultados_sjr <- purrr::map(
  arquivos_sjr,
  limpar_sjr
)

# Nomear cada resultado pelo ano
names(resultados_sjr) <- str_extract(
  basename(arquivos_sjr),
  "\\d{4}"
)

# ============================================================
# 14. JUNTAR OS DADOS HISTÓRICOS
# ============================================================

periodicos_historico <- purrr::map_dfr(
  resultados_sjr,
  "periodicos"
)

categorias_historico <- purrr::map_dfr(
  resultados_sjr,
  "categorias"
)
