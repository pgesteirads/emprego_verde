# ==============================================================================
# CLASSIFICACAO HUMANA - 03. DIVERGENCIAS, REUNIAO E ROTULOS FINAIS
# ==============================================================================
# preparar_reuniao(etapa)  gera resultados/reuniao_<etapa>.xlsx com as
#   atividades a decidir em conjunto (protocolo, secao 7). Na calibracao,
#   todas as 40 vao para a reuniao.
# finalizar_rotulos()      le as decisoes da calibracao e da etapa principal e
#   grava insumos/rotulos_atividade_humana.csv.
# ==============================================================================

etapa("Humana 03. Decisao (funcoes carregadas)")

# Decisao automatica pela regra do protocolo; NA = vai para a reuniao
decisao_automatica <- function(a, b, c, opcao = OPCAO_DECISAO) {
  v <- c(a, b, c)
  tab <- sort(table(v), decreasing = TRUE)
  if (length(tab) == 1) return(c(names(tab)[1], "unanimidade"))
  if (opcao == "A" || length(tab) == 3) return(c(NA, "reuniao"))
  if (setequal(names(tab), c("VERDE", "NEUTRO"))) return(c(NA, "reuniao"))
  c(names(tab)[1], "maioria")
}

preparar_reuniao <- function(etapa_) {
  stopifnot(etapa_ %in% c("calibracao", "principal"))
  w <- respostas_largas(ler_respostas(etapa_))
  cods <- names(CODIFICADORES)
  cj <- conjuntos_humana()[[etapa_]]
  w$ATIVIDADE <- cj$ATIVIDADE[match(w$item, cj$item)]
  ch <- cj$chave[match(w$item, cj$item)]
  nocup <- tapply(perfil$COD_OCUPACAO, perfil$chave, function(z) length(unique(z)))
  w$N_OCUPACOES <- as.integer(nocup[ch])

  dec <- t(mapply(decisao_automatica, w$classe_C1, w$classe_C2, w$classe_C3))
  w$classe_automatica <- dec[, 1]
  w$decisao <- if (etapa_ == "calibracao") "reuniao" else dec[, 2]
  w$alto_impacto <- w$N_OCUPACOES >= LIMIAR_ALTO_IMPACTO & w$decisao != "reuniao"
  gravar_csv(w, file.path(CAMINHOS_HUMANA$resultados, paste0("respostas_", etapa_, ".csv")))

  resumo_cod <- function(i, cod) {
    paste0(w[[paste0("classe_", cod)]][i], " (", w[[paste0("regra_", cod)]][i], ")",
           ifelse(is.na(w[[paste0("obs_", cod)]][i]), "",
                  paste0(" obs: ", w[[paste0("obs_", cod)]][i])))
  }
  monta <- function(idx, prefixo_decisao = "") {
    data.frame(ITEM = w$item[idx], ATIVIDADE = w$ATIVIDADE[idx],
               N_OCUPACOES = w$N_OCUPACOES[idx],
               C1 = resumo_cod(idx, "C1"), C2 = resumo_cod(idx, "C2"), C3 = resumo_cod(idx, "C3"),
               DECISAO = prefixo_decisao, REGRA = "", JUSTIFICATIVA = "",
               stringsAsFactors = FALSE)
  }
  idx_r <- which(w$decisao == "reuniao"); idx_r <- idx_r[order(-w$N_OCUPACOES[idx_r])]
  idx_a <- which(w$alto_impacto);         idx_a <- idx_a[order(-w$N_OCUPACOES[idx_a])]
  abas <- list(Decidir = monta(idx_r))
  if (length(idx_a)) {
    x <- monta(idx_a)
    x$CLASSE_ATUAL <- w$classe_automatica[idx_a]
    abas$Conferir_alto_impacto <- x[, c("ITEM", "ATIVIDADE", "N_OCUPACOES", "C1", "C2", "C3",
                                        "CLASSE_ATUAL", "DECISAO", "REGRA", "JUSTIFICATIVA")]
  }

  arq <- file.path(CAMINHOS_HUMANA$resultados, paste0("reuniao_", etapa_, ".xlsx"))
  if (file.exists(arq)) { cat("ja existe, mantida:", arq, "\n"); return(invisible(w)) }
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Leia-me")
  openxlsx::writeData(wb, "Leia-me", c(
    paste("REUNIAO DE DECISAO CONJUNTA  |  etapa:", etapa_),
    "",
    "Aba 'Decidir': atividades sem decisao automatica. Preencher DECISAO, REGRA e",
    "JUSTIFICATIVA em todas as linhas, aplicando a rubrica, por consenso.",
    if (length(idx_a)) c(
      "Aba 'Conferir_alto_impacto': atividades presentes em muitas ocupacoes que ja",
      "tem classe automatica (CLASSE_ATUAL). Deixe DECISAO em branco para manter;",
      "preencha DECISAO, REGRA e JUSTIFICATIVA so se for mudar.") else NULL,
    "",
    "As classes individuais (C1, C2, C3) ficam registradas como estao; a reuniao",
    "decide apenas a classe final. Linhas ordenadas pelo numero de ocupacoes."),
    colNames = FALSE)
  openxlsx::addWorksheet(wb, "Listas", visible = FALSE)
  openxlsx::writeData(wb, "Listas", data.frame(CLASSE = CLASSES), startCol = 1)
  openxlsx::writeData(wb, "Listas", data.frame(REGRA = names(REGRAS)), startCol = 2)
  for (nm in names(abas)) {
    openxlsx::addWorksheet(wb, nm)
    openxlsx::writeData(wb, nm, abas[[nm]],
                        headerStyle = openxlsx::createStyle(textDecoration = "bold", fgFill = "#DDEBF7"))
    nc <- ncol(abas[[nm]])
    openxlsx::setColWidths(wb, nm, 1:nc, c(14, 60, 8, rep(28, 3), if (nc == 10) 12, 12, 20, 50))
    openxlsx::freezePane(wb, nm, firstRow = TRUE)
    if (nrow(abas[[nm]])) {
      linhas <- 2:(nrow(abas[[nm]]) + 1)
      cdec <- match("DECISAO", names(abas[[nm]]))
      openxlsx::dataValidation(wb, nm, cols = cdec, rows = linhas, type = "list",
                               value = sprintf("'Listas'!$A$2:$A$%d", length(CLASSES) + 1))
      openxlsx::dataValidation(wb, nm, cols = cdec + 1, rows = linhas, type = "list",
                               value = sprintf("'Listas'!$B$2:$B$%d", length(REGRAS) + 1))
    }
  }
  openxlsx::saveWorkbook(wb, arq)
  cat("\nEtapa", etapa_, "- decisoes:\n"); print(table(w$decisao))
  cat("para decidir na reuniao:", length(idx_r), "| alto impacto a conferir:", length(idx_a), "\n")
  cat("planilha da reuniao:", arq, "\n")
  invisible(w)
}

