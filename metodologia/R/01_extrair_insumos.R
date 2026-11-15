# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 01. EXTRACAO DOS INSUMOS
# ==============================================================================
#
# Roda UMA VEZ. Tira da planilha canonica de setembro de 2026 as pecas que
# definem a medida e grava cada uma como CSV em metodologia/insumos/, que e
# versionado no git:
#
#   dicionario.csv              183 expressoes de busca (gera candidatos)
#   excecoes.csv                24 regras que suprimem capturas espurias
#   termos_descartados.csv      15 termos avaliados e rejeitados
#   rotulos_atividade.csv       1.870 atividades com a classe da rubrica
#   referencia_indice_2026_09.csv  o indice publicado, para conferencia
#
# Por que: a planilha (.xlsx) nao e versionada e nao mostra diferencas entre
# versoes. Em CSV, qualquer alteracao de termo, excecao ou rotulo aparece no
# historico do git, com autor e data.
#
# Depois desta etapa, a fonte oficial passa a ser metodologia/insumos/.
# Alteracoes no dicionario ou nos rotulos devem ser feitas nos CSV (rotulos
# novos, so pelo protocolo da etapa 04), nunca de novo na planilha.
#
# Se os CSV ja existem, a etapa nao faz nada. Para refazer a extracao,
# rode com FORCAR_EXTRACAO <- TRUE (sobrescreve os CSV).
# ==============================================================================

if (!exists("FORCAR_EXTRACAO")) FORCAR_EXTRACAO <- FALSE

etapa("01. Extracao dos insumos")

if (all(file.exists(unlist(ARQ_INSUMOS))) && !FORCAR_EXTRACAO) {
  cat("insumos ja existem em metodologia/insumos/; extracao dispensada.\n")
} else {
  if (!file.exists(CAMINHOS$planilha)) {
    stop("Planilha canonica nao encontrada: ", CAMINHOS$planilha)
  }
  ler_aba <- function(aba) {
    as.data.frame(readxl::read_excel(CAMINHOS$planilha, sheet = aba),
                  stringsAsFactors = FALSE)
  }

  # --- Dicionario ---
  dic <- ler_aba("Dicionario")[, c("ID", "Classe", "Categoria", "Padrao",
                                   "Fonte")]

  # --- Excecoes ---
  exc <- ler_aba("Excecoes")[, c("Termo_alvo", "Padrao_excecao",
                                 "Justificativa")]

  # --- Termos descartados ---
  desc <- ler_aba("Termos_descartados")

  # --- Rotulos ---
  # Ocorrencias, N_ocupacoes e Termos sao derivados do corpus e sao
  # recalculados pelo pipeline; por isso nao entram no insumo.
  rot <- ler_aba("Atividades_classificadas")
  rot <- data.frame(
    Atividade    = rot$Atividade,
    Classe_final = rot$Classe_final,
    Passagem_A   = rot$Passagem_A,
    Passagem_B   = rot$Passagem_B,
    Arbitrada    = ifelse(chave(rot$Arbitrada) == "SIM", "sim", "nao"),
    Rodada       = "2026-09_original",
    stringsAsFactors = FALSE
  )
  stopifnot(all(rot$Classe_final %in% CLASSES))

  # --- Indice publicado (referencia para conferencia) ---
  ref <- ler_aba("Indice_por_ocupacao")
  ref <- ref[, setdiff(names(ref), c("QBQ_verde", "QBQ_marrom", "QBQ_liquido"))]

  gravar_csv(dic,  ARQ_INSUMOS$dicionario)
  gravar_csv(exc,  ARQ_INSUMOS$excecoes)
  gravar_csv(desc, ARQ_INSUMOS$descartados)
  gravar_csv(rot,  ARQ_INSUMOS$rotulos)
  gravar_csv(ref,  ARQ_INSUMOS$referencia)

  # --- Conferencia de ida e volta: o CSV relido tem de ser identico ---
  igual <- function(a, b) {
    a[] <- lapply(a, as.character); b[] <- lapply(b, as.character)
    isTRUE(all.equal(a, b, check.attributes = FALSE))
  }
  stopifnot(
    igual(ler_csv(ARQ_INSUMOS$dicionario), dic),
    igual(ler_csv(ARQ_INSUMOS$excecoes),   exc),
    igual(ler_csv(ARQ_INSUMOS$rotulos),    rot)
  )
  cat("dicionario:", nrow(dic), "termos\n")
  cat("excecoes:", nrow(exc), "\n")
  cat("descartados:", nrow(desc), "\n")
  cat("rotulos:", nrow(rot), "atividades\n")
  cat("referencia:", nrow(ref), "ocupacoes\n")
  cat("ida e volta conferida: CSV identicos a planilha.\n")
}
