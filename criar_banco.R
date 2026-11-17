# ============================================================
# PASSO 1: CRIAR O BANCO DE DADOS
# ============================================================
# Rode este arquivo uma vez só (botão Source). Demora alguns minutos.
# Ele pega as planilhas do SCImago e monta o banco
# dados/simulador.sqlite.

library(DBI)
library(RSQLite)

# ANOS DO SCIMAGO USADOS NA NOTA
# A nota de cada revista é o maior percentil nestes anos.
# Quando chegar um ano novo: coloque o CSV em dados/brutos/,
# mude a linha abaixo (ex.: 2022:2026 ou 2023:2026) e rode
# este arquivo de novo, uma vez só.
anos <- 2022:2025

# O banco é criado numa pasta temporária, porque dentro do OneDrive
# fica muito lento. No final ele é copiado para a pasta dados.
arquivo_temp <- tempfile()
con <- dbConnect(SQLite(), arquivo_temp)


# ------------------------------------------------------------
# 1. Colocar as planilhas no banco
# ------------------------------------------------------------
for (ano in anos) {
  planilha <- read.csv2(paste0("dados/brutos/scimagojr ", ano, ".csv"),
                        colClasses = "character", fileEncoding = "UTF-8")
  planilha <- planilha[, c("Sourceid", "Title", "Issn", "SJR", "Categories")]
  planilha$ano <- ano
  dbWriteTable(con, "scimago", planilha, append = TRUE)
}


# ------------------------------------------------------------
# 2. Arrumar o SJR
# ------------------------------------------------------------
# O SJR vem com vírgula (0,145) e o SQLite precisa de ponto (0.145)
dbExecute(con, "UPDATE scimago SET SJR = REPLACE(SJR, ',', '.')")

# Revista sem SJR não entra no cálculo
dbExecute(con, "DELETE FROM scimago WHERE SJR = '' OR SJR IS NULL")


# ------------------------------------------------------------
# 3. Separar as áreas
# ------------------------------------------------------------
# As áreas de cada revista vêm juntas: "Economics (Q1); Finance (Q2)".
# Colocamos um ; no final e vamos cortando a primeira área do texto,
# uma de cada vez, até não sobrar nada.
dbExecute(con, "CREATE TABLE sobra AS SELECT Sourceid, ano, SJR, Categories || ';' AS texto FROM scimago")
dbExecute(con, "CREATE TABLE areas (Sourceid TEXT, ano INTEGER, SJR REAL, area TEXT)")

for (vez in 1:20) {
  # Guarda a primeira área (o pedaço antes do primeiro ;)
  dbExecute(con, "
    INSERT INTO areas
    SELECT Sourceid, ano, SJR, TRIM(SUBSTR(texto, 1, INSTR(texto, ';') - 1))
    FROM sobra
    WHERE texto LIKE '%;%'
  ")
  # Apaga essa área do texto
  dbExecute(con, "UPDATE sobra SET texto = SUBSTR(texto, INSTR(texto, ';') + 1)")
}

# Tira o (Q1), (Q2), (Q3), (Q4) do nome da área
dbExecute(con, "UPDATE areas SET area = REPLACE(area, ' (Q1)', '')")
dbExecute(con, "UPDATE areas SET area = REPLACE(area, ' (Q2)', '')")
dbExecute(con, "UPDATE areas SET area = REPLACE(area, ' (Q3)', '')")
dbExecute(con, "UPDATE areas SET area = REPLACE(area, ' (Q4)', '')")
dbExecute(con, "UPDATE areas SET area = TRIM(area)") # tira espaço que sobrou no final
dbExecute(con, "DELETE FROM areas WHERE area = ''")


# ------------------------------------------------------------
# 4. Calcular o percentil
# ------------------------------------------------------------
# Percentil = parte das revistas da mesma área, no mesmo ano, que tem
# SJR menor ou igual ao da revista. A melhor revista da área fica com 1.
# O CUME_DIST() faz essa conta separada para cada área e cada ano.
dbExecute(con, "
  CREATE TABLE percentis AS
  SELECT Sourceid, ano, area, SJR,
         CUME_DIST() OVER (PARTITION BY ano, area ORDER BY SJR) AS percentil
  FROM areas
")


# ------------------------------------------------------------
# 5. Nota de cada revista
# ------------------------------------------------------------
# A nota é o MAIOR percentil da revista nos anos escolhidos, em qualquer área
dbExecute(con, "
  CREATE TABLE revistas AS
  SELECT percentis.Sourceid, scimago.Title AS nome, MAX(percentis.percentil) AS nota
  FROM percentis
  JOIN scimago ON scimago.Sourceid = percentis.Sourceid AND scimago.ano = percentis.ano
  GROUP BY percentis.Sourceid
")


# ------------------------------------------------------------
# 6. Tabela de ISSN
# ------------------------------------------------------------
# O ISSN vem assim: "15424863, 00079235" (um ou dois ISSN).
# O primeiro está nas letras 1 a 8 e o segundo nas letras 11 a 18.
dbExecute(con, "CREATE TABLE issn AS SELECT DISTINCT SUBSTR(Issn, 1, 8) AS issn, Sourceid FROM scimago")
dbExecute(con, "INSERT INTO issn SELECT DISTINCT SUBSTR(Issn, 11, 8), Sourceid FROM scimago WHERE LENGTH(Issn) > 10")
dbExecute(con, "DELETE FROM issn WHERE LENGTH(issn) < 8")


# ------------------------------------------------------------
# 7. Apagar as tabelas que não precisamos mais
# ------------------------------------------------------------
dbExecute(con, "DROP TABLE sobra")
dbExecute(con, "DROP TABLE areas")
dbExecute(con, "DROP TABLE scimago")

# Índices deixam as buscas mais rápidas
dbExecute(con, "CREATE INDEX indice_issn ON issn (issn)")
dbExecute(con, "CREATE INDEX indice_revistas ON revistas (Sourceid)")
dbExecute(con, "CREATE INDEX indice_area ON percentis (area)")
dbExecute(con, "VACUUM")


# ------------------------------------------------------------
# 8. Conferir e salvar
# ------------------------------------------------------------
# Exemplo: nota da Brazilian Journal of Political Economy
dbGetQuery(con, "
  SELECT revistas.nome, revistas.nota
  FROM issn
  JOIN revistas ON revistas.Sourceid = issn.Sourceid
  WHERE issn.issn = '01013157'
")

dbDisconnect(con)
file.copy(arquivo_temp, "dados/simulador.sqlite", overwrite = TRUE)
