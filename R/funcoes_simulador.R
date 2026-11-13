# ============================================================
# FUNÇÕES DO SIMULADOR
# ============================================================

# Este arquivo só define funções, não roda nada sozinho.
# É usado pelo script 05_lattes.R e pelo app (app/app.R),
# com source("R/funcoes_simulador.R").

library(DBI) # Interface para trabalhar com bancos de dados.
library(RSQLite) # Permite utilizar SQLite no R.
library(rvest) # Ler e extrair informações de páginas HTML.
library(dplyr) # Selecionar, filtrar e transformar dados.
library(stringr) # Limpar textos.

# ============================================================
# 1. ABRIR O HTML DO LATTES
# ============================================================

# O currículo pode chegar de dois jeitos:
# - salvo pela página normal (Ctrl+S): o HTML já é o currículo;
# - salvo pelo "Exibir código-fonte": o HTML é uma tabela em que
#   cada linha (td.line-content) guarda uma linha do código
#   original. Nesse caso juntamos as linhas e lemos de novo.
ler_lattes <- function(arquivo) {
  pagina <- read_html(arquivo, encoding = "windows-1252")

  linhas <- html_text(html_elements(pagina, "td.line-content"))

  if (length(linhas) > 0) {
    pagina <- read_html(paste(linhas, collapse = "\n"))
  }

  pagina
}

# ============================================================
# 2. EXTRAIR OS ARTIGOS
# ============================================================

# Cada artigo publicado fica em um <div class="artigo-completo">.
# Dentro dele:
# - o ano está em <span data-tipo-ordenacao="ano">;
# - o ISSN está no atributo data-issn da imagem do JCR;
# - título e revista estão no link de citações (atributo cvuri).
extrair_artigos <- function(pagina) {
  artigos <- html_elements(pagina, "div.artigo-completo")

  # Pega um campo de dentro do link de citações
  campo_cvuri <- function(cvuri, campo) {
    str_match(cvuri, paste0("[?&]", campo, "=([^&]*)"))[, 2]
  }

  cvuri <- html_attr(
    html_element(artigos, "span.citacoes"),
    "cvuri"
  )

  tibble(
    ano = as.integer(html_text(
      html_element(artigos, "span[data-tipo-ordenacao='ano']")
    )),
    issn = html_attr(html_element(artigos, "img.ajaxJCR"), "data-issn"),
    titulo = campo_cvuri(cvuri, "titulo"),
    revista = campo_cvuri(cvuri, "nomePeriodico"),
    doi = campo_cvuri(cvuri, "doi"),
    # Texto completo da referência, útil para conferir
    referencia = str_squish(html_text(
      html_element(artigos, "div.layout-cell-11")
    ))
  ) |>
    limpar_issn()
}

# Deixa o ISSN no mesmo formato da tabela issn_revista
# (sem hífen, X maiúsculo). Vale para o HTML e para o XML.
limpar_issn <- function(artigos) {
  artigos |>
    mutate(
      issn = str_to_upper(str_remove_all(issn, "[^0-9Xx]")),
      issn = na_if(issn, "")
    )
}

# ============================================================
# 2B. EXTRAIR OS ARTIGOS DO XML
# ============================================================

