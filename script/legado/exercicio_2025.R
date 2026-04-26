
# Ambiente ----------------------------------------------------------------

options(encoding = "latin1")
options(scipen = 999)

#Pacotes usados

if (!require("librarian")) install.packages("librarian")

librarian::shelf(arrow,
                 here,
                 tidyverse,
                 PNADcIBGE,
                 haven,
                 here,
                 survey,
                 srvyr,
                 data.table,
                 glue,
                 gt,
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

#Limpando o ambiente antes de rodar o codigo

rm(list = ls())

gc()


base_pnadc <- arrow::read_parquet("dados/base_pnadc_tratada_trimestral_4.parquet")

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
  mutate(
    # normaliza texto para reduzir risco de mismatch por espaços
    vd4009_txt = str_squish(VD4009),
    
    formalidade = case_when(
      
      # (6) VD4009 = NA e V4032 = NA
      is.na(VD4009) & is.na(V4032) ~ "Ocupado sem informação",
      
      # (12) Trabalhador familiar auxiliar + V4032 NA
      vd4009_txt == "Trabalhador familiar auxiliar" & is.na(V4032) ~ "Ocupado sem informação",
      
      # (1) Empregado privado com carteira + V4032 NA
      vd4009_txt == "Empregado no setor privado com carteira de trabalho assinada" & is.na(V4032) ~ "Formal",
      
      # (2) Doméstico com carteira + V4032 NA
      vd4009_txt == "Trabalhador doméstico com carteira de trabalho assinada" & is.na(V4032) ~ "Formal",
      
      # (3) Público com carteira + V4032 NA
      vd4009_txt == "Empregado no setor público com carteira de trabalho assinada" & is.na(V4032) ~ "Formal",
      
      # (4) Militar e estatutário + V4032 NA
      vd4009_txt == "Militar e servidor estatutário" & is.na(V4032) ~ "Formal",
      
      # (5) Conta-própria + Não
      vd4009_txt == "Conta-própria" & V4032 == "Não" ~ "Informal - Conta própria",
      
      # (10) Conta-própria + Sim
      vd4009_txt == "Conta-própria" & V4032 == "Sim" ~ "Formal",
      
      # (7) Empregador + Sim
      vd4009_txt == "Empregador" & V4032 == "Sim" ~ "Formal",
      
      # (11) Empregador + Não
      vd4009_txt == "Empregador" & V4032 == "Não" ~ "Informal",
      
      # (8) Privado sem carteira + Não
      vd4009_txt == "Empregado no setor privado sem carteira de trabalho assinada" & V4032 == "Não" ~
        "Informal - Sem carteira",
      
      # (14) Privado sem carteira + Sim
      vd4009_txt == "Empregado no setor privado sem carteira de trabalho assinada" & V4032 == "Sim" ~
        "Formal",
      
      # (9) Público sem carteira + Sim
      vd4009_txt == "Empregado no setor público sem carteira de trabalho assinada" & V4032 == "Sim" ~
        "Informal - Sem carteira",
      
      # (15) Público sem carteira + Não
      vd4009_txt == "Empregado no setor público sem carteira de trabalho assinada" & V4032 == "Não" ~
        "Informal",
      
      # (13) Doméstico sem carteira + Não
      vd4009_txt == "Trabalhador doméstico sem carteira de trabalho assinada" & V4032 == "Não" ~
        "Informal",
      
      # (16) Doméstico sem carteira + Sim
      vd4009_txt == "Trabalhador doméstico sem carteira de trabalho assinada" & V4032 == "Sim" ~
        "Formal",
      
      # fallback: ocupados que não bateram em nenhuma regra explícita
      TRUE ~ "Ocupado sem informação"
    ),
    
    # (opcional) ordena níveis para padronizar visualização
    formalidade = factor(
      formalidade,
      levels = c("Formal",
                 "Informal - Sem carteira",
                 "Informal - Conta própria",
                 "Informal",
                 "Ocupado sem informação")
    )
  ) %>%
  select(-vd4009_txt) %>%
  relocate(formalidade, .after = V4032)


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





## Class Verde Atividade (Verde, Neutral, Suja) -----------

#Vai rodar o script que gera a tabela com classificações verdes das atividades e setores
#ATENÇÂO: É necessário uma conta no google cloud e autenticação. Utilizamos o google cloud para pegar a base da rais.

#Pra escolher qual classificação usar, tem que entrar no script abaixo

#source("script/gerando_class_verde.R")

cnae_verde <- readxl::read_xlsx("dados/dados_final/classif_cnae_verde.xlsx")

cnae_verde %>% glimpse()

if (c("cnaedom_nome") %in% colnames(base_pnadc)) {
  
  base_pnadc <- base_pnadc %>% select(-c(cnaedom_nome, class_verde_atividade, setor_cnae20_cod, setor_cnae20_nome, class_verde_setor))
  
} else glimpse(base_pnadc)  


base_pnadc <- base_pnadc %>% select(-c(class_verde_atividade)) %>%  left_join(.,cnae_verde %>% select(cnaedom_cod,class_verde_atividade), by = c("V4013" = "cnaedom_cod"))


## Class Verde Ocupação (Verde, Não-Verde) -----------

tab_caruso <- import(here("dados","dados_original","cbodom_classverde_caruso.xlsx"), 
                     col_types = c("text","text")) %>% 
  clean_names() %>% mutate(cod_ocupacao = str_sub(cod_ocupacao,1,4))

base_pnadc <- base_pnadc %>% left_join(.,tab_caruso, by = c("V4010" = "cod_ocupacao"))

rm(tab_caruso)


## Renda habitual deflacionada e medidas de renda ------------------

base_pnadc <- base_pnadc %>% 
  mutate(renda_hab_def = VD4016*Habitual) 

base_pnadc <- base_pnadc %>% 
  mutate(renda_percentil = cut(renda_hab_def, 
                               breaks = weighted.quantile(renda_hab_def, w = V1028, probs = seq(0, 1, by = 0.25), na.rm = TRUE),
                               labels = c("Q1", "Q2", "Q3", "Q4"),
                               include.lowest = T)) %>% 
  group_by(Ano, class_verde_atividade) %>% #NOTE que to usando as classificações das atividades, não dos setores (pensar melhor nisso)
  mutate(renda_log_var = as.vector(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)),
         renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>% 
  ungroup()

base_pnadc <- base_pnadc %>%
  mutate(
    escolaridade = fct_collapse(
      VD3004,
      "Fundamental incompleto" = c("Sem instrução e menos de 1 ano de estudo",
                                   "Fundamental incompleto ou equivalente"),
      "Fundamental completo"   = "Fundamental completo ou equivalente",
      "Médio completo"         = "Médio completo ou equivalente",
      "Superior completo"      = "Superior completo"
    ) %>%
      fct_relevel("Fundamental incompleto","Fundamental completo",
                  "Médio completo","Superior completo")
  )


base_pnadc <- base_pnadc %>%
  mutate(idade = as.integer(V2009)) %>%
  filter(!is.na(idade), idade >= 14) %>%
  mutate(
    faixa_etaria = dplyr::case_when(
      idade <= 24               ~ "14–24",
      idade <= 39               ~ "25–39",
      idade <= 59               ~ "40–59",
      idade >= 60               ~ "60+"
    ),
    faixa_etaria = factor(faixa_etaria,
                          levels = c("14–24","25–39","40–59","60+"))
  )

#Inclusão das categorias SCN-------------

scn <- readxl::read_xlsx("dados/dados_original/Tradutor_KF.xlsx", sheet = "CNAEDOM X SCN") %>% select("V4013" = 1,5)

base_pnadc <- base_pnadc %>% left_join(.,scn)

#Alguns códigos SCN serão divididos por regras específicas

#Educação e Saúde (Captamos o componente publico a partir das posições de ocupação. Todos que não forem dessas posições cai para o privado)

base_pnadc <- 
  base_pnadc  %>% 
  mutate(SCN = case_when(
  V4013 %in% c("85011","85012","85013","85014","85021", "85029") & VD4009 %in% c("Militar e servidor estatutário","Empregado no setor público com carteira de trabalho assinada","Empregado no setor público sem carteira de trabalho assinada") ~ "8591",
  V4013 %in% c("85011","85012","85013","85014","85021", "85029") & !(VD4009 %in% c("Militar e servidor estatutário","Empregado no setor público com carteira de trabalho assinada","Empregado no setor público sem carteira de trabalho assinada")) ~ "8592",
  V4013 %in% c("86001","86002","86003","86004","86009","87000") & VD4009 %in% c("Militar e servidor estatutário","Empregado no setor público com carteira de trabalho assinada","Empregado no setor público sem carteira de trabalho assinada") ~ "8691",
  V4013 %in% c("86001","86002","86003","86004","86009","87000") & !(VD4009 %in% c("Militar e servidor estatutário","Empregado no setor público com carteira de trabalho assinada","Empregado no setor público sem carteira de trabalho assinada")) ~ "8692",
  TRUE ~ SCN))
  
#Agricultura e Pecuária

#Foi utilizado a proporção de ocupados em cada SCN para dividir os ocupados da base que possuem a atividade cnaedom agropecuaria
#Na base do TRU, temos 

base_pnadc <- base_pnadc %>%
  mutate(
    .id   = row_number(),
    V4013 = as.character(V4013),
    SCN   = as.character(SCN)
  )

# separa só o CNAE que será desagregado
base_01999 <- base_pnadc %>% filter(V4013 == "01999")
base_rest  <- base_pnadc %>% filter(V4013 != "01999")

if (nrow(base_01999) > 0) {
  
  total_w     <- sum(base_01999$V1028, na.rm = TRUE)
  target_0191 <- 0.534 * total_w
  
  base_01999 <- base_01999 %>%
    mutate(.u = runif(n())) %>%     # embaralha para não depender da ordem original
    arrange(.u) %>%
    mutate(.cumw = cumsum(V1028))
  
  k <- which(base_01999$.cumw >= target_0191)[1]
  
  if (is.na(k)) {
    
    base_01999 <- base_01999 %>% mutate(SCN = "0191")
    
  } else {
    
    cum_prev <- if (k == 1) 0 else base_01999$.cumw[k - 1]
    w_k      <- base_01999$V1028[k]
    
    # decide o "indivíduo de fronteira" para minimizar erro na soma ponderada
    err_if_0191 <- abs((cum_prev + w_k) - target_0191)
    err_if_0192 <- abs(cum_prev - target_0191)
    
    boundary_to_0191 <- err_if_0191 <= err_if_0192
    
    base_01999 <- base_01999 %>%
      mutate(
        SCN = case_when(
          row_number() < k ~ "0191",
          row_number() > k ~ "0192",
          TRUE ~ if_else(boundary_to_0191, "0191", "0192")
        )
      )
  }
  
  # reconstrói base preservando ordem original
  base_pnadc <- bind_rows(
    base_rest,
    base_01999 %>% select(-.u, -.cumw)
  ) %>%
    arrange(.id) %>%
    select(-.id)
  
} else {
  
  base_pnadc <- base_pnadc %>% select(-.id)
  
}

# Checagem: proporções ponderadas dentro do CNAE 01999
base_pnadc %>%
  filter(V4013 == "01999") %>%
  group_by(SCN) %>%
  summarise(total_pond = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  mutate(share = total_pond / sum(total_pond))



# CNAEs alvo

base_pnadc <- base_pnadc %>%
  mutate(
    .id   = row_number(),
    V4013 = as.character(V4013),
    SCN   = as.character(SCN)
  )

cnae_alvo <- c("07001", "07002")

base_alvo <- base_pnadc %>% filter(V4013 %in% cnae_alvo)
base_rest <- base_pnadc %>% filter(!(V4013 %in% cnae_alvo))

if (nrow(base_alvo) > 0) {
  
  total_w      <- sum(base_alvo$V1028, na.rm = TRUE)
  target_0791  <- 0.495 * total_w
  
  base_alvo <- base_alvo %>%
    mutate(.u = runif(n())) %>%
    arrange(.u) %>%
    mutate(.cumw = cumsum(V1028))
  
  k <- which(base_alvo$.cumw >= target_0791)[1]
  
  if (is.na(k)) {
    
    base_alvo <- base_alvo %>% mutate(SCN = "0791")
    
  } else {
    
    cum_prev <- if (k == 1) 0 else base_alvo$.cumw[k - 1]
    w_k      <- base_alvo$V1028[k]
    
    err_if_0791 <- abs((cum_prev + w_k) - target_0791)
    err_if_0792 <- abs(cum_prev - target_0791)
    
    boundary_to_0791 <- err_if_0791 <= err_if_0792
    
    base_alvo <- base_alvo %>%
      mutate(
        SCN = case_when(
          row_number() < k ~ "0791",
          row_number() > k ~ "0792",
          TRUE ~ if_else(boundary_to_0791, "0791", "0792")
        )
      )
  }
  
  base_pnadc <- bind_rows(
    base_rest,
    base_alvo %>% select(-.u, -.cumw)
  ) %>%
    arrange(.id) %>%
    select(-.id)
  
} else {
  
  base_pnadc <- base_pnadc %>% select(-.id)
  
}

# Checagem: proporção ponderada dentro de 07001/07002
base_pnadc %>%
  filter(V4013 %in% cnae_alvo) %>%
  group_by(SCN) %>%
  summarise(total_pond = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  mutate(share = total_pond / sum(total_pond))


# CNAEs alvo


base_pnadc <- base_pnadc %>%
  mutate(
    .id   = row_number(),
    V4013 = as.character(V4013),
    SCN   = as.character(SCN)
  )

cnae_alvo <- c("20010", "20090")

base_alvo <- base_pnadc %>% filter(V4013 %in% cnae_alvo)
base_rest <- base_pnadc %>% filter(!(V4013 %in% cnae_alvo))

if (nrow(base_alvo) > 0) {
  
  total_w     <- sum(base_alvo$V1028, na.rm = TRUE)
  target_2091 <- 0.526 * total_w
  
  base_alvo <- base_alvo %>%
    mutate(.u = runif(n())) %>%
    arrange(.u) %>%
    mutate(.cumw = cumsum(V1028))
  
  k <- which(base_alvo$.cumw >= target_2091)[1]
  
  if (is.na(k)) {
    
    base_alvo <- base_alvo %>% mutate(SCN = "2091")
    
  } else {
    
    cum_prev <- if (k == 1) 0 else base_alvo$.cumw[k - 1]
    w_k      <- base_alvo$V1028[k]
    
    err_if_2091 <- abs((cum_prev + w_k) - target_2091)
    err_if_2092 <- abs(cum_prev - target_2091)
    
    boundary_to_2091 <- err_if_2091 <= err_if_2092
    
    base_alvo <- base_alvo %>%
      mutate(
        SCN = case_when(
          row_number() < k ~ "2091",
          row_number() > k ~ "2092",
          TRUE ~ if_else(boundary_to_2091, "2091", "2092")
        )
      )
  }
  
  base_pnadc <- bind_rows(
    base_rest,
    base_alvo %>% select(-.u, -.cumw)
  ) %>%
    arrange(.id) %>%
    select(-.id)
  
} else {
  
  base_pnadc <- base_pnadc %>% select(-.id)
  
}

# Checagem: proporção ponderada dentro das CNAEs alvo
base_pnadc %>%
  filter(V4013 %in% cnae_alvo) %>%
  group_by(SCN) %>%
  summarise(total_pond = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  mutate(share = total_pond / sum(total_pond))

base_pnadc <- base_pnadc %>% left_join(., readxl::read_xlsx("dados/dados_original/Tradutor_KF.xlsx", sheet = "CNAE x Harm x SCN") %>% select("SCN" = 5,"NomeSCN" = 6) %>% distinct() %>% filter(row_number() != 42))

# Tabelas - Estatistica Descritiva -------------------------------------  

#Matriz para insumo produto geral

base_pnadc %>% filter(Ano %in% c(2024)) %>% 
  filter(VD4002 == "Pessoas ocupadas") %>% 
  group_by(Ano, SCN, class_verde_atividade)  %>% 
  summarise(tot_ocup = sum(V1028, na.rm = TRUE), .groups = "drop") %>% 
  pivot_wider(
    names_from  = c(Ano,class_verde_atividade), 
    values_from = tot_ocup,
    values_fill = 0
  )%>% 
  left_join(., readxl::read_xlsx("dados/dados_original/Tradutor_KF.xlsx", sheet = "CNAE x Harm x SCN") %>% select("SCN" = 5,"NomeSCN" = 6) %>% distinct() %>% filter(row_number() != 42)) %>%
  select(SCN, NomeSCN, everything()) %>% 
  writexl::write_xlsx(.,"Total de ocupados por SCN e classificação verde.xlsx")


base_pnadc %>% filter(Ano %in% c(2014,2024)) %>% 
  filter(VD4002 == "Pessoas ocupadas") %>% 
  group_by(Ano, class_verde_setor)  %>% 
  summarise(idade = round(weighted.mean(V2009,V1028),0), .groups = "drop")

base_pnadc %>% filter(Ano %in% c(2014,2024)) %>% 
  filter(VD4002 == "Pessoas ocupadas") %>% 
  mutate(VD3005a = case_match(VD3005,
                            "16 anos ou mais de estudo" ~ 16,               
                            "9 anos de estudo" ~ 9,                        
                            "12 anos de estudo" ~ 12,                       
                            "15 anos de estudo" ~ 15,                       
                            "11 anos de estudo" ~ 11,                       
                            "13 anos de estudo" ~ 13,                       
                            "14 anos de estudo" ~ 14,                       
                            "8 anos de estudo" ~ 8,                        
                            "Sem instrução e menos de 1 ano de estudo" ~ 0,
                            "10 anos de estudo" ~ 10,                       
                            "1 ano de estudo" ~ 1,                         
                            "6 anos de estudo" ~ 6,                        
                            "7 anos de estudo" ~ 7,                        
                            "5 anos de estudo" ~ 5,                        
                            "2 anos de estudo" ~ 2,                        
                            "3 anos de estudo" ~ 3,                        
                            "4 anos de estudo" ~  4 )) %>% 
group_by(Ano, class_verde_setor)  %>% 
  summarise(idade = round(weighted.mean(VD3005a,V1028),0), .groups = "drop")



#Tem alguma CNAE sem classificação?

base_pnadc %>% filter(VD4002 == "Pessoas ocupadas",
                      class_verde_setor %>% is.na(.)) %>% distinct(V4013,setor_cnae20_cod, setor_cnae20_nome)

#Só atividades mal definidas, seguindo

#Total de ocupados

base_pnadc %>% 
  filter(VD4002 == "Pessoas ocupadas") %>% 
  group_by(Ano, class_verde_setor) %>% 
  summarise(tot_ocup = sum(V1028, na.rm = TRUE), .groups = "drop") %>% 
  pivot_wider(
    names_from  = class_verde_setor, 
    values_from = tot_ocup,
    values_fill = 0
  ) %>% 
  # renomeia as colunas de categorias para *_total
  rename_with(~ paste0(.x, "_total"), -Ano) %>% 
  # total geral da linha
  mutate(total_geral = rowSums(across(ends_with("_total")), na.rm = TRUE)) %>% 
  # cria colunas *_percentual (categoria / total_geral)
  mutate(across(
    ends_with("_total"),
    ~ .x / total_geral,
    .names = "{.col}_percentual"
  )) %>% writexl::write_xlsx(path = "produtos/tabelas/ocupados_por_classif.xlsx")

# função genérica: compara dois anos (ano_inicial x ano_final) para várias aberturas

tabela_demografica <- function(.data,
                               ano_inicial,
                               ano_final,
                               aberturas,                 # ex.: c("Gênero"="V2007","Raça"="V2010")
                               var_ano   = "Ano",
                               var_peso  = "V1028",
                               var_setor = "class_verde_setor",
                               filtro    = NULL,
                               em_pct    = TRUE,
                               fill_zero = TRUE,
                               setor_em_wide = TRUE) {
  
  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))
  
  faz_bloco <- function(var_cat, lbl_abertura) {
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(total = sum(.data[[var_peso]], na.rm = TRUE), .groups = "drop_last") %>%
      group_by(.data[[var_ano]], .data[[var_setor]]) %>%
      mutate(total_abertura = sum(total, na.rm = TRUE),
             pct = if (em_pct) 100 * total / total_abertura else total / total_abertura) %>%
      ungroup() %>%
      rename(Ano = !!var_ano,
             setor = !!var_setor,
             categoria = !!var_cat) %>%
      mutate(Ano = as.integer(Ano),
             abertura = lbl_abertura)
    
    if (fill_zero) {
      cats    <- df %>% distinct(!!sym(var_cat))  %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      
      grid <- tidyr::expand_grid(
        Ano       = as.integer(c(ano_inicial, ano_final)),
        setor     = setores,
        categoria = cats
      ) %>% mutate(abertura = lbl_abertura)
      
      bloco <- grid %>%
        left_join(bloco, by = c("Ano","setor","categoria","abertura")) %>%
        mutate(total = tidyr::replace_na(total, 0)) %>%
        group_by(Ano, setor) %>%
        mutate(
          total_abertura = if_else(is.na(total_abertura), sum(total, na.rm = TRUE), total_abertura),
          pct = if (em_pct) if_else(total_abertura > 0, 100 * total / total_abertura, 0)
          else if_else(total_abertura > 0,        total / total_abertura, 0)
        ) %>% ungroup()
    }
    
    # wide por Ano primeiro (total/pct por ano)
    bloco_w <- bloco %>%
      select(abertura, setor, categoria, Ano, total, pct) %>%
      pivot_wider(
        names_from  = Ano,
        values_from = c(total, pct),
        names_sep   = "_"
      ) %>%
      relocate(
        any_of(c(
          paste0("total_", ano_inicial),
          paste0("pct_",   ano_inicial),
          paste0("total_", ano_final),
          paste0("pct_",   ano_final)
        )),
        .after = categoria
      )
    
    # se quiser setor em wide (cada setor vira colunas)
    if (setor_em_wide) {
      cols_value <- c(paste0("total_", ano_inicial),
                      paste0("pct_",   ano_inicial),
                      paste0("total_", ano_final),
                      paste0("pct_",   ano_final))
      
      bloco_w <- bloco_w %>%
        pivot_wider(
          names_from  = setor,
          values_from = all_of(cols_value),
          names_glue  = "{setor}_{.value}"
        )
      
      # ordenar colunas: para cada setor -> total_ano_inicial, pct_ano_inicial, total_ano_final, pct_ano_final
      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_setor_cols <- unlist(lapply(setores_ord, function(s)
        paste0(s, "_", cols_value)
      ))
      
      bloco_w <- bloco_w %>%
        select(abertura, categoria, any_of(ordem_setor_cols))
    }
    
    bloco_w
  }
  
  purrr::imap_dfr(aberturas, faz_bloco) %>%
    arrange(abertura, categoria)
}

# === EXEMPLO (ano inicial 2014) ===
aberturas <- c("Gênero" = "V2007",
               "Raça"   = "V2010",
               "Formalidade" = "formalidade",
               "Contribuição para prev." = "VD4012",
               "Escolaridade" = "escolaridade",
               "Faixa etária" = "faixa_etaria",
               "Urbano x Rural" = "V1022"
               )

tabela_demog_wide <- tabela_demografica(
  .data         = base_pnadc,
  ano_inicial   = 2014,          # << ano inicial fixado em 2014
  ano_final     = 2024,          # ajuste aqui o ano de comparação
  aberturas     = aberturas,
  var_ano       = "Ano",
  var_peso      = "V1028",
  var_setor     = "class_verde_setor",
  filtro        = quote(VD4002 == "Pessoas ocupadas"),
  em_pct        = TRUE,
  fill_zero     = TRUE,
  setor_em_wide = TRUE           # << setor em colunas (wide)
)

sanitize_sheet <- function(x) {
  # remove caracteres proibidos e limita a 31 chars
  x <- gsub("[:\\\\/?*\\[\\]]", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(substr(x, 1, 31))
  ifelse(nchar(x) == 0, "Aba", x)
}

apply_number_formats <- function(wb, sheet, df) {
  cols_total <- grep("_total_", names(df))
  cols_pct   <- grep("_pct_",   names(df))
  
  # se percentuais estiverem em 0–100, converte para 0–1
  if (length(cols_pct) > 0) {
    need_divide <- any(suppressWarnings(sapply(df[cols_pct], function(x) max(x, na.rm = TRUE))) > 1)
    if (need_divide) {
      for (j in cols_pct) df[[j]] <- df[[j]]/100
    }
  }
  
  writeData(wb, sheet, df, withFilter = TRUE)
  addStyle(wb, sheet, createStyle(textDecoration = "bold"),
           rows = 1, cols = 1:ncol(df), gridExpand = TRUE)
  
  if (length(cols_total) > 0)
    addStyle(wb, sheet, createStyle(numFmt = "0"),
             rows = 2:(nrow(df)+1), cols = cols_total, gridExpand = TRUE)
  
  if (length(cols_pct) > 0)
    addStyle(wb, sheet, createStyle(numFmt = "0.0%"),
             rows = 2:(nrow(df)+1), cols = cols_pct, gridExpand = TRUE)
  
  setColWidths(wb, sheet, cols = 1:ncol(df), widths = "auto")
  freezePane(wb, sheet, firstActiveRow = 2, firstActiveCol = 1)
  
  invisible(df)  # retorna df caso queira reaproveitar
}

# --- monta o arquivo ---
wb <- createWorkbook()

# 1) aba completa
addWorksheet(wb, "Tabela Demográfica")
df_full <- tabela_demog_wide
apply_number_formats(wb, "Tabela Demográfica", df_full)

# 2) abas por 'abertura'
abas <- tabela_demog_wide %>% distinct(abertura) %>% pull()

# garantir nomes de abas únicos/limpos
sheet_names <- sanitize_sheet(abas)
sheet_names <- make.unique(sheet_names, sep = " ")

for (i in seq_along(abas)) {
  df_sub <- tabela_demog_wide %>% filter(abertura == abas[i])
  # opcional: remover a coluna 'abertura' dentro das abas específicas
  if ("abertura" %in% names(df_sub)) df_sub <- select(df_sub, -abertura)
  
  addWorksheet(wb, sheet_names[i])
  apply_number_formats(wb, sheet_names[i], df_sub)
}

# 3) salva no mesmo caminho que você já usa
saveWorkbook(wb, "produtos/tabelas/tabela_demografica.xlsx", overwrite = TRUE)



# Tabela demográfica - pela renda -----------------------------------------

# ============================================================
# TABELA DEMOGRÁFICA (RENDA MÉDIA PONDERADA)
# - Em vez de total/pct (quantidade de pessoas), calcula renda média
# - renda = weighted.mean(renda_hab_def, w = V1028, na.rm = TRUE)
# - Mantém mesma lógica de: aberturas, anos (inicial/final), setor em wide, etc.
# ============================================================

library(dplyr)
library(tidyr)
library(purrr)
library(openxlsx)

tabela_demografica_renda <- function(.data,
                                     ano_inicial,
                                     ano_final,
                                     aberturas,                 # ex.: c("Gênero"="V2007","Raça"="V2010")
                                     var_ano    = "Ano",
                                     var_peso   = "V1028",
                                     var_setor  = "class_verde_atividade",
                                     var_renda  = "renda_hab_def",
                                     filtro     = NULL,
                                     fill_missing = TRUE,       # garante grid completo (Ano x setor x categoria)
                                     setor_em_wide = TRUE) {
  
  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))
  
  faz_bloco <- function(var_cat, lbl_abertura) {
    
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(
        # Soma de pesos apenas onde renda não é NA
        w_sum  = sum(.data[[var_peso]] * (!is.na(.data[[var_renda]])), na.rm = TRUE),
        w_ySum = sum(.data[[var_peso]] * .data[[var_renda]], na.rm = TRUE),
        renda_media = if_else(w_sum > 0, w_ySum / w_sum, NA_real_),
        .groups = "drop"
      ) %>%
      rename(
        Ano = !!var_ano,
        setor = !!var_setor,
        categoria = !!var_cat
      ) %>%
      mutate(
        Ano = as.integer(Ano),
        abertura = lbl_abertura
      ) %>%
      select(abertura, Ano, setor, categoria, renda_media)
    
    if (fill_missing) {
      cats    <- df %>% distinct(!!sym(var_cat))   %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      
      grid <- tidyr::expand_grid(
        Ano       = as.integer(c(ano_inicial, ano_final)),
        setor     = setores,
        categoria = cats
      ) %>%
        mutate(abertura = lbl_abertura)
      
      bloco <- grid %>%
        left_join(bloco, by = c("abertura", "Ano", "setor", "categoria"))
      # Para renda média, o "missing" faz mais sentido ficar como NA (não zero)
    }
    
    # wide por Ano primeiro
    bloco_w <- bloco %>%
      pivot_wider(
        names_from  = Ano,
        values_from = renda_media,
        names_prefix = "renda_media_"
      ) %>%
      relocate(
        any_of(c(
          paste0("renda_media_", ano_inicial),
          paste0("renda_media_", ano_final)
        )),
        .after = categoria
      )
    
    # setor em wide (cada setor vira colunas)
    if (setor_em_wide) {
      cols_value <- c(paste0("renda_media_", ano_inicial),
                      paste0("renda_media_", ano_final))
      
      bloco_w <- bloco_w %>%
        pivot_wider(
          names_from = setor,
          values_from = all_of(cols_value),
          names_glue = "{setor}_{.value}"
        )
      
      # ordenar colunas por setor e ano
      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_setor_cols <- unlist(lapply(setores_ord, function(s)
        paste0(s, "_", cols_value)
      ))
      
      bloco_w <- bloco_w %>%
        select(abertura, categoria, any_of(ordem_setor_cols))
    }
    
    bloco_w
  }
  
  purrr::imap_dfr(aberturas, faz_bloco) %>%
    arrange(abertura, categoria)
}

# === EXEMPLO ===
aberturas <- c("Gênero" = "V2007",
               "Raça"   = "V2010",
               "Formalidade" = "formalidade",
               "Contribuição para prev." = "VD4012",
               "Escolaridade" = "escolaridade",
               "Faixa etária" = "faixa_etaria",
               "Urbano x Rural" = "V1022")

tabela_renda_wide <- tabela_demografica_renda(
  .data         = base_pnadc,
  ano_inicial   = 2014,
  ano_final     = 2024,
  aberturas     = aberturas,
  var_ano       = "Ano",
  var_peso      = "V1028",
  var_setor     = "class_verde_atividade",
  var_renda     = "renda_hab_def",
  filtro        = quote(VD4002 == "Pessoas ocupadas"),
  fill_missing  = TRUE,
  setor_em_wide = TRUE
)

writexl::write_xlsx(tabela_renda_wide, "produtos/tabelas/tabela_renda_wide.xlsx")
----------------

    # --- 0) Base filtrada ---
    dados_renda <- base_pnadc %>%
      filter(Ano %in% c(2014, 2024),
             !is.na(renda_hab_def),
             renda_hab_def > 0)
    
    # --- 1) Renda média por Ano x Classificação Verde (colunas = class_verde_setor) ---
    renda_class_verde_wide <- dados_renda %>%
      group_by(Ano, class_verde_atividade) %>%
      summarise(renda_media = weighted.mean(renda_hab_def, V1028, na.rm = TRUE), .groups = "drop") %>%
      pivot_wider(
        names_from  = class_verde_atividade,
        values_from = renda_media
      ) %>%
      arrange(Ano)
    
    # --- 2) Renda média por Formalidade, com colunas = (class_verde_atividade × Ano) ---
    renda_formal_setor_ano_wide <- dados_renda %>%
      group_by(formalidade, class_verde_atividade, Ano) %>%
      summarise(renda_media = weighted.mean(renda_hab_def, V1028, na.rm = TRUE), .groups = "drop") %>%
      pivot_wider(
        names_from  = c(class_verde_atividade, Ano),
        values_from = renda_media,
        names_sep   = "_",        # ex.: 'Agricultura_2014'
        values_fill = NA_real_
      ) %>%
      arrange(formalidade)
    
    # --- 3) Exporta para Excel com formatação moeda ---

    wb <- createWorkbook()
    aba1 <- "Renda x Class (wide)"
    aba2 <- "Renda x Setor x Ano"
    
    addWorksheet(wb, aba1)
    addWorksheet(wb, aba2)
    
    writeData(wb, aba1, renda_class_verde_wide, withFilter = TRUE)
    writeData(wb, aba2, renda_formal_setor_ano_wide, withFilter = TRUE)
    
    estilo_hdr   <- createStyle(textDecoration = "bold")
    estilo_moeda <- createStyle(numFmt = "R$ #,##0.00")
    
    # cabeçalhos
    addStyle(wb, aba1, estilo_hdr, rows = 1, cols = 1:ncol(renda_class_verde_wide), gridExpand = TRUE)
    addStyle(wb, aba2, estilo_hdr, rows = 1, cols = 1:ncol(renda_formal_setor_ano_wide), gridExpand = TRUE)
    
    # aplica moeda em todas as colunas numéricas
    cols_moeda_1 <- which(sapply(renda_class_verde_wide, is.numeric) & names(renda_class_verde_wide) != "Ano")
    cols_moeda_2 <- which(sapply(renda_formal_setor_ano_wide, is.numeric))
    
    if (length(cols_moeda_1) > 0)
      addStyle(wb, aba1, estilo_moeda, rows = 2:(nrow(renda_class_verde_wide)+1), cols = cols_moeda_1, gridExpand = TRUE)
    
    if (length(cols_moeda_2) > 0)
      addStyle(wb, aba2, estilo_moeda, rows = 2:(nrow(renda_formal_setor_ano_wide)+1), cols = cols_moeda_2, gridExpand = TRUE)
    
    setColWidths(wb, aba1, cols = 1:ncol(renda_class_verde_wide), widths = "auto")
    setColWidths(wb, aba2, cols = 1:ncol(renda_formal_setor_ano_wide), widths = "auto")
    freezePane(wb, aba1, firstActiveRow = 2, firstActiveCol = 2)
    freezePane(wb, aba2, firstActiveRow = 2, firstActiveCol = 2)
    
    openxlsx::saveWorkbook(wb, "produtos/tabelas/renda_media_class_formalidade.xlsx", overwrite = TRUE)
    

    # -------- Base filtrada --------
    dados_renda <- base_pnadc %>%
      filter(
        Ano %in% c(2014, 2024),
        !is.na(renda_hab_def),
        renda_hab_def > 0,
        !is.na(V1028)
      )
    
    # -------- Função auxiliar: Índice de Palma ponderado --------
    indice_palma <- function(x, w) {
      qs <- Hmisc::wtd.quantile(
        x,
        weights = w,
        probs = c(0.40, 0.90),
        na.rm = TRUE,
        type = "quantile"
      )
      
      p40 <- unname(qs[1])
      p90 <- unname(qs[2])
      
      if (is.na(p40) || is.na(p90) || p40 <= 0) return(NA_real_)
      
      renda_pobres <- sum(x[x <= p40] * w[x <= p40], na.rm = TRUE)
      renda_ricos  <- sum(x[x >= p90] * w[x >= p90], na.rm = TRUE)
      
      if (renda_pobres <= 0) return(NA_real_)
      
      renda_ricos / renda_pobres
    }
    
    # -------- Tabela 1: Ano x Classificação --------
    palma_class_wide <- dados_renda %>%
      group_by(Ano, class_verde_atividade) %>%
      summarise(
        palma = indice_palma(renda_hab_def, V1028),
        .groups = "drop"
      ) %>%
      pivot_wider(
        names_from  = class_verde_atividade,
        values_from = palma
      ) %>%
      arrange(Ano)
    
    # -------- Tabela 2: Formalidade x Setor x Ano --------
    palma_form_setor_ano_wide <- dados_renda %>%
      group_by(formalidade, class_verde_atividade, Ano) %>%
      summarise(
        palma = indice_palma(renda_hab_def, V1028),
        .groups = "drop"
      ) %>%
      pivot_wider(
        names_from  = c(class_verde_atividade, Ano),
        values_from = palma,
        names_sep   = "_",
        values_fill = NA_real_
      ) %>%
      arrange(formalidade)
    
    # -------- Exportação para Excel --------
    wb <- createWorkbook()
    
    aba1 <- "Palma x Class"
    aba2 <- "Palma x Setor x Ano"
    
    addWorksheet(wb, aba1)
    addWorksheet(wb, aba2)
    
    writeData(wb, aba1, palma_class_wide, withFilter = TRUE)
    writeData(wb, aba2, palma_form_setor_ano_wide, withFilter = TRUE)
    
    # -------- Estilos --------
    estilo_hdr <- createStyle(textDecoration = "bold")
    estilo_num <- createStyle(numFmt = "0.00")
    
    addStyle(wb, aba1, estilo_hdr,
             rows = 1,
             cols = 1:ncol(palma_class_wide),
             gridExpand = TRUE)
    
    addStyle(wb, aba2, estilo_hdr,
             rows = 1,
             cols = 1:ncol(palma_form_setor_ano_wide),
             gridExpand = TRUE)
    
    cols_num_1 <- which(sapply(palma_class_wide, is.numeric) &
                          names(palma_class_wide) != "Ano")
    cols_num_2 <- which(sapply(palma_form_setor_ano_wide, is.numeric))
    
    if (length(cols_num_1) > 0)
      addStyle(
        wb, aba1, estilo_num,
        rows = 2:(nrow(palma_class_wide) + 1),
        cols = cols_num_1,
        gridExpand = TRUE
      )
    
    if (length(cols_num_2) > 0)
      addStyle(
        wb, aba2, estilo_num,
        rows = 2:(nrow(palma_form_setor_ano_wide) + 1),
        cols = cols_num_2,
        gridExpand = TRUE
      )
    
    setColWidths(wb, aba1,
                 cols = 1:ncol(palma_class_wide),
                 widths = "auto")
    
    setColWidths(wb, aba2,
                 cols = 1:ncol(palma_form_setor_ano_wide),
                 widths = "auto")
    
    freezePane(wb, aba1, firstActiveRow = 2, firstActiveCol = 2)
    freezePane(wb, aba2, firstActiveRow = 2, firstActiveCol = 2)
    
    saveWorkbook(
      wb,
      "produtos/tabelas/indice_palma.xlsx",
      overwrite = TRUE
    )
    
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
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       } else if (i == "renda_percentil") {
                         base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                           summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                     Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                     Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                     Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                     Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                           filter(!is.na(class_verde_atividade)) %>% 
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       } else if (i == "renda_log_var") {
                         base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                           summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                           pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                           filter(!is.na(class_verde_atividade)) %>% 
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       } else if (i == "UF") {
                         base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>% 
                           filter(!is.na(class_verde_atividade)) %>% 
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green"))) %>% 
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
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       }
                       
                       else if (i == "renda_media") {
                         base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                           filter(!is.na(formalidade)) %>% 
                           summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>%
                           #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                           filter(!is.na(class_verde_atividade)) %>% 
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       }
                       
                       else {
                         base_pnadc %>% group_by(Ano, class_verde_atividade, !!sym(i)) %>%
                           summarise(n = sum(V1028)) %>%
                           mutate(freq = (n/sum(n))*100) %>%
                           #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                           filter(!is.na(class_verde_atividade)) %>% 
                           mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                       }
                     })

