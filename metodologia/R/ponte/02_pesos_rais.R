# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - 02. PESOS DA RAIS
# ==============================================================================
#
# Numero de vinculos ativos em 31/12 por ocupacao da CBO 2002 (6 digitos), da
# RAIS (Base dos Dados, BigQuery), para os anos em ANOS_RAIS. Esses numeros
# ponderam as ocupacoes da CBO dentro de cada grupo da COD.
#
# O resultado fica em metodologia/insumos/ponte/rais_vinculos_cbo.csv
# (versionado), de modo que o restante da ponte roda sem acesso ao BigQuery.
# Para baixar de novo, rode com FORCAR_RAIS <- TRUE.
#
# Acesso: login com bigrquery::bq_auth() (ver login_bigquery.R) e um projeto
# do Google Cloud para faturamento em PROJETO_FATURAMENTO. As consultas leem
# poucas colunas e cabem na cota gratuita do BigQuery.
# ==============================================================================

if (!exists("FORCAR_RAIS")) FORCAR_RAIS <- FALSE
etapa("Ponte 02. Pesos da RAIS")

ANOS_RAIS <- c(2014, 2016, 2019, 2024)
PROJETO_FATURAMENTO <- "careful-emitter-352918"
ARQ_PONTE$rais <- file.path(DIR_PONTE_INS, "rais_vinculos_cbo.csv")

if (file.exists(ARQ_PONTE$rais) && !FORCAR_RAIS) {
  cat("pesos da RAIS ja baixados; consulta dispensada.\n")
} else {
  bigrquery::bq_auth(email = TRUE, cache = TRUE)
  q <- sprintf(paste(
    "SELECT ano, cbo_2002, COUNT(*) AS vinculos",
    "FROM `basedosdados.br_me_rais.microdados_vinculos`",
    "WHERE ano IN (%s) AND CAST(vinculo_ativo_3112 AS STRING) = '1'",
    "GROUP BY ano, cbo_2002"), paste(ANOS_RAIS, collapse = ", "))
  tb <- bigrquery::bq_project_query(PROJETO_FATURAMENTO, q)
  r <- as.data.frame(bigrquery::bq_table_download(tb))
  r <- r[order(r$ano, r$cbo_2002), ]
  gravar_csv(data.frame(ANO = r$ano, CBO2002 = r$cbo_2002, VINCULOS = r$vinculos), ARQ_PONTE$rais)
  cat("consulta:", q, "\n")
}

rais <- ler_csv(ARQ_PONTE$rais)
rais$VINCULOS <- num(rais$VINCULOS)
print(aggregate(VINCULOS ~ ANO, data = rais, FUN = sum))
