# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 00. CONFIGURACAO
# ==============================================================================
#
# Pacotes, caminhos e parametros usados por todas as etapas.
# Arquivo em ASCII puro de proposito (sem acentos), para nao depender do
# encoding de leitura.
#
# Todos os parametros que afetam o resultado estao aqui. Alterar qualquer um
# deles muda o indice: registre a mudanca no commit.
# ==============================================================================

for (pkg in c("readxl", "stringi", "writexl", "jsonlite")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

# O diretorio de trabalho deve ser a raiz do projeto (abrir emprego_verde.Rproj)
if (!file.exists("emprego_verde.Rproj")) {
  stop("O diretorio de trabalho deve ser a raiz do projeto. ",
       "Abra emprego_verde.Rproj antes de rodar o pipeline.")
}
RAIZ <- normalizePath(getwd(), winslash = "/")

DIR_CBO <- file.path(RAIZ, "analise_cbo_onnet", "ESTRUTURA CBO")

CAMINHOS <- list(
  # Fontes primarias (nao versionadas; o pipeline registra o hash de cada uma)
  perfil    = file.path(DIR_CBO, "CBO2002 - PerfilOcupacional.csv"),
  ocupacao  = file.path(DIR_CBO, "CBO2002 - Ocupacao.csv"),
  familia   = file.path(DIR_CBO, "CBO2002 - Familia.csv"),

  # Planilha canonica de setembro de 2026. Usada apenas na etapa 01 (extracao
  # unica dos insumos). Depois disso, a fonte passa a ser metodologia/insumos/.
  planilha  = file.path(RAIZ, "analise_cbo_onnet",
                        "Esverdeamento_ocupacional_CBO2002.xlsx"),

  # Insumos versionados no git: dicionario, excecoes, descartados, rotulos e
  # o indice de referencia de setembro de 2026.
  insumos   = file.path(RAIZ, "metodologia", "insumos"),

  # Rodadas de rotulagem de atividades novas (protocolo de duas passagens)
  rotulagem = file.path(RAIZ, "metodologia", "rotulagem"),

  # Saidas
  saida     = file.path(RAIZ, "metodologia", "saida"),
  intermed  = file.path(RAIZ, "metodologia", "saida", "intermediarios")
)

ARQ_INSUMOS <- list(
  dicionario  = file.path(CAMINHOS$insumos, "dicionario.csv"),
  excecoes    = file.path(CAMINHOS$insumos, "excecoes.csv"),
  descartados = file.path(CAMINHOS$insumos, "termos_descartados.csv"),
  rotulos     = file.path(CAMINHOS$insumos, "rotulos_atividade.csv"),
  referencia  = file.path(CAMINHOS$insumos, "referencia_indice_2026_09.csv")
)

# ------------------------------------------------------------------------------
# Parametros metodologicos
# ------------------------------------------------------------------------------

# Numero minimo de atividades descritas para que o indice seja reportado.
# Decisao documentada na secao 9 da nota metodologica; revisavel.
MINIMO_ATIVIDADES <- 15

# Classes da rubrica (metodologia/RUBRICA.md)
CLASSES <- c("VERDE", "POTENCIAL", "MARROM", "NEUTRO")

# Se TRUE, o pipeline para com erro quando algum indicador de conferencia
# diverge da nota metodologica. Deixe TRUE; so mude para investigar.
PARAR_SE_DIVERGIR <- TRUE

# Valores de referencia da nota metodologica (setembro de 2026), usados na
# conferencia da etapa 06. So valem enquanto corpus, dicionario e rotulos
# forem os da rodada original. Se algum deles mudar de proposito, atualize
# estes valores no mesmo commit e explique o motivo.
REFERENCIA_NOTA <- c(
  "ocupacoes cobertas"                = 2700,
  "ocupacoes reportaveis"             = 2672,
  "margem extensiva verde (%)"        = 51.2,
  "margem extensiva marrom (%)"       = 10.5,
  "indice verde mediana"              = 0.0081,
  "indice verde p90"                  = 0.0417,
  "indice verde maximo"               = 0.275,
  "ocupacoes sem atividade exclusiva" = 981
)

# Casos de controle com valor conhecido (TRANSFERENCIA.md, secao 3)
CASOS_CONTROLE <- data.frame(
  CBO        = c("732140", "732140"),
  coluna     = c("Verde_amplo", "Verde_especifico"),
  esperado   = c(0.101, 0.900),
  stringsAsFactors = FALSE
)

dir.create(CAMINHOS$saida,     showWarnings = FALSE, recursive = TRUE)
dir.create(CAMINHOS$intermed,  showWarnings = FALSE, recursive = TRUE)
dir.create(CAMINHOS$insumos,   showWarnings = FALSE, recursive = TRUE)
dir.create(CAMINHOS$rotulagem, showWarnings = FALSE, recursive = TRUE)
