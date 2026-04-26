#Script designado a fazer todos os tratamentos e manipulações necessários
#para ter uma classificação verde pela ótica ocupacional, usando como referência Caruso (2010)

#Configurações gerais

options(encoding = "latin1")
options("scipen" = 999)

#Pacotes usados

if (!require("librarian")) install.packages("librarian")

librarian::shelf(tidyverse,
                 haven,
                 rio,
                 writexl,
                 here,
                 janitor)

#Puxando a compatibilização ISCO-08 com CBO Dom

comp_cbo <- read(here("dados","dados_original", "nome do arquivo AAAAAA"))

#Possíveis tratamentos e/ou manipulações.....

#Puxando a tabela do Caruso (2010)

tab_caruso <- import(here("dados","dados_original","cbo02_classverde_caruso.xlsx")) %>% 
  clean_names()

cbo_verde <- left_join(comp_cbo, tab_caruso, by = c("coluna ISCO da comp_cbo" = "code")) %>% 
  select(-colunaISCOdacomp_cbo)