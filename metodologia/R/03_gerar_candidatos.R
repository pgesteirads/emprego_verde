# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 03. GERACAO DE CANDIDATOS
# ==============================================================================
#
# Aplica o dicionario (com as excecoes) a cada enunciado distinto.
#
# ATENCAO: o dicionario NAO classifica. Ele so seleciona as atividades que
# precisam ser lidas. Cerca de um quinto das capturas e NEUTRO. A classe vem
# dos rotulos (etapa 04), decididos pela leitura do enunciado conforme
# metodologia/RUBRICA.md. Nunca atribuir classe pelo termo que capturou.
#
# As expressoes sao PCRE (perl = TRUE) e operam sobre texto normalizado
# (maiusculas, sem acentos), que e o que a chave contem.
#
# Produz no ambiente:
#   dicionario, excecoes
#   candidatos        uma linha por enunciado capturado, com os IDs dos termos
#   auditoria_termos  capturas por termo e supressoes por excecao
# E grava em saida/intermediarios/: candidatos.csv, auditoria_termos.csv,
# auditoria_excecoes.csv
# ==============================================================================

etapa("03. Geracao de candidatos")

dicionario <- ler_csv(ARQ_INSUMOS$dicionario)
excecoes   <- ler_csv(ARQ_INSUMOS$excecoes)

stopifnot(!anyDuplicated(dicionario$ID),
          all(excecoes$Termo_alvo %in% dicionario$ID))

# Toda expressao precisa compilar. Uma expressao invalida pararia aqui, e nao
# silenciosamente no meio da varredura.
for (p in c(dicionario$Padrao, excecoes$Padrao_excecao)) {
  ok <- tryCatch({ grepl(p, "TESTE", perl = TRUE); TRUE },
                 error = function(e) FALSE)
  if (!ok) stop("Expressao invalida no dicionario ou nas excecoes: ", p)
}

# Matriz de capturas: linhas = enunciados distintos, colunas = termos.
captura_bruta <- matrix(FALSE, nrow = length(distintos), ncol = nrow(dicionario),
                        dimnames = list(NULL, dicionario$ID))
captura <- captura_bruta
supressoes <- integer(nrow(excecoes))

for (i in seq_len(nrow(dicionario))) {
  hit <- grepl(dicionario$Padrao[i], distintos, perl = TRUE)
  captura_bruta[, i] <- hit
  idx_exc <- which(excecoes$Termo_alvo == dicionario$ID[i])
  for (j in idx_exc) {
    bloq <- hit & grepl(excecoes$Padrao_excecao[j], distintos, perl = TRUE)
    supressoes[j] <- sum(bloq)
    hit <- hit & !bloq
  }
  captura[, i] <- hit
}

capturado <- rowSums(captura) > 0
termos_por_enunciado <- apply(captura[capturado, , drop = FALSE], 1,
                              function(z) paste(dicionario$ID[z], collapse = ";"))
classes_dic <- apply(captura[capturado, , drop = FALSE], 1, function(z) {
  paste(sort(unique(dicionario$Classe[z])), collapse = ";")
})

candidatos <- data.frame(
  chave              = distintos[capturado],
  termos             = unname(termos_por_enunciado),
  classes_dicionario = unname(classes_dic),
  stringsAsFactors   = FALSE
)

auditoria_termos <- data.frame(
  ID                   = dicionario$ID,
  Classe_dicionario    = dicionario$Classe,
  Categoria            = dicionario$Categoria,
  Padrao               = dicionario$Padrao,
  Capturas_brutas      = colSums(captura_bruta),
  Capturas_apos_excecao = colSums(captura),
  stringsAsFactors     = FALSE,
  row.names            = NULL
)
auditoria_excecoes <- cbind(excecoes, Enunciados_suprimidos = supressoes)

gravar_csv(candidatos, file.path(CAMINHOS$intermed, "candidatos.csv"))
gravar_csv(auditoria_termos, file.path(CAMINHOS$intermed, "auditoria_termos.csv"))
gravar_csv(auditoria_excecoes,
           file.path(CAMINHOS$intermed, "auditoria_excecoes.csv"))

cat("termos no dicionario:", nrow(dicionario), "\n")
cat("excecoes:", nrow(excecoes), "\n")
cat("atividades candidatas:", nrow(candidatos), "\n")
cat("termos que nao capturam nada:",
    sum(auditoria_termos$Capturas_apos_excecao == 0), "\n")
rm(captura_bruta)
