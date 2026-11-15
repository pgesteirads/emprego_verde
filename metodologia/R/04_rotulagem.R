# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 04. ROTULAGEM
# ==============================================================================
#
# Junta a cada atividade candidata a classe decidida pela rubrica
# (VERDE, POTENCIAL, MARROM, NEUTRO), lida de insumos/rotulos_atividade.csv.
#
# A classificacao e julgamento: le-se o enunciado e aplica-se
# metodologia/RUBRICA.md. O R nao decide a classe. O que esta etapa
# automatiza e tudo o que cerca o julgamento:
#
#   1. confere a consistencia dos rotulos (sem conflito, classes validas);
#   2. recalcula a concordancia entre as duas passagens da rodada original;
#   3. detecta candidatas sem rotulo (corpus novo ou dicionario alterado) e
#      prepara uma rodada de rotulagem em metodologia/rotulagem/;
#   4. oferece as funcoes para avaliar e incorporar essa rodada.
#
# Candidatas sem rotulo NAO entram no indice ate passarem pelo protocolo.
#
# PROTOCOLO PARA ATIVIDADES NOVAS (European Commission, 2022)
# -----------------------------------------------------------
#   a) Rodar o pipeline. Se houver candidatas sem rotulo, ele cria
#      metodologia/rotulagem/rodada_AAAA-MM-DD/itens.tsv.
#   b) Duas pessoas (ou duas execucoes independentes), sem ver o resultado
#      uma da outra, classificam itens.tsv conforme RUBRICA.md e salvam
#      passagem_A.tsv e passagem_B.tsv na mesma pasta, com as colunas
#      ID e CLASSE (separadas por TAB).
#   c) avaliar_rodada("metodologia/rotulagem/rodada_AAAA-MM-DD")
#      calcula concordancia e kappa e grava divergencias.tsv.
#   d) Uma terceira leitura preenche as colunas ARBITRAGEM e JUSTIFICATIVA
#      de divergencias.tsv.
#   e) incorporar_rodada("metodologia/rotulagem/rodada_AAAA-MM-DD")
#      acrescenta os rotulos a insumos/rotulos_atividade.csv.
#   f) Rodar o pipeline de novo e fazer commit dos CSV e da pasta da rodada.
#
# Produz no ambiente:
#   rotulos          data.frame dos rotulos com a coluna chave
#   classe_de        vetor nomeado chave -> classe, so para candidatas
#   sem_rotulo       chaves candidatas sem rotulo
#   concordancia_original  kappa e concordancia da rodada de 2026-09
# ==============================================================================

etapa("04. Rotulagem")

# ------------------------------------------------------------------------------
# Funcoes do protocolo de rotulagem
# ------------------------------------------------------------------------------

preparar_rodada <- function(chaves, perfil, candidatos, dir_base = CAMINHOS$rotulagem) {
  # Texto original (com acentos) de cada chave: primeira ocorrencia no corpus
  orig <- perfil$NOME_ATIVIDADE[match(chaves, perfil$chave)]
  n_ocup <- tapply(perfil$COD_OCUPACAO, perfil$chave,
                   function(z) length(unique(z)))[chaves]
  itens <- data.frame(
    ID        = sprintf("N%05d", seq_along(chaves)),
    ATIVIDADE = orig,
    TERMOS    = candidatos$termos[match(chaves, candidatos$chave)],
    N_OCUPACOES = as.integer(n_ocup),
    stringsAsFactors = FALSE
  )
  dir <- file.path(dir_base, paste0("rodada_", format(Sys.Date(), "%Y-%m-%d")))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  gravar_tsv(itens, file.path(dir, "itens.tsv"))
  writeLines(c(
    "RODADA DE ROTULAGEM",
    "",
    "itens.tsv: atividades capturadas pelo dicionario que ainda nao tem classe.",
    "",
    "1. Duas leituras independentes classificam todos os itens conforme",
    "   metodologia/RUBRICA.md, sem acesso ao resultado uma da outra.",
    "   A coluna TERMOS mostra o que capturou a atividade; NAO e a classe.",
    "2. Salvar passagem_A.tsv e passagem_B.tsv nesta pasta, com cabecalho",
    "   ID<TAB>CLASSE e CLASSE em VERDE, POTENCIAL, MARROM ou NEUTRO.",
    "3. No R: avaliar_rodada(\"<esta pasta>\") -> gera divergencias.tsv",
    "4. Preencher ARBITRAGEM e JUSTIFICATIVA em divergencias.tsv.",
    "5. No R: incorporar_rodada(\"<esta pasta>\")",
    "6. Rodar o pipeline de novo e fazer commit."
  ), file.path(dir, "LEIA-ME.txt"))
  dir
}

