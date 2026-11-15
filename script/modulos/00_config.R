###############################################################################
#                                                                             #
#   EMPREGO VERDE - 00. CONFIGURA??ES E PAR?METROS GLOBAIS                     #
#                                                                             #
#   Carrega pacotes e define todos os par?metros, caminhos e vari?veis        #
#   globais usados pelo restante da pipeline.                                 #
#                                                                             #
#   Depend?ncias: nenhuma (deve ser o primeiro a rodar).                      #
#   Origem: emprego_verde_consolidado.R, se??o 0.                             #
#                                                                             #
###############################################################################

options(encoding = "latin1")
options(scipen = 999)
options(digits = 3)

# --- Instala??o e carregamento de pacotes ---

if (!require("librarian")) install.packages("librarian")

librarian::shelf(
  # Manipula??o de dados
  tidyverse, data.table, janitor, glue,
  # Leitura/escrita de arquivos
  arrow, haven, rio, readxl, writexl, openxlsx,
  # PNADc
  PNADcIBGE,
  # Survey / pesos
  survey, srvyr, spatstat,
  # Banco de dados (BigQuery / RAIS)
  dbplyr, bigrquery,
  # Tabelas e relat?rios
  gt, pander,
  # Visualiza??o
  ggplot2, scales, RColorBrewer, treemapify,
  # Geoespacial
  geobr, sf,
  # Utilidades
  here, Hmisc
)

rm(list = ls())
gc()

# --- Par?metros do exerc?cio ---
# Altere aqui os anos, trimestres e classifica??o desejada

ANOS_ANALISE    <- c(2014, 2016, 2019, 2024)
TRIMESTRE       <- 4
ANO_INICIAL     <- 2014
ANO_FINAL       <- 2024

# Classifica??o verde escolhida (op??es na planilha Harmonizacao.xlsx):
#   "class_verde_cnae20", "class_verde_cnae20_alternativo",
#   "class_verde_cnae20_alternativo_adm_pub", "class_verde_definitiva"
CLASS_ESCOLHIDA <- "class_verde_definitiva"

# N?veis das classifica??es verdes (para ordenar fatores)
NIVEIS_CLASS_ATIV  <- c("Brown", "Neutral", "Green")
CORES_CLASS_ATIV   <- c("Brown" = "chocolate", "Neutral" = "lightblue", "Green" = "darkgreen")

# Caminhos
CAMINHO_DADOS_REFERENCIA <- here("dados", "referencia")
CAMINHO_DADOS_PROCESSADOS <- here("dados", "processados")
CAMINHO_PNADC_TRIM      <- here("dados", "pnadc_trim")
CAMINHO_PRODUTOS_TAB    <- here("produtos", "tabelas")
CAMINHO_PRODUTOS_GRAF   <- here("produtos", "graficos")

# Aliases para compatibilidade com c?digo legado
CAMINHO_DADOS_ORIGINAL  <- CAMINHO_DADOS_REFERENCIA
CAMINHO_DADOS_FINAL     <- CAMINHO_DADOS_PROCESSADOS

# Caminho dos microdados brutos do IBGE (dentro do projeto)
# Veja dados/microdados_ibge/LEIA-ME.txt para instru??es de como popular esta pasta
CAMINHO_MICRODADOS_TRIM  <- here("dados", "microdados_ibge", "trimestral")
CAMINHO_DEFLATOR         <- here("dados", "microdados_ibge", "trimestral", "deflator_PNADC_2025_trimestral_040506.xls")

# Vari?veis de interesse da PNADc
VARS_PNADC <- list(
  id           = c("Ano", "Trimestre", "UF", "Capital", "UPA", "Estrato", "V1008", "V1014", "V1028"),
  genero       = c("V2007"),
  cor          = c("V2010"),
  ocupacao     = c("V4010", "VD4009", "VD4002", "VD4012", "V4032"),
  escolaridade = c("VD3004", "VD3005"),
  idade        = c("V2009"),
  regiao       = c("V1022", "RM_RIDE", "UF"),
  atividade    = c("V4013"),
  renda        = c("VD4016")
)

VARS_VEC <- unique(unname(unlist(VARS_PNADC)))

# Par?metros para desagrega??o SCN (propor??es da TRU)
SCN_PROPORCOES <- list(
  list(cnae_alvo = "01999",           scn_1 = "0191", scn_2 = "0192", prop_1 = 0.534),
  list(cnae_alvo = c("07001","07002"), scn_1 = "0791", scn_2 = "0792", prop_1 = 0.495),
  list(cnae_alvo = c("20010","20090"), scn_1 = "2091", scn_2 = "2092", prop_1 = 0.526)
)

