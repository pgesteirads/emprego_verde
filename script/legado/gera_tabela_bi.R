library(dplyr)
library(tidyr)
library(purrr)

df <- arrow::read_parquet("base_pnadc_2014_2024_SCN.parquet")

wmean_safe <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

empilha_indicadores_verde_multiloc <- function(df,
                                               tipo_aberturas,
                                               peso_col = "V1028",
                                               renda_col = "renda_hab_def",
                                               incluir_sem_classif = TRUE) {
  
  # base padronizada
  df2 <- df %>%
    mutate(
      Ano = as.character(.data[["Ano"]]),
      UF_nome = as.character(.data[["UF"]]),
      uf_cod = as.integer(.data[["uf"]]),
      class_verde_atividade = as.character(.data[["class_verde_atividade"]]),
      .peso = as.numeric(.data[[peso_col]]),
      .renda = as.numeric(.data[[renda_col]])
    )
  
  if (incluir_sem_classif) {
    df2 <- df2 %>%
      mutate(class_verde_atividade = ifelse(is.na(class_verde_atividade) | class_verde_atividade == "",
                                            "Sem classificação",
                                            class_verde_atividade))
  } else {
    df2 <- df2 %>% filter(!is.na(class_verde_atividade), class_verde_atividade != "")
  }
  
  # Grande Região via 1º dígito do código da UF (11..17, 21..29, 31..35, 41..43, 50..53)
  df2 <- df2 %>%
    mutate(
      reg_dig = substr(sprintf("%02d", uf_cod), 1, 1),
      GrandeRegiao = case_when(
        reg_dig == "1" ~ "Norte",
        reg_dig == "2" ~ "Nordeste",
        reg_dig == "3" ~ "Sudeste",
        reg_dig == "4" ~ "Sul",
        reg_dig == "5" ~ "Centro-Oeste",
        TRUE ~ NA_character_
      )
    )
  
  calc_nivel <- function(df_in, localidade_vec, nivel_tag) {
    
    df_loc <- df_in %>%
      mutate(
        localidade = localidade_vec,
        nivel_localidade = nivel_tag
      ) %>%
      filter(!is.na(localidade), localidade != "")
    
    # denominador da "economia total" por ano/localidade
    tot_economia <- df_loc %>%
      group_by(Ano, nivel_localidade, localidade) %>%
      summarise(ocupados_economia = sum(.peso, na.rm = TRUE), .groups = "drop")
    
    # loop por tipo de abertura (evita pivot_longer na base inteira)
    res <- map_dfr(tipo_aberturas, function(var) {
      df_loc %>%
        mutate(
          tipo_abertura = var,
          abertura = as.character(.data[[var]])
        ) %>%
        filter(!is.na(abertura), abertura != "") %>%
        group_by(Ano, nivel_localidade, localidade, tipo_abertura, abertura, class_verde_atividade) %>%
        summarise(
          ocupados = sum(.peso, na.rm = TRUE),
          renda_media = wmean_safe(.renda, .peso),
          .groups = "drop"
        ) %>%
        group_by(Ano, nivel_localidade, localidade, tipo_abertura, abertura) %>%
        mutate(prop_no_grupo = ocupados / sum(ocupados, na.rm = TRUE)) %>%
        ungroup() %>%
        left_join(tot_economia, by = c("Ano", "nivel_localidade", "localidade")) %>%
        mutate(prop_economia = ocupados / ocupados_economia) %>%
        select(Ano, nivel_localidade, localidade, tipo_abertura, abertura,
               class_verde_atividade, ocupados, prop_no_grupo, prop_economia, renda_media)
    })
    
    res
  }
  
  # 3 níveis: UF, Grande Região, Brasil
  res_uf <- calc_nivel(df2, localidade_vec = df2$UF_nome, nivel_tag = "UF")
  res_gr <- calc_nivel(df2, localidade_vec = df2$GrandeRegiao, nivel_tag = "Grande Regiao")
  res_br <- calc_nivel(df2, localidade_vec = rep("Brasil", nrow(df2)), nivel_tag = "Brasil")
  
  res_all <- bind_rows(res_uf, res_gr, res_br)
  
  # empilha indicadores em 1 coluna "valor"
  res_long <- res_all %>%
    pivot_longer(
      cols = c(ocupados, prop_no_grupo, prop_economia, renda_media),
      names_to = "indicador",
      values_to = "valor"
    )
  
  res_long
}

# ---- EXEMPLO ----
tipo_aberturas <- c("faixa_etaria", "escolaridade","formalidade","V2007","V2010", "SCN", "setor_cnae20_nome")
# (evite "idade" se não quiser uma explosão de cardinalidade)

base_final <- empilha_indicadores_verde_multiloc(
  df = base_pnadc,
  tipo_aberturas = tipo_aberturas,
  peso_col = "V1028",
  renda_col = "renda_hab_def"
)

base_final
# colunas:
# Ano | nivel_localidade | localidade | tipo_abertura | abertura | class_verde_atividade | indicador | valor

# ---- SE VOCÊ PRECISA “EXATAMENTE” 5 COLUNAS ----
base_5cols <- base_final %>%
  mutate(tipo_abertura = paste(nivel_localidade, tipo_abertura, class_verde_atividade, indicador, sep = " | ")) %>%
  select(Ano, localidade, tipo_abertura, abertura, valor)

base_5cols %>% writexl::write_xlsx(., "possibilidade para o BI.xlsx")
