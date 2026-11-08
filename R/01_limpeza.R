# ============================================================
# 1. CARREGAR PACOTES
# ============================================================

library(readr) # 	Importar e exportar arquivos CSV.
library(dplyr) # 	Selecionar, filtrar e transformar dados.
library(tidyr) # Organizar e separar os dados.
library(stringr) # Trabalhar com textos e caracteres.
library(purrr) # Aplicar funções repetidamente a vários arquivos.


# ============================================================
# 2. DEFINIR PASTAS
# ============================================================

pasta_brutos <- "dados/brutos" # Arquivos originais
pasta_limpos <- "dados/limpos" # Onde será guardado os arquivos tratados

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
  
  # 1. Identificar o ano
  ano <- as.integer(
    stringr::str_extract(
      basename(arquivo),
      "\\d{4}"
    )
  )
  
  # 2. Importar o arquivo
  dados <- read_delim(
    arquivo,
    delim = ";",
    show_col_types = FALSE
  )
  
  # 3. Converter SJR
  dados <- dados |>
    mutate(
      SJR = parse_number(
        SJR,
        locale = locale(decimal_mark = ",")
      ),
      ano = .env$ano
    )
  
  # 4. Selecionar colunas e adicionar ano
  dados <- dados |>
    select(
      Sourceid,
      Title,
      Type,
      Issn,
      SJR,
      Categories,
      Areas,
      all_of("Publisher...6"),
      ano
    ) 
  
  # 5. Separar categorias
  categorias <- dados |>
    select(Sourceid, Title, SJR, Categories, ano) |>
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
      )
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
  
  # 6. Retornar resultados
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

names(resultados_sjr[["2021"]]$periodicos)

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

# ============================================================
# 16. SALVAR OS DADOS LIMPOS
# ============================================================

write_csv(
  periodicos_historico,
  file.path(pasta_limpos, "periodicos_historico.csv")
)

write_csv(
  categorias_historico,
  file.path(pasta_limpos, "categorias_historico.csv")
)
