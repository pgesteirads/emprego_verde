# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - 04. COBERTURA E VERIFICACOES
# ==============================================================================
# Mede, para cada ano da PNADc (4o trimestre), a parcela dos ocupados cujo
# grupo da COD recebeu indice; lista os grupos sem indice; e confere casos de
# controle. Grava saida/ponte/cobertura_pnadc.csv e grupos_sem_indice.csv.
# ==============================================================================

etapa("Ponte 04. Cobertura na PNADc")

pn <- arrow::read_parquet(file.path(RAIZ, "dados", "base_pnadc_tratada_trimestral_4.parquet"),
                          col_select = c("Ano", "V4010", "V1028"))
pn <- pn[!is.na(pn$V4010), ]
pn$Ano <- as.integer(pn$Ano)
ano_ref <- function(a) ANOS_RAIS[which.min(abs(ANOS_RAIS - a))]

cob <- do.call(rbind, lapply(sort(unique(pn$Ano)), function(a) {
  x <- pn[pn$Ano == a, ]
  ic <- indice_cod[indice_cod$ANO_RAIS == ano_ref(a) & !is.na(indice_cod$Verde_amplo), ]
  peso <- tapply(x$V1028, x$V4010, sum)
  com <- names(peso) %in% ic$COD
  data.frame(ANO_PNADC = a, ANO_RAIS = ano_ref(a), COD_NA_PNADC = length(peso),
             COD_COM_INDICE = sum(com),
             OCUPADOS_MIL = round(sum(peso) / 1e3),
             COBERTURA_PCT = round(100 * sum(peso[com]) / sum(peso), 2))
}))
print(cob, row.names = FALSE)
gravar_csv(cob, file.path(DIR_PONTE_SAI, "cobertura_pnadc.csv"))

x <- pn[pn$Ano == max(pn$Ano), ]
peso <- tapply(x$V1028, x$V4010, sum)
ic <- indice_cod[indice_cod$ANO_RAIS == ano_ref(max(pn$Ano)), ]
sem <- names(peso)[!names(peso) %in% ic$COD[!is.na(ic$Verde_amplo)]]
gs <- data.frame(COD = sem, TITULO = titulo_cod(sem), OCUPADOS_MIL = round(peso[sem] / 1e3, 1),
                 MOTIVO = ifelse(sem %in% ic$COD, "so ocupacoes nao reportaveis ou sem Perfil Ocupacional",
                                 "sem ocupacao da CBO ligada"))
gs <- gs[order(-gs$OCUPADOS_MIL), ]
gravar_csv(gs, file.path(DIR_PONTE_SAI, "grupos_sem_indice.csv"))
cat("\nGrupos da COD sem indice na PNADc", max(pn$Ano), ":\n"); print(head(gs, 15), row.names = FALSE)

# Casos de controle
ic24 <- ic[!is.na(ic$Verde_amplo), ]
cat("\nInstalador fotovoltaico (CBO 732140) esta ligado a:",
    paste(ponte$COD[ponte$CBO2002 == "732140"], collapse = ", "), "\n")
print(ic24[ic24$COD %in% ponte$COD[ponte$CBO2002 == "732140"],
           c("COD", "TITULO_COD", "N_CBO_REPORTAVEIS", "Verde_amplo", "Marrom")], row.names = FALSE)
cat("\nMaiores indices verdes por grupo da COD:\n")
print(head(ic24[order(-ic24$Verde_amplo), c("COD", "TITULO_COD", "Verde_amplo", "Marrom")], 10), row.names = FALSE)
cat("\nMaiores indices marrons por grupo da COD:\n")
print(head(ic24[order(-ic24$Marrom), c("COD", "TITULO_COD", "Verde_amplo", "Marrom")], 10), row.names = FALSE)
