# Simulador PPGE

Simulador de credenciamento docente do PPGE. O docente envia o currículo
Lattes em XML, informa o período de avaliação e os afastamentos, e o app
calcula a pontuação dos artigos a partir do SJR (SCImago Journal Rank).

Feito em R (Shiny) com um banco SQLite. As contas são feitas em SQL.

## Regras

1. A nota de cada artigo é o **maior percentil da revista entre 2022 e 2025**.
   O percentil é a parte das revistas da mesma área com SJR menor ou igual ao
   da revista. Se a revista está em mais de uma área, vale o maior.
2. Contam os artigos do período de avaliação. Os dias de afastamento são
   somados (dia repetido conta uma vez) e o início do período volta esse total.
3. Não pontuam: nota abaixo de 0,25, revista fora do SCImago e artigo sem ISSN.
4. A soma dos **4 melhores artigos** precisa ser **1,25 ou mais**.

## Arquivos

```
criar_banco.R    PASSO 1: monta o banco a partir dos CSVs (rodar uma vez)
funcoes.R        Funções: ler o Lattes e calcular as notas
app.R            PASSO 2: o app (botão Run App)
relatorio.Rmd    Modelo do relatório em PDF
publicar.R       PASSO 3: publicar no shinyapps.io
dados/brutos/    Planilhas do SCImago (2022 a 2025)
dados/exemplo/   Currículo fictício para testar
```

## Banco de dados (`dados/simulador.sqlite`)

| Tabela      | O que tem                                         |
|-------------|---------------------------------------------------|
| `percentis` | Revista, ano, área, SJR e percentil na área       |
| `revistas`  | Nome da revista e a nota (maior percentil)        |
| `issn`      | ISSN de cada revista                              |

Os dados do docente ficam em tabelas temporárias, que somem quando o app fecha.

O banco não vai para o GitHub. Para criar, rode o `criar_banco.R` (menos de
1 minuto).

### Ano novo do SCImago

1. Coloque o CSV novo em `dados/brutos/` (ex.: `scimagojr 2026.csv`).
2. No topo do `criar_banco.R`, mude a linha `anos <- 2022:2025`.
3. Rode o `criar_banco.R` uma vez.

## Como rodar

1. Instale os pacotes:

   ```r
   install.packages(c("shiny", "DBI", "RSQLite", "xml2", "ggplot2",
                      "rmarkdown", "knitr", "rsconnect", "tinytex"))
   tinytex::install_tinytex()  # para gerar o PDF
   ```

2. Rode o `criar_banco.R`.
3. Crie o arquivo `.Renviron` na pasta do projeto com a linha
   `SIMULADOR_SENHA=a_senha_escolhida` (ele não vai para o GitHub).
4. Abra o `app.R` e clique em **Run App**. Para testar, use
   `dados/exemplo/curriculo_ficticio.xml`.

## Privacidade

- O app aceita só o XML do Lattes, que só o próprio docente consegue baixar
  ([guia da UFJF](https://www2.ufjf.br/propp/2024/11/13/como-gerar-o-arquivo-xml-do-curriculo-lattes/)).
- O currículo é usado só enquanto o app está aberto e depois é apagado.
- O PDF é gerado só no download e não fica guardado.

## Publicar no shinyapps.io

Na primeira vez, crie a conta em <https://www.shinyapps.io>, vá em
**Account > Tokens > Show secret** e rode no console o comando
`rsconnect::setAccountInfo(...)` (não cole em nenhum arquivo). Depois rode o
`publicar.R`.
