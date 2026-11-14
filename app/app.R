library(shiny)
library(here) # Acha a pasta do projeto, de onde quer que o app rode.

# Funções de leitura do Lattes e de pontuação
source(here("R", "funcoes_simulador.R"))

arquivo_banco <- here("dados/limpos", "simulador_ppge.sqlite")

# Listas das caixas de busca da aba Simulação. Ficam fora do
# server para serem montadas UMA vez, quando o app liga, e não
# a cada pessoa que abre o app (a de revistas leva ~1,5 s).
con_inicio <- dbConnect(SQLite(), arquivo_banco)
revistas <- listar_revistas(con_inicio)
categorias_scimago <- listar_categorias(con_inicio)
dbDisconnect(con_inicio)

opcoes_revistas <- setNames(revistas$Sourceid, revistas$rotulo)

# ============================================================
# SENHA DE ACESSO
# ============================================================

# A senha NÃO fica escrita no código (o repositório está no
# GitHub). Ela fica no arquivo .Renviron, na pasta do projeto,
# que está no .gitignore. O arquivo tem uma linha:
#   SIMULADOR_SENHA=a_senha_escolhida
#
# Se a senha já estiver definida (por exemplo, configurada no
# painel do servidor), ela vale e o .Renviron não é lido.
if (!nzchar(Sys.getenv("SIMULADOR_SENHA")) && file.exists(here(".Renviron"))) {
  readRenviron(here(".Renviron"))
}
senha_correta <- Sys.getenv("SIMULADOR_SENHA")

# Tela que aparece antes do simulador
ui_login <- fluidPage(
  div(
    style = "max-width: 380px; margin: 12vh auto 0;",

    h2("Simulador PPGE"),

    p("Acesso restrito aos docentes do programa. Digite a senha
      fornecida pela secretaria do PPGE."),

    passwordInput("senha", "Senha:", width = "100%"),

    actionButton("entrar", "Entrar", class = "btn-primary"),

    br(), br(),

    textOutput("erro_login"),

    # Enter no campo de senha também entra
    tags$script(HTML(
      "$(document).on('keyup', '#senha', function(e) {
         if (e.key === 'Enter') $('#entrar').click();
       });"
    ))
  )
)

# A página mostra a tela de login ou o simulador, conforme a
# pessoa já tenha digitado a senha certa (decidido no server)
ui <- fluidPage(
  title = "Simulador PPGE",
  style = "padding: 0;",
  uiOutput("pagina")
)

