# ==============================================================================
# CLASSIFICACAO HUMANA - SCRIPT MESTRE
# ==============================================================================
#
# Carrega o pipeline do indice (etapas 00 a 04) e as funcoes da classificacao
# humana. Nada e gerado ao carregar: cada passo e disparado a mao, na ordem
# do protocolo (metodologia/PROTOCOLO_CLASSIFICACAO_HUMANA.md).
#
#   source("metodologia/R/humana/_run_humana.R")
#
#   gerar_planilhas()                 # 9 planilhas: 3 etapas x 3 codificadores
#   # -> cada um preenche calibracao_Cx.xlsx
#   concordancia("calibracao"); preparar_reuniao("calibracao")
#   # -> reuniao de calibracao preenche resultados/reuniao_calibracao.xlsx
#   # -> cada um preenche principal_Cx.xlsx e recall_Cx.xlsx
#   concordancia("principal"); preparar_reuniao("principal")
#   # -> reunioes preenchem resultados/reuniao_principal.xlsx
#   rotulos <- finalizar_rotulos()    # grava insumos/rotulos_atividade_humana.csv
#   avaliar_recall()
#
# Documentacao: metodologia/R/humana/LEIA-ME.md
# ==============================================================================

local({
  base <- file.path("metodologia", "R")
  for (a in c("00_config.R", "funcoes.R", "01_extrair_insumos.R", "02_ler_corpus.R",
              "03_gerar_candidatos.R", "04_rotulagem.R")) {
    source(file.path(base, a), encoding = "UTF-8", local = globalenv())
  }
  for (a in c("00_config_humana.R", "01_gerar_planilhas.R", "02_ler_e_concordancia.R",
              "03_decisao.R", "04_recall.R")) {
    source(file.path(base, "humana", a), encoding = "UTF-8", local = globalenv())
  }
})

cat("\nModo:", MODO_HUMANA, "| pasta:", CAMINHOS_HUMANA$base, "\n")
cat("Codificadores:", paste(names(CODIFICADORES), CODIFICADORES, sep = " = ", collapse = "; "), "\n")
cat("Regra de decisao das divergencias: opcao", OPCAO_DECISAO, "\n")
if (any(CODIFICADORES == "DEFINIR")) cat("ATENCAO: nomes dos codificadores ainda nao definidos em 00_config_humana.R\n")
