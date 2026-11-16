# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - 01. EXTRACAO DOS INSUMOS
# ==============================================================================
#
# Roda UMA VEZ (ou com FORCAR_PONTE <- TRUE). Grava em
# metodologia/insumos/ponte/, versionado no git:
#
#   cbo2002_ciuo88.csv   ligacao de cada ocupacao da CBO 2002 a um grupo da
#                        CIUO-88, pela tabua oficial CBO 2002 x CBO 94 x
#                        CIUO-88 (MTE), tal como sistematizada na base
#                        analise_cbo_onnet/Base_CBO2002_x_ONET-SOC.xlsx
#                        (aba Crosswalk_completo). TIPO_LIGACAO indica se a
#                        ligacao e da propria ocupacao ou herdada da familia.
#   ciuo88_isco08.csv    tabela de correspondencia oficial da OIT entre a
#                        CIUO-88 (ISCO-88) e a ISCO-08, com a marca de
#                        correspondencia parcial ("p").
#
# As tabelas de ligacao manual (ligacoes_manuais_familia.csv e
# ligacoes_manuais_cod.csv) sao escritas a mao e nao sao geradas aqui.
# ==============================================================================

if (!exists("FORCAR_PONTE")) FORCAR_PONTE <- FALSE
etapa("Ponte 01. Extracao dos insumos")

DIR_PONTE_INS <- file.path(CAMINHOS$insumos, "ponte")
dir.create(DIR_PONTE_INS, showWarnings = FALSE, recursive = TRUE)
ARQ_PONTE <- list(
  cbo_ciuo   = file.path(DIR_PONTE_INS, "cbo2002_ciuo88.csv"),
  ciuo_isco  = file.path(DIR_PONTE_INS, "ciuo88_isco08.csv"),
  manual_fam = file.path(DIR_PONTE_INS, "ligacoes_manuais_familia.csv"),
  manual_cod = file.path(DIR_PONTE_INS, "ligacoes_manuais_cod.csv"),
  rotulos_cod = file.path(DIR_PONTE_INS, "cod_rotulos_brasileiros.csv")
)

if (all(file.exists(unlist(ARQ_PONTE[c("cbo_ciuo", "ciuo_isco")]))) && !FORCAR_PONTE) {
  cat("insumos da ponte ja existem; extracao dispensada.\n")
} else {
  cw <- as.data.frame(readxl::read_excel(
    file.path(RAIZ, "analise_cbo_onnet", "Base_CBO2002_x_ONET-SOC.xlsx"),
    sheet = "Crosswalk_completo", col_types = "text"))
  cbo_ciuo <- unique(cw[, c("CBO2002", "CIUO88", "TIPO_LIGACAO_CBO")])
  names(cbo_ciuo) <- c("CBO2002", "CIUO88", "TIPO_LIGACAO")
  gravar_csv(cbo_ciuo, ARQ_PONTE$cbo_ciuo)
  cat("ocupacoes ligadas a mais de um grupo CIUO-88:",
      sum(table(cbo_ciuo$CBO2002) > 1), "\n")

  oit <- as.data.frame(readxl::read_excel(
    file.path(RAIZ, "analise_cbo_onnet", "Correspondence_EN_ISCO_88_to_ISCO_08.xlsx"),
    sheet = "ISCO-88 to 08", col_types = "text"))
  ciuo_isco <- data.frame(CIUO88 = oit[["ISCO-88 code"]], ISCO08 = oit[["ISCO-08 code"]],
                          PARCIAL = ifelse(is.na(oit[["...4"]]), "nao", "sim"),
                          TITULO_ISCO08 = oit[["ISCO-08 Title"]], stringsAsFactors = FALSE)
  ciuo_isco <- unique(ciuo_isco[!is.na(ciuo_isco$CIUO88) & !is.na(ciuo_isco$ISCO08), ])
  gravar_csv(ciuo_isco, ARQ_PONTE$ciuo_isco)
  cat("CBO 2002 com CIUO-88:", nrow(cbo_ciuo), "\n")
  cat("pares CIUO-88 x ISCO-08:", nrow(ciuo_isco), "\n")
}
