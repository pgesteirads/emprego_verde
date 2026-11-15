###############################################################################
#                                                                             #
#   EMPREGO VERDE - 02. GERAÇÃO DAS CLASSIFICAÇÕES VERDES                     #
#                                                                             #
#   Define as funções que geram/carregam as classificações verdes:           #
#     - gerar_classificacao_verde_cnae()  : atividades (CNAE), via RAIS/BQ    #
#     - carregar_classificacao_verde_cbo(): ocupações (CBO), Caruso 2010      #
#                                                                             #
#   Dependências: 00_config.R (CLASS_ESCOLHIDA, CAMINHO_DADOS_*).             #
#   Origem: emprego_verde_consolidado.R, seção 2.                             #
#                                                                             #
###############################################################################

# --- 2a. Classificação verde das atividades (CNAE) ---
# Gera a tabela classif_cnae_verde.xlsx a partir da planilha de harmonização
# e dados da RAIS (BigQuery). Rode apenas se o arquivo não existir.

gerar_classificacao_verde_cnae <- function(class_escolhida = CLASS_ESCOLHIDA,
                                           anos_rais = c(2012, 2016, 2019, 2021)) {

  arquivo_saida <- file.path(CAMINHO_DADOS_FINAL, "classif_cnae_verde.xlsx")

  if (file.exists(arquivo_saida)) {
    message("  [SKIP] classif_cnae_verde.xlsx já existe.")
    return(read_xlsx(arquivo_saida))
  }

  message("  Gerando classificação verde CNAE...")

  # --- Puxar dados da RAIS via BigQuery ---
  arquivo_rais <- file.path(CAMINHO_DADOS_FINAL, "rais_vinculos.csv")

  if (file.exists(arquivo_rais)) {
    rais_vinculos <- read.csv(arquivo_rais) %>% select(-X)
  } else {
    message("    Conectando ao BigQuery para baixar RAIS...")
    con_rais <- dbConnect(bigquery(),
                          project = "basedosdados",
                          dataset = "br_me_rais",
                          billing = "emprego-verde")

    rais_microdados <- tbl(con_rais, "microdados_vinculos")

    rais_vinculos <- rais_microdados %>%
      select(ano, vinculo_ativo_3112, cnae_2_subclasse) %>%
      filter(ano %in% anos_rais, vinculo_ativo_3112 == 1) %>%
      group_by(ano, cnae_2_subclasse) %>%
      summarise(qtd_emprego = n()) %>%
      collect()

    # Converter subclasse (7 dígitos) para atividade (5 dígitos)
    rais_vinculos <- rais_vinculos %>%
      mutate(cnae_2_subclasse = str_extract(cnae_2_subclasse, "^\\d{5}")) %>%
      group_by(ano, cnae_2_subclasse) %>%
      summarise(qtd_emprego = sum(qtd_emprego)) %>%
      ungroup() %>%
      pivot_wider(names_from = ano, values_from = qtd_emprego, names_glue = "qtd_emprego_{ano}")

    write.csv(rais_vinculos, arquivo_rais)
  }

  # --- Ler e processar classificações verdes ---
  todas_classificacoes <- c("class_verde_cnae20", "class_verde_cnae20_alternativo",
                            "class_verde_cnae20_alternativo_adm_pub", "class_verde_definitiva")
  classificacoes_remover <- setdiff(todas_classificacoes, class_escolhida)

  class_verde_cnae20 <- read_xlsx(
    path = file.path(CAMINHO_DADOS_ORIGINAL, "Harmonizacao.xlsx"),
    col_names = TRUE,
    sheet = "ativ_cnaedom X ativ_cnae20"
  ) %>%
    select(-OBS, -all_of(classificacoes_remover)) %>%
    mutate(cnae20_atividade_codigo = str_replace_all(cnae20_atividade_codigo, "[-.]", "")) %>%
    rename("class_verde_cnae20" = all_of(class_escolhida))

  # Guardar info de setor antes de desduplicar

  class_verde_setor_cnae20 <- class_verde_cnae20 %>%
    select(V4013, cnae20_atividade_codigo, setor_cnae20_cod, setor_cnae20)

  # --- Resolver atividades duplicadas com classificações divergentes ---
  # Critério: manter a classificação da atividade com maior qtd de emprego

  class_verde_cnae20 <- class_verde_cnae20 %>%
    group_by(V4013, CNAE20.DOMICILIO.NOME) %>%
    mutate(cnae20_atividade_codigo = as.numeric(cnae20_atividade_codigo)) %>%
    left_join(rais_vinculos, by = c("cnae20_atividade_codigo" = "cnae_2_subclasse"))

  colunas_emprego <- names(rais_vinculos)[str_detect(names(rais_vinculos), "qtd_emprego")]
  primeira_coluna_per <- paste0(colunas_emprego[1], "_per")

  class_verde_cnae20 <- class_verde_cnae20 %>%
    mutate(across(all_of(colunas_emprego),
                  ~ (.x / sum(.x, na.rm = TRUE)) * 100,
                  .names = "{col}_per")) %>%
    group_by(V4013) %>%
    slice_max(order_by = !!sym(primeira_coluna_per))

  # --- Classificar setores ---
  class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>%
    left_join(class_verde_cnae20 %>%
                select(V4013, class_verde_cnae20, all_of(colunas_emprego))) %>%
    select(-V4013) %>%
    distinct() %>%
    group_by(setor_cnae20_cod, setor_cnae20, class_verde_cnae20) %>%
    summarise(across(all_of(colunas_emprego), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
    filter(!is.na(!!sym(colunas_emprego[1]))) %>%
    group_by(setor_cnae20_cod) %>%
    slice_max(order_by = !!sym(colunas_emprego[1]))

  # --- Montar tabela final cnae_verde ---
  cnae_verde <- read_xlsx(
    path = file.path(CAMINHO_DADOS_ORIGINAL, "Harmonizacao.xlsx"),
    col_names = TRUE,
    sheet = "class_verde_cnaedom"
  ) %>%
    left_join(
      class_verde_cnae20 %>%
        select(V4013, class_verde_cnae20) %>%
        rename(class_verde_atividade = class_verde_cnae20),
      by = c("cnaedom_cod" = "V4013")
    ) %>%
    left_join(
      class_verde_setor_cnae20 %>%
        select(setor_cnae20_cod, class_verde_cnae20) %>%
        rename(class_verde_setor = class_verde_cnae20),
      by = "setor_cnae20_cod"
    ) %>%
    select(-class_verde_cnaedom, -class_verde_setor_cnae20) %>%
    relocate(class_verde_atividade, .before = setor_cnae20_cod)

  write_xlsx(cnae_verde, path = arquivo_saida)
  message(glue("  [OK] Salvo: {arquivo_saida}"))

  return(cnae_verde)
}


# --- 2b. Classificação verde das ocupações (CBO) ---
# Baseada em Caruso (2010). Retorna tabela de CBO domiciliar x classificação verde.

carregar_classificacao_verde_cbo <- function() {
  tab_caruso <- import(
    file.path(CAMINHO_DADOS_ORIGINAL, "cbodom_classverde_caruso.xlsx"),
    col_types = c("text", "text")
  ) %>%
    clean_names() %>%
    mutate(cod_ocupacao = str_sub(cod_ocupacao, 1, 4))

  return(tab_caruso)
}
