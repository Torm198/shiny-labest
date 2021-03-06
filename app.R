require(shiny)
require(leaflet)
require(shinydashboard)
require(tidyverse)
require(fresh)
require(readxl)
require(DT)

meu_tema <- create_theme(
    adminlte_color(
        red = "#C4C4C4",
        light_blue = "#03719C"
    ),
    adminlte_sidebar(
        dark_bg = "#343837"
    )
)



#######################carregamento dos modelos########################### 

modelo_aluguel_asa_norte <- readRDS('modelos aluguel/Asa Norte.rds')
modelo_aluguel_asa_sul <- readRDS('modelos aluguel/Asa Sul.rds')
modelo_aluguel_lago_sul <- readRDS('modelos aluguel/Lago Sul.rds')

modelo_venda_apt <- readRDS('modelos venda/modapt.gz')
modelo_venda_casa <- readRDS('modelos venda/modcasa.gz')





############# funcao de apoio ###################


def_bairro <- function(bairro,imovel){
    if_else(imovel=='casa',
            if_else(bairro=='lago',
                    'Lago Sul',
                    'Plano'
            ),
            if_else(bairro=='norte',
                    'Asa Norte',
                    'Asa Sul'))
}






#####################carregamento do banco#####################




# banco do wi imoveis
bairros <- c("Asa Norte","Asa Sul","Lago Sul")
opcoes <- c('Aluguel',"Venda")

analise <- readRDS('bancos tratados/banco_shiny.RDS') %>% mutate(ID=1:n())


# banco da uniao

uniao_aprovado <- readRDS('bancos tratados/uniao_aprovado.RDS')
uniao_edital <- readRDS('bancos tratados/uniao_edital.RDS')
uniao_processo <- readRDS('bancos tratados/uniao_processo.RDS')

processo <- read_excel("uniao.xlsx",sheet="processo")
aprovado <- read_excel("uniao.xlsx",sheet="aprovados")
edital <- read_excel("uniao.xlsx",sheet="edital")
############# Header do dashboard #####################
title <- tags$a(href='https://www.google.com',
                icon("building"),
                'Imóveis União')




##################Menu lateral######################

menu_lateral <- dashboardSidebar(
    sidebarMenu(
        id = "tabs",
        menuItem('Localização', tabName = 'exp'),
        menuItem('Estimação', tabName = 'est'),
        menuItem('Imóveis da União',tabName = 'uniao')
    ),
    
    
    # exploratoria
    conditionalPanel(
        "input.tabs == 'exp'",
        selectInput('bairro', 'Escolha o bairro', choices = bairros)

        
        
    ),
    
    
    
    # estimacao
    conditionalPanel(
        condition = "input.tabs == 'est'",
        selectInput(
            "local",
            "Localização",
            choices = list(
                "Asa Norte" = "norte",
                "Asa Sul" = "sul",
                "Lago Sul" = "lago"
            ),
            selected = "norte"
        ),
        radioButtons('imovel', 'Tipo de imóvel', choices = list('Casa'= 'casa','Apartamento'='apt')),
        numericInput("m2", "Metragem", value = 50, min = 0)
        
    ),
    
    # asa norte
    conditionalPanel(
        condition = "input.tabs == 'est'",
        sliderInput(
            "vaga",
            "Número de Vagas",
            min = 0,
            max = 10,
            step = 1,
            value = 0
        )
    ),
    
    # asa sul
    conditionalPanel(
        condition = "input.tabs == 'est'",
        numericInput("quarto", "Número de Quartos", value =
                         2, min = 0),
        numericInput(
            "condo",
            "Valor do Condomínio R$",
            value = 100,
            min = 0
        )
    ),
    
    # lago sul
    conditionalPanel(
        condition = "input.tabs == 'est'",
        numericInput("ban", "Número de Banheiros", value =
                         2, min = 0)
        
    ),
    
    # uniao
    conditionalPanel(
        condition = "input.tabs == 'uniao' ",
        radioButtons(
            'status',
            'Status:',
            choices = c('Em processo', 'Aprovado', 'Edital')
        ),
        radioButtons(
            'reforma',
            'Preço de reforma:',
            choices = c("R$420/m²","R$550/m²","R$650/m²")
        )
    )
    
)




