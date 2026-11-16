# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - 03. CONSTRUCAO DA PONTE E INDICE POR COD
# ==============================================================================
#
# Liga cada ocupacao da CBO 2002 (6 digitos) a um ou mais grupos da COD
# (4 digitos), por quatro rotas, em ordem de preferencia:
#
#   tabua_ocupacao  CBO 2002 -> CIUO-88 pela tabua oficial do MTE, com
#                   ligacao propria da ocupacao; CIUO-88 -> ISCO-08 pela
#                   correspondencia da OIT; ISCO-08 = COD.
#   tabua_familia   igual, mas a ligacao CBO -> CIUO-88 foi herdada da
#                   familia da ocupacao.
#   manual_familia  familias da CBO ausentes da tabua oficial, ligadas a
#                   grupos da COD pelo titulo (insumos/ponte/
#                   ligacoes_manuais_familia.csv).
#   manual_cod      grupos da COD presentes na PNADc que ficaram sem nenhuma
#                   ocupacao da CBO pelas rotas anteriores, ligados a familias
#                   da CBO pelo titulo (insumos/ponte/ligacoes_manuais_cod.csv).
#
# Indice de cada grupo da COD: media dos indices das ocupacoes da CBO ligadas
# a ele, ponderada pelos vinculos da RAIS. Quando uma ocupacao se liga a k
# grupos, seus vinculos sao divididos igualmente entre eles. So entram
# ocupacoes reportaveis (15 atividades ou mais). Grupo sem nenhum vinculo na
# RAIS recebe a media simples, com marca.
#
# Requer as etapas 00 a 05 do indice e as etapas 01 e 02 da ponte.
# ==============================================================================

etapa("Ponte 03. Construcao da ponte")

DIR_PONTE_SAI <- file.path(CAMINHOS$saida, "ponte")
dir.create(DIR_PONTE_SAI, showWarnings = FALSE, recursive = TRUE)

cbo_ciuo  <- ler_csv(ARQ_PONTE$cbo_ciuo)
ciuo_isco <- ler_csv(ARQ_PONTE$ciuo_isco)
man_fam   <- ler_csv(ARQ_PONTE$manual_fam)
rot_br    <- ler_csv(ARQ_PONTE$rotulos_cod)

ocup <- data.frame(CBO2002 = indice$CBO, FAMILIA = indice$Familia, stringsAsFactors = FALSE)

# --- Rotas pela tabua oficial ---
t1 <- merge(cbo_ciuo, ciuo_isco[, c("CIUO88", "ISCO08", "PARCIAL")], by = "CIUO88")
t1 <- data.frame(CBO2002 = t1$CBO2002, COD = t1$ISCO08,
                 ROTA = ifelse(t1$TIPO_LIGACAO == "direta-ocupacao", "tabua_ocupacao",
                               "tabua_familia"),
                 PARCIAL = t1$PARCIAL, stringsAsFactors = FALSE)

# --- Rota manual por familia ---
mf <- do.call(rbind, lapply(seq_len(nrow(man_fam)), function(i) {
  cods <- strsplit(man_fam$COD[i], ";")[[1]]
  cb <- ocup$CBO2002[ocup$FAMILIA == man_fam$COD_FAMILIA[i]]
  if (!length(cb)) return(NULL)
  expand.grid(CBO2002 = cb, COD = cods, stringsAsFactors = FALSE)
}))
mf$ROTA <- "manual_familia"; mf$PARCIAL <- NA_character_

ponte <- rbind(t1, mf[, names(t1)])
ponte <- ponte[ponte$CBO2002 %in% ocup$CBO2002, ]

# --- Rota manual pelo lado da COD ---
if (file.exists(ARQ_PONTE$manual_cod)) {
  mc <- ler_csv(ARQ_PONTE$manual_cod)
  mcl <- do.call(rbind, lapply(seq_len(nrow(mc)), function(i) {
    fams <- strsplit(mc$FAMILIAS_CBO[i], ";")[[1]]
    cb <- ocup$CBO2002[ocup$FAMILIA %in% fams]
    if (!length(cb)) return(NULL)
    data.frame(CBO2002 = cb, COD = mc$COD[i], ROTA = "manual_cod", PARCIAL = NA_character_,
               stringsAsFactors = FALSE)
  }))
  ponte <- rbind(ponte, mcl)
}
# um par CBO x COD aparece uma vez so (prevalece a primeira rota)
ordem_rota <- c("tabua_ocupacao", "tabua_familia", "manual_familia", "manual_cod")
ponte <- ponte[order(ponte$CBO2002, ponte$COD, match(ponte$ROTA, ordem_rota)), ]
ponte <- ponte[!duplicated(ponte[, c("CBO2002", "COD")]), ]
ponte$N_COD_DA_CBO <- as.integer(table(ponte$CBO2002)[ponte$CBO2002])

