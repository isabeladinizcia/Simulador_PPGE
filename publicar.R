# ============================================================
# PASSO 3: PUBLICAR NO SHINYAPPS.IO
# ============================================================
# Na primeira vez, copie do site (Account > Tokens) o comando
# rsconnect::setAccountInfo(...) e rode no CONSOLE.
# Não cole esse comando aqui, porque ele tem a sua chave secreta.

library(rsconnect)

deployApp(
  appFiles = c("app.R", "funcoes.R", "relatorio.Rmd", "dados/simulador.sqlite", ".Renviron"),
  appName = "simulador-ppge"
)
