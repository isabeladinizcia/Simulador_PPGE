# ============================================================
# 08 - PUBLICAR O APP NO SHINYAPPS.IO
# ============================================================

# Antes de rodar este script (só na primeira vez):
#
# 1. Crie uma conta em https://www.shinyapps.io
# 2. Instale o pacote:  install.packages("rsconnect")
# 3. No site, vá em Account > Tokens > Show > Show secret.
#    Copie o comando rsconnect::setAccountInfo(...) que aparece
#    e rode no console do RStudio. Ele liga o RStudio à sua conta.
#    NÃO cole esse comando em nenhum arquivo do projeto: ele tem
#    a sua chave secreta.
#
# Depois disso, é só rodar este script (Source) sempre que quiser
# publicar uma versão nova do app.

# ============================================================
# 1. CARREGAR PACOTE
# ============================================================

library(rsconnect) # Envia o app para o shinyapps.io.

# ============================================================
# 2. CONFERIR SE ESTÁ TUDO PRONTO
# ============================================================

# A conta do shinyapps.io já foi ligada ao RStudio?
if (nrow(accounts()) == 0) {
  stop("Nenhuma conta do shinyapps.io configurada. Veja o passo 3 no topo do script.")
}

# O banco menor do app existe? (criado pelo R/07_banco_app.R)
if (!file.exists("dados/limpos/simulador_ppge_app.sqlite")) {
  stop("Rode antes o script R/07_banco_app.R para criar o banco do app.")
}

# A senha está no .Renviron? (o conteúdo não é mostrado)
tem_senha <- file.exists(".Renviron") &&
  any(grepl("^SIMULADOR_SENHA=.+", readLines(".Renviron", warn = FALSE)))

if (!tem_senha) {
  stop("Crie o arquivo .Renviron com a linha SIMULADOR_SENHA=... antes de publicar.")
}

# ============================================================
# 3. ARQUIVOS QUE VÃO PARA A NUVEM
# ============================================================

# Só o que o app precisa. Ficam de fora os CSVs, o banco completo,
# os scripts 01 a 08 e os arquivos do RStudio.
arquivos <- c(
  "app.R",                                   # entrada do app
  "app/app.R",                               # o app
  "R/funcoes_simulador.R",                   # funções do cálculo
  "relatorio/relatorio_docente.Rmd",         # modelo do PDF
  "dados/limpos/simulador_ppge_app.sqlite",  # banco do app
  "Simulador_PPGE.Rproj",                    # marca a pasta do projeto (usado pelo here)
  ".Renviron"                                # senha de acesso
)

# Tamanho total do envio, em MB
round(sum(file.size(arquivos)) / 1024^2)

# ============================================================
# 4. PUBLICAR
# ============================================================

# O endereço do app vai ser:
#   https://SEU-USUARIO.shinyapps.io/simulador-ppge/
deployApp(
  appDir = ".",
  appFiles = arquivos,
  appName = "simulador-ppge",
  appTitle = "Simulador PPGE",
  launch.browser = TRUE
)