ler_reuniao <- function(etapa_) {
  arq <- file.path(CAMINHOS_HUMANA$resultados, paste0("reuniao_", etapa_, ".xlsx"))
  ler_aba <- function(aba) {
    if (!aba %in% readxl::excel_sheets(arq)) return(NULL)
    x <- as.data.frame(readxl::read_excel(arq, sheet = aba, col_types = "text"))
    x$DECISAO <- toupper(trimws(x$DECISAO)); x$REGRA <- toupper(trimws(x$REGRA))
    x
  }
  d <- ler_aba("Decidir"); a <- ler_aba("Conferir_alto_impacto")
  checa <- function(x, obrigatorio) {
    if (is.null(x) || !nrow(x)) return(character(0))
    preenchido <- !is.na(x$DECISAO) & x$DECISAO != ""
    ruim <- (obrigatorio & !preenchido) |
      (preenchido & (!x$DECISAO %in% CLASSES | !x$REGRA %in% names(REGRAS) |
                       REGRAS[ifelse(is.na(x$REGRA), "", x$REGRA)] != x$DECISAO |
                       is.na(x$JUSTIFICATIVA)))
    x$ITEM[ruim %in% TRUE]
  }
  pend <- c(checa(d, TRUE), checa(a, FALSE))
  if (length(pend)) stop(etapa_, ": ", length(pend), " linhas da reuniao sem decisao, ",
                         "regra compativel ou justificativa (ex.: ",
                         paste(head(pend, 3), collapse = ", "), ").")
  list(decidir = d, alto = a)
}

finalizar_rotulos <- function() {
  partes <- lapply(c("calibracao", "principal"), function(e) {
    w <- ler_csv(file.path(CAMINHOS_HUMANA$resultados, paste0("respostas_", e, ".csv")))
    rn <- ler_reuniao(e)
    w$classe_final <- w$classe_automatica
    w$regra_final <- NA_character_
    w$justificativa <- NA_character_
    aplica <- function(x) {
      if (is.null(x) || !nrow(x)) return()
      x <- x[!is.na(x$DECISAO) & x$DECISAO != "", ]
      m <- match(x$ITEM, w$item)
      w$classe_final[m] <<- x$DECISAO
      w$regra_final[m] <<- x$REGRA
      w$justificativa[m] <<- x$JUSTIFICATIVA
      w$decisao[m] <<- ifelse(w$decisao[m] == "reuniao", "reuniao", "conferencia_alto_impacto")
    }
    aplica(rn$decidir); aplica(rn$alto)
    if (anyNA(w$classe_final)) stop(e, ": atividades sem classe final.")
    w$etapa <- e
    w
  })
  f <- do.call(rbind, partes)
  out <- data.frame(Atividade = f$ATIVIDADE, Classe_final = f$classe_final,
                    C1 = f$classe_C1, C2 = f$classe_C2, C3 = f$classe_C3,
                    Decisao = f$decisao, Regra_reuniao = f$regra_final,
                    Justificativa = f$justificativa, Etapa = f$etapa,
                    Rodada = paste0("humana_", format(Sys.Date(), "%Y-%m")),
                    stringsAsFactors = FALSE)
  destino <- if (MODO_HUMANA == "real") file.path(CAMINHOS$insumos, "rotulos_atividade_humana.csv")
             else file.path(CAMINHOS_HUMANA$resultados, "rotulos_atividade_humana_SIMULADO.csv")
  gravar_csv(out, destino)

  # Mudanca em relacao a maioria e comparacao com setembro
  maioria <- apply(f[, c("classe_C1", "classe_C2", "classe_C3")], 1, function(z) {
    t <- sort(table(z), decreasing = TRUE); if (t[1] >= 2) names(t)[1] else NA })
  reun <- f$decisao == "reuniao"
  cat("rotulos finais:", nrow(out), "->", destino, "\n")
  print(table(out$Classe_final))
  cat("decididos em reuniao:", sum(reun), "| reuniao contrariou a maioria:",
      sum(reun & !is.na(maioria) & maioria != f$classe_final), "\n")
  ks <- kappa_cohen(out$Classe_final, unname(classe_todas[chave(out$Atividade)]))
  cat(sprintf("rotulos humanos x setembro: concordancia %.1f%%, kappa %.3f (n = %d)\n",
              100 * ks$concordancia, ks$kappa, ks$n))
  invisible(out)
}