names(tabelas_class) <- names(vars_tabela)

## Por atividade -------------------------------------------------------

tabelas_ativ <- map(vars_tabela_vec,
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% filter(!is.na(V4013)) %>%  group_by(Ano, V4013, class_verde_atividade) %>%
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev)
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013, class_verde_atividade) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) 
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013, class_verde_atividade) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>% 
                          pivot_wider(names_from = Ano, values_from = renda_log_var)  
                      } else if (i == "UF") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, !!sym(i), V4013, class_verde_atividade) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup()
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, !!sym(i), V4013, class_verde_atividade) %>%
                          filter(!is.na(formalidade)) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) 
                        #pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                      }
                      
                      else if (i == "renda_media") {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013, class_verde_atividade) %>%
                          filter(!is.na(formalidade)) %>% 
                          summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>%  
                          pivot_wider(names_from = Ano, values_from = renda_media)
                      }
                      
                      else {
                        base_pnadc %>% filter(!is.na(V4013)) %>% group_by(Ano, V4013, class_verde_atividade, !!sym(i)) %>%
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
library(dplyr)
library(tidyr)
library(purrr)
library(openxlsx)
library(Hmisc)

# -------- Função auxiliar ROBUSTA: Índice de Palma ponderado --------
indice_palma <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & is.finite(x) & is.finite(w) & (w > 0)
  if (!any(ok)) return(NA_real_)
  
  x <- x[ok]
  w <- w[ok]
  if (length(x) < 2) return(NA_real_)
  
  qs <- tryCatch(
    Hmisc::wtd.quantile(
      x,
      weights = w,
      probs = c(0.40, 0.90),
      na.rm = TRUE,
      type = "quantile"
    ),
    error = function(e) rep(NA_real_, 2)
  )
  
  p40 <- unname(qs[1])
  p90 <- unname(qs[2])
  
  if (is.na(p40) || is.na(p90) || p40 <= 0) return(NA_real_)
  
  idx_pobres <- x <= p40
  idx_ricos  <- x >= p90
  if (!any(idx_pobres) || !any(idx_ricos)) return(NA_real_)
  
  renda_pobres <- sum(x[idx_pobres] * w[idx_pobres], na.rm = TRUE)
  renda_ricos  <- sum(x[idx_ricos]  * w[idx_ricos],  na.rm = TRUE)
  
  if (!is.finite(renda_pobres) || renda_pobres <= 0) return(NA_real_)
  
  renda_ricos / renda_pobres
}

