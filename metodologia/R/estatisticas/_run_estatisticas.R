# ==============================================================================
# ESTATÍSTICAS DESCRITIVAS COM A PNADc - SCRIPT MESTRE
# ==============================================================================
# Usa o índice por grupo da COD já gravado pela ponte
# (metodologia/saida/ponte/indice_por_cod.csv). Uso, a partir da raiz:
#
#     source("metodologia/R/estatisticas/_run_estatisticas.R")
#
# Gera as tabelas (CSV e xlsx completo), a nota de resultados em Word e a
# planilha formatada para o grupo de pesquisa (estatisticas_descritivas_grupo.xlsx).
#
# Para atualizar depois da classificação humana: rode o pipeline do índice,
# depois a ponte (metodologia/R/ponte/_run_ponte.R), depois este script.
# ==============================================================================

local({
  base <- file.path("metodologia", "R")
  for (a in c("00_config.R", "funcoes.R")) source(file.path(base, a), encoding = "UTF-8", local = globalenv())
  for (a in c("01_base_analitica.R", "02_tabelas.R", "03_nota_resultados.R", "04_planilha_grupo.R")) {
    arq <- file.path(base, "estatisticas", a)
    if (file.exists(arq)) source(arq, encoding = "UTF-8", local = globalenv())
  }
})
