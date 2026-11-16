# ==============================================================================
# CLASSIFICACAO HUMANA - 01. CONJUNTOS DE ITENS E PLANILHAS
# ==============================================================================
# Requer as etapas 00 a 04 do pipeline do indice (candidatos, perfil, distintos).
#
# conjuntos_humana()  define, com sementes fixas, os itens da calibracao, da
#                     classificacao principal e da auditoria de recall.
# gerar_planilhas()   grava as planilhas Excel de cada codificador e as chaves.
#                     Recusa-se a sobrescrever planilhas existentes.
# ==============================================================================

etapa("Humana 01. Planilhas (funcoes carregadas)")

texto_original <- function(chaves) perfil$NOME_ATIVIDADE[match(chaves, perfil$chave)]

conjuntos_humana <- function() {
  cand <- data.frame(item = id_item(candidatos$chave), chave = candidatos$chave,
                     dic = candidatos$classes_dicionario, stringsAsFactors = FALSE)
  cand$ATIVIDADE <- texto_original(cand$chave)
  cand <- cand[order(cand$item), ]

  # Calibracao: estratificada pela classe sugerida pelo termo do dicionario
  set.seed(SEMENTE_CALIBRACAO)
  estrato <- ifelse(grepl(";", cand$dic), "AMBIGUO", cand$dic)
  por_estrato <- split(seq_len(nrow(cand)), estrato)
  quota <- round(N_CALIBRACAO * lengths(por_estrato) / nrow(cand))
  quota[quota == 0] <- 1
  while (sum(quota) > N_CALIBRACAO) { i <- which.max(quota); quota[i] <- quota[i] - 1 }
  while (sum(quota) < N_CALIBRACAO) { i <- which.max(lengths(por_estrato) - quota); quota[i] <- quota[i] + 1 }
  idx_cal <- unlist(mapply(function(ix, q) ix[sample.int(length(ix), q)],
                           por_estrato, quota, SIMPLIFY = FALSE))
  calibracao <- cand[sort(idx_cal), c("item", "chave", "ATIVIDADE")]
  principal  <- cand[-idx_cal, c("item", "chave", "ATIVIDADE")]

  # Recall: sorteio entre os enunciados NAO capturados
  nao_cap <- setdiff(distintos, candidatos$chave)
  set.seed(SEMENTE_RECALL)
  ch <- sort(nao_cap)[sample.int(length(nao_cap), N_RECALL)]
  recall <- data.frame(item = id_item(ch), chave = ch, ATIVIDADE = texto_original(ch),
                       stringsAsFactors = FALSE)
  recall <- recall[order(recall$item), ]

  list(calibracao = calibracao, principal = principal, recall = recall)
}

# Texto da aba de instrucoes
instrucoes_planilha <- function(etapa_, cod) {
  c(paste0("CLASSIFICACAO DE ATIVIDADES OCUPACIONAIS  |  etapa: ", etapa_,
           "  |  codificador: ", cod),
    "",
    "1. Leia metodologia/RUBRICA.md antes de comecar e mantenha-a aberta.",
    "2. Para cada linha da aba 'Classificacao', escolha na lista suspensa:",
    "   CLASSE: VERDE, POTENCIAL, MARROM ou NEUTRO;",
    "   REGRA: o trecho da rubrica que decidiu (VERDE, POTENCIAL, MARROM, NEUTRO_1 a NEUTRO_6",
    "   ou NEUTRO_CONSERVADOR). A regra precisa ser compativel com a classe.",
    "3. OBSERVACAO e opcional: use para registrar duvidas.",
    "4. Julgue somente o enunciado. Nao procure saber a que ocupacao ele pertence.",
    "5. Nao converse com os outros codificadores sobre itens especificos ate todos",
    "   entregarem. Nao abra os rotulos de setembro nem as planilhas dos outros.",
    "6. Nao altere a ordem das linhas nem as colunas LINHA e ATIVIDADE.",
    "7. Pode salvar e continuar depois. Faca pausas: sessoes de cerca de 1 hora.",
    if (etapa_ == "recall") c("",
      "Nesta etapa, as atividades NAO foram capturadas pelo dicionario de termos.",
      "A maioria deve ser NEUTRO. Aplique a rubrica normalmente e marque outra classe",
      "sempre que o enunciado tiver conteudo ambiental.") else NULL,
    if (etapa_ == "principal") c("",
      "Algumas atividades podem aparecer mais de uma vez. Classifique cada linha",
      "normalmente, sem procurar a ocorrencia anterior.") else NULL)
}