tabela_demografica_palma <- function(.data,
                                     ano_inicial,
                                     ano_final,
                                     aberturas,
                                     var_ano    = "Ano",
                                     var_peso   = "V1028",
                                     var_setor  = "class_verde_atividade",  # << TROCA AQUI (default)
                                     var_renda  = "renda_hab_def",
                                     filtro     = NULL,
                                     fill_missing = TRUE,
                                     setor_em_wide = TRUE) {
  
  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))
  
  faz_bloco <- function(var_cat, lbl_abertura) {
    
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(
        palma = indice_palma(
          x = .data[[var_renda]],
          w = .data[[var_peso]]
        ),
        .groups = "drop"
      ) %>%
      rename(
        Ano = !!var_ano,
        setor = !!var_setor,
        categoria = !!var_cat
      ) %>%
      mutate(
        Ano = as.integer(Ano),
        abertura = lbl_abertura
      ) %>%
      select(abertura, Ano, setor, categoria, palma)
    
    if (fill_missing) {
      cats    <- df %>% distinct(!!sym(var_cat))   %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      
      grid <- tidyr::expand_grid(
        Ano       = as.integer(c(ano_inicial, ano_final)),
        setor     = setores,
        categoria = cats
      ) %>% mutate(abertura = lbl_abertura)
      
      bloco <- grid %>%
        left_join(bloco, by = c("abertura", "Ano", "setor", "categoria"))
    }
    
    bloco_w <- bloco %>%
      pivot_wider(
        names_from  = Ano,
        values_from = palma,
        names_prefix = "palma_"
      ) %>%
      relocate(
        any_of(c(
          paste0("palma_", ano_inicial),
          paste0("palma_", ano_final)
        )),
        .after = categoria
      )
    
    if (setor_em_wide) {
      cols_value <- c(paste0("palma_", ano_inicial),
                      paste0("palma_", ano_final))
      
      bloco_w <- bloco_w %>%
        pivot_wider(
          names_from  = setor,
          values_from = all_of(cols_value),
          names_glue  = "{setor}_{.value}"
        )
      
      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_setor_cols <- unlist(lapply(setores_ord, function(s)
        paste0(s, "_", cols_value)
      ))
      
      bloco_w <- bloco_w %>%
        select(abertura, categoria, any_of(ordem_setor_cols))
    }
    
    bloco_w
  }
  
  purrr::imap_dfr(aberturas, faz_bloco) %>%
    arrange(abertura, categoria)
}

