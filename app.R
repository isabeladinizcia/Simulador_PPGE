# ============================================================
# ENTRADA DO APP PARA A NUVEM (shinyapps.io)
# ============================================================

# O shinyapps.io procura um arquivo app.R na pasta principal do
# projeto. O app de verdade está em app/app.R; este arquivo só
# aponta para ele.
#
# No RStudio, você pode continuar rodando app/app.R normalmente.

shiny::shinyAppDir("app")
