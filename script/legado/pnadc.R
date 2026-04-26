


# Ambiente ----------------------------------------------------------------

options(encoding = "latin1")
options(scipen = 999)

#Pacotes usados

if (!require("librarian")) install.packages("librarian")

librarian::shelf(arrow,
                 tidyverse,
                 PNADcIBGE,
                 haven,
                 here,
                 survey,
                 srvyr,
                 data.table,
                 glue,
                 rio,
                 readxl,
                 writexl,
                 openxlsx,
                 janitor,
                 spatstat,
                 geobr,
                 sf,
                 pander,
                 treemapify,
                 scales,
                 RColorBrewer)

if (!require("radiant")) install.packages("radiant")

#Limpando o ambiente antes de rodar o codigo

rm(ls())

gc()

# Variaveis de interesse --------------------------------------------------

vars <- list(
 id = c("Ano","Trimestre","Capital", "UPA", "Estrato", "V1008", "V1014", "V1028") 
,genero = c("V2007")
,cor = c("V2010")
,ocupacao = c("V4010","VD4009","VD4002","VD4012","V4032", "VD4002")
,escolaridade = c("VD3004","VD3005")
,idade = c("V2009")
,regiao = c("V1022","RM_RIDE","UF")
,atividade = c("V4013"),
renda = c("VD4016", "Habitual"))

vars_vec <- unname(unlist(vars))

anos <- c(2012,2016,2019,2022)

trimestres <- c(4)

## PNADc -------------------------------------------------------------------

if ("base_pnadc.parquet" %in% list.files(here("dados","dados_original"))) {
  
  base_pnadc <- read_parquet(here("dados","dados_original", "base_pnadc.parquet"))
  
} else {
  
  lista_pnadc <- map2(anos, trimestres, function(x,y) get_pnadc(year = x, quarter = y, vars = vars_vec, design = F, deflator = T))
  
  base_pnadc <- bind_rows(lista_pnadc)
  
  rm(lista_pnadc)
  
  base_pnadc <- base_pnadc %>% select((vars_vec))
  
  write_parquet(base_pnadc, sink = here("dados","dados_original", "base_pnadc.parquet"))
  
  gc()
}

base_pnadc <- base_pnadc %>% group_by(Ano)




#abrindo pnadc de interesse

arrow::

# Inclusões de variáveis necessárias --------------------------------------

## Setor (CNAE 2.0) -----------------------------------------------

setor_df <- read_xlsx(path = here("dados","dados_original", "Harmonizacao.xlsx"), col_names = T)

setor_df <- setor_df %>% select(-3:-4)

base_pnadc <- left_join(base_pnadc, setor_df)


## Região Geográfica ----------------------------------------------

uf_regiao <- read_xlsx(here("dados","dados_original", "uf_regiao.xlsx"), col_names = T)

base_pnadc <- left_join(base_pnadc, uf_regiao)

base_pnadc <- base_pnadc %>% relocate(regiao, .after = UF)


## Formalidade na ocupacao -------------------------------


base_pnadc <- base_pnadc %>% 
  mutate(formalidade = ifelse((!is.na(V4013) & V4032 == "Sim") | str_detect(VD4009, "Militar") | str_detect(VD4009,"com carteira"),
                              "Formal",
                              ifelse(!is.na(V4013) & V4032 == "Não",
                                     case_when(str_detect(VD4009, "sem carteira") == T ~ "Informal - Sem carteira",
                                               str_detect(VD4009, "Empregador") == T ~ "Informal - Empregador",
                                               str_detect(VD4009, "Conta-própria") == T ~ "Informal - Conta-própria",
                                               .default = "Informal"),
                                     NA)),
         formalidade = ifelse(is.na(formalidade) & !is.na(V4013) & (is.na(V4032) | is.na(VD4009)),
                              "Ocupado sem informação",
                              formalidade))

base_pnadc <- base_pnadc %>% 
  mutate(formalidade = ifelse((!is.na(V4013) & V4032 == "Sim") | str_detect(VD4009, "Militar") | str_detect(VD4009,"com carteira"),
                              "Formal",
                              formalidade))

base_pnadc <- base_pnadc %>% 
  mutate(formalidade = ifelse((!is.na(V4013) & str_detect(VD4009, "familiar auxiliar")),
                              "Ocupado sem informação",
                              formalidade))

base_pnadc <- base_pnadc %>% relocate(formalidade, .after = V4032)


## Redefinindo variavel de cor ---------------------------------------------

base_pnadc <- base_pnadc %>% 
  mutate(V2010 = ifelse(V2010 %in% c("Branca", "Amarela"), "Brancos e Amarelos",
                              ifelse(V2010 %in% c("Preta", "Parda", "Indígena"),
                                     "Pretos, Pardos e Indígenas",
                                     "Ignorado")))


