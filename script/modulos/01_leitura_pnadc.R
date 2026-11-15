###############################################################################
#                                                                             #
#   EMPREGO VERDE - 01. LEITURA DOS MICRODADOS DA PNADc                       #
#                                                                             #
#   Define ler_pnadc_trimestral(): lê os microdados brutos da PNADc e salva   #
#   em formato parquet. Rode APENAS se os parquets ainda não existirem.       #
#                                                                             #
#   Dependências: 00_config.R (CAMINHO_MICRODADOS_TRIM, CAMINHO_PNADC_TRIM).  #
#   Origem: emprego_verde_consolidado.R, seção 1.                             #
#                                                                             #
###############################################################################

# --- Leitura PNADc Trimestral (4o trimestre) ---

ler_pnadc_trimestral <- function(anos = 2012:2024,
                                 caminho_microdados = CAMINHO_MICRODADOS_TRIM,
                                 caminho_saida = CAMINHO_PNADC_TRIM) {

  lista_arquivos <- list.files(path = caminho_microdados, full.names = TRUE)

  arquivos_input <- lista_arquivos[str_detect(lista_arquivos, "(?=.*txt)(?=.*input)")]
  arquivos_dict  <- lista_arquivos[str_detect(lista_arquivos, "(?=.*dicionario)")]

  for (ano in anos) {
    arquivo_saida <- glue("{caminho_saida}/pnadc_04{ano}.parquet")
    if (file.exists(arquivo_saida)) {
      message(glue("  [SKIP] {arquivo_saida} já existe."))
      next
    }

    message(glue("  Lendo PNADc trimestral {ano}..."))

    arquivos_micro <- lista_arquivos[
      !str_detect(lista_arquivos, "input") &
        str_detect(lista_arquivos, sprintf("PNADC_\\d{2}%s\\.txt$", ano))
    ]

    df <- read_pnadc(microdata = arquivos_micro, input_txt = arquivos_input) %>%
      pnadc_labeller(dictionary.file = arquivos_dict)

    arrow::write_parquet(df, arquivo_saida)
    message(glue("  [OK] Salvo: {arquivo_saida}"))
  }
}

# DESCOMENTE para executar a leitura (necessário apenas na primeira vez):
# ler_pnadc_trimestral()
