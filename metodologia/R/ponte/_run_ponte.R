# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - SCRIPT MESTRE
# ==============================================================================
# Leva o indice de esverdeamento das ocupacoes da CBO 2002 para os grupos da
# COD usados na PNAD Continua. Uso, a partir da raiz do projeto:
#
#     source("metodologia/R/ponte/_run_ponte.R")
#
# Nota metodologica: metodologia/Nota_metodologica_ponte_CBO_COD.docx
# ==============================================================================

local({
  base <- file.path("metodologia", "R")
  for (a in c("00_config.R", "funcoes.R", "01_extrair_insumos.R", "02_ler_corpus.R",
              "03_gerar_candidatos.R", "04_rotulagem.R", "05_calcular_indice.R")) {
    source(file.path(base, a), encoding = "UTF-8", local = globalenv())
  }
  for (a in c("01_extrair_insumos_ponte.R", "02_pesos_rais.R", "03_construir_ponte.R",
              "04_validar_ponte.R")) {
    source(file.path(base, "ponte", a), encoding = "UTF-8", local = globalenv())
  }
})
