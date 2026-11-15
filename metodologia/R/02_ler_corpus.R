# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 02. LEITURA DO CORPUS
# ==============================================================================
#
# Le o Perfil Ocupacional da CBO 2002 (fonte primaria) e os titulos de
# ocupacoes e familias. Cria a chave normalizada de cada enunciado.
#
# Produz no ambiente:
#   perfil     um registro por (ocupacao, atividade), com a coluna chave
#   distintos  vetor de enunciados distintos (chaves)
#   titulos_ocup, titulos_fam   vetores nomeados pelo codigo
#   fontes     data.frame com o hash MD5 de cada fonte primaria
# ==============================================================================

etapa("02. Leitura do corpus")

if (!file.exists(CAMINHOS$perfil)) {
  stop("Perfil Ocupacional nao encontrado: ", CAMINHOS$perfil,
       "\nEsse arquivo nao e versionado. Ele vem da pagina de downloads da ",
       "CBO no site do MTE (estrutura da CBO 2002).")
}

perfil <- ler_cbo(CAMINHOS$perfil)
colunas_esperadas <- c("COD_FAMILIA", "COD_OCUPACAO", "NOME_ATIVIDADE")
faltam <- setdiff(colunas_esperadas, names(perfil))
if (length(faltam) > 0) {
  stop("Colunas ausentes no Perfil Ocupacional: ", paste(faltam, collapse = ", "))
}

n_bruto <- nrow(perfil)
perfil <- perfil[perfil$NOME_ATIVIDADE != "" & perfil$COD_OCUPACAO != "", ]
perfil$chave <- chave(perfil$NOME_ATIVIDADE)
distintos <- unique(perfil$chave)

titulos_ocup <- if (file.exists(CAMINHOS$ocupacao)) {
  t <- ler_cbo(CAMINHOS$ocupacao); setNames(t$TITULO, t$CODIGO)
} else character(0)
titulos_fam <- if (file.exists(CAMINHOS$familia)) {
  t <- ler_cbo(CAMINHOS$familia); setNames(t$TITULO, t$CODIGO)
} else character(0)

fontes <- data.frame(
  arquivo = c("CBO2002 - PerfilOcupacional.csv", "CBO2002 - Ocupacao.csv",
              "CBO2002 - Familia.csv"),
  md5     = c(hash_arquivo(CAMINHOS$perfil), hash_arquivo(CAMINHOS$ocupacao),
              hash_arquivo(CAMINHOS$familia)),
  stringsAsFactors = FALSE
)

cat("registros lidos:", n_bruto, "\n")
cat("registros validos:", nrow(perfil), "\n")
cat("ocupacoes:", length(unique(perfil$COD_OCUPACAO)), "\n")
cat("familias:", length(unique(perfil$COD_FAMILIA)), "\n")
cat("enunciados distintos (apos normalizacao):", length(distintos), "\n")
cat("md5 do Perfil Ocupacional:", fontes$md5[1], "\n")