# O próprio dono do currículo consegue baixar o Lattes em XML
# (vem dentro de um .zip). No XML cada informação tem um campo
# próprio, então a leitura é mais segura que a do HTML:
#
# <ARTIGO-PUBLICADO>
#   <DADOS-BASICOS-DO-ARTIGO TITULO-DO-ARTIGO="..." ANO-DO-ARTIGO="..." DOI="..."/>
#   <DETALHAMENTO-DO-ARTIGO TITULO-DO-PERIODICO-OU-REVISTA="..." ISSN="..."/>
# </ARTIGO-PUBLICADO>
#
# A tabela devolvida tem as mesmas colunas da versão em HTML,
# então o resto do cálculo não muda.
extrair_artigos_xml <- function(arquivo) {
  curriculo <- xml2::read_xml(arquivo)

  artigos <- xml2::xml_find_all(curriculo, ".//ARTIGO-PUBLICADO")
  basicos <- xml2::xml_find_first(artigos, "DADOS-BASICOS-DO-ARTIGO")
  detalhes <- xml2::xml_find_first(artigos, "DETALHAMENTO-DO-ARTIGO")

  # Atributo vazio ("") vira NA
  atributo <- function(nos, nome) {
    na_if(xml2::xml_attr(nos, nome), "")
  }

  tibble(
    ano = as.integer(atributo(basicos, "ANO-DO-ARTIGO")),
    issn = atributo(detalhes, "ISSN"),
    titulo = atributo(basicos, "TITULO-DO-ARTIGO"),
    revista = atributo(detalhes, "TITULO-DO-PERIODICO-OU-REVISTA"),
    doi = atributo(basicos, "DOI"),
    # Referência resumida, útil para conferir
    referencia = str_squish(paste0(
      titulo, ". ", revista,
      ", v. ", atributo(detalhes, "VOLUME"),
      ", p. ", atributo(detalhes, "PAGINA-INICIAL"),
      "-", atributo(detalhes, "PAGINA-FINAL"),
      ", ", ano, "."
    ))
  ) |>
    limpar_issn()
}

# ============================================================
# 2C. LER O CURRÍCULO EM QUALQUER FORMATO
# ============================================================

# É esta função que o app usa. Ela aceita:
# - .zip baixado do Lattes (com o XML dentro);
# - .xml;
# - .html / .htm (salvo do navegador).
#
# O formato é descoberto pelo conteúdo do arquivo, e não só
# pelo nome, porque o nome pode vir sem extensão.
ler_artigos_lattes <- function(arquivo) {
  # .zip: os primeiros bytes de um zip são sempre "PK"
  inicio <- readBin(arquivo, "raw", n = 2)

  if (identical(rawToChar(inicio), "PK")) {
    pasta <- tempfile("lattes_")
    arquivos_zip <- unzip(arquivo, exdir = pasta)
    arquivo <- arquivos_zip[str_detect(arquivos_zip, "(?i)[.]xml$")][1]

    if (is.na(arquivo)) {
      stop("O arquivo .zip não tem nenhum XML do Lattes dentro.")
    }
  }

  # XML do Lattes: começa com <?xml e tem a tag CURRICULO-VITAE
  comeco <- readChar(arquivo, nchars = 500, useBytes = TRUE)

  if (str_detect(comeco, "<\\?xml") &&
      str_detect(comeco, "CURRICULO-VITAE")) {
    extrair_artigos_xml(arquivo)
  } else {
    extrair_artigos(ler_lattes(arquivo))
  }
}

# ============================================================
# 3. PERCENTIL DE CADA ARTIGO
# ============================================================

# Mesma consulta do 06_pontuacao.Rmd (opção A: percentil da
# revista no ano em que o artigo foi publicado).
#
# Os artigos vão para uma tabela TEMPORÁRIA: ela só existe
# nesta conexão e some quando a conexão fecha. Assim, no app,
# dois docentes usando ao mesmo tempo não se misturam.
percentil_artigos <- function(con, artigos, ano_inicio, ano_fim) {
  dbWriteTable(
    con,
    "artigos_temp",
    artigos,
    temporary = TRUE,
    overwrite = TRUE
  )

  # Os ? são trocados, em ordem, pelos valores de params.
  resultado <- dbGetQuery(
    con,
    "
    SELECT a.rowid AS id_artigo,
           a.ano,
           a.titulo,
           a.revista,
           a.issn,
           MAX(i.Sourceid) IS NOT NULL AS no_scimago,
           MAX(p.percentil) AS percentil
    FROM artigos_temp AS a
    LEFT JOIN issn_revista AS i
           ON i.issn = a.issn
    LEFT JOIN percentil_revista_ano AS p
           ON p.Sourceid = i.Sourceid
          AND p.ano = a.ano
    WHERE a.ano BETWEEN ? AND ?
    GROUP BY a.rowid
    ORDER BY percentil DESC
    ",
    params = list(ano_inicio, ano_fim)
  )

  # Explica a situação de cada artigo
  resultado |>
    mutate(
      situacao = case_when(
        is.na(issn) ~ "Sem ISSN no currículo",
        no_scimago == 0 ~ "Revista não encontrada no SCImago",
        is.na(percentil) ~ "Sem percentil no ano do artigo",
        percentil < 0.25 ~ "Percentil abaixo de 0,25",
        TRUE ~ "Válido"
      )
    ) |>
    select(-no_scimago)
}