escrever_planilha <- function(df, arquivo, etapa_, cod) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Instrucoes")
  openxlsx::writeData(wb, "Instrucoes", instrucoes_planilha(etapa_, cod), colNames = FALSE)
  openxlsx::setColWidths(wb, "Instrucoes", 1, 110)

  openxlsx::addWorksheet(wb, "Classificacao")
  out <- data.frame(LINHA = df$LINHA, ATIVIDADE = df$ATIVIDADE, CLASSE = "", REGRA = "",
                    OBSERVACAO = "", stringsAsFactors = FALSE)
  openxlsx::writeData(wb, "Classificacao", out,
                      headerStyle = openxlsx::createStyle(textDecoration = "bold",
                                                          fgFill = "#DDEBF7"))
  openxlsx::setColWidths(wb, "Classificacao", 1:5, c(8, 90, 14, 22, 40))
  openxlsx::freezePane(wb, "Classificacao", firstRow = TRUE)

  openxlsx::addWorksheet(wb, "Listas", visible = FALSE)
  openxlsx::writeData(wb, "Listas", data.frame(CLASSE = CLASSES), startCol = 1)
  openxlsx::writeData(wb, "Listas", data.frame(REGRA = names(REGRAS)), startCol = 2)
  linhas <- 2:(nrow(out) + 1)
  openxlsx::dataValidation(wb, "Classificacao", cols = 3, rows = linhas, type = "list",
                           value = sprintf("'Listas'!$A$2:$A$%d", length(CLASSES) + 1))
  openxlsx::dataValidation(wb, "Classificacao", cols = 4, rows = linhas, type = "list",
                           value = sprintf("'Listas'!$B$2:$B$%d", length(REGRAS) + 1))
  openxlsx::saveWorkbook(wb, arquivo, overwrite = FALSE)
}

gerar_planilhas <- function(etapas = ETAPAS_HUMANA) {
  cj <- conjuntos_humana()
  for (e in etapas) {
    for (k in seq_along(CODIFICADORES)) {
      cod <- names(CODIFICADORES)[k]
      if (file.exists(arq_planilha(e, cod))) {
        cat("ja existe, mantida:", basename(arq_planilha(e, cod)), "\n"); next
      }
      itens_e <- cj[[e]]
      itens_e$repeticao <- FALSE
      if (e == "principal") {
        set.seed(SEMENTE_REPETICAO + k)
        rep_ <- itens_e[sample.int(nrow(itens_e), round(TAXA_REPETICAO * nrow(itens_e))), ]
        rep_$repeticao <- TRUE
        itens_e <- rbind(itens_e, rep_)
      }
      # ordem propria de cada codificador; a repeticao nunca fica perto do original
      set.seed(SEMENTE_ORDEM + 10 * k + match(e, ETAPAS_HUMANA))
      repeat {
        o <- sample.int(nrow(itens_e))
        pos <- match(seq_len(nrow(itens_e)), o)
        dup <- which(itens_e$repeticao)
        orig <- match(itens_e$item[dup], itens_e$item)
        if (!length(dup) || all(abs(pos[dup] - pos[orig]) > 50)) break
      }
      itens_e <- itens_e[o, ]
      itens_e$LINHA <- seq_len(nrow(itens_e))
      gravar_csv(itens_e[, c("LINHA", "item", "repeticao")], arq_chave(e, cod))
      escrever_planilha(itens_e, arq_planilha(e, cod), e, cod)
      cat(sprintf("%-10s %s: %d linhas -> %s\n", e, cod, nrow(itens_e),
                  basename(arq_planilha(e, cod))))
    }
  }
  # registro dos conjuntos (sem classes), para o protocolo
  reg <- list(data = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              n = lapply(cj, nrow),
              hash_rubrica = hash_arquivo(file.path(RAIZ, "metodologia", "RUBRICA.md")),
              hash_dicionario = hash_arquivo(ARQ_INSUMOS$dicionario),
              hash_excecoes = hash_arquivo(ARQ_INSUMOS$excecoes),
              hash_chaves = lapply(list.files(CAMINHOS_HUMANA$chaves, full.names = TRUE),
                                   hash_arquivo))
  writeLines(jsonlite::toJSON(reg, auto_unbox = TRUE, pretty = TRUE),
             file.path(CAMINHOS_HUMANA$base, "registro_conjuntos.json"), useBytes = TRUE)
  invisible(cj)
}