# === EXEMPLO ===
aberturas <- c("Gênero" = "V2007",
               "Raça"   = "V2010",
               "Formalidade" = "formalidade",
               "Contribuição para prev." = "VD4012",
               "Escolaridade" = "escolaridade",
               "Faixa etária" = "faixa_etaria",
               "Urbano x Rural" = "V1022")

tabela_palma_wide <- tabela_demografica_palma(
  .data         = base_pnadc,
  ano_inicial   = 2014,
  ano_final     = 2024,
  aberturas     = aberturas,
  var_ano       = "Ano",
  var_peso      = "V1028",
  var_setor     = "class_verde_atividade",   # << e aqui explicitamente (opcional)
  var_renda     = "renda_hab_def",
  filtro        = quote(VD4002 == "Pessoas ocupadas"),
  fill_missing  = TRUE,
  setor_em_wide = TRUE
)


# Gráficos ----------------------------------------------------------------

anos_graf <- c(as.numeric(base_pnadc$Ano) %>% sort %>% head(1),as.numeric(base_pnadc$Ano) %>% sort %>% tail(1))

## Renda ------------------------------------------------------


### Boxplots agrupados ------------------------------------------------------

ggplot(tabelas_class[["renda_percentil"]] %>%
         ungroup() %>% 
         filter(Ano %in% anos_graf), aes(x = class_verde_atividade, y = Q2, fill = class_verde_atividade)) +
  geom_boxplot(aes(ymin = Min, lower = Q1, middle = Q2, upper = Q3, ymax = Max), stat = "identity") +
  facet_wrap(~Ano) +
  ylim(0,13) +
  theme_minimal() +
  theme(legend.position = "none") +
  scale_fill_manual(values = c("chocolate", "lightblue", "darkgreen")) +
  labs(x = "Green classification", y = "Income", title = paste0("Boxplot of Log Income by Green Classification (",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))