# ============================================================
# 4. PONTUAÇÃO DO DOCENTE
# ============================================================

# Soma dos 4 melhores artigos válidos (percentil >= 0,25).
# O mínimo para credenciamento é 1,25.
calcular_pontuacao <- function(percentis, minimo = 1.25) {
  melhores <- percentis |>
    filter(situacao == "Válido") |>
    arrange(desc(percentil)) |>
    head(4) |>
    mutate(posicao = row_number()) |>
    select(posicao, ano, revista, titulo, percentil)

  pontuacao <- sum(melhores$percentil)

  list(
    melhores = melhores,
    pontuacao = pontuacao,
    minimo = minimo,
    atinge = pontuacao >= minimo
  )
}

# ============================================================
# 5. PERÍODO DE AVALIAÇÃO COM AFASTAMENTOS
# ============================================================

# Soma os dias de afastamento e recua o início do período por
# esse total. Como o Lattes só informa o ano do artigo, o
# resultado final é dado em anos (ano_inicio e ano_fim).
#
# - periodo: vetor com duas datas (início e fim da avaliação);
# - afastamentos: lista em que cada item tem duas datas
#   (início e fim de um afastamento).
#
# Só contam os dias de afastamento que caem dentro do período
# de avaliação. Se dois afastamentos se sobrepõem, cada dia é
# contado uma vez só.
calcular_periodo <- function(periodo, afastamentos = list()) {
  dias_periodo <- seq(periodo[1], periodo[2], by = "day")

  dias_afastado <- afastamentos |>
    # Garante que as datas estão no formato de data
    lapply(function(a) suppressWarnings(as.Date(a))) |>
    # Ignora afastamentos incompletos ou com datas invertidas
    Filter(f = function(a) length(a) == 2 && !anyNA(a) && a[1] <= a[2]) |>
    lapply(function(a) seq(a[1], a[2], by = "day")) |>
    # unlist() transforma as datas em números (dias desde 1970),
    # por isso comparamos os dois lados como números.
    unlist() |>
    unique()

  total_dias <- sum(as.numeric(dias_periodo) %in% dias_afastado)

  inicio_recuado <- periodo[1] - total_dias

  list(
    dias_afastado = total_dias,
    inicio_recuado = inicio_recuado,
    ano_inicio = as.integer(format(inicio_recuado, "%Y")),
    ano_fim = as.integer(format(periodo[2], "%Y"))
  )
}

# ============================================================
# 6. AVALIAÇÃO COMPLETA DE UM DOCENTE
# ============================================================

# Junta todas as etapas em uma função só. É ela que o app e o
# relatório usam, para os dois darem sempre o mesmo resultado.
#
# - con: conexão com o banco simulador_ppge.sqlite;
# - arquivo: currículo Lattes (.zip, .xml ou .html);
# - periodo: vetor com duas datas (início e fim da avaliação);
# - afastamentos: lista em que cada item tem duas datas.
avaliar_docente <- function(con, arquivo, periodo, afastamentos = list()) {
  # 1. Ler os artigos do currículo
  artigos <- ler_artigos_lattes(arquivo)

  # 2. Período de avaliação, já recuado pelos afastamentos
  periodo_final <- calcular_periodo(periodo, afastamentos)

  # 3. Percentil e situação de cada artigo do período
  percentis <- percentil_artigos(
    con,
    artigos,
    ano_inicio = periodo_final$ano_inicio,
    ano_fim = periodo_final$ano_fim
  )

  # 4. Pontuação: soma dos 4 melhores artigos válidos
  pontos <- calcular_pontuacao(percentis)

  list(
    artigos = artigos,
    periodo = periodo_final,
    percentis = percentis,
    melhores = pontos$melhores,
    pontuacao = pontos$pontuacao,
    minimo = pontos$minimo,
    atinge = pontos$atinge
  )
}

# ============================================================
# 7. CONSULTAS PARA A ABA SIMULAÇÃO
# ============================================================