## Definição de região metropolitana ------------------

base_pnadc <- base_pnadc %>% 
  mutate(regiao_metrop = case_when(str_detect(RM_RIDE, "Região") == T ~ "Sim",
                                   TRUE ~ "Não"))





## Class Verde Atividade (Verde, Limpa, Suja) -----------

#Vai rodar o script que gera a tabela com classifiações verdes das atividades e setores
#ATENÇÂO: É necessário uma conta no google cloud e autenticação. Utilizamos o google cloud para pegar a base da rais.

#Pra escolher qual classificação usar, tem que entrar no script abaixo

source("script/gerando_class_verde.R")

if (c("cnaedom_nome") %in% colnames(base_pnadc)) {
  
  base_pnadc <- base_pnadc %>% select(-c(cnaedom_nome, class_verde_atividade, setor_cnae20_cod, setor_cnae20_nome, class_verde_setor))
  
} else glimpse(base_pnadc)  


base_pnadc <- base_pnadc %>% left_join(.,cnae_verde, by = c("V4013" = "cnaedom_cod"))


## Class Verde Ocupação (Verde, Não-Verde) -----------

tab_caruso <- import(here("dados","dados_original","cbodom_classverde_caruso.xlsx"), 
                     col_types = c("text","text")) %>% 
  clean_names()

base_pnadc <- base_pnadc %>% left_join(.,tab_caruso, by = c("V4010" = "cod_ocupacao"))

rm(tab_caruso)


## Renda habitual deflacionada e medidas de renda ------------------

base_pnadc <- base_pnadc %>% 
  mutate(renda_hab_def = VD4016*Habitual) %>% 
  mutate(renda_percentil = cut(renda_hab_def, 
                               breaks = weighted.quantile(renda_hab_def, w = V1028, probs = seq(0, 1, by = 0.25), na.rm = TRUE),
                               labels = c("Q1", "Q2", "Q3", "Q4"),
                               include.lowest = T)) %>% 
  group_by(Ano, class_verde_atividade) %>% #NOTE que to usando as classificações das atividades, não dos setores (pensar melhor nisso)
  mutate(renda_log_var = as.vector(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)),
         renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>% 
  ungroup()

# Tabelas - Estatistica Descritiva ----------------------------------------

vars_tabela <- list(
    genero = c("V2007"),
    cor = c("V2010"),
    ocupacao = "formalidade",
    escolaridade_classif = c("VD3004"),
    escolaridade_anos = c("VD3005"),
    idade = c("V2009"),
    regiao_urbano_rural = "V1022",
    regiao_metrop = "regiao_metrop",
    regiao_uf = "UF",
    regiao = "regiao",
    renda_log_dev = c("renda_log_dev"),
    renda_percentil = c("renda_percentil"),
    renda_log_var = c("renda_log_var"),
    renda_media = c("renda_media")
      )  

vars_tabela_vec <- unlist(unname(vars_tabela))
   
#Gerando as tabelas para as atividades da cnaedom


## Por classificação -------------------------------------------------------

tabelas_class <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      } else if (i == "UF") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V"))) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup()
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>%
                          filter(!is.na(formalidade))
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      }
                      
                      else if (i == "renda_media") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          filter(!is.na(formalidade)) %>% 
                          summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>%
                          #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      }
                      
                      else {
                        base_pnadc %>% group_by(Ano, class_verde_atividade, !!sym(i)) %>%
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "O", "L", "V")))
                      }
                    })

names(tabelas_class) <- names(vars_tabela)

## Por atividade -------------------------------------------------------

tabelas_ativ <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% filter(!is.na(V4013)) %>%  group_by(Ano, V4013) %>%
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev)
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) 
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>% 
                          pivot_wider(names_from = Ano, values_from = renda_log_var)  
                      } else if (i == "UF") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, !!sym(i), V4013) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup()
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, !!sym(i), V4013) %>%
                          filter(!is.na(formalidade)) %>% 
                        summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) 
                          #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                      }
                      
                      else if (i == "renda_media") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013) %>%
                          filter(!is.na(formalidade)) %>% 
                        summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>%  
                       pivot_wider(names_from = Ano, values_from = renda_media)
                      }
                      
                      else {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013, !!sym(i)) %>%
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) 
                          #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                      }
                    })

names(tabelas_ativ) <- names(vars_tabela)
   
## Por setor -------------------------------------------------------

