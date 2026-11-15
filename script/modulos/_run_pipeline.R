###############################################################################
#                                                                             #
#   EMPREGO VERDE - SCRIPT MESTRE (ORQUESTRADOR)                              #
#                                                                             #
#   Roda a pipeline completa via source() dos modulos na ordem correta.      #
#   Os modulos 05-10 compartilham objetos no ambiente global (base_pnadc,    #
#   tabelas_*, etc.), por isso devem ser executados nesta sequencia.         #
#                                                                             #
#   Uso:                                                                       #
#     source("script/modulos/_run_pipeline.R")                               #
#   ou, a partir da pasta script/modulos/:                                    #
#     Rscript _run_pipeline.R                                                 #
#                                                                             #
#   OBS: este arquivo foi mantido em ASCII puro de proposito (sem acentos),  #
#   para nao depender do encoding. Os modulos sao lidos como latin1.         #
#   Substitui o antigo emprego_verde_consolidado.R (mantido como backup).    #
#                                                                             #
###############################################################################

# Pasta onde estao os modulos (funciona via source() e via Rscript)
DIR_MODULOS <- tryCatch(
  dirname(normalizePath(sys.frame(1)$ofile)),
  error = function(e) {
    args <- commandArgs(trailingOnly = FALSE)
    arg_file <- sub("^--file=", "", args[grep("^--file=", args)])
    if (length(arg_file) > 0) dirname(normalizePath(arg_file)) else getwd()
  }
)

carregar <- function(arquivo) {
  caminho <- file.path(DIR_MODULOS, arquivo)
  message(glue::glue(">>> source: {arquivo}"))
  source(caminho, encoding = "latin1")
}

# 1) Configuracao (pacotes, parametros, caminhos)
carregar("00_config.R")

# 2) Definicoes de funcoes (sem efeitos colaterais)
carregar("01_leitura_pnadc.R")
carregar("02_classificacoes_verdes.R")
carregar("03_tratamento_base.R")
carregar("04_funcoes_tabelas.R")

# OBS: a leitura dos microdados (ler_pnadc_trimestral) NAO e chamada
# automaticamente. Rode-a manualmente uma unica vez, se os parquets ainda
# nao existirem:
#   ler_pnadc_trimestral()

# 3) Execucao da pipeline (constroi e consome objetos no ambiente global)
carregar("05_preparar_dados.R")
carregar("06_gerar_tabelas.R")
carregar("07_gerar_graficos.R")
carregar("08_exportar_resultados.R")
carregar("09_tabela_bi.R")
carregar("10_tabela_bi_cv.R")

message("=== PIPELINE COMPLETA ===")
