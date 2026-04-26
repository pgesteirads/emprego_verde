#Script designado a fazer todos os tratamentos e manipulações necessários
#para ter uma classificação verde da cnae, no ambito da atividade e no ambito do setor

#Configurações gerais

options(encoding = "latin1")
options("digits" = 3)

#Pacotes usados

if (!require("librarian")) install.packages("librarian")

librarian::shelf(tidyverse,
                 haven,
                 data.table,
                 readxl,
                 writexl,
                 openxlsx,
                 janitor,
                 dbplyr,
                 bigrquery,
                 here)


# Puxando a RAIS da basedosdados ------------------------------------------

#AVISO: para utilizar as funções abaixo você deve possuir uma conta google
#e autorizar as permissões que as funções abaixo irá te requisitar.
#As funções abaixo usam sua conta google para contabilizar os dados que voce vai 
#puxar na sua conta da google cloud.

#Pegando a tabela com a quantidade de empregos da rais. O if verifica se a tabela ja existe na pasta de dados.
#Se já existir, ele não faz todo o trabalho de conectar ao db

if (("classif_cnae_verde.xlsx" %in% list.files(path = here("dados","dados_final")))) {
 
   cnae_verde <- read_xlsx("dados/dados_final/classif_cnae_verde.xlsx")

} else {

if (("rais_vinculos.csv" %in% list.files(path = here("dados","dados_final")))) {
  
  rais_vinculos <- read.csv(file = "dados/dados_final/rais_vinculos.csv")

} else {

  con_rais <- dbConnect(bigquery(),
                        project = "basedosdados",
                        dataset = "br_me_rais",
                        billing = "emprego-verde")
  
  rais_microdados_vinculos <- tbl(con_rais, "microdados_vinculos")
  
  rais_vinculos <- select(rais_microdados_vinculos,
                          c(ano,
                            vinculo_ativo_3112,
                            cnae_2_subclasse)) %>% 
    filter(ano %in% anos,
           vinculo_ativo_3112 == 1) %>%
    group_by(ano,cnae_2_subclasse) %>% 
    summarise(qtd_emprego = n()) %>% 
    collect()
  #Como eu peguei por subclasse (7 digitos), acaba sendo um pouco mais criterioso que a atividade (5 digitos).
  #Por conta disso, vou tirar os ultimos 2 digitos e agrupar os empregos, para ter a atividade
  
  rais_vinculos <- rais_vinculos %>%
    mutate(cnae_2_subclasse = str_extract(cnae_2_subclasse, pattern = "^\\d{5}")) %>% 
    group_by(ano,cnae_2_subclasse) %>% 
    summarise(qtd_emprego = sum(qtd_emprego)) %>% 
    ungroup()
  
  rais_vinculos <- rais_vinculos %>% 
    pivot_wider(names_from = ano, values_from = qtd_emprego, names_glue = "qtd_emprego_{ano}")
  
  write.csv(rais_vinculos, file = "dados/dados_final/rais_vinculos.csv")
  
}

rais_vinculos <- rais_vinculos %>% 
  select(-X)

#Puxando a base com as classificações verdes de cada atividade

class_verde_cnae20 <- readxl::read_xlsx(path = "dados/dados_original/Harmonizacao.xlsx", col_names = T, sheet = "ativ_cnaedom X ativ_cnae20")

#ESCOLHA UMA CLASSIFICAÇÃO

classificacoes <- c("class_verde_cnae20", "class_verde_cnae20_alternativo", "class_verde_cnae20_alternativo_adm_pub", "class_verde_definitiva")

class_escolhida <- c("class_verde_definitiva")

classificacoes <- classificacoes %>% setdiff(., class_escolhida)

class_verde_cnae20 <- class_verde_cnae20 %>% 
  select(-c("OBS"), -all_of(classificacoes)) %>%
  mutate(cnae20_atividade_codigo = str_replace(str_replace(cnae20_atividade_codigo, "[-]",""), "[.]","")) %>% 
  rename("class_verde_cnae20" = all_of(class_escolhida))

class_verde_setor_cnae20 <- class_verde_cnae20 %>% select(V4013, cnae20_atividade_codigo, setor_cnae20_cod, setor_cnae20)

# APENDICE: Vendo as atividades problemáticas -----------------------------
#
#Quais são as problemáticas? 
#As atividades que possuem mais de uma atividade correspondente na cnae20 e que essas atividades tem class divergentes
#
#Pegando apenas as atividades que possuem classificações divergentes:
#  
#class_dup <- class_verde_cnae20 %>% 
#  group_by(V4013, CNAE20.DOMICILIO.NOME) %>% 
#  filter(n_distinct(class_verde_cnae20) > 1)
#
##Incluindo a quantidade de emprego
#
#class_dup <- class_dup %>%
#  mutate(cnae20_atividade_codigo = str_replace(str_replace(cnae20_atividade_codigo, "[-]",""), "[.]","")) %>%
#  left_join(., rais_vinculos, by = c("cnae20_atividade_codigo" = "cnae_2_subclasse")) %>% 
#  
##Gerando medidas percentuais dessa quantidade em relação a atividade  
#  
#  mutate(across(c("qtd_emprego_2012","qtd_emprego_2016","qtd_emprego_2019","qtd_emprego_2021"), 
#                function(x) (x/sum(x, na.rm = T))*100,
#                .names = "{col}_per")) %>% 
#  
##Agregando esses percentuais de acordo com as classificação verdes que a atividade da cnaedom possui  
#  
#  group_by(V4013, CNAE20.DOMICILIO.NOME, class_verde_cnae20) %>% 
#  summarise(across(c("qtd_emprego_2012_per","qtd_emprego_2016_per","qtd_emprego_2019_per","qtd_emprego_2021_per"),
#                   function(x) sum(x, na.rm = T))) %>% 
#  ungroup()
#
#writexl::write_xlsx(class_dup, path = "dados/dados_final/classif_divergentes.xlsx")
#
##Fazendo a média das quantidades
#
#class_dup_final <- class_dup %>%
#  mutate(qtd_emprego_medio = rowMeans(.[4:7]))
#
##Escolhendo a classificação que fica com base na maior média
#
#class_dup_final <- class_dup_final %>% 
#  group_by(V4013, CNAE20.DOMICILIO.NOME) %>% 
#  filter(qtd_emprego_medio == max(qtd_emprego_medio))
#
#
#
#

# DE VOLTA A BASE TODA: repetindo o critério acima para a base toda --------

#Na seção anterior, eu tava interessado em ver com calma como era a situação dessas atividades,
#agora que eu vi, voltei para a base toda e vou usar esse mesmo critério de pegar o emprego médio máximo
#para limar as atividades duplicadas com classificações divergentes

class_verde_cnae20 <- class_verde_cnae20 %>% 
  group_by(V4013, CNAE20.DOMICILIO.NOME)

#Incluindo a quantidade de emprego

class_verde_cnae20 <- class_verde_cnae20  %>%
  mutate(cnae20_atividade_codigo = as.numeric(cnae20_atividade_codigo)) %>% 
  left_join(., rais_vinculos, by = c("cnae20_atividade_codigo" = "cnae_2_subclasse"))
  
  #Gerando medidas percentuais dessa quantidade em relação a atividade  
  
  class_verde_cnae20 <- class_verde_cnae20 %>%
  mutate(across(c("qtd_emprego_2012","qtd_emprego_2016","qtd_emprego_2019","qtd_emprego_2021"), 
                function(x) (x/sum(x, na.rm = T))*100,
                .names = "{col}_per"))
  
#  #Agregando esses percentuais de acordo com as classificação verdes que a atividade da cnaedom possui (NAO SEI PQ EU FIZ ISSO)  
#  
#  class_verde_cnae20 <- class_verde_cnae20 %>%  group_by(V4013, CNAE20.DOMICILIO.NOME, class_verde_cnae20) %>% 
#  summarise(across(c("qtd_emprego_2012_per","qtd_emprego_2016_per","qtd_emprego_2019_per","qtd_emprego_2021_per"),
#                   function(x) sum(x, na.rm = T))) %>% 
#  ungroup()
  
  #Tirando os repetidos com menor qtd de emprego (estou usando qtd_emprego_2012 como base mas mesmo se fizesse a média dos empregos, daria a mesma coisa)
  
  class_verde_cnae20 <- class_verde_cnae20 %>%
    group_by(V4013) %>% 
    slice_max(order_by = qtd_emprego_2012_per)

#Classificando os setores
  
  #Pegando as informações de classificação verde da tabela anterior e as infos de qtd de emprego
  
class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>% 
  left_join(.,class_verde_cnae20 %>% select(V4013,class_verde_cnae20, qtd_emprego_2012, qtd_emprego_2016, qtd_emprego_2019, qtd_emprego_2021))

  #Agregando as qtd de emprego 

class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>% 
  select(-V4013) %>% 
  distinct()

class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>% 
  group_by(setor_cnae20_cod,setor_cnae20,class_verde_cnae20) %>% 
  summarise(across(c("qtd_emprego_2012","qtd_emprego_2016","qtd_emprego_2019","qtd_emprego_2021"), function(x) sum(x, na.rm = T))) %>% 
  filter(!is.na(qtd_emprego_2012))

class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>% 
  ungroup()

#Tirando os repetidos com menor qtd de emprego (estou usando qtd_emprego_2012 como base mas mesmo se fizesse a média dos empregos, daria a mesma coisa)

class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>%
  group_by(setor_cnae20_cod) %>% 
  slice_max(order_by = qtd_emprego_2012)

#Ver se tem alguma entrada duplicada

get_dupes(class_verde_setor_cnae20, setor_cnae20_cod)

#Agora temos as classificações tanto para as atividades da cnaedom quanto para os setores da cnae20. Colocando na cnaedom

cnae_verde <- readxl::read_xlsx(path = "dados/dados_original/Harmonizacao.xlsx",
                                col_names = T, sheet = "class_verde_cnaedom")

cnae_verde <- cnae_verde %>% 
  left_join(.,(class_verde_cnae20 %>% 
                 select(V4013, class_verde_cnae20)) %>% 
                 rename("class_verde_atividade" = "class_verde_cnae20"), 
            by = c("cnaedom_cod" = "V4013")) %>% 
  left_join(., (class_verde_setor_cnae20 %>% 
                  select(setor_cnae20_cod, class_verde_cnae20) %>% 
                  rename("class_verde_setor" = "class_verde_cnae20")), 
            by = "setor_cnae20_cod") %>% 
  select(-class_verde_cnaedom, -class_verde_setor_cnae20) %>% 
  relocate(class_verde_atividade, .before = setor_cnae20_cod)

rm(class_verde_cnae20, class_verde_setor_cnae20, class_dup_final, class_dup, con_rais,rais_microdados_vinculos)

write_xlsx(cnae_verde, path = "dados/dados_final/classif_cnae_verde.xlsx")

}