ler_passagem <- function(caminho, itens) {
  p <- ler_tsv(caminho)
  names(p) <- toupper(names(p))
  if (!all(c("ID", "CLASSE") %in% names(p))) {
    stop(basename(caminho), " precisa das colunas ID e CLASSE.")
  }
  p$CLASSE <- toupper(trimws(p$CLASSE))
  invalidas <- setdiff(unique(p$CLASSE), CLASSES)
  if (length(invalidas)) stop("Classes invalidas em ", basename(caminho), ": ",
                              paste(invalidas, collapse = ", "))
  faltam <- setdiff(itens$ID, p$ID)
  if (length(faltam)) stop(basename(caminho), " nao classifica ", length(faltam),
                           " itens (ex.: ", paste(head(faltam, 3), collapse = ", "), ").")
  setNames(p$CLASSE, p$ID)[itens$ID]
}

avaliar_rodada <- function(dir) {
  itens <- ler_tsv(file.path(dir, "itens.tsv"))
  a <- ler_passagem(file.path(dir, "passagem_A.tsv"), itens)
  b <- ler_passagem(file.path(dir, "passagem_B.tsv"), itens)
  k <- kappa_cohen(a, b)
  cat(sprintf("itens: %d | concordancia: %.1f%% | kappa: %.3f\n",
              k$n, 100 * k$concordancia, k$kappa))
  print(k$tabela)
  div <- itens[a != b, c("ID", "ATIVIDADE")]
  div$PASSAGEM_A <- a[a != b]
  div$PASSAGEM_B <- b[a != b]
  div$ARBITRAGEM <- ""
  div$JUSTIFICATIVA <- ""
  gravar_tsv(div, file.path(dir, "divergencias.tsv"))
  writeLines(sprintf("itens=%d concordancia=%.4f kappa=%.4f divergencias=%d",
                     k$n, k$concordancia, k$kappa, nrow(div)),
             file.path(dir, "concordancia.txt"))
  cat(nrow(div), "divergencias gravadas em", file.path(dir, "divergencias.tsv"), "\n")
  invisible(k)
}

incorporar_rodada <- function(dir) {
  itens <- ler_tsv(file.path(dir, "itens.tsv"))
  a <- ler_passagem(file.path(dir, "passagem_A.tsv"), itens)
  b <- ler_passagem(file.path(dir, "passagem_B.tsv"), itens)
  final <- ifelse(a == b, a, NA_character_)
  arbitrada <- a != b
  if (any(arbitrada)) {
    div <- ler_tsv(file.path(dir, "divergencias.tsv"))
    div$ARBITRAGEM <- toupper(trimws(div$ARBITRAGEM))
    pend <- div$ID[is.na(div$ARBITRAGEM) | !div$ARBITRAGEM %in% CLASSES]
    if (length(pend)) stop(length(pend), " divergencias sem arbitragem valida ",
                           "(ex.: ", paste(head(pend, 3), collapse = ", "), ").")
    sem_just <- div$ID[is.na(div$JUSTIFICATIVA)]
    if (length(sem_just)) stop("Arbitragem sem justificativa: ",
                               paste(head(sem_just, 3), collapse = ", "))
    final[match(div$ID, itens$ID)] <- div$ARBITRAGEM
  }
  stopifnot(!anyNA(final))
  novos <- data.frame(
    Atividade = itens$ATIVIDADE, Classe_final = unname(final),
    Passagem_A = unname(a), Passagem_B = unname(b),
    Arbitrada = ifelse(arbitrada, "sim", "nao"),
    Rodada = basename(dir), stringsAsFactors = FALSE
  )
  atuais <- ler_csv(ARQ_INSUMOS$rotulos)
  if (any(chave(novos$Atividade) %in% chave(atuais$Atividade))) {
    stop("Algumas atividades desta rodada ja tem rotulo. Rodada ja incorporada?")
  }
  gravar_csv(rbind(atuais, novos), ARQ_INSUMOS$rotulos)
  cat(nrow(novos), "rotulos incorporados a", ARQ_INSUMOS$rotulos, "\n")
  print(table(novos$Classe_final))
  invisible(novos)
}