# Lista de revistas para a caixa de busca do app.
# O rótulo mostra o nome e um ISSN, para diferenciar revistas
# com nomes parecidos.
listar_revistas <- function(con) {
  # No SQLite, com MAX(ano) no SELECT, o Title vem da mesma linha
  # do ano mais recente (nome atual da revista).
  dbGetQuery(con, "
    WITH ultima AS (
      SELECT Sourceid, Title, MAX(ano) AS ano
      FROM percentil_revista_ano
      GROUP BY Sourceid
    ),
    um_issn AS (
      SELECT Sourceid, MIN(issn) AS issn
      FROM issn_revista
      GROUP BY Sourceid
    )
    SELECT u.Sourceid,
           u.Title || ' (' || COALESCE(i.issn, 'sem ISSN') || ')' AS rotulo
    FROM ultima AS u
    LEFT JOIN um_issn AS i ON i.Sourceid = u.Sourceid
    ORDER BY u.Title
  ")
}

# Lista das áreas (categorias do SCImago)
listar_categorias <- function(con) {
  dbGetQuery(con, "
    SELECT DISTINCT categoria FROM categorias ORDER BY categoria
  ")$categoria
}

# Percentil de uma revista em todos os anos (o maior percentil
# entre as categorias dela, que é o que vale na pontuação)
historico_revista <- function(con, sourceid) {
  dbGetQuery(
    con,
    "
    SELECT CAST(ano AS INTEGER) AS ano, Title AS revista,
           categoria_percentil AS categoria,
           SJR, quartil, percentil
    FROM percentil_revista_ano
    WHERE Sourceid = ?
    ORDER BY ano
    ",
    params = list(sourceid)
  )
}

# Percentil de todas as revistas de uma área, em cada ano.
# Aqui o percentil é calculado só dentro desta área (mesma conta
# do 03_percentis.R, feita em SQL com CUME_DIST).
historico_categoria <- function(con, categoria) {
  dbGetQuery(
    con,
    "
    SELECT Sourceid, Title AS revista, CAST(ano AS INTEGER) AS ano,
           SJR, quartil,
           CUME_DIST() OVER (PARTITION BY ano ORDER BY SJR) AS percentil
    FROM categorias
    WHERE categoria = ?
      AND SJR IS NOT NULL
    ",
    params = list(categoria)
  )
}

# Percentil de um artigo hipotético: revista + ano.
# Se o ano ainda não tem SCImago (ex.: 2026), usa o ano mais
# recente da revista como ESTIMATIVA.
percentil_hipotetico <- function(con, sourceid, ano) {
  historico <- historico_revista(con, sourceid)

  if (nrow(historico) == 0) {
    return(list(percentil = NA, ano_usado = NA, estimado = FALSE))
  }

  if (ano %in% historico$ano) {
    linha <- historico[historico$ano == ano, ]
    estimado <- FALSE
  } else if (ano > max(historico$ano)) {
    linha <- historico[historico$ano == max(historico$ano), ]
    estimado <- TRUE
  } else {
    # Ano antigo em que a revista não estava no SCImago
    return(list(percentil = NA, ano_usado = NA, estimado = FALSE))
  }

  list(
    percentil = linha$percentil,
    ano_usado = linha$ano,
    estimado = estimado
  )
}

# Junta os artigos reais (do currículo) com os hipotéticos e
# recalcula a pontuação.
# - percentis: resultado de percentil_artigos() (pode ser NULL);
# - hipoteticos: data.frame com ano, revista e percentil.
simular_pontuacao <- function(percentis, hipoteticos) {
  reais <- if (is.null(percentis)) {
    tibble(ano = integer(), revista = character(), titulo = character(),
           percentil = numeric(), situacao = character())
  } else {
    percentis |>
      mutate(titulo = paste0(titulo, " (currículo)"))
  }

  hip <- hipoteticos |>
    mutate(
      titulo = "Artigo hipotético",
      situacao = case_when(
        is.na(percentil) ~ "Sem percentil no ano do artigo",
        percentil < 0.25 ~ "Percentil abaixo de 0,25",
        TRUE ~ "Válido"
      )
    )

  bind_rows(
    select(reais, ano, revista, titulo, percentil, situacao),
    select(hip, ano, revista, titulo, percentil, situacao)
  ) |>
    calcular_pontuacao()
}