################# corpo do dashboard ########################
corpo <- dashboardBody(
    tags$body(tags$style(HTML('.content-wrapper {
                                  background-image: url(https://images.unsplash.com/photo-1464938050520-ef2270bb8ce8?ixlib=rb-1.2.1&ixid=MXwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHw%3D&auto=format&fit=crop&w=1506&q=80);
                                  z-index: 800;
                            
                              }
                                  '))),
    tags$body(tags$style(HTML('table {
                                background-color: #d2d6de;
                            
                              }
                                  '))),
    tags$body(tags$style(HTML('a {
                                 color: #f4f4f4;
                                }
                                  '))),
    use_theme(meu_tema),
    tags$head(tags$style(HTML('.main-header .logo{
                                  font-family: "Georgia",Times,"Times New Roman", serif;
                                  font-weight:bold;
                                  font-size:20px;
                                  }
                                  '))),
    tabItems(
        
        #exploratoria
        tabItem('exp',
                fillPage(
                    # box(plotlyOutput('precos_aluguel')),
                    # box(plotlyOutput('precos_venda')),
                    # box(plotlyOutput('metragem')),
                    tags$style(type = "text/css", "#map {height: calc(100vh - 80px) !important;}"),
                    leafletOutput('mapa',height="85vh")
                )),
        
        
        #estimacao
        tabItem('est',
                fluidRow(
                    infoBoxOutput('estima_aluguel',width=6),
                    infoBoxOutput('estima_venda',width=6),
                    infoBoxOutput('compara',width=6),
                    infoBoxOutput('metroq',width=6),
                    infoBoxOutput('caprate',width=6)
                )),
        
        #uniao
        tabItem('uniao',
                dataTableOutput('tabela'))
    ))







####################### back end ######################################
server <- function(input, output) {
    
    #exploratoria
    
    banco_filtro <- reactive({
        filter(analise,bairro==input$bairro)
    })
    
    # output$precos_venda <- renderPlotly({
    #     plot_ly(data = banco_filtro(),x=~Venda,type = 'histogram',bingroup=1) %>%
    #         layout(title= 'Distribuição dos preços',
    #                xaxis=list(title='Valor de Venda em Reais' ),
    #                bargap=0.1
    #         )
    # })
    # 
    # output$precos_aluguel <- renderPlotly({
    #     plot_ly(data = banco_filtro(),x=~Aluguel,type = 'histogram',bingroup=1) %>%
    #         layout(title= 'Distribuição dos preços',
    #                xaxis=list(title='Valor de Aluguel em Reais' ),
    #                bargap=0.1
    #         )
    # })
    # 
    
    #grafico para distribuicao de metragem
    # output$metragem <- renderPlotly({
    #     plot_ly(data = banco_filtro(),x=~area_util_m2,type = 'histogram',bingroup=1) %>%
    #         layout(title= 'Distribuição de metragem',
    #                xaxis=list(title='Área Útil em metros quadrados'),
    #                bargap=0.1)
    #     
    # })
    
    ########gerar o mapa#############
    output$mapa <-  renderLeaflet({
        suppressWarnings({leaflet(banco_filtro()) %>%
                addTiles() %>%
                addMarkers(lng = ~longitude,
                           lat = ~latitude,
                           popup = ~paste('R$',Venda,'com',area_util_m2,'metros quadrados, com',quartos,'quartos, R$',condominio,' de condomínio,',vagas,'vagas')
                           ) %>%
                setView( -47.9292,-15.7801,10)})
    })
    
    
    
    #estimacao
    
    
    
    # valores estimados
    data_est <- reactive({
        
        
        
        # todos os inputs relevantes para estimacao entram nesse data.frame
        banco_predicao <- data.frame(`Area Util`=input$m2,
                                     Condominio=input$condo,
                                     Vagas=as.numeric(input$vaga>=1),
                                     Quartos=input$quarto,
                                     Banheiros=input$ban,
                                     area_util_m2=input$m2,
                                     vagas=input$vaga,
                                     quartos=input$quarto,
                                     banheiros=input$ban,
                                     bairro=def_bairro(input$local,input$imovel),
                                     check.names = F
        )
        
        
        #estimacao do valor do aluguel
        valor_aluguel <- switch(input$local, 
                                norte = round((0.3*predict.lm(modelo_aluguel_asa_norte,newdata=banco_predicao)+1)^(1/0.3),2),
                                
                                sul = round(exp(predict.lm(modelo_aluguel_asa_sul,newdata=banco_predicao)),2),
                                
                                lago = round(predict.lm(modelo_aluguel_lago_sul,newdata=banco_predicao),2)
        )
        #estimacao do valor de venda
        valor_venda <- switch(input$imovel,
                              apt = round((-0.05*predict.lm(modelo_venda_apt,newdata=banco_predicao)+1)^(1/-0.05),2),
                              casa = round(exp(predict.lm(modelo_venda_casa,newdata=banco_predicao)),2)
        )
        
        
        return(c(valor_aluguel,valor_venda))
    })
    
    
    data_diff <- reactive({abs(data_est()[1]-input$alug)})
    
    
    
    
    
    
    output$estima_aluguel <- renderValueBox({
        valueBox(tags$p("Aluguel Estimado",style="font-size: 60%;",style="color:#343837;"),
                 tags$p(
                     paste('R$',suppressWarnings({format(data_est()[1],decimal.mark = ',',big.mark = '.')})),
                     style="font-size: 150%;",style="color:#343837;"
                 ),
                 icon = icon("coins"),
                 color = "red"
                 
                 
                 
        )})
    
    output$estima_venda <- renderValueBox({
        valueBox(tags$p("Venda Estimado",style="font-size: 60%;",style="color:#343837;"),
                 tags$p(
                     paste('R$',suppressWarnings({format(data_est()[2],decimal.mark = ',',big.mark = '.')})),
                     style="font-size: 150%;",style="color:#343837;"
                 ),
                 icon = icon("money-bill"),
                 color = "red"
                 
                 
                 
        )})
    
    
    
    output$compara <- renderValueBox({
        valueBox(tags$p("Valor da Venda/m²",style="font-size: 60%;",style="color:#343837;"),
                 
                 tags$p(
                     paste('R$',suppressWarnings({format(round(data_est()[2]/input$m2,2),decimal.mark = ',',big.mark = '.')}),'/M²'),
                     style="font-size: 150%;",style="color:#343837;"
                 ),
                 icon = icon("comments-dollar"),
                 color = "red"
                 
                 
                 
        )})
    
    
    
    output$metroq <- renderValueBox({
        valueBox(tags$p("Valor do Aluguel/m²",style="font-size: 60%;",style="color:#343837;"),
                 tags$p(
                     paste('R$',suppressWarnings({format(round(data_est()[1]/input$m2,2),decimal.mark = ',',big.mark = '.')}),'/M²'),
                     style="font-size: 150%;",style="color:#343837;"
                 ),
                 icon = icon("comment-dollar"),
                 color = "red"
                 
                 
                 
        )})
    
    
    output$caprate <- renderValueBox({
        valueBox(tags$p("Cap Rate",style="font-size: 60%;",style="color:#343837;"),
                 tags$p(
                     paste(suppressWarnings({format(round(data_est()[1]*100/data_est()[2],2),decimal.mark = ',',big.mark = '.')}),'% por mês'),
                     style="font-size: 150%;",
                     style="color:#343837;"
                 ),
                 icon = icon("percentage"),
                 color = "red"
                 
                 
                 
        )})
    
    ###uniao#########
    
    uniao_filtro <- reactive(
        if(input$status == "Em processo"){
            if(input$reforma == "R$420/m²"){
                uniao_processo$`Preço Sugerido` <- uniao_processo$`Preço Estimado` - processo$ref1
                uniao_processo$`Cap Rate` <- paste(round((uniao_processo$`Aluguel Estimado`/uniao_processo$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_processo[,-c(4,5)]
            } else if (input$reforma == "R$550/m²"){
                uniao_processo$`Preço Sugerido` <- uniao_processo$`Preço Estimado` - processo$ref2
                uniao_processo$`Cap Rate` <- paste(round((uniao_processo$`Aluguel Estimado`/uniao_processo$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_processo[,-c(3,5)]
            } else {
                uniao_processo$`Preço Sugerido` <- uniao_processo$`Preço Estimado` - processo$ref3
                uniao_processo$`Cap Rate` <- paste(round((uniao_processo$`Aluguel Estimado`/uniao_processo$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_processo[,-c(3,4)]
            }
        } else if (input$status == "Aprovado"){
            if(input$reforma == "R$420/m²"){
                uniao_aprovado$`Preço Sugerido` <- uniao_aprovado$`Preço Estimado` - aprovado$ref1
                uniao_aprovado$`Cap Rate` <- paste(round((uniao_aprovado$`Aluguel Estimado`/uniao_aprovado$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_aprovado[,-c(4,5)]
            } else if (input$reforma == "R$550/m²"){
                uniao_aprovado$`Preço Sugerido` <- uniao_aprovado$`Preço Estimado` - aprovado$ref2
                uniao_aprovado$`Cap Rate` <- paste(round((uniao_aprovado$`Aluguel Estimado`/uniao_aprovado$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_aprovado[,-c(3,5)]
            } else {
                uniao_aprovado$`Preço Sugerido` <- uniao_aprovado$`Preço Estimado` - aprovado$ref3
                uniao_aprovado$`Cap Rate` <- paste(round((uniao_aprovado$`Aluguel Estimado`/uniao_aprovado$`Preço Sugerido`)*100,2),"%",sep="")
                uniao_aprovado[,-c(3,4)]
            }
        } else {
            if (input$reforma == "R$420/m²"){
                sugerido <- uniao_edital$`Preço Estimado` - edital$ref1
                diferenca <- sugerido - edital$precouniao
                uniao_edital$`Preço Sugerido` <- sugerido
                uniao_edital$`Comparação (R$)` <- diferenca
                uniao_edital$`Comparação (%)` <- paste(round((diferenca/sugerido)*100,1),"%",sep="")
                uniao_edital$`Cap Rate` <- paste(round((as.numeric(uniao_edital$`Aluguel Estimado`)/edital$precouniao)*100,2),"%",sep="")
                uniao_edital[,-c(4,5)]
            } else if (input$reforma == "R$550/m²"){
                sugerido <- uniao_edital$`Preço Estimado` - edital$ref2
                diferenca <- sugerido - edital$precouniao
                uniao_edital$`Preço Sugerido` <- sugerido
                uniao_edital$`Comparação (R$)` <- diferenca
                uniao_edital$`Comparação (%)` <- paste(round((diferenca/sugerido)*100,1),"%",sep="")
                uniao_edital$`Cap Rate` <- paste(round((as.numeric(uniao_edital$`Aluguel Estimado`)/edital$precouniao)*100,2),"%",sep="")
                uniao_edital[,-c(3,5)]
            } else {
                sugerido <- uniao_edital$`Preço Estimado` - edital$ref3
                diferenca <- sugerido - edital$precouniao
                uniao_edital$`Preço Sugerido` <- sugerido
                uniao_edital$`Comparação (R$)` <- diferenca
                uniao_edital$`Comparação (%)` <- paste(round((diferenca/sugerido)*100,1),"%",sep="")
                uniao_edital$`Cap Rate` <- paste(round((as.numeric(uniao_edital$`Aluguel Estimado`)/edital$precouniao)*100,2),"%",sep="")
                uniao_edital[,-c(3,4)]
            }
        }
    )
    
    
    output$tabela <- renderDataTable(uniao_filtro(),option = list(pageLength=50, scrollY='780px'))
    
    
    
    
    
}


######### rodar o shiny ###############
ui <- dashboardPage(
    dashboardHeader(title = title),
    sidebar=menu_lateral,
    body=corpo)
shinyApp(ui = ui, server = server)