# ------------------------------------------------------------------------------
# 1. Leitura e consistencia dos rotulos
# ------------------------------------------------------------------------------

rotulos <- ler_csv(ARQ_INSUMOS$rotulos)
rotulos$chave <- chave(rotulos$Atividade)

invalidas <- setdiff(unique(rotulos$Classe_final), CLASSES)
if (length(invalidas)) stop("Classes invalidas nos rotulos: ",
                            paste(invalidas, collapse = ", "))

# A mesma atividade (apos normalizacao) nao pode ter duas classes
conflito <- tapply(rotulos$Classe_final, rotulos$chave,
                   function(z) length(unique(z)) > 1)
if (any(conflito)) {
  stop("Rotulos conflitantes para a mesma atividade: ",
       paste(head(names(conflito)[conflito], 5), collapse = " | "))
}
n_fundidos <- nrow(rotulos) - length(unique(rotulos$chave))
classe_todas <- tapply(rotulos$Classe_final, rotulos$chave, `[`, 1)

cat("rotulos:", nrow(rotulos), "linhas,", length(classe_todas),
    "atividades distintas apos normalizacao\n")
if (n_fundidos > 0) {
  cat("  (", n_fundidos, " linhas so diferem em caixa ou espacamento, ",
      "com a mesma classe)\n", sep = "")
}
print(table(rotulos$Classe_final))

# ------------------------------------------------------------------------------
# 2. Concordancia da rodada original (reproduz a nota: 95,3% e kappa 0,934)
# ------------------------------------------------------------------------------

orig <- rotulos[rotulos$Rodada == "2026-09_original", ]
concordancia_original <- kappa_cohen(orig$Passagem_A, orig$Passagem_B)
cat(sprintf(paste0("rodada original: %d atividades com as duas passagens | ",
                   "concordancia %.1f%% | kappa %.3f | arbitradas %d\n"),
            concordancia_original$n, 100 * concordancia_original$concordancia,
            concordancia_original$kappa, sum(orig$Arbitrada == "sim")))

# ------------------------------------------------------------------------------
# 3. Juncao com as candidatas
# ------------------------------------------------------------------------------

# So recebe classe quem o dicionario capturou. Rotulo de atividade que deixou
# de ser candidata (termo removido, excecao nova) nao conta.
classe_de <- classe_todas[intersect(candidatos$chave, names(classe_todas))]
classe_de <- setNames(as.character(classe_de), names(classe_de))

sem_rotulo <- sort(setdiff(candidatos$chave, names(classe_todas)))
fora_candidatos <- setdiff(names(classe_todas), candidatos$chave)

candidatos$classe <- unname(classe_todas[candidatos$chave])
gravar_csv(candidatos, file.path(CAMINHOS$intermed, "candidatos.csv"))

cat("candidatas com rotulo:", length(classe_de), "\n")
cat("rotulos de atividades que nao sao candidatas:", length(fora_candidatos), "\n")
if (length(fora_candidatos)) {
  print(table(Classe = classe_todas[fora_candidatos]))
  gravar_csv(data.frame(chave = fora_candidatos,
                        classe = unname(classe_todas[fora_candidatos])),
             file.path(CAMINHOS$intermed, "rotulos_fora_candidatos.csv"))
}

if (length(sem_rotulo) > 0) {
  dir_rodada <- preparar_rodada(sem_rotulo, perfil, candidatos)
  warning(length(sem_rotulo), " candidatas sem rotulo ficaram FORA do indice. ",
          "Rodada de rotulagem preparada em ", dir_rodada)
} else {
  cat("candidatas sem rotulo: 0\n")
}
