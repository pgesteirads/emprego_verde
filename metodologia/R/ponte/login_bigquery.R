# Login no Google para o BigQuery (uma vez por maquina). Abre o navegador;
# o token fica guardado no cache do gargle e e reutilizado depois.
options(rlang_interactive = TRUE)
if (!requireNamespace("httpuv", quietly = TRUE)) install.packages("httpuv", repos = "https://cloud.r-project.org")
bigrquery::bq_auth(cache = TRUE)
cat("\nLogin feito como:", bigrquery::bq_user(), "\n")
x <- bigrquery::bq_project_query("emprego-verde",
  "SELECT COUNT(*) AS n FROM `basedosdados.br_me_rais.microdados_vinculos` WHERE ano = 2023 AND sigla_uf = 'AC'")
print(bigrquery::bq_table_download(x))
cat("\nBigQuery OK\n")
