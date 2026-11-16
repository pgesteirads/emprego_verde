# ==============================================================================
# PAINEL DE MODELOS - 04. AGREGACAO, CONCORDANCIA E ARBITRAGEM
# ==============================================================================
# Aplica as regras de votacao da secao 7 do protocolo, mede a concordancia
# entre os membros, compara com a rodada de setembro e prepara a planilha de
# arbitragem. finalizar_painel() incorpora as decisoes dos arbitros.
# ==============================================================================

etapa("Painel 04. Agregacao (funcoes carregadas)")

regra_votacao <- function(a, b, c) {
  v <- c(a, b, c)
  ok <- v[!is.na(v)]
  if (length(ok) < 2) return(c(NA, "sem_respostas"))
  tab <- sort(table(ok), decreasing = TRUE)
  if (length(ok) == 2) {
    return(if (length(tab) == 1) c(names(tab)[1], "dois_membros") else c(NA, "arbitragem"))
  }
  if (length(tab) == 1) return(c(names(tab)[1], "unanimidade"))
  if (length(tab) == 3) return(c(NA, "arbitragem"))
  maioria <- names(tab)[1]; minoria <- names(tab)[2]
  if (setequal(c(maioria, minoria), c("VERDE", "NEUTRO"))) return(c(NA, "arbitragem"))
  c(maioria, "maioria")
}

agregar_painel <- function() {
  r <- lapply(names(PAINEL), function(m) {
    x <- respostas_validas(arquivo_respostas(m), prompts$hash_principal)
    names(x)[-1] <- paste0(names(x)[-1], "_", m)
    x
  })
  painel <- Reduce(function(a, b) merge(a, b, by = "id", all = TRUE),
                   r, init = data.frame(id = itens$ID))
  painel <- merge(itens, painel, by.x = "ID", by.y = "id", all.x = TRUE)

  dec <- t(mapply(regra_votacao, painel$classe_A, painel$classe_B, painel$classe_C))
  painel$classe_painel <- dec[, 1]
  painel$decisao <- dec[, 2]
  painel$classe_setembro <- unname(classe_todas[painel$chave])

  # --- Concordancia ---
  pares <- combn(names(PAINEL), 2, simplify = FALSE)
  conc <- do.call(rbind, lapply(pares, function(p) {
    k <- kappa_cohen(painel[[paste0("classe_", p[1])]], painel[[paste0("classe_", p[2])]])
    data.frame(comparacao = paste(p, collapse = " x "), n = k$n,
               concordancia = round(k$concordancia, 4), kappa = round(k$kappa, 4))
  }))
  fl <- kappa_fleiss(as.matrix(painel[, paste0("classe_", names(PAINEL))]))
  conc <- rbind(conc, data.frame(comparacao = "Fleiss (A, B, C)", n = fl$n,
                                 concordancia = NA, kappa = round(fl$kappa, 4)))
  ks <- kappa_cohen(painel$classe_painel, painel$classe_setembro)
  conc <- rbind(conc, data.frame(comparacao = "painel x setembro (itens decididos)",
                                 n = ks$n, concordancia = round(ks$concordancia, 4),
                                 kappa = round(ks$kappa, 4)))

  # --- Saidas ---
  cols <- c("ID", "ATIVIDADE", paste0(rep(c("classe_", "regra_", "justificativa_"),
                                          each = length(PAINEL)), names(PAINEL)),
            "classe_painel", "decisao", "classe_setembro")
  gravar_csv(painel[, cols], file.path(CAMINHOS_PAINEL$resultados, "painel_agregado.csv"))
  gravar_csv(conc, file.path(CAMINHOS_PAINEL$resultados, "concordancia.csv"))

  arb <- painel[painel$decisao %in% c("arbitragem", "sem_respostas"), ]
  planilha <- data.frame(
    ID = arb$ID, ATIVIDADE = arb$ATIVIDADE,
    A = paste0(arb$classe_A, " (", arb$regra_A, "): ", arb$justificativa_A),
    B = paste0(arb$classe_B, " (", arb$regra_B, "): ", arb$justificativa_B),
    C = paste0(arb$classe_C, " (", arb$regra_C, "): ", arb$justificativa_C),
    ARBITRAGEM = "", REGRA = "", JUSTIFICATIVA = "", ARBITROS = "",
    stringsAsFactors = FALSE)
  arq_arb <- file.path(CAMINHOS_PAINEL$resultados, "arbitragem.tsv")
  if (file.exists(arq_arb)) {
    cat("arbitragem.tsv ja existe; nao foi sobrescrito.\n")
  } else {
    gravar_tsv(planilha, arq_arb)
  }

  cat("\nDecisoes:\n"); print(table(painel$decisao, useNA = "ifany"))
  cat("\nClasse do painel (itens decididos):\n"); print(table(painel$classe_painel))
  cat("\nConcordancia:\n"); print(conc, row.names = FALSE)
  cat("\n", nrow(planilha), " itens para arbitragem em ", arq_arb, "\n", sep = "")
  painel_agregado <<- painel
  invisible(painel)
}

# Le a planilha de arbitragem preenchida e grava os rotulos finais do painel
# em metodologia/insumos/rotulos_atividade_painel.csv. Nao troca o insumo do
# indice: essa troca e uma decisao a parte (ver LEIA-ME).
finalizar_painel <- function() {
  if (!exists("painel_agregado")) agregar_painel()
  p <- painel_agregado
  arb <- ler_tsv(file.path(CAMINHOS_PAINEL$resultados, "arbitragem.tsv"))
  arb$ARBITRAGEM <- toupper(trimws(arb$ARBITRAGEM))
  pend <- arb$ID[is.na(arb$ARBITRAGEM) | !arb$ARBITRAGEM %in% CLASSES |
                   is.na(arb$JUSTIFICATIVA) | is.na(arb$ARBITROS)]
  if (length(pend)) stop(length(pend), " itens de arbitragem sem classe valida, ",
                         "justificativa ou arbitros (ex.: ",
                         paste(head(pend, 3), collapse = ", "), ").")
  m <- match(arb$ID, p$ID)
  p$classe_painel[m] <- arb$ARBITRAGEM
  p$justificativa_arbitragem <- NA_character_
  p$justificativa_arbitragem[m] <- arb$JUSTIFICATIVA
  p$arbitros <- NA_character_
  p$arbitros[m] <- arb$ARBITROS
  stopifnot(!anyNA(p$classe_painel))
  out <- data.frame(
    Atividade = p$ATIVIDADE, Classe_final = p$classe_painel,
    Membro_A = p$classe_A, Membro_B = p$classe_B, Membro_C = p$classe_C,
    Decisao = p$decisao, Justificativa_arbitragem = p$justificativa_arbitragem,
    Arbitros = p$arbitros, Rodada = paste0("painel_", format(Sys.Date(), "%Y-%m")),
    stringsAsFactors = FALSE)
  destino <- file.path(CAMINHOS$insumos,
                       if (MODO_PAINEL == "real") "rotulos_atividade_painel.csv"
                       else "rotulos_atividade_painel_SIMULADO.csv")
  if (MODO_PAINEL == "simulado") destino <- file.path(CAMINHOS_PAINEL$resultados,
                                                      basename(destino))
  gravar_csv(out, destino)
  cat(nrow(out), "rotulos finais gravados em", destino, "\n")
  print(table(out$Classe_final))
  invisible(out)
}
