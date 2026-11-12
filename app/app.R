library(shiny)
library(here) # Acha a pasta do projeto, de onde quer que o app rode.

# Funções de leitura do Lattes e de pontuação
source(here("R", "funcoes_simulador.R"))

arquivo_banco <- here("dados/limpos", "simulador_ppge.sqlite")

ui <- navbarPage(
  
  title = "Simulador PPGE",
  
  # 1. INÍCIO
  tabPanel(
    "Início",
    
    fluidPage(
      h1("Simulador de Credenciamento PPGE"),
      
      p("Bem-vindo(a) ao simulador de credenciamento docente."),
      
      p("Este sistema auxilia na análise da produção científica
        conforme os critérios estabelecidos pelo PPGE."),
      
      hr(),
      
      h3("Como funciona?"),
      
      p("1. Informe seus dados e envie seu currículo Lattes."),
      p("2. Confira os artigos identificados pelo sistema."),
      p("3. Consulte os critérios de credenciamento."),
      p("4. Visualize sua pontuação e o resultado."),
      
      br(),
      
      p("Comece pela aba Dados do docente.")
    )
  ),
  
  # 2. DADOS DO DOCENTE
  tabPanel(
    "Dados do docente",
    
    fluidPage(
      h2("Informações do docente"),
      
      textInput("nome", "Nome completo:"),
      
      textInput("area", "Área de atuação:"),
      
      dateRangeInput(
        "periodo",
        "Período de avaliação:",
        start = "2022-01-01",
        end = Sys.Date(),
        format = "dd/mm/yyyy",
        separator = "até",
        language = "pt-BR"
      ),
      
      h3("Afastamentos"),
      
      p("O tempo de afastamento é somado e o início do período
        de avaliação recua por esse total."),

      numericInput(
        "n_afastamentos",
        "Quantidade de afastamentos:",
        value = 0,
        min = 0,
        max = 10,
        step = 1
      ),

      # Um campo de período para cada afastamento (criado no server)
      uiOutput("campos_afastamentos"),

      strong(textOutput("periodo_considerado")),
      
      h3("Currículo Lattes"),
      
      fileInput(
        "lattes",
        "Enviar currículo Lattes",
        accept = c(".zip", ".xml", ".html", ".htm")
      ),

      p("Formatos aceitos:"),

      tags$ul(
        tags$li("XML (recomendado): o próprio dono do currículo baixa
          o arquivo .zip pela plataforma Lattes. Pode enviar o .zip
          direto, ou o .xml que está dentro dele."),
        tags$li("HTML: abra o currículo, clique com o botão direito,
          escolha \"Exibir código-fonte\" e salve a página (Ctrl+S).
          A página normal salva com Ctrl+S também funciona.")
      ),

      textOutput("leitura_lattes")
    )
  ),
  
  # 3. PRODUÇÃO CIENTÍFICA
  tabPanel(
    "Produção científica",
    
    fluidPage(
      h2("Produção científica"),
      
      p("Artigos do currículo Lattes publicados no período de
        avaliação, com o percentil da revista no ano do artigo."),
      
      textOutput("aviso_artigos"),
      
      tableOutput("artigos")
    )
  ),
  
  # 4. CRITÉRIOS
  tabPanel(
    "Critérios",
    
    fluidPage(
      h2("Critérios de credenciamento"),
      
      h4("Pontuação dos artigos"),
      
      p("Será considerado o maior percentil alcançado
        pela revista no período de referência."),
      
      p("Somente revistas com percentil igual ou superior
        a 0,25 serão consideradas."),

      p("Artigos publicados em anos que ainda não têm SCImago
        (por exemplo, 2026) ficam sem percentil e não pontuam."),
      
      h4("Pontuação mínima"),
      
      p("A soma dos quatro artigos de maior pontuação
        deverá ser igual ou superior a 1,25."),
      
      p("Os critérios definitivos serão ajustados conforme
        as regras oficiais do programa.")
    )
  ),
  
  # 5. RESULTADO
  tabPanel(
    "Resultado",
    
    fluidPage(
      h2("Resultado da avaliação"),
      
      h3(textOutput("resultado")),
      
      h4("Artigos que entram na pontuação"),
      
      tableOutput("melhores")
    )
  ),
  
  # 6. SIMULAÇÃO
  tabPanel(
    "Simulação",
    
    fluidPage(
      h2("Simulação e previsões"),
      
      p("Aqui será possível explorar cenários de publicação
        e possíveis pontuações futuras."),
      
      p("As previsões serão implementadas posteriormente.")
    )
  ),
  
  # 7. RELATÓRIO
  tabPanel(
    "Relatório",
    
    fluidPage(
      h2("Relatório personalizado"),
      
      p("Nesta área será possível gerar um relatório
        com os resultados da avaliação.")
    )
  ),
  
  # 8. ADMINISTRAÇÃO
  tabPanel(
    "Administração",
    
    fluidPage(
      h2("Área administrativa"),
      
      p("Área destinada à equipe responsável pelo simulador."),
      
      p("A autenticação e os recursos administrativos
        serão implementados posteriormente.")
    )
  )
)

server <- function(input, output, session) {
  
  # Uma conexão com o banco para cada pessoa usando o app.
  # Ela fecha sozinha quando a pessoa sai.
  con <- dbConnect(SQLite(), arquivo_banco)
  session$onSessionEnded(function() dbDisconnect(con))

  # Quantidade de afastamentos informada (vazio conta como 0)
  n_afastamentos <- reactive({
    n <- input$n_afastamentos
    if (is.null(n) || is.na(n)) 0 else max(0, min(10, round(n)))
  })

  # Cria um campo de período para cada afastamento.
  # isolate() mantém as datas já digitadas quando a quantidade muda.
  output$campos_afastamentos <- renderUI({
    lapply(seq_len(n_afastamentos()), function(i) {
      id <- paste0("afastamento_", i)
      anterior <- isolate(input[[id]])

      dateRangeInput(
        id,
        paste0("Afastamento ", i, ":"),
        start = if (is.null(anterior)) NA else anterior[1],
        end = if (is.null(anterior)) NA else anterior[2],
        format = "dd/mm/yyyy",
        separator = "até",
        language = "pt-BR"
      )
    })
  })

  # Período de avaliação já recuado pelos afastamentos
  periodo <- reactive({
    afastamentos <- lapply(
      seq_len(n_afastamentos()),
      function(i) input[[paste0("afastamento_", i)]]
    )

    calcular_periodo(input$periodo, afastamentos)
  })

  output$periodo_considerado <- renderText({
    p <- periodo()

    paste0(
      "Período considerado: ", p$ano_inicio, " a ", p$ano_fim,
      " (", p$dias_afastado, " dias de afastamento)."
    )
  })

  # Artigos lidos do HTML enviado
  artigos <- reactive({
    req(input$lattes)

    # Se o arquivo não for um currículo válido, mostra um aviso
    # em vez de travar o app.
    tryCatch(
      ler_artigos_lattes(input$lattes$datapath),
      error = function(e) {
        validate(paste(
          "Não foi possível ler o currículo. Envie o .zip ou .xml",
          "baixado do Lattes, ou o HTML salvo do navegador."
        ))
      }
    )
  })
  
  # Percentil de cada artigo no período escolhido
  percentis <- reactive({
    percentil_artigos(
      con,
      artigos(),
      ano_inicio = periodo()$ano_inicio,
      ano_fim = periodo()$ano_fim
    )
  })
  
  pontos <- reactive({
    calcular_pontuacao(percentis())
  })
  
  # Mostra na aba Dados do docente quantos artigos foram lidos
  # (ou o aviso de erro, se a leitura falhou)
  output$leitura_lattes <- renderText({
    if (nrow(artigos()) == 0) {
      return(paste(
        "Nenhum artigo encontrado. Confira se o arquivo enviado",
        "é mesmo o currículo Lattes."
      ))
    }

    paste(nrow(artigos()), "artigos encontrados no currículo.")
  })

  output$aviso_artigos <- renderText({
    if (is.null(input$lattes)) {
      return("Envie o currículo na aba Dados do docente.")
    }
    
    paste0(
      nrow(artigos()), " artigos no currículo, ",
      nrow(percentis()), " no período de avaliação (",
      periodo()$ano_inicio, " a ", periodo()$ano_fim, ")."
    )
  })
  
  output$artigos <- renderTable({
    percentis() |>
      select(
        Ano = ano,
        Revista = revista,
        Artigo = titulo,
        ISSN = issn,
        Percentil = percentil,
        Situação = situacao
      )
  }, digits = 3)
  
  output$resultado <- renderText({
    if (is.null(input$lattes)) {
      return("A avaliação ainda não foi realizada.")
    }
    
    p <- pontos()
    
    paste0(
      "Pontuação: ", format(round(p$pontuacao, 3), decimal.mark = ","),
      " (mínimo ", format(p$minimo, decimal.mark = ","), ") - ",
      ifelse(p$atinge, "Atinge o mínimo", "Não atinge o mínimo")
    )
  })
  
  output$melhores <- renderTable({
    pontos()$melhores |>
      select(
        Posição = posicao,
        Ano = ano,
        Revista = revista,
        Artigo = titulo,
        Percentil = percentil
      )
  }, digits = 3)
  
}

shinyApp(ui = ui, server = server)
