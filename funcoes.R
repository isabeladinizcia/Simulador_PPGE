# ============================================================
# FUNÇÕES QUE O APP USA
# ============================================================

library(DBI)
library(RSQLite)
library(xml2)


# ------------------------------------------------------------
# Ler os artigos do currículo Lattes (XML)
# ------------------------------------------------------------
ler_lattes <- function(arquivo, nome) {

  # Se for .zip, tira o XML de dentro
  if (grepl("\\.zip$", nome)) {
    arquivo <- unzip(arquivo, exdir = tempdir())[1]
  }

  curriculo <- read_xml(arquivo)

  # Confere se é mesmo o currículo Lattes
  if (xml_name(curriculo) != "CURRICULO-VITAE") {
    stop("Não é o XML do Lattes")
  }

  # Pega as informações de cada artigo
  basicos <- xml_find_all(curriculo, "//ARTIGO-PUBLICADO/DADOS-BASICOS-DO-ARTIGO")
  detalhes <- xml_find_all(curriculo, "//ARTIGO-PUBLICADO/DETALHAMENTO-DO-ARTIGO")

  artigos <- data.frame(
    ano = as.numeric(xml_attr(basicos, "ANO-DO-ARTIGO")),
    titulo = xml_attr(basicos, "TITULO-DO-ARTIGO"),
    revista = xml_attr(detalhes, "TITULO-DO-PERIODICO-OU-REVISTA"),
    issn = xml_attr(detalhes, "ISSN")
  )

  # Apaga o XML que saiu do .zip (não guardamos nada do docente)
  if (grepl("\\.zip$", nome)) {
    unlink(arquivo)
  }

  artigos
}


# ------------------------------------------------------------
# Calcular a nota de cada artigo
# ------------------------------------------------------------
calcular_notas <- function(con, artigos, ano_inicio, ano_fim) {

  # Os artigos vão para uma tabela TEMPORÁRIA, que some quando o app fecha
  dbWriteTable(con, "artigos", artigos, temporary = TRUE, overwrite = TRUE)

  # Tira o hífen do ISSN para ficar igual ao do banco (0101-3157 -> 01013157)
  dbExecute(con, "UPDATE artigos SET issn = REPLACE(issn, '-', '')")

  # Junta cada artigo com a revista pelo ISSN e pega a nota da revista.
  # Só entram os artigos do período.
  dbExecute(con, "DELETE FROM notas")
  dbExecute(con, "
    INSERT INTO notas (ano, titulo, revista, issn, nota)
    SELECT artigos.ano, artigos.titulo, artigos.revista, artigos.issn, MAX(revistas.nota)
    FROM artigos
    LEFT JOIN issn ON issn.issn = artigos.issn
    LEFT JOIN revistas ON revistas.Sourceid = issn.Sourceid
    WHERE artigos.ano >= ? AND artigos.ano <= ?
    GROUP BY artigos.rowid
  ", params = list(ano_inicio, ano_fim))

  # Escreve a situação de cada artigo
  dbExecute(con, "UPDATE notas SET situacao = 'Válido'")
  dbExecute(con, "UPDATE notas SET situacao = 'Nota abaixo de 0,25' WHERE nota < 0.25")
  dbExecute(con, "UPDATE notas SET situacao = 'Revista não está no SCImago' WHERE nota IS NULL")
  dbExecute(con, "UPDATE notas SET situacao = 'Sem ISSN no currículo' WHERE issn = '' OR issn IS NULL")
}
