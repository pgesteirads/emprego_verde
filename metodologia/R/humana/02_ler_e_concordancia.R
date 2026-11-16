# ==============================================================================
# CLASSIFICACAO HUMANA - 02. LEITURA DAS PLANILHAS E CONCORDANCIA
# ==============================================================================
# ler_respostas(etapa)  le as planilhas preenchidas, confere cada linha e
#                       devolve as respostas por atividade e codificador.
#                       Para com a lista de linhas a corrigir, se houver.
# concordancia(etapa)   kappas por par e de Fleiss; na etapa principal,
#                       consistencia de cada codificador nas repeticoes.
# ==============================================================================

etapa("Humana 02. Leitura e concordancia (funcoes carregadas)")

ler_planilha_cod <- function(etapa_, cod) {
  arq <- arq_planilha(etapa_, cod)
  if (!file.exists(arq)) stop("Planilha nao encontrada: ", arq)
  x <- as.data.frame(readxl::read_excel(arq, sheet = "Classificacao",
                                        col_types = "text"), stringsAsFactors = FALSE)
  ch <- ler_csv(arq_chave(etapa_, cod))
  if (nrow(x) != nrow(ch) || !all(as.integer(x$LINHA) == as.integer(ch$LINHA))) {
    stop(basename(arq), ": as linhas nao batem com a chave. A ordem ou o numero de ",
         "linhas foi alterado?")
  }
  x$CLASSE <- toupper(trimws(x$CLASSE))
  x$REGRA  <- toupper(trimws(x$REGRA))
  problema <- ifelse(is.na(x$CLASSE) | x$CLASSE == "", "CLASSE vazia",
              ifelse(!x$CLASSE %in% CLASSES, "CLASSE invalida",
              ifelse(is.na(x$REGRA) | x$REGRA == "", "REGRA vazia",
              ifelse(!x$REGRA %in% names(REGRAS), "REGRA invalida",
              ifelse(REGRAS[x$REGRA] != x$CLASSE, "REGRA incompativel com a CLASSE", NA)))))
  data.frame(cod = cod, LINHA = x$LINHA, item = ch$item,
             repeticao = ch$repeticao == "sim", classe = x$CLASSE, regra = x$REGRA,
             observacao = x$OBSERVACAO, problema = problema, stringsAsFactors = FALSE)
}

ler_respostas <- function(etapa_) {
  r <- do.call(rbind, lapply(names(CODIFICADORES), function(cod) ler_planilha_cod(etapa_, cod)))
  prob <- r[!is.na(r$problema), ]
  if (nrow(prob)) {
    arq <- file.path(CAMINHOS_HUMANA$resultados, paste0("pendencias_", etapa_, ".csv"))
    gravar_csv(prob[, c("cod", "LINHA", "classe", "regra", "problema")], arq)
    print(table(Codificador = prob$cod, Problema = prob$problema))
    stop(nrow(prob), " linhas com problema na etapa ", etapa_, ". Lista em ", arq)
  }
  r
}

# Uma linha por atividade, uma coluna de classe/regra/observacao por
# codificador (primeira ocorrencia; repeticoes ficam de fora)
respostas_largas <- function(r) {
  r1 <- r[!r$repeticao, ]
  out <- data.frame(item = sort(unique(r1$item)), stringsAsFactors = FALSE)
  for (cod in names(CODIFICADORES)) {
    x <- r1[r1$cod == cod, ]
    m <- match(out$item, x$item)
    out[[paste0("classe_", cod)]] <- x$classe[m]
    out[[paste0("regra_", cod)]]  <- x$regra[m]
    out[[paste0("obs_", cod)]]    <- x$observacao[m]
  }
  out
}

concordancia <- function(etapa_) {
  r <- ler_respostas(etapa_)
  w <- respostas_largas(r)
  cods <- names(CODIFICADORES)
  pares <- combn(cods, 2, simplify = FALSE)
  tab <- do.call(rbind, lapply(pares, function(p) {
    k <- kappa_cohen(w[[paste0("classe_", p[1])]], w[[paste0("classe_", p[2])]])
    data.frame(etapa = etapa_, comparacao = paste(p, collapse = " x "), n = k$n,
               concordancia = round(k$concordancia, 4), kappa = round(k$kappa, 4))
  }))
  fl <- kappa_fleiss(as.matrix(w[, paste0("classe_", cods)]))
  unan <- mean(apply(w[, paste0("classe_", cods)], 1, function(z) length(unique(z)) == 1))
  tab <- rbind(tab, data.frame(etapa = etapa_, comparacao = "Fleiss (3 codificadores)",
                               n = fl$n, concordancia = round(unan, 4),
                               kappa = round(fl$kappa, 4)))
  if (etapa_ == "principal") {
    for (cod in cods) {
      x <- r[r$cod == cod, ]
      dup <- x[x$repeticao, ]
      orig <- x[!x$repeticao, ][match(dup$item, x$item[!x$repeticao]), ]
      k <- kappa_cohen(orig$classe, dup$classe)
      tab <- rbind(tab, data.frame(etapa = etapa_, comparacao = paste(cod, "x", cod, "(repeticoes)"),
                                   n = k$n, concordancia = round(k$concordancia, 4),
                                   kappa = round(k$kappa, 4)))
    }
  }
  gravar_csv(tab, file.path(CAMINHOS_HUMANA$resultados, paste0("concordancia_", etapa_, ".csv")))
  cat("\nConcordancia na etapa", etapa_, "(na linha de Fleiss, 'concordancia' = unanimidade):\n")
  print(tab, row.names = FALSE)
  invisible(list(respostas = r, largas = w, tabela = tab))
}

# Kappa de Fleiss (itens com as tres respostas)
kappa_fleiss <- function(m, niveis = CLASSES) {
  m <- m[stats::complete.cases(m), , drop = FALSE]
  n <- ncol(m)
  cont <- t(apply(m, 1, function(z) table(factor(z, levels = niveis))))
  p_j <- colSums(cont) / (nrow(m) * n)
  P_i <- (rowSums(cont^2) - n) / (n * (n - 1))
  list(n = nrow(m), kappa = (mean(P_i) - sum(p_j^2)) / (1 - sum(p_j^2)))
}
