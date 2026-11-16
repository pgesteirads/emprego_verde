# ==============================================================================
# CLASSIFICACAO HUMANA - 04. AUDITORIA DE RECALL
# ==============================================================================
# avaliar_recall()  le as tres planilhas de recall e conta os falsos negativos
#   do dicionario: atividades nao capturadas que os codificadores classificaram
#   com classe diferente de NEUTRO. Reporta por consenso (os tres) e pela uniao
#   (ao menos um), por classe, com intervalo de confianca de 95% para a taxa.
#   Grava a lista para discutir possivel ampliacao do dicionario.
# ==============================================================================

etapa("Humana 04. Recall (funcoes carregadas)")

avaliar_recall <- function() {
  conc <- concordancia("recall")
  w <- conc$largas
  cods <- names(CODIFICADORES)
  cls <- as.matrix(w[, paste0("classe_", cods)])
  n_nao_neutro <- rowSums(cls != "NEUTRO")
  cj <- conjuntos_humana()$recall
  w$ATIVIDADE <- cj$ATIVIDADE[match(w$item, cj$item)]
  w$consenso <- n_nao_neutro == length(cods)
  w$uniao <- n_nao_neutro >= 1
  w$classe_maioria <- apply(cls, 1, function(z) {
    t <- sort(table(z), decreasing = TRUE); if (t[1] >= 2) names(t)[1] else "SEM_MAIORIA" })

  ic <- function(k, n) round(100 * stats::binom.test(k, n)$conf.int, 1)
  n <- nrow(w)
  resumo <- data.frame(
    criterio = c("consenso (3 de 3 nao NEUTRO)", "maioria (2 ou mais)", "uniao (1 ou mais)"),
    falsos_negativos = c(sum(w$consenso), sum(n_nao_neutro >= 2), sum(w$uniao)),
    n_amostra = n)
  resumo$taxa_pct <- round(100 * resumo$falsos_negativos / n, 1)
  resumo$ic95 <- sapply(resumo$falsos_negativos, function(k) paste(ic(k, n), collapse = " a "))
  por_classe <- as.data.frame(table(Classe_maioria = w$classe_maioria[n_nao_neutro >= 2]))

  gravar_csv(resumo, file.path(CAMINHOS_HUMANA$resultados, "recall_resumo.csv"))
  gravar_csv(w[w$uniao, c("item", "ATIVIDADE", paste0("classe_", cods), paste0("obs_", cods),
                          "classe_maioria", "consenso")],
             file.path(CAMINHOS_HUMANA$resultados, "recall_falsos_negativos.csv"))
  cat("\nAuditoria de recall (amostra de", n, "atividades nao capturadas):\n")
  print(resumo, row.names = FALSE)
  cat("\nClasse dos falsos negativos por maioria:\n"); print(por_classe, row.names = FALSE)
  cat("\nUniverso nao capturado:", length(distintos) - nrow(candidatos),
      "atividades distintas. Lista dos casos em resultados/recall_falsos_negativos.csv\n")
  invisible(list(resumo = resumo, por_classe = por_classe, itens = w))
}