cbo_sem <- setdiff(ocup$CBO2002, ponte$CBO2002)
cat("pares CBO x COD:", nrow(ponte), "| ocupacoes da CBO ligadas:",
    length(unique(ponte$CBO2002)), "de", nrow(ocup), "| sem ligacao:", length(cbo_sem), "\n")
print(table(Rota = ponte$ROTA[!duplicated(ponte$CBO2002)]))

# ------------------------------------------------------------------------------
# Indice por grupo da COD, ponderado pelos vinculos da RAIS
# ------------------------------------------------------------------------------

COLUNAS_INDICE <- c("Verde_amplo", "Verde_amplo_broad", "Marrom", "Liquido", "Liquido_broad",
                    "Verde_especifico", "Marrom_especifico", "Liquido_especifico")

oit_tit <- setNames(ciuo_isco$TITULO_ISCO08, ciuo_isco$ISCO08)
man_cod_tit <- if (file.exists(ARQ_PONTE$manual_cod)) {
  x <- ler_csv(ARQ_PONTE$manual_cod); setNames(x$TITULO_COD, x$COD) } else character(0)
titulo_cod <- function(cod) {
  t <- unname(oit_tit[cod])
  t[is.na(t)] <- unname(setNames(rot_br$TITULO, rot_br$COD)[cod[is.na(t)]])
  t[is.na(t)] <- unname(man_cod_tit[cod[is.na(t)]])
  t
}

indice_por_cod <- function(ano_rais) {
  r <- rais[rais$ANO == ano_rais, ]
  p <- ponte
  p$VINCULOS_CBO <- r$VINCULOS[match(p$CBO2002, r$CBO2002)]
  p$VINCULOS_CBO[is.na(p$VINCULOS_CBO)] <- 0
  p$PESO <- p$VINCULOS_CBO / p$N_COD_DA_CBO
  m <- match(p$CBO2002, indice$CBO)
  p$REPORTAVEL <- indice$Reportavel[m] == "sim"
  for (cl in COLUNAS_INDICE) p[[cl]] <- indice[[cl]][m]
  q <- p[p$REPORTAVEL, ]
  cods <- sort(unique(p$COD))
  out <- data.frame(ANO_RAIS = ano_rais, COD = cods, TITULO_COD = titulo_cod(cods),
                    stringsAsFactors = FALSE)
  out$N_CBO_LIGADAS <- as.integer(table(p$COD)[cods])
  out$N_CBO_REPORTAVEIS <- as.integer(table(factor(q$COD, levels = cods)))
  out$VINCULOS_RAIS <- round(tapply(q$PESO, factor(q$COD, levels = cods), sum))
  out$VINCULOS_RAIS[is.na(out$VINCULOS_RAIS)] <- 0
  out$PONDERACAO <- ifelse(out$N_CBO_REPORTAVEIS == 0, "sem_ocupacao_reportavel",
                    ifelse(out$VINCULOS_RAIS > 0, "rais", "media_simples"))
  rota_princ <- tapply(p$ROTA, p$COD, function(z) names(sort(table(z), decreasing = TRUE))[1])
  out$ROTA_PREDOMINANTE <- unname(rota_princ[cods])
  for (cl in COLUNAS_INDICE) {
    out[[cl]] <- vapply(cods, function(k) {
      x <- q[q$COD == k & !is.na(q[[cl]]), ]
      if (!nrow(x)) return(NA_real_)
      w <- if (sum(x$PESO) > 0) x$PESO else rep(1, nrow(x))
      round(sum(w * x[[cl]]) / sum(w), 5)
    }, numeric(1))
  }
  list(indice = out, pares = p)
}

res_cod <- lapply(ANOS_RAIS, indice_por_cod)
indice_cod <- do.call(rbind, lapply(res_cod, `[[`, "indice"))
pares_2024 <- res_cod[[which(ANOS_RAIS == max(ANOS_RAIS))]]$pares

gravar_csv(ponte, file.path(DIR_PONTE_SAI, "ponte_cbo2002_cod.csv"))
gravar_csv(indice_cod, file.path(DIR_PONTE_SAI, "indice_por_cod.csv"))
cat("grupos da COD com indice (RAIS", max(ANOS_RAIS), "):",
    sum(!is.na(indice_cod$Verde_amplo[indice_cod$ANO_RAIS == max(ANOS_RAIS)])), "\n")
print(table(Ponderacao = indice_cod$PONDERACAO[indice_cod$ANO_RAIS == max(ANOS_RAIS)]))
