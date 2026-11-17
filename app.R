# ============================================================
# PASSO 2: O APP (botão Run App)
# ============================================================

library(shiny)
library(ggplot2)
source("funcoes.R")

# A senha fica no arquivo .Renviron, que não vai para o GitHub
readRenviron(".Renviron")
senha_certa <- Sys.getenv("SIMULADOR_SENHA")

# Lista das áreas, para a aba Histórico
con <- dbConnect(SQLite(), "dados/simulador.sqlite")
lista_areas <- dbGetQuery(con, "SELECT DISTINCT area FROM percentis ORDER BY area")$area
dbDisconnect(con)


# ============================================================
# TELAS
# ============================================================

tela_login <- fluidPage(
  h2("Simulador PPGE"),
  passwordInput("senha", "Senha:"),
  actionButton("entrar", "Entrar"),
  textOutput("erro")
)

tela_simulador <- navbarPage("Simulador PPGE",

  tabPanel("Início",
    h2("Simulador de Credenciamento PPGE"),
    h4("Regras"),
    p("1. A nota de cada artigo é o maior percentil da revista entre 2022 e 2025 (SCImago)."),
    p("2. Contam os artigos do período de avaliação. Os dias de afastamento fazem o início do período voltar."),
    p("3. Não pontuam: nota abaixo de 0,25, revista fora do SCImago e artigo sem ISSN."),
    p("4. A soma dos 4 melhores artigos precisa ser 1,25 ou mais."),
    h4("Privacidade"),
    p("O currículo é usado só para o cálculo e é apagado quando você fecha o simulador.")
  ),

  tabPanel("Calcular",
    textInput("nome", "Seu nome:"),
    dateRangeInput("periodo", "Período de avaliação:", start = "2022-01-01", end = "2025-12-31",
                   format = "dd/mm/yyyy", separator = "até", language = "pt-BR"),
    h4("Afastamentos"),
    dateRangeInput("afastamento", "Período do afastamento:",
                   format = "dd/mm/yyyy", separator = "até", language = "pt-BR"),
    actionButton("adicionar_afastamento", "Adicionar afastamento"),
    actionButton("limpar_afastamentos", "Limpar afastamentos"),
    tableOutput("lista_afastamentos"),
    h4("Currículo"),
    fileInput("lattes", "Currículo Lattes em XML (.zip ou .xml):"),
    a("Como baixar o XML do Lattes",
      href = "https://www2.ufjf.br/propp/2024/11/13/como-gerar-o-arquivo-xml-do-curriculo-lattes/",
      target = "_blank"),
    br(), br(),
    actionButton("calcular", "Calcular"),
    hr(),
    textOutput("periodo_texto"),
    h3(textOutput("resultado")),
    h4("Os 4 melhores artigos"),
    tableOutput("melhores"),
    h4("Todos os artigos do período"),
    tableOutput("todos"),
    downloadButton("baixar", "Baixar relatório em PDF")
  ),

  tabPanel("Simulação",
    p("Procure a revista pelo nome ou pelo ISSN e veja como um artigo novo nela mudaria a sua pontuação."),
    textInput("busca", "Nome ou ISSN da revista:"),
    actionButton("buscar", "Buscar"),
    selectInput("revista_escolhida", "Revista:", choices = NULL, width = "100%"),
    actionButton("adicionar", "Adicionar artigo"),
    actionButton("limpar", "Limpar"),
    h3(textOutput("simulacao_texto")),
    tableOutput("simulacao")
  ),

  tabPanel("Histórico por área",
    selectInput("area", "Área:", choices = lista_areas),
    selectInput("revistas_grafico", "Revistas no gráfico:", choices = NULL, multiple = TRUE, width = "100%"),
    plotOutput("grafico"),
    tableOutput("historico")
  )
)

ui <- uiOutput("tela")


# ============================================================
# SERVIDOR
# ============================================================

