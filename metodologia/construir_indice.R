# ==============================================================================
# Reconstroi o indice de esverdeamento ocupacional a partir das fontes primarias
# ==============================================================================
#
# Versao em R de construir_indice.py. As duas produzem o mesmo resultado.
#
# O que este script faz
# ---------------------
# Le o Perfil Ocupacional da CBO 2002, aplica o dicionario de termos para gerar
# atividades candidatas, junta os rotulos de classe ja decididos conforme
# metodologia/RUBRICA.md e recalcula os indices reportados na nota metodologica.
#
# Como rodar
# ----------
# Abrir emprego_verde.Rproj (o diretorio de trabalho deve ser a raiz do
# projeto) e executar:
#
#     source("metodologia/construir_indice.R")
#
# Pacotes: readxl e stringi (instalados automaticamente se faltarem).
#
# Entradas
# --------
# analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - PerfilOcupacional.csv
#     Fonte primaria, 192.745 registros. Nao versionado no git.
# analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - Ocupacao.csv
#     Titulos das ocupacoes.
# analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx
#     Fonte canonica do dicionario (abas Dicionario e Excecoes) e dos rotulos
#     de classe das 1.870 atividades (aba Atividades_classificadas).
#
# Saida
# -----
# metodologia/saida/indice_por_ocupacao_R.csv   (separador ; e decimal ,)
# metodologia/saida/candidatos_sem_rotulo_R.csv (so se houver; ver abaixo)
#
# Sobre atividades sem rotulo
# ---------------------------
# Se o dicionario capturar uma atividade que nao tem rotulo, ela NAO entra no
# indice e e listada em candidatos_sem_rotulo_R.csv. Sobre o corpus original a
# lista deve sair vazia. Lista nao vazia significa que o corpus mudou (nova
# versao da CBO) ou que o dicionario foi alterado. As novas atividades precisam
# passar pelo protocolo de duas passagens da RUBRICA.md antes de entrar no
# indice. Nunca atribuir classe pelo termo que capturou.
#
# Observacao sobre as expressoes regulares
# ----------------------------------------
# As expressoes do dicionario sao aplicadas com perl = TRUE (motor PCRE), que
# e compativel com a sintaxe usada (\b, grupos, alternancia). Elas operam sobre
# texto normalizado: maiusculas e sem acentos. Nao aplicar sobre o texto
# original.
# ==============================================================================