ui_simulador <- navbarPage(
  
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
      
      p("1. Informe seus dados e envie seu currículo Lattes em XML."),
      p("2. Confira os artigos identificados pelo sistema."),
      p("3. Consulte os critérios de credenciamento."),
      p("4. Visualize sua pontuação e o resultado."),
      
      h3("Privacidade dos seus dados"),

      tags$ul(
        tags$li("O currículo enviado é usado apenas para fazer o
          cálculo, enquanto você está com o simulador aberto."),
        tags$li("Nenhum dado do docente fica guardado: ao fechar o
          simulador, o currículo e os resultados são apagados do
          servidor."),
        tags$li("O relatório em PDF é gerado só no momento do download
          e é de uso único e exclusivo do próprio docente.")
      ),

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
        "Enviar currículo Lattes em XML",
        accept = c(".zip", ".xml"),
        buttonLabel = "Escolher arquivo",
        placeholder = "Nenhum arquivo escolhido"
      ),

      p("O simulador aceita apenas o currículo Lattes em XML.
        Só o próprio docente consegue baixar o seu currículo nesse
        formato, entrando na Plataforma Lattes com o seu login. Assim,
        ninguém consegue simular o currículo de outra pessoa."),

      tags$ul(
        tags$li("Na Plataforma Lattes, o currículo em XML é baixado
          como um arquivo .zip. Pode enviar o .zip direto, ou o .xml
          que está dentro dele."),
        tags$li(
          "Não sabe como baixar? Veja o ",
          tags$a(
            "guia passo a passo para gerar o XML do Lattes",
            href = "https://www2.ufjf.br/propp/2024/11/13/como-gerar-o-arquivo-xml-do-curriculo-lattes/",
            target = "_blank",
            rel = "noopener"
          ),
          " (Pró-Reitoria de Pós-Graduação e Pesquisa da UFJF)."
        )
      ),

      textOutput("leitura_lattes"),

      p(em("O currículo é usado só para o cálculo e é apagado
        quando você fecha o simulador. Nenhum dado fica guardado."))
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

      p("Cada artigo vale o percentil da revista no ano em que
        o artigo foi publicado, calculado a partir do SJR
        (SCImago Journal Rank)."),

      p("O percentil é a fração das revistas da mesma área com SJR
        menor ou igual ao da revista. Quando a revista está em mais
        de uma área, vale o maior percentil."),

      h4("Artigos que não pontuam"),

      tags$ul(
        tags$li("Percentil abaixo de 0,25."),
        tags$li("Revista que não está no SCImago."),
        tags$li("Artigo sem ISSN no currículo."),
        tags$li("Artigo publicado em ano que ainda não tem SCImago
          (por exemplo, 2026).")
      ),

      h4("Período de avaliação e afastamentos"),

      p("Contam os artigos publicados no período de avaliação.
        O tempo de afastamento é somado e o início do período
        recua por esse total."),

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

      tabsetPanel(

        # 6a. Artigos hipotéticos
        tabPanel(
          "Simular novos artigos",

          br(),

          p("Escolha uma revista e o ano de publicação para ver como
            um novo artigo mudaria a sua pontuação. Os artigos do
            currículo enviado também entram na conta."),

          p(em("Para anos que ainda não têm SCImago, o percentil é
            estimado pelo ano mais recente da revista.")),

          fluidRow(
            column(
              6,
              selectizeInput(
                "sim_revista",
                "Revista:",
                choices = NULL,
                options = list(placeholder = "Digite o nome ou o ISSN")
              )
            ),
            column(
              3,
              numericInput(
                "sim_ano",
                "Ano de publicação:",
                value = as.integer(format(Sys.Date(), "%Y")),
                min = 2015,
                max = 2035,
                step = 1
              )
            ),
            column(
              3,
              br(),
              actionButton("sim_adicionar", "Adicionar artigo"),
              actionButton("sim_limpar", "Limpar")
            )
          ),

          h4("Artigos hipotéticos"),
          tableOutput("sim_hipoteticos"),

          h3(textOutput("sim_comparacao")),

          h4("Os 4 melhores artigos com a simulação"),
          tableOutput("sim_melhores")
        ),

        # 6b. Histórico de uma área
        tabPanel(
          "Histórico por área",

          br(),

          p("Percentil das revistas de uma área em cada ano,
            calculado só dentro da área escolhida. Selecione
            revistas na tabela para comparar no gráfico."),

          selectizeInput(
            "hist_area",
            "Área:",
            choices = NULL,
            width = "100%",
            options = list(placeholder = "Digite o nome da área")
          ),

          plotOutput("hist_area_grafico", height = "350px"),

          DT::DTOutput("hist_area_tabela")
        )
      )
    )
  ),
  
  # 7. RELATÓRIO
  tabPanel(
    "Relatório",
    
    fluidPage(
      h2("Relatório personalizado"),

      p("Baixe um relatório em PDF com o período de avaliação,
        os artigos considerados, a pontuação e o resultado."),

      p(em("O relatório é de uso único e exclusivo do próprio
        docente. Ele é gerado só no momento do download e não fica
        guardado no servidor.")),

      h4(textOutput("resumo_relatorio")),

      br(),

      # Só aparece depois que o currículo é enviado
      uiOutput("botao_relatorio")
    )
  )

  # A aba Administração foi retirada por enquanto. Se voltar a
  # ser necessária (por exemplo, para atualizar o SCImago), entra
  # aqui como "8. ADMINISTRAÇÃO".
)

server <- function(input, output, session) {
  
  # Uma conexão com o banco para cada pessoa usando o app.
  # Ela fecha sozinha quando a pessoa sai.
  con <- dbConnect(SQLite(), arquivo_banco)

  # Quando a pessoa sai do app: fecha a conexão (a tabela
  # temporária com os artigos some junto) e apaga o currículo
  # enviado. Nenhum dado do docente fica guardado no servidor.
  session$onSessionEnded(function() {
    dbDisconnect(con)
    curriculo <- isolate(input$lattes$datapath)
    if (!is.null(curriculo)) unlink(curriculo)
  })

  # ---------- LOGIN ----------

  # TRUE depois que a pessoa digita a senha certa. Vale só para
  # esta sessão: ao fechar ou recarregar a página, pede de novo.
  logado <- reactiveVal(FALSE)
  tentativas <- reactiveVal(0)

  output$pagina <- renderUI({
    if (logado()) ui_simulador else ui_login
  })

  observeEvent(input$entrar, {
    if (!nzchar(senha_correta)) {
      output$erro_login <- renderText(
        "A senha do simulador não foi configurada. Avise a secretaria do PPGE."
      )
      return()
    }

    if (tentativas() >= 5) {
      output$erro_login <- renderText(
        "Muitas tentativas erradas. Recarregue a página e tente de novo."
      )
      return()
    }

    if (identical(input$senha, senha_correta)) {
      logado(TRUE)
    } else {
      tentativas(tentativas() + 1)
      # Espera 1 segundo a cada erro, para dificultar quem tenta
      # adivinhar a senha testando muitas combinações
      Sys.sleep(1)
      output$erro_login <- renderText("Senha incorreta.")
    }
  })

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

      # NA deixa o campo vazio; o Shiny avisa no console que não
      # conseguiu converter NA em data, por isso o suppressWarnings
      suppressWarnings(dateRangeInput(
        id,
        paste0("Afastamento ", i, ":"),
        start = if (is.null(anterior)) NA else anterior[1],
        end = if (is.null(anterior)) NA else anterior[2],
        format = "dd/mm/yyyy",
        separator = "até",
        language = "pt-BR"
      ))
    })
  })

  # Lista de afastamentos preenchidos (um par de datas cada).
  # Os incompletos ficam de fora.
  afastamentos <- reactive({
    lapply(
      seq_len(n_afastamentos()),
      function(i) input[[paste0("afastamento_", i)]]
    ) |>
      Filter(f = function(a) length(a) == 2 && !anyNA(a))
  })

  # Período de avaliação já recuado pelos afastamentos
  periodo <- reactive({
    calcular_periodo(input$periodo, afastamentos())
  })

  output$periodo_considerado <- renderText({
    p <- periodo()

    paste0(
      "Período considerado: ", p$ano_inicio, " a ", p$ano_fim,
      " (", p$dias_afastado, " dias de afastamento)."
    )
  })

  # Artigos lidos do XML enviado
  artigos <- reactive({
    # Sem login, nenhum cálculo é feito (proteção também no
    # server, não só na tela)
    req(logado(), input$lattes)

    # Se o arquivo não for o XML do Lattes, mostra o motivo em
    # vez de travar o app (a mensagem vem de ler_artigos_lattes)
    tryCatch(
      ler_artigos_lattes(input$lattes$datapath),
      error = function(e) {
        validate(conditionMessage(e))
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
  
  # Frase do resultado, usada nas abas Resultado e Relatório
  texto_resultado <- reactive({
    p <- pontos()

    paste0(
      "Pontuação: ", format(round(p$pontuacao, 3), decimal.mark = ","),
      " (mínimo ", format(p$minimo, decimal.mark = ","), ") - ",
      ifelse(p$atinge, "Atinge o mínimo", "Não atinge o mínimo")
    )
  })

  output$resultado <- renderText({
    if (is.null(input$lattes)) {
      return("A avaliação ainda não foi realizada.")
    }

    texto_resultado()
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

  # ---------- SIMULAÇÃO ----------

  # Preenche as caixas de busca com as listas montadas no início
  # do arquivo. server = TRUE: o navegador só recebe as revistas
  # que combinam com o que foi digitado (são mais de 50 mil).
  # selected = character(0) deixa a caixa vazia no início.
  # Isso só pode ser feito depois do login, quando as caixas
  # passam a existir na tela. O onFlushed espera a tela do
  # simulador ser desenhada no navegador antes de preencher.
  observeEvent(logado(), {
    req(logado())
    session$onFlushed(function() {
      updateSelectizeInput(session, "sim_revista",
                           choices = opcoes_revistas, selected = character(0),
                           server = TRUE)
      updateSelectizeInput(session, "hist_area",
                           choices = categorias_scimago, selected = character(0),
                           server = TRUE)
    }, once = TRUE)
  })

  # Artigos hipotéticos adicionados pelo docente
  hipoteticos <- reactiveVal(
    data.frame(ano = integer(), revista = character(),
               percentil = numeric(), observacao = character())
  )

  observeEvent(input$sim_adicionar, {
    req(logado(), input$sim_revista, input$sim_ano)

    sourceid <- as.numeric(input$sim_revista)
    ano <- as.integer(input$sim_ano)
    p <- percentil_hipotetico(con, sourceid, ano)

    observacao <- if (is.na(p$percentil)) {
      "Revista sem SCImago neste ano"
    } else if (p$estimado) {
      paste("Estimado pelo SCImago", p$ano_usado)
    } else {
      paste("SCImago", p$ano_usado)
    }

    nova <- data.frame(
      ano = ano,
      revista = revistas$rotulo[revistas$Sourceid == sourceid][1],
      percentil = p$percentil,
      observacao = observacao
    )

    hipoteticos(rbind(hipoteticos(), nova))
  })

  observeEvent(input$sim_limpar, {
    hipoteticos(hipoteticos()[0, ])
  })

  output$sim_hipoteticos <- renderTable({
    validate(need(nrow(hipoteticos()) > 0,
                  "Nenhum artigo hipotético adicionado ainda."))

    hipoteticos() |>
      select(Ano = ano, Revista = revista, Percentil = percentil,
             Observação = observacao)
  }, digits = 3)

  # Pontuação com os artigos hipotéticos. Sem currículo enviado,
  # conta só os hipotéticos.
  simulacao <- reactive({
    reais <- if (is.null(input$lattes)) NULL else percentis()
    simular_pontuacao(reais, hipoteticos())
  })

  output$sim_comparacao <- renderText({
    req(nrow(hipoteticos()) > 0)

    atual <- if (is.null(input$lattes)) 0 else pontos()$pontuacao
    s <- simulacao()
    fmt <- function(x) format(round(x, 3), nsmall = 3, decimal.mark = ",")

    paste0(
      "Pontuação atual: ", fmt(atual),
      "  ->  com a simulação: ", fmt(s$pontuacao),
      " (", ifelse(s$atinge, "atinge", "não atinge"), " o mínimo de 1,25)"
    )
  })

  output$sim_melhores <- renderTable({
    req(nrow(hipoteticos()) > 0)

    simulacao()$melhores |>
      select(Posição = posicao, Ano = ano, Revista = revista,
             Artigo = titulo, Percentil = percentil)
  }, digits = 3)

  # Histórico de uma área
  hist_area <- reactive({
    req(logado(), input$hist_area)
    historico_categoria(con, input$hist_area)
  })

  # Tabela larga: uma linha por revista, uma coluna por ano.
  # Ordenada pelo percentil do ano mais recente.
  hist_area_larga <- reactive({
    dados <- hist_area()
    ultimo <- max(dados$ano)

    dados |>
      group_by(Sourceid) |>
      mutate(revista = revista[which.max(ano)]) |>
      ungroup() |>
      select(Sourceid, revista, ano, percentil) |>
      mutate(percentil = round(percentil, 3)) |>
      tidyr::pivot_wider(names_from = ano, values_from = percentil,
                         names_sort = TRUE) |>
      arrange(desc(.data[[as.character(ultimo)]]))
  })

  output$hist_area_tabela <- DT::renderDT({
    DT::datatable(
      select(hist_area_larga(), -Sourceid),
      rownames = FALSE,
      colnames = c("Revista" = "revista"),
      selection = list(mode = "multiple", selected = 1:3),
      options = list(pageLength = 10, scrollX = TRUE,
                     language = list(
                       search = "Buscar:",
                       lengthMenu = "Mostrar _MENU_ revistas",
                       info = "Revistas _START_ a _END_ de _TOTAL_",
                       infoEmpty = "Nenhuma revista",
                       infoFiltered = "(filtradas de _MAX_)",
                       zeroRecords = "Nenhuma revista encontrada",
                       paginate = list(previous = "Anterior", `next` = "Próxima")
                     ))
    )
  })

  output$hist_area_grafico <- renderPlot({
    linhas <- input$hist_area_tabela_rows_selected
    validate(need(length(linhas) > 0,
                  "Selecione revistas na tabela para ver no gráfico."))

    escolhidas <- hist_area_larga()$Sourceid[linhas]

    dados <- hist_area() |>
      filter(Sourceid %in% escolhidas) |>
      group_by(Sourceid) |>
      mutate(revista = revista[which.max(ano)]) |>
      ungroup()

    ggplot2::ggplot(dados, ggplot2::aes(ano, percentil, colour = revista)) +
      ggplot2::geom_hline(yintercept = 0.25, linetype = "dashed",
                          colour = "grey50") +
      ggplot2::geom_line(linewidth = 1) +
      ggplot2::geom_point(size = 2.5) +
      ggplot2::scale_x_continuous(breaks = sort(unique(hist_area()$ano))) +
      ggplot2::scale_y_continuous(limits = c(0, 1),
                                  breaks = seq(0, 1, 0.25)) +
      ggplot2::labs(title = input$hist_area, x = "Ano", y = "Percentil",
                    colour = NULL) +
      ggplot2::theme_minimal(base_size = 14) +
      ggplot2::theme(legend.position = "bottom",
                     legend.direction = "vertical")
  })

  # ---------- RELATÓRIO ----------

  output$resumo_relatorio <- renderText({
    if (is.null(input$lattes)) {
      return("Envie o currículo na aba Dados do docente para gerar o relatório.")
    }

    texto_resultado()
  })

  output$botao_relatorio <- renderUI({
    req(input$lattes)
    downloadButton("baixar_relatorio", "Baixar relatório (PDF)")
  })

  output$baixar_relatorio <- downloadHandler(

    filename = function() {
      nome <- if (isTruthy(input$nome)) input$nome else "docente"
      # Nome do arquivo sem acentos e espaços
      nome <- iconv(nome, to = "ASCII//TRANSLIT")
      nome <- gsub("[^A-Za-z0-9]+", "_", nome)
      paste0("relatorio_", nome, "_", format(Sys.Date(), "%Y%m%d"), ".pdf")
    },

    content = function(file) {
      req(logado())
      # O mesmo resultado mostrado nas outras abas
      avaliacao <- list(
        artigos = artigos(),
        periodo = periodo(),
        percentis = percentis(),
        melhores = pontos()$melhores,
        pontuacao = pontos()$pontuacao,
        minimo = pontos()$minimo,
        atinge = pontos()$atinge
      )

      # O PDF é montado numa pasta temporária, para dois docentes
      # baixando ao mesmo tempo não se atrapalharem
      pasta <- tempfile("relatorio_")
      dir.create(pasta)
      # Depois do download, apaga a pasta com o PDF e os arquivos
      # do LaTeX: o relatório fica só com o docente
      on.exit(unlink(pasta, recursive = TRUE), add = TRUE)
      modelo <- file.path(pasta, "relatorio_docente.Rmd")
      file.copy(here("relatorio", "relatorio_docente.Rmd"), modelo)

      id <- showNotification(
        "Gerando o relatório...",
        duration = NULL,
        closeButton = FALSE
      )
      on.exit(removeNotification(id), add = TRUE)

      tryCatch(
        {
          # O PDF é gerado dentro da pasta temporária (onde também
          # ficam os arquivos do LaTeX) e depois copiado para o download
          pdf <- rmarkdown::render(
            modelo,
            output_dir = pasta,
            intermediates_dir = pasta,
            envir = new.env(),
            quiet = TRUE,
            params = list(
              nome = if (isTruthy(input$nome)) input$nome else "",
              area = if (isTruthy(input$area)) input$area else "",
              periodo = input$periodo,
              afastamentos = afastamentos(),
              avaliacao = avaliacao
            )
          )

          file.copy(pdf, file, overwrite = TRUE)
        },

        # Se o PDF não puder ser gerado, mostra o motivo na tela e
        # no console, em vez de o navegador baixar uma página de erro
        error = function(e) {
          # Erros do LaTeX ficam no arquivo .log, nas linhas com "!"
          logs <- list.files(pasta, pattern = "[.]log$", full.names = TRUE)
          erros_latex <- unlist(lapply(logs, function(l) {
            grep("^!", readLines(l, warn = FALSE), value = TRUE)
          }))

          motivo <- paste(c(conditionMessage(e), head(erros_latex, 3)), collapse = "\n")

          message("Erro ao gerar o relatório:\n", motivo)

          showNotification(
            paste("Não foi possível gerar o PDF:", motivo),
            type = "error",
            duration = NULL
          )

          stop(e)
        }
      )
    }
  )

}

shinyApp(ui = ui, server = server)