server <- function(input, output, session) {

  # Cada pessoa que abre o app tem a sua conexão com o banco
  con <- dbConnect(SQLite(), "dados/simulador.sqlite")

  # Tabelas temporárias: somem quando a pessoa fecha o app
  dbExecute(con, "CREATE TEMP TABLE afastamentos (inicio TEXT, fim TEXT)")
  dbExecute(con, "CREATE TEMP TABLE dias_afastado (dia TEXT)")
  dbExecute(con, "CREATE TEMP TABLE notas (ano INTEGER, titulo TEXT, revista TEXT, issn TEXT, nota REAL, situacao TEXT)")
  dbExecute(con, "CREATE TEMP TABLE simulados (revista TEXT, nota REAL)")

  # Quando a pessoa fecha o app: fecha o banco e apaga o currículo
  session$onSessionEnded(function() {
    dbDisconnect(con)
    unlink(isolate(input$lattes$datapath))
  })

  guardado <- reactiveValues() # resultados para o relatório em PDF


  # ---------- LOGIN ----------
  logado <- reactiveVal(FALSE)

  output$tela <- renderUI({
    if (logado()) {
      tela_simulador
    } else {
      tela_login
    }
  })

  observeEvent(input$entrar, {
    if (senha_certa != "" && input$senha == senha_certa) {
      logado(TRUE)
    } else {
      Sys.sleep(1) # espera 1 segundo para atrapalhar quem tenta adivinhar
      output$erro <- renderText("Senha errada.")
    }
  })


  # ---------- AFASTAMENTOS ----------
  mostrar_afastamentos <- function() {
    tabela <- dbGetQuery(con, "SELECT inicio, fim FROM afastamentos")
    output$lista_afastamentos <- renderTable(tabela)
  }

  observeEvent(input$adicionar_afastamento, {
    if (input$afastamento[1] > input$afastamento[2]) {
      showNotification("A data de início é depois da data de fim.")
      return()
    }
    dbExecute(con, "INSERT INTO afastamentos VALUES (?, ?)",
              params = list(as.character(input$afastamento[1]), as.character(input$afastamento[2])))
    mostrar_afastamentos()
  })

  observeEvent(input$limpar_afastamentos, {
    dbExecute(con, "DELETE FROM afastamentos")
    mostrar_afastamentos()
  })


  # ---------- BOTÃO CALCULAR ----------
  observeEvent(input$calcular, {

    if (is.null(input$lattes)) {
      showNotification("Envie o currículo primeiro.")
      return()
    }

    # 1. Ler o currículo
    artigos <- try(ler_lattes(input$lattes$datapath, input$lattes$name))
    if (inherits(artigos, "try-error")) {
      showNotification("Arquivo inválido. Envie o XML do Lattes (.zip ou .xml).")
      return()
    }

    # 2. Afastamentos: cada dia de afastamento vira uma linha na tabela dias_afastado
    dbExecute(con, "DELETE FROM dias_afastado")
    afastamentos <- dbGetQuery(con, "SELECT inicio, fim FROM afastamentos")

    if (nrow(afastamentos) > 0) {
      for (i in 1:nrow(afastamentos)) {
        dias <- seq(as.Date(afastamentos$inicio[i]), as.Date(afastamentos$fim[i]), by = "day")
        dbWriteTable(con, "dias_afastado", data.frame(dia = as.character(dias)), append = TRUE)
      }
    }

    inicio <- input$periodo[1]
    fim <- input$periodo[2]

    # Conta os dias diferentes dentro do período
    # (um dia que está em dois afastamentos conta uma vez só)
    dias_afastado <- dbGetQuery(con, "
      SELECT COUNT(DISTINCT dia) AS total
      FROM dias_afastado
      WHERE dia >= ? AND dia <= ?
    ", params = list(as.character(inicio), as.character(fim)))$total

    # O início do período volta o número de dias de afastamento
    novo_inicio <- inicio - dias_afastado
    ano_inicio <- as.numeric(format(novo_inicio, "%Y"))
    ano_fim <- as.numeric(format(fim, "%Y"))

    # 3. Calcular as notas
    calcular_notas(con, artigos, ano_inicio, ano_fim)

    todos <- dbGetQuery(con, "
      SELECT ano, revista, titulo, nota, situacao
      FROM notas
      ORDER BY nota DESC
    ")

    melhores <- dbGetQuery(con, "
      SELECT ano, revista, titulo, nota
      FROM notas
      WHERE situacao = 'Válido'
      ORDER BY nota DESC
      LIMIT 4
    ")

    total <- sum(melhores$nota)

    if (total >= 1.25) {
      resultado <- "Atinge o mínimo"
    } else {
      resultado <- "Não atinge o mínimo"
    }

    # 4. Mostrar na tela
    texto_periodo <- paste0("Contam os artigos de ", ano_inicio, " a ", ano_fim,
                            " (", dias_afastado, " dias de afastamento)")

    output$periodo_texto <- renderText(texto_periodo)
    output$resultado <- renderText(paste("Pontuação:", round(total, 3), "-", resultado))
    output$melhores <- renderTable(melhores, digits = 3)
    output$todos <- renderTable(todos, digits = 3)

    # 5. Guardar para o relatório
    guardado$periodo <- texto_periodo
    guardado$afastamentos <- afastamentos
    guardado$total <- total
    guardado$resultado <- resultado
    guardado$melhores <- melhores
    guardado$todos <- todos
  })


  # ---------- RELATÓRIO EM PDF ----------
  output$baixar <- downloadHandler(
    filename = "relatorio_ppge.pdf",
    content = function(file) {
      rmarkdown::render("relatorio.Rmd", output_file = file, intermediates_dir = tempdir(),
                        envir = new.env(),
                        params = list(nome = input$nome,
                                      periodo = guardado$periodo,
                                      afastamentos = guardado$afastamentos,
                                      total = guardado$total,
                                      resultado = guardado$resultado,
                                      melhores = guardado$melhores,
                                      todos = guardado$todos))
    }
  )


  # ---------- SIMULAÇÃO ----------
  mostrar_simulacao <- function() {
    tabela <- dbGetQuery(con, "
      SELECT revista, 'Artigo do currículo' AS tipo, nota FROM notas WHERE situacao = 'Válido'
      UNION ALL
      SELECT revista, 'Artigo simulado' AS tipo, nota FROM simulados WHERE nota >= 0.25
      ORDER BY nota DESC
      LIMIT 4
    ")
    output$simulacao <- renderTable(tabela, digits = 3)
    output$simulacao_texto <- renderText(paste("Pontuação com a simulação:", round(sum(tabela$nota), 3)))
  }

  observeEvent(input$buscar, {
    texto <- paste0("%", gsub("-", "", input$busca), "%")

    achadas <- dbGetQuery(con, "
      SELECT DISTINCT revistas.Sourceid, revistas.nome
      FROM revistas
      LEFT JOIN issn ON issn.Sourceid = revistas.Sourceid
      WHERE revistas.nome LIKE ? OR issn.issn LIKE ?
      ORDER BY revistas.nome
      LIMIT 50
    ", params = list(texto, texto))

    if (nrow(achadas) == 0) {
      showNotification("Nenhuma revista encontrada.")
    }

    updateSelectInput(session, "revista_escolhida", choices = setNames(achadas$Sourceid, achadas$nome))
  })

  observeEvent(input$adicionar, {
    dbExecute(con, "
      INSERT INTO simulados
      SELECT nome, nota FROM revistas WHERE Sourceid = ?
    ", params = list(input$revista_escolhida))
    mostrar_simulacao()
  })

  observeEvent(input$limpar, {
    dbExecute(con, "DELETE FROM simulados")
    mostrar_simulacao()
  })


  # ---------- HISTÓRICO POR ÁREA ----------
  observeEvent(input$area, {
    tabela <- dbGetQuery(con, "
      SELECT revistas.nome AS revista, percentis.ano, percentis.percentil
      FROM percentis
      JOIN revistas ON revistas.Sourceid = percentis.Sourceid
      WHERE percentis.area = ?
      ORDER BY revistas.nome, percentis.ano
    ", params = list(input$area))
    output$historico <- renderTable(tabela, digits = 3)

    # Lista de revistas da área, das melhores para as piores
    # (pelo percentil dentro desta área).
    # As 3 primeiras já aparecem no gráfico.
    nomes <- dbGetQuery(con, "
      SELECT revistas.nome
      FROM percentis
      JOIN revistas ON revistas.Sourceid = percentis.Sourceid
      WHERE percentis.area = ?
      GROUP BY revistas.nome
      ORDER BY MAX(percentis.percentil) DESC
    ", params = list(input$area))$nome
    updateSelectInput(session, "revistas_grafico", choices = nomes, selected = head(nomes, 3))
  })

  output$grafico <- renderPlot({
    dados <- dbGetQuery(con, "
      SELECT revistas.nome AS revista, percentis.ano, percentis.percentil
      FROM percentis
      JOIN revistas ON revistas.Sourceid = percentis.Sourceid
      WHERE percentis.area = ?
    ", params = list(input$area))

    # Fica só com as revistas escolhidas
    dados <- dados[dados$revista %in% input$revistas_grafico, ]

    ggplot(dados, aes(x = ano, y = percentil, colour = revista)) +
      geom_line() +
      geom_point() +
      geom_hline(yintercept = 0.25, linetype = "dashed") +
      ylim(0, 1) +
      labs(x = "Ano", y = "Percentil", colour = "Revista")
  })
}

shinyApp(ui, server)