tabelas_setor <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>%  group_by(Ano, setor_cnae20_cod) %>%
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev)
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, setor_cnae20_cod) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) 
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, setor_cnae20_cod) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>% 
                          pivot_wider(names_from = Ano, values_from = renda_log_var)  
                      } else if (i == "UF") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, !!sym(i), setor_cnae20_cod) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup()
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, !!sym(i), setor_cnae20_cod) %>%
                          filter(!is.na(formalidade)) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) 
                        #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                      }
                      
                      else if (i == "renda_media") {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, setor_cnae20_cod) %>%
                          filter(!is.na(formalidade)) %>% 
                          summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>%  
                          pivot_wider(names_from = Ano, values_from = renda_media)
                      }
                      
                      else {
                        base_pnadc %>% filter(!is.na(setor_cnae20_cod)) %>% group_by(Ano, setor_cnae20_cod, !!sym(i)) %>%
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) 
                        #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                      }
                    })

names(tabelas_setor) <- names(vars_tabela)

#Gerando as tabelas para os setores da cnae20
 
#tabelas_setor <-  map(vars_tabela_vec,
#                   function(i) {
#                     base_pnadc %>% group_by(Ano, class_verde_setor, !!sym(i)) %>%
#                       summarise(n = sum(V1028)) %>%
#                       mutate(freq = (n/sum(n))*100) %>%
#                       pivot_wider(names_from = i, values_from = c(n, freq)) 
#                   })
#names(tabelas_setor) <- names(vars_tabela)
#
#write.xlsx(tabelas_setor, 
#           file = "produtos/tabelas/tabelas_setor.xlsx", 
#           keepNA = T,
#           overwrite = T,
#           colWidths = "auto",
#           digits = 2)
#
#

# Gráficos ----------------------------------------------------------------

anos_graf <- c(head(anos, n = 1),tail(anos, n = 1))

## Renda ------------------------------------------------------


### Boxplots agrupados ------------------------------------------------------