for (pkg in c("readxl", "stringi")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

# ------------------------------------------------------------------------------
# Parametros
# ------------------------------------------------------------------------------

RAIZ <- getwd()

CAMINHOS <- list(
  perfil   = file.path(RAIZ, "analise_cbo_onnet", "ESTRUTURA CBO",
                       "CBO2002 - PerfilOcupacional.csv"),
  ocupacao = file.path(RAIZ, "analise_cbo_onnet", "ESTRUTURA CBO",
                       "CBO2002 - Ocupacao.csv"),
  planilha = file.path(RAIZ, "analise_cbo_onnet",
                       "Esverdeamento_ocupacional_CBO2002.xlsx"),
  saida    = file.path(RAIZ, "metodologia", "saida")
)

# Numero minimo de atividades descritas para que o indice seja reportado.
# Decisao documentada na secao 9 da nota metodologica; revisavel.
MINIMO_ATIVIDADES <- 15

for (f in CAMINHOS[c("perfil", "planilha")]) {
  if (!file.exists(f)) {
    stop("Arquivo nao encontrado: ", f,
         "\nO diretorio de trabalho deve ser a raiz do projeto ",
         "(abra emprego_verde.Rproj).")
  }
}

# ------------------------------------------------------------------------------
# Funcoes auxiliares
# ------------------------------------------------------------------------------

# Maiusculas, sem acentos. Obrigatorio antes de aplicar as expressoes.
normalizar <- function(x) {
  toupper(stringi::stri_trans_general(x, "Latin-ASCII"))
}

# Chave de juncao entre corpus e rotulos: texto normalizado, espacos colapsados.
chave <- function(x) {
  trimws(gsub("\\s+", " ", normalizar(x)))
}

razao <- function(num, den) {
  ifelse(den > 0, round(num / den, 5), NA_real_)
}

# Grava CSV em UTF-8 com BOM (abre direto no Excel em portugues), separador ;
# e decimal virgula. Escreve os bytes diretamente, de modo que os acentos saem
# corretos em qualquer locale.
gravar_csv <- function(df, caminho) {
  campo <- function(x) {
    if (is.numeric(x)) {
      out <- ifelse(is.na(x), "",
                    sub(".", ",", format(x, scientific = FALSE, trim = TRUE,
                                         drop0trailing = TRUE), fixed = TRUE))
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
}

# ------------------------------------------------------------------------------
# 1. Leitura
# ------------------------------------------------------------------------------

# Os arquivos da CBO vem em latin-1. A leitura com encoding = "latin1" (e nao
# fileEncoding) marca o texto sem recodificar a conexao, o que funciona em
# qualquer locale, inclusive Windows, Linux e Mac.
ler_cbo <- function(caminho) {
  x <- read.csv2(caminho, encoding = "latin1", colClasses = "character",
                 strip.white = TRUE, quote = "")
  x[] <- lapply(x, enc2utf8)
  x
}

perfil <- ler_cbo(CAMINHOS$perfil)
perfil <- perfil[perfil$NOME_ATIVIDADE != "" & perfil$COD_OCUPACAO != "", ]
perfil$chave <- chave(perfil$NOME_ATIVIDADE)

dicionario <- readxl::read_excel(CAMINHOS$planilha, sheet = "Dicionario")
excecoes   <- readxl::read_excel(CAMINHOS$planilha, sheet = "Excecoes")
rotulos    <- readxl::read_excel(CAMINHOS$planilha,
                                 sheet = "Atividades_classificadas")
rotulos    <- setNames(rotulos$Classe_final, chave(rotulos$Atividade))

cat("registros de atividade:", nrow(perfil), "\n")
distintos <- unique(perfil$chave)
cat("enunciados distintos:", length(distintos), "\n")

# ------------------------------------------------------------------------------
# 2. Varredura do dicionario (so nos enunciados distintos, por economia)
# ------------------------------------------------------------------------------

capturado <- rep(FALSE, length(distintos))
for (i in seq_len(nrow(dicionario))) {
  hit <- grepl(dicionario$Padrao[i], distintos, perl = TRUE)
  exc <- excecoes$Padrao_excecao[excecoes$Termo_alvo == dicionario$ID[i]]
  for (e in exc) hit <- hit & !grepl(e, distintos, perl = TRUE)
  capturado <- capturado | hit
}
candidatos <- distintos[capturado]
cat("atividades candidatas:", length(candidatos), "\n")

sem_rotulo <- sort(setdiff(candidatos, names(rotulos)))
if (length(sem_rotulo) > 0) {
  warning(length(sem_rotulo), " atividades candidatas sem rotulo. ",
          "Ver saida/candidatos_sem_rotulo_R.csv")
}

# ------------------------------------------------------------------------------
# 3. Contagens por ocupacao
# ------------------------------------------------------------------------------

# Denominador: numero de registros de atividade da ocupacao.
n_ativ <- table(perfil$COD_OCUPACAO)

# Numeradores: atividades distintas da ocupacao, com a classe do rotulo.
pares <- unique(perfil[, c("COD_OCUPACAO", "COD_FAMILIA", "chave")])
pares$classe <- unname(rotulos[pares$chave])

# Atividade exclusiva: usada por esta ocupacao e por nenhuma outra da mesma
# familia. Aproxima a nocao de tarefa especifica de Vona et al. (2018), que a
# CBO nao marca.
usos <- aggregate(COD_OCUPACAO ~ COD_FAMILIA + chave, data = pares,
                  FUN = length)
names(usos)[3] <- "n_usos"
pares <- merge(pares, usos, by = c("COD_FAMILIA", "chave"))
pares$exclusiva <- pares$n_usos <= 1

conta <- function(filtro) {
  x <- tapply(filtro, pares$COD_OCUPACAO, sum)
  x[is.na(x)] <- 0
  x
}
ocup <- sort(names(n_ativ))

nv  <- conta(pares$classe %in% "VERDE")[ocup]
np  <- conta(pares$classe %in% "POTENCIAL")[ocup]
nm  <- conta(pares$classe %in% "MARROM")[ocup]
ne  <- conta(pares$exclusiva)[ocup]
nve <- conta(pares$exclusiva & pares$classe %in% "VERDE")[ocup]
nme <- conta(pares$exclusiva & pares$classe %in% "MARROM")[ocup]
n   <- as.integer(n_ativ[ocup])

# ------------------------------------------------------------------------------
# 4. Indices
# ------------------------------------------------------------------------------

familia <- tapply(pares$COD_FAMILIA, pares$COD_OCUPACAO, `[`, 1)[ocup]

titulos <- if (file.exists(CAMINHOS$ocupacao)) {
  t <- ler_cbo(CAMINHOS$ocupacao)
  setNames(t$TITULO, t$CODIGO)[ocup]
} else {
  rep(NA_character_, length(ocup))
}

indice <- data.frame(
  CBO                = ocup,
  Ocupacao           = unname(titulos),
  Familia            = unname(familia),
  N_atividades       = n,
  Reportavel         = ifelse(n >= MINIMO_ATIVIDADES, "sim", "nao"),
  Verde_amplo        = razao(nv, n),
  Verde_amplo_broad  = razao(nv + np, n),
  Marrom             = razao(nm, n),
  Liquido            = razao(nv - nm, n),
  Liquido_broad      = razao(nv + np - nm, n),
  N_ativ_verdes      = as.integer(nv),
  N_ativ_potenciais  = as.integer(np),
  N_ativ_marrons     = as.integer(nm),
  N_ativ_especificas = as.integer(ne),
  Verde_especifico   = razao(nve, ne),
  Marrom_especifico  = razao(nme, ne),
  Liquido_especifico = razao(nve - nme, ne),
  stringsAsFactors   = FALSE,
  row.names          = NULL
)

# ------------------------------------------------------------------------------
# 5. Gravacao
# ------------------------------------------------------------------------------

dir.create(CAMINHOS$saida, showWarnings = FALSE, recursive = TRUE)
destino <- file.path(CAMINHOS$saida, "indice_por_ocupacao_R.csv")
gravar_csv(indice, destino)

if (length(sem_rotulo) > 0) {
  gravar_csv(data.frame(Atividade = sem_rotulo, stringsAsFactors = FALSE),
             file.path(CAMINHOS$saida, "candidatos_sem_rotulo_R.csv"))
}

# ------------------------------------------------------------------------------
# 6. Conferencia contra os numeros da nota metodologica
# ------------------------------------------------------------------------------

rep_ <- indice[indice$Reportavel == "sim", ]
v <- sort(rep_$Verde_amplo)
fam_multi <- names(which(tapply(pares$COD_OCUPACAO, pares$COD_FAMILIA,
                                function(z) length(unique(z))) > 1))

conferencia <- data.frame(
  indicador = c("ocupacoes cobertas",
                "ocupacoes reportaveis",
                "margem extensiva verde (%)",
                "margem extensiva marrom (%)",
                "indice verde mediana",
                "indice verde p90",
                "indice verde maximo",
                "ocupacoes sem atividade exclusiva"),
  obtido = c(nrow(indice),
             nrow(rep_),
             round(100 * mean(rep_$Verde_amplo > 0), 1),
             round(100 * mean(rep_$Marrom > 0), 1),
             round(median(v), 4),
             round(v[min(length(v), floor(length(v) * 0.9) + 1)], 4),
             round(max(v), 4),
             sum(indice$N_ativ_especificas == 0 &
                   indice$Familia %in% fam_multi)),
  referencia = c(2700, 2672, 51.2, 10.5, 0.0081, 0.0417, 0.275, 981)
)
conferencia$situacao <- ifelse(
  abs(conferencia$obtido - conferencia$referencia) <=
    pmax(0.0002, abs(conferencia$referencia) * 0.01),
  "ok", "DIVERGE"
)

cat("\n")
print(conferencia, row.names = FALSE)
cat("\nescrito:", destino, "\n")