ggsave(paste0("produtos/gráficos/renda_percentil", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


### Renda Média ------------------------------------------------------

ggplot(data = base_pnadc %>% 
         select(V1028,class_verde_atividade,Ano, renda_hab_def) %>%
         filter(!is.na(class_verde_atividade)) %>% 
         group_by(Ano,class_verde_atividade) %>% 
         summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = T)) %>% 
         group_by(class_verde_atividade) %>% 
         mutate(rotulo = ifelse(Ano %in% c(2014,2024),renda_media,NA))) +
  aes(x = Ano, y = renda_media, group = class_verde_atividade, colour = class_verde_atividade) +
  geom_line(linewidth = 0.8) +
  geom_point()+
  geom_label(aes(label= round(rotulo)), size=2.5, fill = "white", color = "black")+
  scale_color_manual(values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate")) +
  theme_minimal() +
  theme(
    legend.position = "bottom"   # moves legend below the plot
  ) +
  labs(title = "Average Income by Year and Classification",
       x = "Year",
       y = "Average income",
       color = "Classification")
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
  labs(title = paste0("Logarithmic Income Histogram (",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"),
       x = "Income",
       y = "Frequency",
       fill = "Classification") +
  facet_wrap(~ factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")), ncol = 1)+
  scale_fill_manual(values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate")) +
  scale_y_log10(labels = label_number()) +
  scale_x_continuous(limits = c(0,250000))+
  theme_minimal()
ggsave(paste0("produtos/gráficos/hist_renda", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Mapas -------------------------------------------------------------------

### Mapa dos estados +- sujos --------------------------------------------------

limite <- c(
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Brown") %>% select(freq) %>% min(.),
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Brown") %>% select(freq) %>% max())  

ggplot() +
  geom_sf(data=tabelas_class[["regiao_uf"]] %>% 
            ungroup()  %>% 
            filter(Ano %in% anos_graf, class_verde_atividade == "Brown") %>%
            mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
            left_join(.,geobr::read_state(year = 2019) %>% 
                        select(name_state) %>% 
                        mutate(name_state = make_clean_names(name_state))) %>% 
            st_as_sf(), 
          aes(fill=freq), color= NA, size=.15) +
  facet_grid(~Ano) +
  labs(subtitle=paste0("Proportion of Brown Jobs by State (UF) ", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
  scale_fill_distiller(palette = "YlOrRd", name="",direction = 1, limits = limite) +
  theme_void() 

ggsave(paste0("produtos/gráficos/mapa_empregos_sujos",".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



### Mapa dos estados +- limpos --------------------------------------------------

limite <- c(
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Neutral") %>% select(freq) %>% min(),
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Neutral") %>% select(freq) %>% max())   

ggplot() +
  geom_sf(data=tabelas_class[["regiao_uf"]] %>% 
            ungroup()  %>% 
            filter(Ano %in% anos_graf, class_verde_atividade == "Neutral") %>%
            mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
            left_join(geobr::read_state(year = 2019) %>% 
                        select(name_state) %>% 
                        mutate(name_state = make_clean_names(name_state)),.) %>% 
            st_as_sf(), 
          aes(fill=freq), color= NA, size=.15) +
  facet_wrap(~Ano) +
  labs(subtitle=paste0("Proportion of Neutral Jobs by State (UF) ", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
  scale_fill_distiller(palette = "Blues", name="",direction = 1, limits = limite) +
  theme_void()
ggsave(paste0("produtos/gráficos/mapa_empregos_limpos", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



### Mapa dos estados +- verdes --------------------------------------------------

limite <- c(
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Green") %>% select(freq) %>% min(),
  tabelas_class[["regiao_uf"]] %>% 
    ungroup()  %>% 
    filter(Ano %in% anos_graf, class_verde_atividade == "Green") %>% select(freq) %>% max())   

ggplot() +
  geom_sf(data=tabelas_class[["regiao_uf"]] %>% 
            ungroup()  %>% 
            filter(Ano %in% anos_graf, class_verde_atividade == "Green") %>%
            mutate(name_state = make_clean_names(UF, allow_dupes = T)) %>% 
            left_join(geobr::read_state(year = 2019) %>% 
                        select(name_state) %>% 
                        mutate(name_state = make_clean_names(name_state)),.) %>% 
            st_as_sf(), 
          aes(fill=freq), color= NA, size=.15) +
  facet_wrap(~Ano) +
  labs(subtitle=paste0("Proportion of Green Jobs by State (UF) ", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")"), size=8) +
  scale_fill_distiller(palette = "Browns", name="",direction = 1, limits = limite) +
  theme_void()
ggsave(paste0("produtos/gráficos/mapa_empregos_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


rm(limite)


## Grandes regiões ---------------------------------------------------------

ggplot(
  data = tabelas_class[["regiao"]] %>%
    filter(Ano %in% anos_graf) %>%
    group_by(Ano, regiao) %>%
    mutate(freq = n*100/sum(n, na.rm = TRUE)),
  aes(x = regiao, y = freq, group = class_verde_atividade, fill = class_verde_atividade)
) +
  geom_col(width = 0.5, color = "black") +
  geom_label(
    aes(label= paste0(round(freq), "%")),
    position = position_stack(vjust = 0.5),
    size = 2.5, fill = "white"
  ) +
  facet_wrap(~Ano) +
  labs(
    x = "Region", y = "Prop. (%)",
    title = paste0(
      "Proportion of occupied by Region and Classification Type ",
      "(", head(anos_graf, 1), "-", tail(anos_graf, 1), ")"
    ),
    fill = "Classification type"
  ) +
  scale_fill_manual(
    values = c(
      "Green" = "#1b9e77",
      "Brown" = "#d95f02",
      "Neutral" = "#7570b3"
      # adicione todas as categorias reais de class_verde_atividade
    )
  )  
ggsave(paste0("produtos/gráficos/regiao_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Ocupados -----------------------------------------------------------------

### Evolução da qtd de ocupados por tipo de classificação -------------------

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "Green") %>% 
         select(!class_verde_atividade) %>% 
         ungroup()) +
  aes(x = Ano, y = n, group = 1)+
  geom_point(color = "darkgreen")+
  geom_line(color = "darkgreen")+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados em ocupações verdes")
ggsave(paste0("produtos/gráficos/qtd_ocupados_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "Neutral") %>% 
         select(!class_verde_atividade) %>% 
         ungroup()) +
  aes(x = Ano, y = n, group = 1)+
  geom_point(color = "lightblue")+
  geom_line(color = "lightblue")+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade de ocupados", title = "Qtd de ocupados em ocupações Neutrals")
ggsave(paste0("produtos/gráficos/qtd_ocupados_Neutrals", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         filter(class_verde_atividade == "Brown") %>% 
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

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)),
       aes(x = Ano, y = n, color = class_verde_atividade, group = class_verde_atividade))+
  geom_line(linewidth = 1)+
  geom_point(size = 2)+
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  theme_minimal() +
  scale_color_manual(name = "Classification",values = c("Brown" = "chocolate", "Neutral" = "lightblue", "Green" = "darkgreen"))+
  labs(x = "Year", y = "Number of Employed Persons", title = "Number of Employed Persons by Classification")
ggsave(paste0("produtos/gráficos/qtd_ocupados_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



### Evolução da proporção de ocupados em cada classif ---------------------------------

#Acho que o ideal seria usar a VD4002, mas vamos usar os NAs da VD4009 como proxy para desocupados

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(!is.na(formalidade)) %>% 
         summarise(n = sum(n)) %>%
         mutate(freq = (n/sum(n))*100) %>% 
         ungroup())  +
  aes(x = Ano, y = freq, fill = class_verde_atividade, group = class_verde_atividade) + 
  geom_bar(position = "stack",  stat="identity", color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  theme_minimal() +
  labs(x = "Ano", y = "Prop.", title = "Proportion of Employed Persons by Classification")+
  scale_fill_manual(name = "Classification",values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate"))
ggsave(paste0("produtos/gráficos/prop_ocupados_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_class[["ocupacao"]] %>% 
         filter(Ano %in% anos_graf,
                !is.na(formalidade)) %>% 
         mutate(freq = n/sum(n)*100)) +
  aes(x = class_verde_atividade, y = freq, fill = formalidade, group = formalidade) +
  geom_col(width = 0.5, color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~Ano) +
  labs(x = "Classification", y = "Prop. (%)", fill = "Employment formality", title = paste0("Proportion of Employed Persons by Employment Formality ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))+
  scale_fill_discrete(labels = c(
    "Formal" = "Formal",
    "Informal - Sem carteira" = "Informal - Self-employed",
    "Informal - Conta própria" = "Informal - Employee",
    "Informal - Sem carteira" = "Informal - Without a formal contract",
    "Ocupado sem informação" = "Worker without information"))

ggsave(paste0("produtos/gráficos/prop_formalidade_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



## Arvore de ocupações ---------------------------------

ggplot(base_pnadc %>% 
         select(cnaedom_nome,formalidade,Ano,V1028, class_verde_atividade, setor_cnae20_nome) %>% 
         filter(!is.na(formalidade),
                class_verde_atividade == "Brown",
                Ano == 2024) %>% 
         group_by(setor_cnae20_nome, cnaedom_nome) %>% 
         summarise(qtd = round(sum(V1028))) %>%
         ungroup() %>% 
         mutate(pct = sprintf("%d%%",round(qtd/round(sum(qtd))* 100)),
                rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", "\n", "(", pct, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
  geom_treemap()+ 
  labs(caption = paste("Total: ",base_pnadc %>% 
                         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
                         filter(!is.na(formalidade),
                                class_verde_atividade == "Brown",
                                Ano == 2024) %>%
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
                class_verde_atividade == "Neutral",
                Ano == 2024) %>% 
         group_by(setor_cnae20_nome, cnaedom_nome) %>% 
         summarise(qtd = round(sum(V1028))) %>%
         ungroup() %>% 
         mutate(pct = sprintf("%d%%",round(qtd/round(sum(qtd))* 100)),
                rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", "\n", "(", pct, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
  geom_treemap()+ 
  labs(caption = paste("Total: ",base_pnadc %>% 
                         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
                         filter(!is.na(formalidade),
                                class_verde_atividade == "Neutral",
                                Ano == 2024) %>%
                         summarise(qtd = round(sum(V1028)))))+
  theme(legend.position = "none",
        plot.caption = element_text(size = 25, hjust = 0))+
  geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                    grow = F, reflow = T)+
  geom_treemap_subgroup_border()
ggsave(paste0("produtos/gráficos/arvore_ocup_Neutrals", ".png"), plot = last_plot(), bg = "white",dpi = 800, width = 12, height = 8)

ggplot(base_pnadc %>% 
         select(cnaedom_nome,formalidade,Ano,V1028, class_verde_atividade, setor_cnae20_nome) %>% 
         filter(!is.na(formalidade),
                class_verde_atividade == "Green",
                Ano == 2024) %>% 
         group_by(setor_cnae20_nome, cnaedom_nome) %>% 
         summarise(qtd = round(sum(V1028))) %>%
         ungroup() %>% 
         mutate(pct = sprintf("%d%%",round(qtd/round(sum(qtd))* 100)),
                rotulo = paste(cnaedom_nome, "\n", "(", qtd, ")", "\n", "(", pct, ")", sep = "")),
       aes(area = qtd, fill = setor_cnae20_nome, label = rotulo, subgroup = setor_cnae20_nome))+
  geom_treemap()+
  labs(caption = paste("Total: ",base_pnadc %>% 
                         select(formalidade,Ano,V1028, class_verde_atividade) %>% 
                         filter(!is.na(formalidade),
                                class_verde_atividade == "Green",
                                Ano == 2024) %>%
                         summarise(qtd = round(sum(V1028)))))+
  theme(legend.position = "none",
        plot.caption = element_text(size = 25, hjust = 0))+
  geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                    grow = F, reflow = T)+
  geom_treemap_subgroup_border()
ggsave(paste0("produtos/gráficos/arvore_ocup_verdes", ".png"), plot = last_plot(), bg = "white",dpi = 800, width = 12, height = 8)


## Formalidade -------------------------------------------------------------

ggplot(data = tabelas_class[["ocupacao"]] %>% 
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

ggplot(data = tabelas_class[["cor"]] %>%
         filter(Ano %in% anos_graf,
                V2010 != "Ignorado"))+
  aes(x = class_verde_atividade, y = freq, fill = V2010, group = V2010) +
  geom_col(width = 0.5, color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~Ano) +
  labs(x = "Classification", y = "Prop. (%)", fill = "Color", title = paste0("Proportion of Employed Persons by Race/Color and Classification", "(",head(anos_graf, n = 1), " - ", tail(anos_graf, n = 1),")")) +
  scale_fill_discrete(labels = c(
    "Brancos e Amarelos"   = "White and Yellow",
    "Pretos, Pardos e Indígenas"    = "Black and Indigenous"))
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
  labs(x = "Classification", y = "Prop. (%)", fill = "Education", title = paste0("Proportion of Employed Persons by Educational Attainment ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")")) +
  scale_fill_discrete(labels = c(
    "Fundamental Incompleto" = "Incomplete Primary Education",
    "Fundamental Completo"  = "Complete Primary Education",
    "Médio Completo"        = "Complete Secondary Education",
    "Superior Completo"     = "Complete Higher Education"))
ggsave(paste0("produtos/gráficos/prop_esc_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



ggplot(data = tabelas_class[["escolaridade_anos"]] %>%
         mutate(VD3005 = str_sub(VD3005,1,2)) %>% 
         mutate(VD3005 = ifelse(VD3005 == "Se", 0, VD3005)) %>% 
         mutate(VD3005 = as.integer(VD3005)) %>%
         group_by(Ano, class_verde_atividade) %>% 
         summarise(ano_medio_escolaridade = weighted.mean(VD3005, n)) %>% 
         ungroup() %>% 
         mutate(Classificação = case_when(
           class_verde_atividade == "Green" ~ "darkgreen",
           class_verde_atividade == "Neutral" ~ "lightblue",
           class_verde_atividade == "Brown" ~ "chocolate")) %>% 
         group_by(class_verde_atividade) %>% 
         mutate(rotulo = ifelse(Ano %in% c(2014,2024),ano_medio_escolaridade,NA))) +
  aes(x = Ano, y = ano_medio_escolaridade, group = Classificação, color = Classificação) + 
  geom_point(size = 2)+
  geom_line(linewidth = 1)+
  geom_label(aes(label= round(rotulo)), size=2.5, fill = "white", color = "black")+
  theme_minimal()+
  labs(x = "Year", y = "Average Years of Schooling", color = "Classification", title = "Average Years of Schooling of Employed Persons by Classification Type")+
  scale_color_identity(labels = c(darkgreen = "Green", lightblue = "Neutral", chocolate = "Brown"), guide = "legend")
ggsave(paste0("produtos/gráficos/escolaridade_media_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


## Região Metrop ---------------------------------

ggplot(data = tabelas_class[["regiao_metrop"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "fill",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  
  facet_grid(~regiao_metrop)+
  labs(x = "Year", y = "Proportion", title = "Proportion of Employed Persons by Metropolitan Region")+
  scale_fill_manual(name = "Classification",values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate"))
ggsave(paste0("produtos/gráficos/prop_regiao_metrop_barra", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


ggplot(data = tabelas_class[["regiao_metrop"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "dodge",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  
  facet_grid(~regiao_metrop)+
  labs(x = "Ano", y = "Quantidade", title = "Quantidade de ocupados segundo região metropolitana")+
  scale_fill_manual(name = "Classificação Verde",values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_regiao_metrop_barra_lado", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Urbano Rural ---------------------------------

ggplot(data = tabelas_class[["regiao_urbano_rural"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_col(colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  facet_grid(~V1022, labeller = label_bquote(paste0("teste",.(regiao_metrop))))+
  theme_minimal() +
  labs(x = "Ano", y = "Quantidade", title = "Quantidade de ocupados segundo tipo da região (urbano x rural)")+
  scale_fill_manual(name = "Classificação Verde",values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_regiao_urbano_rural_empilhado", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)



ggplot(data = tabelas_class[["regiao_urbano_rural"]] %>%
         filter(Ano %in% anos_graf))+
  aes(x = Ano, y = n, fill = class_verde_atividade) +
  geom_bar(stat = "identity",
           position = "dodge",
           colour = "black") +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  facet_grid(~V1022)+
  labs(x = "Ano", y = "Count", title = "Number of Employed Persons by Area Type (Urban vs. Rural)")+
  scale_fill_manual(name = "Classificação Verde",values = c("Green" = "darkgreen", "Neutral" = "lightblue", "Brown" = "chocolate"))
ggsave(paste0("produtos/gráficos/qtd_urbano_rural_barra", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Idade ---------------------------------

ggplot(data = tabelas_class[["idade"]] %>% 
         summarise(idade_media = weighted.mean(V2009, n)) %>%
         ungroup() %>% 
         mutate(Classificação = case_when(
           class_verde_atividade == "Green" ~ "darkgreen",
           class_verde_atividade == "Neutral" ~ "lightblue",
           class_verde_atividade == "Brown" ~ "chocolate")
         )
) +
  aes(x = Ano, y = idade_media, group = class_verde_atividade, color = Classificação)+ 
  geom_point(size = 2)+
  geom_line(linewidth = 1)+
  labs(x = "Year", y = "Average Age", title = "Average Age of Employed Persons by Classification Type", color = "Classification")+
  scale_color_identity(labels = c(darkgreen = "Green", lightblue = "Neutral", chocolate = "Brown"), guide = "legend")
ggsave(paste0("produtos/gráficos/idade_media_por_classif", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)

## Genero ---------------------------------

ggplot(data = tabelas_class[["genero"]] %>%
         filter(Ano %in% anos_graf),
       aes(x = class_verde_atividade, y = freq, group = V2007, fill = V2007)) +
  geom_col(width = 0.5, color = "black")+
  geom_label(aes(label= paste0(round(freq), "%")), position=position_stack(vjust=0.5), size=2.5, fill = "white")+
  facet_wrap(~Ano) +
  labs(x = "Classification", y = "Prop. (%)", title = paste0("Proportion of Men and Women by Classification Type ", "(",head(anos_graf, n =1), "-", tail(anos_graf, n = 1),")"))+
  scale_fill_manual(name = "Gender",values = c("Homem" = "lightgreen", "Mulher" = "purple3"),labels = c(
     "Homem" = "Man", 
     "Mulher" = "Woman"))
ggsave(paste0("produtos/gráficos/prop_genero_classif_alterna", ".png"), plot = last_plot(), bg = "white",dpi = 600, width = 8, height = 6)


# Matriz ocup-ativ --------------------------------------------------------

base_pnadc %>% filter(Ano == 2024) %>% 
  tabyl(class_verde_setor, class_verde_ocup) %>% write.xlsx(., file = "teste2.xlsx")

xtabs(formula = V1028 ~ setor_cnae20_nome + class_verde_ocup,
      data = base_pnadc %>% filter(Ano == 2012)) %>% 
  as.data.frame %>% 
  pivot_wider(names_from = class_verde_ocup, values_from = Freq) %>%
  mutate(across(.cols = c("Green","nao_verde"), function(x) x/rowSums(.[-1]), .names = "prop_{.col}")) %>% 
  rename_with(.cols = ends_with("Green"), .fn = function(x) paste(x, "2012", sep = "_")) %>% full_join(.,
                                                                                                       
                                                                                                       (xtabs(formula = V1028 ~ setor_cnae20_nome + class_verde_ocup,
                                                                                                              data = base_pnadc %>% filter(Ano == 2022)) %>% 
                                                                                                          as.data.frame %>% 
                                                                                                          pivot_wider(names_from = class_verde_ocup, values_from = Freq) %>%
                                                                                                          mutate(across(.cols = c("Green","nao_verde"), function(x) x/rowSums(.[-1]), .names = "prop_{.col}")) %>% 
                                                                                                          rename_with(.cols = ends_with("Green"), .fn = function(x) paste(x, "2022", sep = "_"))
                                                                                                        
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
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% group_by(Ano, class_verde_atividade) %>%
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                      } else if (i == "UF") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_atividade) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green"))) %>% 
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
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
                      }
                      
                      else {
                        base_pnadc %>% group_by(Ano, class_verde_atividade, !!sym(i)) %>%
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          pivot_wider(names_from = i, values_from = c(n, freq)) %>% 
                          filter(!is.na(class_verde_atividade)) %>% 
                          mutate(class_verde_atividade = factor(class_verde_atividade, levels = c("Brown", "Neutral", "Green")))
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

tabelas_ocup <- map(vars_tabela_vec[1:10],
                    function(i) {
                      if (i == "renda_log_dev") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2014,2024)) %>% 
                          summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_dev) %>% 
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde"))) 
                      } else if (i == "renda_percentil") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2014,2024)) %>% 
                          summarise(Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = T)),
                                    Q1 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = T)),
                                    Q2 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = T)),
                                    Q3 = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = T)),
                                    Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = T))) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde"))) 
                      } else if (i == "renda_log_var") {
                        base_pnadc %>% group_by(Ano, class_verde_ocup) %>% filter(Ano %in% c(2014,2024)) %>% 
                          summarise(renda_log_var = as.vector((weighted.var(log(renda_hab_def),w = V1028, na.rm = T)))) %>%
                          pivot_wider(names_from = Ano, values_from = renda_log_var) %>% 
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde")))
                      } else if (i == "regiao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_ocup) %>% filter(Ano %in% c(2014,2024)) %>%  
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde"))) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>% 
                          ungroup() %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                      
                      else if (i == "ocupacao") {
                        base_pnadc %>% group_by(Ano, !!sym(i), class_verde_ocup) %>% filter(Ano %in% c(2014,2024)) %>% 
                          filter(!is.na(formalidade))
                        summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde"))) %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                      
                      else {
                        base_pnadc %>% group_by(Ano, class_verde_ocup, !!sym(i)) %>% filter(Ano %in% c(2014,2024)) %>% 
                          summarise(n = sum(V1028)) %>%
                          mutate(freq = (n/sum(n))*100) %>%
                          filter(!is.na(class_verde_ocup)) %>% 
                          mutate(class_verde_ocup = factor(class_verde_ocup, levels = c("Green", "nao_verde"))) %>% 
                          pivot_wider(., names_from = c(Ano, class_verde_ocup), values_from = c(n, freq))
                      }
                    })

names(tabelas_ocup) <- names(vars_tabela[1:10])

tabela_demo <- tabelas_ocup[1:10] %>% 
  list_rbind(names_to = "caracteristica") %>% 
  mutate(V2009 = as.character(V2009),
         descricao = coalesce(V2007, V2010, formalidade, VD3004, VD3005, V2009, V1022, regiao_metrop, UF, regiao)) %>% 
  select(caracteristica, descricao, everything(), -c(V2007, V2010, formalidade, VD3004, VD3005, V2009, V1022, regiao_metrop, UF,regiao)) %>%
  filter(!(caracteristica %in% c("escolaridade_anos", "idade", "regiao_uf")))

tabela_demo_expo <- tabela_demo %>% 
  group_by(caracteristica) %>% 
  gt::gt(rowname_col = "descricao") %>% 
  tab_spanner(label = "2014",columns = c(n_2014_nao_verde, n_2014_verde, freq_2014_nao_verde, freq_2014_verde)) %>% 
  tab_spanner(label = "2024",columns = c(n_2024_nao_verde, n_2024_verde, freq_2024_nao_verde, freq_2024_verde)) %>% 
  cols_label(n_2014_nao_verde = html("Qtd. Empregos <br>Não-Verdes"),
             n_2014_verde = html("Qtd. Empregos <br>Verdes"),
             freq_2014_nao_verde = html("% Empregos <br>Não-Verdes"),
             freq_2014_verde = html("% Empregos <br>Verdes"),
             n_2024_nao_verde = html("Qtd. Empregos <br>Não-Verdes"),
             n_2024_verde = html("Qtd. Empregos <br>Verdes"),
             freq_2024_nao_verde = html("% Empregos <br>Não-Verdes"),
             freq_2024_verde = html("% Empregos <br>Verdes")) %>% 
  fmt_number(columns = starts_with("n"), scale_by = 0.000001, decimals = 2) %>% 
  fmt_number(columns = starts_with("freq"), decimals = 2) %>%
  text_replace("NA","-", locations = cells_body()) %>% 
  text_transform(fn = function(x) paste(x, "mi", sep = " "), locations = cells_body(columns = starts_with("n_"))) %>% 
  text_transform(fn = function(x) paste(x, "%", sep = ""), locations = cells_body(columns = starts_with("freq"))) %>% 
  gt::gtsave(., "produtos/tabelas/tabela_demo.png")


write.xlsx(tabelas_ocup, 
           file = "produtos/tabelas/tabelas_ocup.xlsx", 
           keepNA = T,
           overwrite = T,
           colWidths = "auto",
           digits = 2)