ggplot(tabelas_ativ[["renda_percentil"]] %>%
         ungroup() %>% 
         filter(Ano %in% anos_graf), aes(x = class_verde_atividade, y = Q2, fill = class_verde_atividade)) +
  geom_boxplot(aes(ymin = Min, lower = Q1, middle = Q2, upper = Q3, ymax = Max), stat = "identity") +
  facet_wrap(~Ano) +
  ylim(0,13) +
  theme_minimal() +
  theme(legend.position = "none") +
  scale_fill_manual(values = c("chocolate", "yellow", "lightblue", "darkgreen")) +
  labs(x = "Classificação das atividades", y = "Renda", title = paste0("Boxplot Log Renda por Classificação Verde (",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))
  ggsave(paste0("produtos/gráficos/renda_percentil", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  

### Renda Média ------------------------------------------------------
  
ggplot(data = base_pnadc %>% 
         select(V1028,class_verde_atividade,Ano, renda_hab_def) %>%
         filter(!is.na(class_verde_atividade)) %>% 
         group_by(Ano,class_verde_atividade) %>% 
         summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>% 
         group_by(class_verde_atividade) %>% 
         mutate(rotulo = ifelse(Ano %in% c(2012,2022),renda_media,NA))) +
aes(x = Ano, y = renda_media, group = class_verde_atividade, colour = class_verde_atividade) +
geom_line(linewidth = 0.8) +
geom_point()+
geom_label(aes(label= round(rotulo)), size=2.5, fill = "white", color = "black")+
scale_color_manual(values = c("V" = "darkgreen", "L" = "lightblue", "S" = "chocolate")) +
theme_minimal() +
labs(title = "Renda média por ano e classificação",
     x = "Ano",
     y = "Renda média",
     color = "Classificação")
ggsave(paste0("produtos/gráficos/renda_media_class", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

### Histograma da Renda ------------------------------------------------------

ggplot(data = base_pnadc %>% 
         select(V1028,class_verde_atividade,Ano, renda_hab_def) %>%
         filter(!is.na(class_verde_atividade),
                Ano %in% anos_graf),
       aes(x = renda_hab_def,
           fill = class_verde_atividade),
           weight = V1028) +
  geom_histogram(binwidth = 5000, color = "black", alpha = 0.7) +
  facet_wrap(~Ano) +
  labs(title = paste0("Histograma Logarítmico da Renda (",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"),
       x = "Renda",
       y = "Frequência",
       fill = "Classificação") +
  facet_wrap(~ factor(class_verde_atividade, levels = c("S", "L", "V")), ncol = 1)+
  scale_fill_manual(values = c("V" = "darkgreen", "L" = "lightblue", "S" = "chocolate")) +
  scale_y_log10(labels = label_number()) +
  scale_x_continuous(limits = c(0,250000))+
  theme_minimal()
  ggsave(paste0("produtos/gráficos/hist_renda", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Mapas -------------------------------------------------------------------
  
### Mapa dos estados +- sujos --------------------------------------------------

limite <- c(
  tabelas_ativ[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "S") %>% select(freq) %>% min(),
  tabelas_ativ[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "S") %>% select(freq) %>% max())  
  
ggplot() +
  geom_sf(data=tabelas_ativ[["regiao_uf"]] %>% 
            ungroup()  %>% 
            filter(Ano %in% anos_graf, class_verde_atividade == "S") %>%
            mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
            left_join(.,geobr::read_state(year = 2019) %>% 
                        select(name_state) %>% 
                        mutate(name_state = make_clean_names(name_state))) %>% 
            st_as_sf(), 
          aes(fill=freq), color= NA, size=.15) +
    facet_grid(~Ano) +
    labs(subtitle=paste0("Proporção de Empregos Sujos por UF", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
  scale_fill_distiller(palette = "YlOrRd", name="",direction = 1, limits = limite) +
  theme_void() 
  
  ggsave(paste0("produtos/gráficos/mapa_empregos_sujos",".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  


### Mapa dos estados +- limpos --------------------------------------------------

  limite <- c(
    tabelas_ativ[["regiao_uf"]] %>% 
      ungroup()  %>% 
      filter(Ano %in% anos_graf, class_verde_atividade == "L") %>% select(freq) %>% min(),
    tabelas_ativ[["regiao_uf"]] %>% 
      ungroup()  %>% 
      filter(Ano %in% anos_graf, class_verde_atividade == "L") %>% select(freq) %>% max())   
  
  ggplot() +
    geom_sf(data=tabelas_ativ[["regiao_uf"]] %>% 
              ungroup()  %>% 
              filter(Ano %in% anos_graf, class_verde_atividade == "L") %>%
              mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
              left_join(geobr::read_state(year = 2019) %>% 
                          select(name_state) %>% 
                          mutate(name_state = make_clean_names(name_state)),.) %>% 
              st_as_sf(), 
            aes(fill=freq), color= NA, size=.15) +
    facet_wrap(~Ano) +
    labs(subtitle=paste0("Proporção de Empregos Limpos por UF", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
    scale_fill_distiller(palette = "Blues", name="",direction = 1, limits = limite) +
    theme_void()
  ggsave(paste0("produtos/gráficos/mapa_empregos_limpos", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  


### Mapa dos estados +- verdes --------------------------------------------------

  limite <- c(
    tabelas_ativ[["regiao_uf"]] %>% 
      ungroup()  %>% 
      filter(Ano %in% anos_graf, class_verde_atividade == "V") %>% select(freq) %>% min(),
    tabelas_ativ[["regiao_uf"]] %>% 
      ungroup()  %>% 
      filter(Ano %in% anos_graf, class_verde_atividade == "V") %>% select(freq) %>% max())   
  
  ggplot() +
    geom_sf(data=tabelas_ativ[["regiao_uf"]] %>% 
              ungroup()  %>% 
              filter(Ano %in% anos_graf, class_verde_atividade == "V") %>%
              mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
              left_join(geobr::read_state(year = 2019) %>% 
                          select(name_state) %>% 
                          mutate(name_state = make_clean_names(name_state)),.) %>% 
              st_as_sf(), 
            aes(fill=freq), color= NA, size=.15) +
    facet_wrap(~Ano) +
    labs(subtitle=paste0("Proporção de Empregos Verdes por UF", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
    scale_fill_distiller(palette = "Greens", name="",direction = 1, limits = limite) +
    theme_void()
  ggsave(paste0("produtos/gráficos/mapa_empregos_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  

rm(limite)


## Ocupados -----------------------------------------------------------------

### Evolução da qtd de ocupados por tipo de classificação -------------------

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "V") %>% 
         select(!class_verde_atividade) %>% 
         ungroup()) +
  aes(x = Ano, y = n, group = 1)+
  geom_point(color = "darkgreen")+
  geom_line(color = "darkgreen")+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados em ocupações verdes")
  ggsave(paste0("produtos/gráficos/qtd_ocupados_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "L") %>% 
         select(!class_verde_atividade) %>% 
         ungroup()) +
  aes(x = Ano, y = n, group = 1)+
  geom_point(color = "lightblue")+
  geom_line(color = "lightblue")+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados em ocupações limpas")
  ggsave(paste0("produtos/gráficos/qtd_ocupados_limpas", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  
ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "S") %>% 
         select(!class_verde_atividade) %>% 
         ungroup()) +
  aes(x = Ano, y = n, group = 1)+
  geom_point(color = "chocolate")+
  geom_line(color = "chocolate")+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados em ocupações sujas")
ggsave(paste0("produtos/gráficos/qtd_ocupados_sujas", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

### Evolução da qtd de ocupados em cada classif ---------------------------------

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)),
       aes(x = Ano, y = n, color = class_verde_atividade, group = class_verde_atividade))+
  geom_line(linewidth = 1)+
  geom_point(size = 2)+
scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  scale_color_manual(name = "Classificação Verde",values = c("S" = "chocolate", "L" = "lightblue", "V" = "darkgreen"))+
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados por classificação")
ggsave(paste0("produtos/gráficos/qtd_ocupados_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



### Evolução da proporção de ocupados em cada classif ---------------------------------

#Acho que o ideal seria usar a VD4002, mas vamos usar os NAs da VD4009 como proxy para desocupados

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         mutate(freq = (n/sum(n))*100) %>% 
         ungroup())  +
  aes(x = Ano, y = freq, fill = class_verde_atividade, group = class_verde_atividade) + 
  geom_bar(position = "stack",  stat="identity", color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  theme_minimal() +
  labs(x = "Ano", y = "Prop.", title = "Proporção de ocupados segundo a classificação")+
  scale_fill_manual(name = "Classificação Verde",values = c("V" = "darkgreen", "L" = "lightblue", "O" = "yellow2", "S" = "chocolate"))
ggsave(paste0("produtos/gráficos/prop_ocupados_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(Ano %in% anos_graf,
                !is.na(formalidade)) %>% 
         mutate(freq = n/sum(n)*100)) +
  aes(x = class_verde_atividade, y = freq, fill = formalidade, group = formalidade) +
  geom_col(width = 0.5, color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~Ano) +
  labs(x = "Classificação verde", y = "Percentual (%)", label = "teste", title = paste0("Proporção de ocupados segundo a formalidade da ocupação ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))
ggsave(paste0("produtos/gráficos/prop_formalidade_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



## Arvore de ocupações ---------------------------------

ggplot(base_pnadc %>% 
          select(cnaedom_nome,formalidade,Ano,V1028, class_verde_atividade, setor_cnae20_nome) %>% 
          filter(!is.na(formalidade),
                 class_verde_atividade == "S",
                 Ano == 2022) %>% 
          group_by(setor_cnae20_nome, cnaedom_nome) %>% 
          summarise(qtd = round(sum(V1028))) %>% 
          mutate(rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
         geom_treemap()+ 
  labs(caption = paste("Total: ",base_pnadc %>% 
                         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
                         filter(!is.na(formalidade),
                                class_verde_atividade == "S",
                                Ano == 2022) %>%
                         summarise(qtd = round(sum(V1028)))))+
  theme(legend.position = "none",
        plot.caption = element_text(size = 25, hjust = 0))+
  geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                    grow = F, reflow = T)+
  geom_treemap_subgroup_border()
ggsave(paste0("produtos/gráficos/arvore_ocup_sujas", ".png"), plot = last_plot(), bg = "white",dpi = 800, width = 12, height = 8)

ggplot(base_pnadc %>% 
         select(cnaedom_nome,formalidade,Ano,V1028, class_verde_atividade, setor_cnae20_nome) %>% 
         filter(!is.na(formalidade),
                class_verde_atividade == "L",
                Ano == 2022) %>% 
         group_by(setor_cnae20_nome, cnaedom_nome) %>% 
         summarise(qtd = round(sum(V1028))) %>% 
         mutate(rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
  geom_treemap()+ 
  labs(caption = paste("Total: ",base_pnadc %>% 
                         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
                         filter(!is.na(formalidade),
                                class_verde_atividade == "L",
                                Ano == 2022) %>%
                         summarise(qtd = round(sum(V1028)))))+
  theme(legend.position = "none",
        plot.caption = element_text(size = 25, hjust = 0))+
  scale_color_manual(palette = "Blues")+
  geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                    grow = F, reflow = T)+
  geom_treemap_subgroup_border()
ggsave(paste0("produtos/gráficos/arvore_ocup_limpas", ".png"), plot = last_plot(), bg = "white",dpi = 800, width = 12, height = 8)

ggplot(base_pnadc %>% 
         select(cnaedom_nome,formalidade,Ano,V1028, class_verde_atividade, setor_cnae20_nome) %>% 
         filter(!is.na(formalidade),
                class_verde_atividade == "V",
                Ano == 2022) %>% 
         group_by(setor_cnae20_nome, cnaedom_nome) %>% 
         summarise(qtd = round(sum(V1028))) %>% 
         mutate(rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
  geom_treemap()+
  labs(caption = paste("Total: ",base_pnadc %>% 
         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
         filter(!is.na(formalidade),
                class_verde_atividade == "V",
                Ano == 2022) %>%
         summarise(qtd = round(sum(V1028)))))+
  theme(legend.position = "none",
        plot.caption = element_text(size = 25, hjust = 0))+
  scale_color_manual(palette = "Blues")+
  geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                    grow = F, reflow = T)+
  geom_treemap_subgroup_border()
ggsave(paste0("produtos/gráficos/arvore_ocup_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 800, width = 12, height = 8)


## Formalidade -------------------------------------------------------------

ggplot(data = tabelas_ativ[["ocupacao"]] %>% 
         filter(Ano %in% anos_graf,
                !is.na(formalidade)) %>% 
         mutate(freq = n/sum(n)*100)) +
  aes(x = class_verde_atividade, y = freq, fill = formalidade, group = formalidade) +
    geom_col(width = 0.5, color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~Ano) +
  labs(x = "Classificação verde", y = "Percentual (%)", label = "teste", title = paste0("Proporção de ocupados segundo a formalidade da ocupação ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))
  ggsave(paste0("produtos/gráficos/prop_formalidade_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Cor ---------------------------------------------------------------------

  ggplot(data = tabelas_ativ[["cor"]] %>%
           filter(Ano %in% anos_graf,
                  V2010 != "Ignorado"))+
    aes(x = class_verde_atividade, y = freq, fill = V2010, group = V2010) +
    geom_col(width = 0.5, color = "black")+
    geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
    facet_wrap(~Ano) +
    labs(x = "Classificação verde", y = "Quantidade", title = paste0("Proporção de ocupados segundo cor tipo de classificação ", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"))
  ggsave(paste0("produtos/gráficos/prop_cor_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Escolaridade ------------------------------------------------------------

  ggplot(data = base_pnadc %>%
           select(Ano,V1028,class_verde_atividade, VD3004) %>% 
           filter(Ano %in% anos_graf,
                  !is.na(class_verde_atividade)) %>% 
           mutate(VD3004 = case_when(
             VD3004 == "Sem instrução e menos de 1 ano de estudo" | VD3004 == "Fundamental incompleto ou equivalente" ~ "Fundamental Incompleto",
             VD3004 == "Fundamental completo ou equivalente" | VD3004 == "Médio incompleto ou equivalente" ~ "Fundamental Completo",
             VD3004 == "Médio completo ou equivalente" | VD3004 == "Superior incompleto ou equivalente" ~ "Médio Completo",
             TRUE ~ "Superior Completo")) %>%
           mutate(VD3004 = factor(VD3004, 
                         levels = c("Fundamental Incompleto", "Fundamental Completo","Médio Completo", "Superior Completo"))) %>% 
             group_by(Ano,class_verde_atividade,VD3004) %>% 
             summarise(qtd = sum(V1028)) %>% 
             mutate(freq = qtd/sum(qtd)*100)
         )+
    aes(x = class_verde_atividade, y = freq, fill = VD3004, group = VD3004) +
    geom_col(width = 0.5, color = "black")+
    geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
    facet_wrap(~Ano) +
    labs(x = "Classificação verde", y = "Percentual (%)", title = paste0("Proporção de ocupados segundo escolaridade ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))
  ggsave(paste0("produtos/gráficos/prop_esc_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



ggplot(data = tabelas_ativ[["escolaridade_anos"]] %>%
           mutate(VD3005 = str_sub(VD3005,1,2)) %>% 
           mutate(VD3005 = ifelse(VD3005 == "Se", 0, VD3005)) %>% 
           mutate(VD3005 = as.integer(VD3005)) %>%
           group_by(Ano, class_verde_atividade) %>% 
           summarise(ano_medio_escolaridade = weighted.mean(VD3005, n)) %>% 
         ungroup() %>% 
         mutate(Classificação = case_when(
           class_verde_atividade == "V" ~ "darkgreen",
           class_verde_atividade == "L" ~ "lightblue",
           class_verde_atividade == "S" ~ "chocolate")) %>% 
       group_by(class_verde_atividade) %>% 
         mutate(rotulo = ifelse(Ano %in% c(2012,2022),ano_medio_escolaridade,NA))) +
  aes(x = Ano, y = ano_medio_escolaridade, group = Classificação, color = Classificação) + 
  geom_point(size = 2)+
  geom_line(linewidth = 1)+
  geom_label(aes(label= round(rotulo)), size=2.5, fill = "white", color = "black")+
  theme_minimal()+
  labs(x = "Ano", y = "Escolaridade Média", title = "Escolaridade média dos ocupados segundo tipo da classificação")+
  scale_color_identity(labels = c(darkgreen = "V", lightblue = "L", chocolate = "S"), guide = "legend")
ggsave(paste0("produtos/gráficos/escolaridade_media_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Região Metrop ---------------------------------

ggplot(data = tabelas_ativ[["regiao_metrop"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "fill",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  
  facet_grid(~regiao_metrop)+
  labs(x = "Ano", y = "Quantidade", title = "Proporção de ocupados segundo região metropolitana")+
  scale_fill_manual(name = "Classificação Verde",values = c("V" = "darkgreen", "L" = "lightblue", "O" = "yellow2", "S" = "chocolate"))
ggsave(paste0("produtos/gráficos/prop_regiao_metrop_barra", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


ggplot(data = tabelas_ativ[["regiao_metrop"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "dodge",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  
  facet_grid(~regiao_metrop)+
  labs(x = "Ano", y = "Quantidade", title = "Quantidade de ocupados segundo região metropolitana")+
  scale_fill_manual(name = "Classificação Verde",values = c("V" = "darkgreen", "L" = "lightblue", "O" = "yellow2", "S" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_regiao_metrop_barra_lado", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Urbano Rural ---------------------------------

ggplot(data = tabelas_ativ[["regiao_urbano_rural"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_col(colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  facet_grid(~V1022, labeller = label_bquote(paste0("teste",.(regiao_metrop))))+
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade", title = "Quantidade de ocupados segundo tipo da região (urbano x rural)")+
  scale_fill_manual(name = "Classificação Verde",values = c("V" = "darkgreen", "L" = "lightblue", "O" = "yellow2", "S" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_regiao_urbano_rural_empilhado", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



ggplot(data = tabelas_ativ[["regiao_urbano_rural"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "dodge",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  facet_grid(~V1022)+
  labs(x = "Ano", y = "Quantidade", title = "Quantidade de ocupados segundo tipo da região (urbano x rural)")+
  scale_fill_manual(name = "Classificação Verde",values = c("V" = "darkgreen", "L" = "lightblue", "O" = "yellow2", "S" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_urbano_rural_barra", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Idade ---------------------------------

ggplot(data = tabelas_ativ[["idade"]] %>% 
         summarise(idade_media = weighted.mean(V2009, n)) %>%
         ungroup() %>% 
         mutate(Classificação = case_when(
           class_verde_atividade == "V" ~ "darkgreen",
           class_verde_atividade == "L" ~ "lightblue",
           class_verde_atividade == "O" ~ "yellow2",
           class_verde_atividade == "S" ~ "chocolate")
         )
       ) +
  aes(x = Ano, y = idade_media, group = class_verde_atividade, color = Classificação)+ 
  geom_point(size = 2)+
  geom_line(linewidth = 1)+
  labs(x = "Ano", y = "Idade Média", title = "Idade média dos ocupados segundo tipo da classificação")+
  scale_color_identity(labels = c(darkgreen = "V", lightblue = "L", yellow2 = "O", chocolate = "S"), guide = "legend")
ggsave(paste0("produtos/gráficos/idade_media_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Genero ---------------------------------

  ggplot(data = tabelas_ativ[["genero"]] %>%
           filter(Ano %in% anos_graf),
         aes(x = Ano, y = freq, group = V2007, fill = V2007)) +
    geom_col(width = 0.5, color = "black")+
    geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~class_verde_atividade) +
  labs(x = "Classificação verde", y = "Quantidade", title = paste0("Proporção de Homens e Mulheres segundo tipo de classificação ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))+
    scale_fill_manual(name = "Gênero",values = c("Homem" = "lightgreen", "Mulher" = "purple3"))
  ggsave(paste0("produtos/gráficos/prop_genero_classif_alterna", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)
  

# Matriz ocup-ativ --------------------------------------------------------

base_pnadc %>% filter(Ano == 2022) %>% 
  tabyl(class_verde_setor, class_verde_ocup) %>% write.xlsx(., file = "teste2.xlsx")
      
xtabs(formula = V1028 ~ setor_cnae20_nome + class_verde_ocup,
        data = base_pnadc %>% filter(Ano == 2012)) %>% 
    as.data.frame %>% 
    pivot_wider(names_from = class_verde_ocup, values_from = Freq) %>%
    mutate(across(.cols = c("verde","nao_verde"), function(x) x/rowSums(.[-1]), .names = "prop_{.col}")) %>% 
  rename_with(.cols = ends_with("verde"), .fn = function(x) paste(x, "2012", sep = "_")) %>% full_join(.,
  
(xtabs(formula = V1028 ~ setor_cnae20_nome + class_verde_ocup,
      data = base_pnadc %>% filter(Ano == 2022)) %>% 
  as.data.frame %>% 
  pivot_wider(names_from = class_verde_ocup, values_from = Freq) %>%
  mutate(across(.cols = c("verde","nao_verde"), function(x) x/rowSums(.[-1]), .names = "prop_{.col}")) %>% 
  rename_with(.cols = ends_with("verde"), .fn = function(x) paste(x, "2022", sep = "_"))
  
), by = "setor_cnae20_nome") %>% 
  left_join(., cnae_verde %>% select(setor_cnae20_nome,class_verde_setor) %>% distinct()) %>% 
  relocate(class_verde_setor, .after = "setor_cnae20_nome") %>%
  mutate(across(.cols = (where(is.numeric) | starts_with("prop")), .fn = function(x) round(100*x, digits = 2))) %>% 
  write.xlsx(., 
             file = "produtos/tabelas/matriz_setor_ocup.xlsx", 
             keepNA = T,
             overwrite = T,
             colWidths = "auto",
             digits = 2)

#Tabela Demográfica

#é pra ter o seguinte formato



            
            
# Exportando tabelas ------------------------------------------------------

#Em excel

tabelas_ativ <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V")))
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V")))
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V")))
                      } else if (i == "UF") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V"))) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup()
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>%
                          filter(!is.na(formalidade))
                        summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V")))
                      }
                      
                      else {
                        base_pnadc %>% group_by(Ano, class_verde_atividade, !!sym(i)) %>%
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("S", "L", "V")))
                      }
                    })

names(tabelas_ativ) <- names(vars_tabela)

write.xlsx(tabelas_class, 
           file = "produtos/tabelas/tabelas_class.xlsx", 
           keepNA = T,
           overwrite = T,
           colWidths = "auto",
           digits = 2)


write.xlsx(tabelas_ativ, 
           file = "produtos/tabelas/tabelas_ativ.xlsx", 
           keepNA = T,
           overwrite = T,
           colWidths = "auto",
           digits = 2)

write.xlsx(tabelas_setor, 
           file = "produtos/tabelas/tabelas_setor.xlsx", 
           keepNA = T,
           overwrite = T,
           colWidths = "auto",
           digits = 2)

#Tabelas ocup

tabelas_ocup <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2012,2022)) %>% 
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev) %>% 
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde"))) 
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2012,2022)) %>% 
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde"))) 
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2012,2022)) %>% 
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde")))
                      } else if (i == "regiao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_ocup) %>% filter(Ano %in% c(2012,2022)) %>%  
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde"))) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup() %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_ocup) %>% filter(Ano %in% c(2012,2022)) %>% 
                          filter(!is.na(formalidade))
                        summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde"))) %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                      
                      else {
                        base_pnadc %>% group_by(Ano, class_verde_ocup, !!sym(i)) %>% filter(Ano %in% c(2012,2022)) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("verde", "nao_verde"))) %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                    })

names(tabelas_ocup) <- names(vars_tabela)

tabela_demo <- tabelas_ocup[1:10] %>% 
  list_rbind(names_to = "caracteristica") %>% 
  mutate(V2009 = as.character(V2009),
         descricao = coalesce(V2007, V2010, formalidade, VD3004, VD3005, V2009, V1022, regiao_metrop, UF, regiao)) %>% 
  select(caracteristica, descricao, everything(), -c(V2007, V2010, formalidade, VD3004, VD3005, V2009, V1022, regiao_metrop, UF,regiao)) %>%
  filter(!(caracteristica %in% c("escolaridade_anos", "idade", "regiao_uf")))

tabela_demo %>% 
  group_by(caracteristica) %>% 
  gt::gt(rowname_col = "decricao") %>% 
  tab_spanner(label = "2012",columns = c(n_2012_nao_verde, n_2012_verde, freq_2012_nao_verde, freq_2012_verde)) %>% 
  tab_spanner(label = "2022",columns = c(n_2022_nao_verde, n_2022_verde, freq_2022_nao_verde, freq_2022_verde)) %>% 
  cols_label(n_2012_nao_verde = html("Qtd. Empregos <br>Não-Verdes"),
             n_2012_verde = html("Qtd. Empregos <br>Verdes"),
             freq_2012_nao_verde = html("% Empregos <br>Não-Verdes"),
             freq_2012_verde = html("% Empregos <br>Verdes"),
             n_2022_nao_verde = html("Qtd. Empregos <br>Não-Verdes"),
             n_2022_verde = html("Qtd. Empregos <br>Verdes"),
             freq_2022_nao_verde = html("% Empregos <br>Não-Verdes"),
             freq_2022_verde = html("% Empregos <br>Verdes")) %>% 
  fmt_number(columns = starts_with("n"), scale_by = 0.000001, decimals = 2) %>% 
  fmt_number(columns = starts_with("freq"), decimals = 2) %>%
  text_replace("NA","-", locations = cells_body()) %>% 
  text_transform(fn = function(x) paste(x, "mi", sep = " "), locations = cells_body(columns = starts_with("n"),
                                                                                    rows = !str_detect(pattern = "-"))) %>% 
  text_transform(fn = function(x) paste(x, "%", sep = ""), locations = cells_body(columns = starts_with("freq"),
                                                                                  rows = !str_detect(pattern = "-")))
  
write_xlsx(tabela_demo, path = here("produtos/tabelas/tabela_demo.xlsx"))
  

write.xlsx(tabelas_ocup, 
           file = "produtos/tabelas/tabelas_ocup.xlsx", 
           keepNA = T,
           overwrite = T,
           colWidths = "auto",
           digits = 2)
