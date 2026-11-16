# ==============================================================================
# PAINEL DE MODELOS - 06. VALIDACAO HUMANA
# ==============================================================================
# sortear_validacao(): depois da agregacao e da arbitragem, sorteia a amostra
#   estratificada pela classe final do painel e gera uma planilha em branco
#   para cada codificador, com ordem propria. A classe do painel e as
#   probabilidades de selecao ficam num arquivo separado (gabarito), que os
#   codificadores NAO devem abrir antes de terminar.
# avaliar_validacao(): depois que os dois codificadores preencherem as
#   planilhas, calcula kappa humano x humano, humano x painel, matriz de
#   confusao e o alternative annotator test. Protocolo, secao 9.
# ==============================================================================

etapa("Painel 06. Validacao humana (funcoes carregadas)")

sortear_validacao <- function(rotulos_finais) {
  dir <- CAMINHOS_PAINEL$validacao
  gab_arq <- file.path(dir, "gabarito_NAO_ABRIR.csv")
  if (file.exists(gab_arq)) stop("A amostra ja foi sorteada (", gab_arq, "). ",
                                 "Sortear de novo invalida o desenho.")
  rf <- data.frame(ID = id_item(chave(rotulos_finais$Atividade)),
                   ATIVIDADE = rotulos_finais$Atividade,
                   classe_painel = rotulos_finais$Classe_final,
                   decisao = rotulos_finais$Decisao, stringsAsFactors = FALSE)
  set.seed(SEMENTE_VALIDACAO)
  am <- do.call(rbind, lapply(CLASSES, function(cl) {
    x <- rf[rf$classe_painel == cl, ]
    n <- min(N_VALIDACAO_CLASSE, nrow(x))
    s <- x[sample(nrow(x), n), ]
    s$prob_selecao <- n / nrow(x)
    s
  }))
  am$ordem_alt_test <- sample(nrow(am))
  gravar_csv(am, gab_arq)
  for (cod in c("codificador_1", "codificador_2")) {
    o <- am[sample(nrow(am)), c("ID", "ATIVIDADE")]
    o$CLASSE <- ""; o$REGRA <- ""; o$OBSERVACAO <- ""
    gravar_tsv(o, file.path(dir, paste0(cod, ".tsv")))
  }
  writeLines(c(
    "VALIDACAO HUMANA",
    "",
    "codificador_1.tsv e codificador_2.tsv: uma planilha para cada pessoa.",
    "Preencha CLASSE (VERDE, POTENCIAL, MARROM ou NEUTRO) e REGRA (VERDE,",
    "POTENCIAL, MARROM, NEUTRO_1 a NEUTRO_6 ou NEUTRO_CONSERVADOR) aplicando",
    "metodologia/RUBRICA.md, sem consultar a outra pessoa.",
    "",
    "NAO abra gabarito_NAO_ABRIR.csv, painel_agregado.csv nem os rotulos de",
    "setembro antes de terminar. Eles contem as classes do painel.",
    "",
    "Ao terminar: avaliar_validacao()"
  ), file.path(dir, "LEIA-ME.txt"))
  cat(nrow(am), "itens sorteados; planilhas em", dir, "\n")
  print(table(am$classe_painel))
  invisible(am)
}

# Alternative annotator test (Calderon, Reichart e Dror, 2025), versao para
# dois anotadores humanos e rotulos categoricos. Para cada humano j, compara
# se o painel concorda com o outro humano mais do que o humano j concorda com
# ele, com margem epsilon; teste t unilateral pareado. O painel passa se
# vencer para pelo menos metade dos humanos.
# ATENCAO: implementacao simplificada; conferir com o codigo oficial
# (github.com/nitaytech/alttest) antes de reportar no artigo.
alt_test <- function(h1, h2, llm, epsilon = 0.1, alfa = 0.05) {
  ok <- !is.na(h1) & !is.na(h2) & !is.na(llm)
  h1 <- h1[ok]; h2 <- h2[ok]; llm <- llm[ok]
  um <- function(hj, outro) {
    d <- as.numeric(llm == outro) - as.numeric(hj == outro)
    p <- tryCatch(stats::t.test(d + epsilon, mu = 0, alternative = "greater")$p.value,
                  error = function(e) if (mean(d + epsilon) > 0) 0 else 1)
    c(vantagem = mean(d), p = p)
  }
  r <- rbind(humano_1 = um(h1, h2), humano_2 = um(h2, h1))
  p_aj <- stats::p.adjust(r[, "p"], method = "BY")
  vence <- p_aj < alfa
  list(n = sum(ok), epsilon = epsilon, resultados = cbind(r, p_ajustado = p_aj, vence = vence),
       taxa_vitoria = mean(vence), aprovado = mean(vence) >= 0.5)
}

avaliar_validacao <- function(epsilon = 0.1) {
  dir <- CAMINHOS_PAINEL$validacao
  gab <- ler_csv(file.path(dir, "gabarito_NAO_ABRIR.csv"))
  ler_cod <- function(cod) {
    x <- ler_tsv(file.path(dir, paste0(cod, ".tsv")))
    x$CLASSE <- toupper(trimws(x$CLASSE))
    inval <- x$ID[is.na(x$CLASSE) | !x$CLASSE %in% CLASSES]
    if (length(inval)) stop(cod, ": ", length(inval), " itens sem classe valida.")
    setNames(x$CLASSE, x$ID)[gab$ID]
  }
  h1 <- ler_cod("codificador_1"); h2 <- ler_cod("codificador_2")
  pnl <- gab$classe_painel
  consenso <- ifelse(h1 == h2, h1, NA)

  k_hh <- kappa_cohen(h1, h2)
  k_1p <- kappa_cohen(h1, pnl)
  k_2p <- kappa_cohen(h2, pnl)
  k_cp <- kappa_cohen(consenso, pnl)
  med <- data.frame(
    comparacao = c("codificador 1 x codificador 2", "codificador 1 x painel",
                   "codificador 2 x painel", "consenso humano x painel"),
    n = c(k_hh$n, k_1p$n, k_2p$n, k_cp$n),
    concordancia = round(c(k_hh$concordancia, k_1p$concordancia,
                           k_2p$concordancia, k_cp$concordancia), 4),
    kappa = round(c(k_hh$kappa, k_1p$kappa, k_2p$kappa, k_cp$kappa), 4))

  sub <- num(gab$ordem_alt_test) <= N_ALT_TEST
  at <- alt_test(h1[sub], h2[sub], pnl[sub], epsilon = epsilon)

  confusao <- table(Humano_consenso = factor(consenso, levels = CLASSES),
                    Painel = factor(pnl, levels = CLASSES))

  gravar_csv(med, file.path(CAMINHOS_PAINEL$resultados, "validacao_humana_kappas.csv"))
  tab_conf <- cbind(Humano_consenso = CLASSES, as.data.frame.matrix(confusao))
  gravar_csv(tab_conf, file.path(CAMINHOS_PAINEL$resultados,
                                 "validacao_humana_confusao.csv"))
  cat("\nConcordancia:\n"); print(med, row.names = FALSE)
  cat("\nMatriz de confusao (itens com consenso humano):\n"); print(confusao)
  cat(sprintf("\nAlternative annotator test (n = %d, epsilon = %.2f): taxa de vitoria %.2f -> %s\n",
              at$n, at$epsilon, at$taxa_vitoria, if (at$aprovado) "APROVADO" else "REPROVADO"))
  print(at$resultados)
  invisible(list(kappas = med, confusao = confusao, alt_test = at))
}
