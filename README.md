# Simulador PPGE

Simulador de credenciamento docente do PPGE. O docente envia o currículo
Lattes em XML, informa o período de avaliação e os afastamentos, e o app
calcula a pontuação dos artigos a partir do SJR (SCImago Journal Rank),
mostra se atinge o mínimo para credenciamento e gera um relatório em PDF.

Feito em R, com Shiny e SQLite.

## Regras de pontuação

- Cada artigo vale o **percentil da revista no ano em que foi publicado**.
  O percentil é a fração das revistas da mesma área (categoria do SCImago)
  com SJR menor ou igual ao da revista. Se a revista está em mais de uma
  área, vale o maior percentil.
- **Não pontuam:** artigos com percentil abaixo de 0,25, de revistas fora do
  SCImago, sem ISSN no currículo ou de anos que ainda não têm SCImago
  (por exemplo, 2026).
- Contam os artigos publicados no **período de avaliação**. Os dias de
  afastamento são somados (sem contar duas vezes dias sobrepostos) e o
  início do período recua por esse total.
- A soma dos **4 melhores artigos** precisa ser igual ou maior que **1,25**.

> Os critérios definitivos ainda serão ajustados conforme as regras oficiais
> do programa.

## O app

O app tem as abas:

1. **Início** – como funciona e privacidade dos dados.
2. **Dados do docente** – nome, área, período de avaliação, afastamentos e
   envio do currículo Lattes.
3. **Produção científica** – artigos encontrados no período, com o percentil
   de cada um.
4. **Critérios** – as regras acima.
5. **Resultado** – pontuação e os artigos que entram na conta.
6. **Simulação** – simula novos artigos (revista + ano) e mostra o histórico
   de percentil de uma revista ou de uma área.
7. **Relatório** – baixa o relatório em PDF.

### Currículo Lattes só em XML

O app aceita **apenas o XML do Lattes** (o `.zip` baixado do Lattes ou o
`.xml` de dentro dele). O HTML da página pública é recusado. Como só o próprio
dono consegue baixar o XML, ninguém consegue simular o currículo de outra
pessoa. Passo a passo para gerar o arquivo:
[guia da UFJF](https://www2.ufjf.br/propp/2024/11/13/como-gerar-o-arquivo-xml-do-curriculo-lattes/).

### Senha de acesso

O app pede uma senha antes de abrir. Ela **não** fica no código: fica no
arquivo `.Renviron`, na pasta do projeto, que está no `.gitignore`. O arquivo
tem uma linha:

```
SIMULADOR_SENHA=a_senha_escolhida
```

Cada computador ou servidor tem o seu `.Renviron`.

### Privacidade

- O currículo é usado só para o cálculo, enquanto o app está aberto.
- Os artigos vão para uma tabela temporária do banco, que some quando a
  pessoa fecha o app; o arquivo enviado também é apagado.
- O PDF é gerado só no momento do download e não fica guardado no servidor.

## Estrutura do projeto

```
app.R                        Entrada do app para o shinyapps.io (aponta para app/app.R)
app/app.R                    O app Shiny
R/funcoes_simulador.R        Funções usadas pelo app, pelo 05 e pelo 06
R/01_limpeza.R               Limpa os CSVs do SCImago (2015–2025)
R/02_banco_dados.R           Cria o banco SQLite com os dados limpos
R/03_percentis.R             Calcula o percentil de cada revista por área e ano
R/04_issn.R                  Cria a tabela ISSN -> revista
R/05_lattes.R                Testa a leitura de um currículo Lattes
R/06_pontuacao.Rmd           Calcula a pontuação de um docente (relatório HTML)
R/07_banco_app.R             Cria o banco menor, só com o que o app usa
R/08_publicar.R              Publica o app no shinyapps.io
relatorio/relatorio_docente.Rmd   Modelo do relatório em PDF
dados/brutos/                CSVs originais do SCImago
dados/limpos/                CSVs limpos e bancos SQLite
dados/exemplo/               Currículo fictício para testes
```

## Como rodar

### 1. Pacotes

No RStudio, abra o `Simulador_PPGE.Rproj` e instale os pacotes:

```r
install.packages(c(
  "shiny", "here", "DBI", "RSQLite", "dplyr", "tidyr", "stringr",
  "readr", "purrr", "xml2", "DT", "ggplot2", "rmarkdown", "knitr",
  "rsconnect", "tinytex"
))
tinytex::install_tinytex()  # LaTeX para gerar o PDF do relatório
```

### 2. Criar o banco de dados

O banco (`dados/limpos/*.sqlite`) passa de 100 MB e por isso **não está no
GitHub**. Para recriá-lo, rode os scripts em ordem:

1. `R/01_limpeza.R`
2. `R/02_banco_dados.R`
3. `R/03_percentis.R`
4. `R/04_issn.R`
5. `R/07_banco_app.R` (banco menor para o app; feche o app antes de rodar)

Rode de novo do 01 ao 04 e o 07 sempre que entrar um ano novo do SCImago
(o CSV novo vai em `dados/brutos/`).

### 3. Senha

Crie o arquivo `.Renviron` na pasta do projeto com a linha
`SIMULADOR_SENHA=...` (veja [Senha de acesso](#senha-de-acesso)).

### 4. Abrir o app

Abra `app/app.R` e clique em **Run App**. Para testar sem um currículo
real, use `dados/exemplo/curriculo_ficticio.xml`.

O `R/06_pontuacao.Rmd` faz o mesmo cálculo fora do app: mude os `params`
no topo (arquivo, período e afastamentos) e clique em **Knit**.

## Publicar no shinyapps.io

Na primeira vez:

1. Crie uma conta em <https://www.shinyapps.io>.
2. No site, vá em **Account > Tokens > Show > Show secret**, copie o comando
   `rsconnect::setAccountInfo(...)` e rode no console do RStudio.
   **Não** cole esse comando em nenhum arquivo do projeto: ele tem a sua
   chave secreta.

Depois, rode o `R/08_publicar.R` (Source). Ele confere se a conta, o banco
do app e o `.Renviron` estão prontos e envia só os arquivos que o app
precisa. O endereço fica `https://SEU-USUARIO.shinyapps.io/simulador-ppge/`.
