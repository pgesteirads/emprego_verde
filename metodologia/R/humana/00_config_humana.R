# ==============================================================================
# CLASSIFICACAO HUMANA - 00. CONFIGURACAO
# ==============================================================================
# Valores fixados pelo protocolo (metodologia/PROTOCOLO_CLASSIFICACAO_HUMANA.md).
# Alterar depois do pre-registro e um desvio: registre na secao 11.
#
# MODO_HUMANA
#   "real":     planilhas e resultados em metodologia/classificacao_humana/
#   "simulado": mesma coisa em metodologia/classificacao_humana_simulada/
#               (fora do git), com codificadores simulados para teste
# ==============================================================================

if (!exists("MODO_HUMANA")) MODO_HUMANA <- "real"
stopifnot(MODO_HUMANA %in% c("real", "simulado"))

if (!requireNamespace("openxlsx", quietly = TRUE)) install.packages("openxlsx")

# [DEFINIR] nomes dos codificadores (os arquivos usam C1, C2, C3)
CODIFICADORES <- c(C1 = "DEFINIR", C2 = "DEFINIR", C3 = "DEFINIR")

# [DEFINIR] regra de decisao das divergencias: "A" ou "B" (protocolo, secao 7)
OPCAO_DECISAO <- "A"

N_CALIBRACAO       <- 40
TAXA_REPETICAO     <- 0.05
N_RECALL           <- 800
LIMIAR_ALTO_IMPACTO <- 10   # ocupacoes; conferidas na reuniao mesmo com unanimidade

SEMENTE_CALIBRACAO <- 20261117
SEMENTE_REPETICAO  <- 20261118
SEMENTE_RECALL     <- 20261119
SEMENTE_ORDEM      <- 20261120

DIR_HUMANA <- file.path(RAIZ, "metodologia",
                        if (MODO_HUMANA == "real") "classificacao_humana"
                        else "classificacao_humana_simulada")
CAMINHOS_HUMANA <- list(
  base       = DIR_HUMANA,
  planilhas  = file.path(DIR_HUMANA, "planilhas"),      # o que cada codificador preenche
  chaves     = file.path(DIR_HUMANA, "chaves"),         # linha da planilha -> atividade
  resultados = file.path(DIR_HUMANA, "resultados")
)
for (d in CAMINHOS_HUMANA) dir.create(d, showWarnings = FALSE, recursive = TRUE)

ETAPAS_HUMANA <- c("calibracao", "principal", "recall")

REGRAS <- c(VERDE = "VERDE", POTENCIAL = "POTENCIAL", MARROM = "MARROM",
            NEUTRO_1 = "NEUTRO", NEUTRO_2 = "NEUTRO", NEUTRO_3 = "NEUTRO",
            NEUTRO_4 = "NEUTRO", NEUTRO_5 = "NEUTRO", NEUTRO_6 = "NEUTRO",
            NEUTRO_CONSERVADOR = "NEUTRO")

arq_planilha <- function(etapa_, cod) file.path(CAMINHOS_HUMANA$planilhas,
                                                paste0(etapa_, "_", cod, ".xlsx"))
arq_chave <- function(etapa_, cod) file.path(CAMINHOS_HUMANA$chaves,
                                             paste0(etapa_, "_", cod, ".csv"))
