# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - FUNCOES AUXILIARES
# ==============================================================================
# Sem efeitos colaterais: so define funcoes. ASCII puro de proposito.
# ==============================================================================

# Maiusculas, sem acentos. Obrigatorio antes de aplicar as expressoes do
# dicionario, que foram escritas para texto normalizado.
normalizar <- function(x) {
  toupper(stringi::stri_trans_general(x, "Latin-ASCII"))
}

# Chave de juncao entre corpus e rotulos: texto normalizado, espacos
# colapsados. Dois enunciados que so diferem em caixa, acento ou espacamento
# viram a mesma atividade.
chave <- function(x) {
  trimws(gsub("\\s+", " ", normalizar(x)))
}

# Hash de um texto e identificador estavel de atividade (12 primeiros
# caracteres do MD5 da chave normalizada)
hash_texto <- function(x) as.character(openssl::md5(enc2utf8(x)))
id_item <- function(chave) unname(substr(vapply(chave, hash_texto, character(1)), 1, 12))

razao <- function(num, den) {
  ifelse(den > 0, round(num / den, 5), NA_real_)
}

# Hash MD5 de um arquivo, para registrar exatamente qual versao de cada
# insumo gerou o resultado.
hash_arquivo <- function(caminho) {
  if (!file.exists(caminho)) return(NA_character_)
  unname(tools::md5sum(caminho))
}

# ------------------------------------------------------------------------------
# Leitura e gravacao
# ------------------------------------------------------------------------------

# Os arquivos da CBO vem em latin-1. encoding = "latin1" marca o texto sem
# recodificar a conexao, o que funciona em qualquer locale.
ler_cbo <- function(caminho) {
  x <- utils::read.csv2(caminho, encoding = "latin1", colClasses = "character",
                        strip.white = TRUE, quote = "")
  x[] <- lapply(x, enc2utf8)
  x
}

# Grava CSV em UTF-8 com BOM (abre direto no Excel em portugues), separador ;
# e decimal virgula. Escreve os bytes diretamente, de modo que os acentos
# saem corretos em qualquer locale. Texto sempre entre aspas.
gravar_csv <- function(df, caminho) {
  campo <- function(x) {
    if (is.logical(x)) x <- ifelse(x, "sim", "nao")
    if (is.numeric(x)) {
      # formatacao elemento a elemento: sem zeros a direita artificiais
      out <- vapply(x, function(v) {
        if (is.na(v)) return("")
        sub(".", ",", format(v, scientific = FALSE, trim = TRUE,
                             drop0trailing = TRUE, digits = 15), fixed = TRUE)
      }, character(1))
    } else {
      x <- enc2utf8(as.character(x))
      out <- ifelse(is.na(x), "", paste0('"', gsub('"', '""', x), '"'))
    }
    out
  }
  linhas <- c(paste(names(df), collapse = ";"),
              do.call(paste, c(lapply(df, campo), sep = ";")))
  texto <- enc2utf8(paste0(paste(linhas, collapse = "\r\n"), "\r\n"))
  con <- file(caminho, open = "wb")
  on.exit(close(con))
  writeBin(as.raw(c(0xef, 0xbb, 0xbf)), con)
  writeBin(charToRaw(texto), con)
  invisible(caminho)
}

# Le um CSV gravado por gravar_csv(). Todas as colunas como texto; a
# conversao numerica e feita por quem le, explicitamente.
ler_csv <- function(caminho) {
  x <- utils::read.csv(caminho, sep = ";", quote = "\"", encoding = "UTF-8",
                       colClasses = "character", na.strings = "",
                       check.names = FALSE)
  names(x) <- sub("^﻿", "", names(x))
  x
}

num <- function(x) as.numeric(sub(",", ".", x, fixed = TRUE))

# Arquivos de rotulagem: texto separado por TAB, UTF-8, sem aspas.
gravar_tsv <- function(df, caminho) {
  df[] <- lapply(df, function(x) {
    x <- enc2utf8(as.character(x))
    x[is.na(x)] <- ""
    gsub("[\t\r\n]+", " ", x)
  })
  linhas <- c(paste(names(df), collapse = "\t"),
              do.call(paste, c(df, sep = "\t")))
  con <- file(caminho, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(enc2utf8(paste0(paste(linhas, collapse = "\n"), "\n"))),
           con)
  invisible(caminho)
}

ler_tsv <- function(caminho, cabecalho = TRUE) {
  x <- utils::read.delim(caminho, header = cabecalho, sep = "\t", quote = "",
                         encoding = "UTF-8", colClasses = "character",
                         na.strings = "", strip.white = TRUE,
                         check.names = FALSE)
  names(x) <- sub("^﻿", "", names(x))
  x
}

# ------------------------------------------------------------------------------
# Estatisticas de concordancia
# ------------------------------------------------------------------------------

# Kappa de Cohen entre duas classificacoes do mesmo conjunto de itens.
kappa_cohen <- function(a, b, niveis = CLASSES) {
  ok <- !is.na(a) & !is.na(b)
  a <- factor(a[ok], levels = niveis)
  b <- factor(b[ok], levels = niveis)
  tab <- table(a, b)
  n <- sum(tab)
  po <- sum(diag(tab)) / n
  pe <- sum(rowSums(tab) * colSums(tab)) / n^2
  list(n = n, concordancia = po, kappa = (po - pe) / (1 - pe), tabela = tab)
}

# Registro simples de etapa no console
etapa <- function(...) cat("\n==== ", ..., " ====\n", sep = "")
