
library(shiny)

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
        end = Sys.Date()
      ),
      
      h3("Afastamentos"),
      
      checkboxInput(
        "licenca",
        "Possuiu licença ou afastamento?",
        FALSE
      ),
      
      conditionalPanel(
        condition = "input.licenca == true",
        
        dateInput("inicio_afastamento", "Início do afastamento:"),
        
        dateInput("fim_afastamento", "Fim do afastamento:")
      ),
      
      h3("Currículo Lattes"),
      
      fileInput(
        "lattes",
        "Enviar currículo Lattes",
        accept = c(".html", ".htm")
      ),
      
      p("O formato definitivo do arquivo será confirmado
        posteriormente.")
    )
  ),
  
  # 3. PRODUÇÃO CIENTÍFICA
  tabPanel(
    "Produção científica",
    
    fluidPage(
      h2("Produção científica"),
      
      p("Aqui serão apresentados os artigos identificados
        no currículo Lattes."),
      
      p("A extração automática será implementada posteriormente."),
      
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
      
      p("O resultado será calculado após a integração
        da produção científica e dos dados SJR."),
      
      textOutput("resultado")
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
  
  # Exemplo provisório de artigos
  output$artigos <- renderTable({
    
    data.frame(
      Artigo = c(
        "Artigo demonstrativo 1",
        "Artigo demonstrativo 2"
      ),
      
      Revista = c(
        "Revista fictícia A",
        "Revista fictícia B"
      ),
      
      Ano = c(2024, 2023),
      
      Percentil = c(0.75, 0.50)
    )
    
  })
  
  output$resultado <- renderText({
    
    "A avaliação ainda não foi realizada."
    
  })
  
}

shinyApp(ui = ui, server = server)
