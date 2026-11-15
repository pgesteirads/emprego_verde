# ==============================================================================
# INDICE DE ESVERDEAMENTO OCUPACIONAL - 06. VALIDACAO
# ==============================================================================
#
# Quatro blocos de verificacao. O resultado de todos vai para
# saida/validacao.csv. Se PARAR_SE_DIVERGIR = TRUE (padrao), qualquer
# falha interrompe o pipeline antes da exportacao.
#
#   A. Testes do dicionario: casos que definiram o desenho (a armadilha
#      CIMENTO dentro de CONHECIMENTO, ginecologia, plexo solar etc.).
#   B. Conferencia contra os oito indicadores da nota metodologica.
#   C. Comparacao celula a celula com o indice publicado em setembro de 2026.
#   D. Casos de controle (instalador fotovoltaico, 732140).
#
# Os blocos B e C so fazem sentido enquanto corpus, dicionario e rotulos
# forem os da rodada original. Se algum deles mudar de proposito, a
# divergencia e esperada: atualize REFERENCIA_NOTA em 00_config.R no mesmo
# commit e registre o motivo.
# ==============================================================================

etapa("06. Validacao")

validacao <- data.frame(bloco = character(), teste = character(),
                        obtido = character(), esperado = character(),
                        situacao = character(), stringsAsFactors = FALSE)
registrar <- function(bloco, teste, obtido, esperado, ok) {
  validacao[nrow(validacao) + 1, ] <<- list(bloco, teste, as.character(obtido),
                                            as.character(esperado),
                                            if (isTRUE(ok)) "ok" else "FALHA")
}

# ------------------------------------------------------------------------------
# A. Testes do dicionario
# ------------------------------------------------------------------------------

# IDs dos termos que capturam um texto, ja descontadas as excecoes
casar <- function(texto) {
  t <- chave(texto)
  ids <- character(0)
  for (i in seq_len(nrow(dicionario))) {
    if (grepl(dicionario$Padrao[i], t, perl = TRUE)) {
      exc <- excecoes$Padrao_excecao[excecoes$Termo_alvo == dicionario$ID[i]]
      if (!any(vapply(exc, grepl, logical(1), x = t, perl = TRUE))) {
        ids <- c(ids, dicionario$ID[i])
      }
    }
  }
  ids
}

# termo = ID que deve (captura = TRUE) ou nao deve (FALSE) capturar o texto
testes_dic <- data.frame(
  texto = c("Segregar resíduos de serviços de saúde",
            "Retirar resíduos de areia das peças",
            "Instalar sistemas fotovoltaicos",
            "Operar forno de coque",
            "Aplicar conhecimentos técnicos",
            "Preparar coquetel de frutas",
            "Realizar citologia ginecológica",
            "Massagear plexo solar",
            "Aplicar técnicas de mineração de dados",
            "Ensinar artes plásticas",
            "Auscultar ruídos cardíacos",
            "Preparar concreto para fundação",
            "Reparar dano moral"),
  termo = c("V041", "V041", "V010", "M336", "M340", "M336", "V003", "V011",
            "M320", "M360", "V085", "M341", "P230"),
  captura = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE,
              FALSE, FALSE, FALSE, TRUE, FALSE),
  stringsAsFactors = FALSE
)
for (i in seq_len(nrow(testes_dic))) {
  achou <- testes_dic$termo[i] %in% casar(testes_dic$texto[i])
  registrar("A. dicionario",
            sprintf("%s %s '%s'", testes_dic$termo[i],
                    if (testes_dic$captura[i]) "captura" else "nao captura",
                    chave(testes_dic$texto[i])),
            achou, testes_dic$captura[i], achou == testes_dic$captura[i])
}

# O dicionario captura "resíduos de areia", mas a rubrica a classifica NEUTRO:
# confirma que a classe vem do rotulo, nao do termo.
k_areia <- chave("Retirar resíduos de areia das peças")
if (k_areia %in% names(classe_de)) {
  registrar("A. dicionario", "rotulo de 'residuos de areia' e NEUTRO",
            classe_de[[k_areia]], "NEUTRO", classe_de[[k_areia]] == "NEUTRO")
}

# ------------------------------------------------------------------------------
# B. Conferencia contra a nota metodologica
# ------------------------------------------------------------------------------

rep_ <- indice[indice$Reportavel == "sim", ]
v <- sort(rep_$Verde_amplo)
fam_multi <- names(which(tapply(pares$COD_OCUPACAO, pares$COD_FAMILIA,
                                function(z) length(unique(z))) > 1))
obtido_nota <- c(
  "ocupacoes cobertas"                = nrow(indice),
  "ocupacoes reportaveis"             = nrow(rep_),
  "margem extensiva verde (%)"        = round(100 * mean(rep_$Verde_amplo > 0), 1),
  "margem extensiva marrom (%)"       = round(100 * mean(rep_$Marrom > 0), 1),
  "indice verde mediana"              = round(median(v), 4),
  "indice verde p90"                  = round(v[min(length(v), floor(length(v) * 0.9) + 1)], 4),
  "indice verde maximo"               = round(max(v), 4),
  "ocupacoes sem atividade exclusiva" = sum(indice$N_ativ_especificas == 0 &
                                              indice$Familia %in% fam_multi)
)
for (nm_ in names(REFERENCIA_NOTA)) {
  ref <- REFERENCIA_NOTA[[nm_]]; ob <- obtido_nota[[nm_]]
  registrar("B. nota", nm_, ob, ref,
            abs(ob - ref) <= max(0.0002, abs(ref) * 0.01))
}

# Concordancia da rodada original
registrar("B. nota", "kappa entre passagens (rodada original)",
          round(concordancia_original$kappa, 3), 0.934,
          abs(concordancia_original$kappa - 0.934) < 0.002)

# ------------------------------------------------------------------------------
# C. Comparacao celula a celula com o indice publicado
# ------------------------------------------------------------------------------

ref_ind <- ler_csv(ARQ_INSUMOS$referencia)
colunas_num <- c("N_atividades", "Verde_amplo", "Verde_amplo_broad", "Marrom",
                 "Liquido", "Liquido_broad", "N_ativ_verdes",
                 "N_ativ_potenciais", "N_ativ_marrons", "N_ativ_especificas",
                 "Verde_especifico", "Marrom_especifico", "Liquido_especifico")
registrar("C. publicado", "mesmo conjunto de ocupacoes",
          nrow(indice), nrow(ref_ind), setequal(indice$CBO, ref_ind$CBO))

m <- match(indice$CBO, ref_ind$CBO)
diferencas <- list()
for (col in colunas_num) {
  a <- indice[[col]]; b <- num(ref_ind[[col]])[m]
  dif <- !((is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) < 1e-4))
  if (any(dif)) {
    diferencas[[col]] <- data.frame(CBO = indice$CBO[dif], coluna = col,
                                    pipeline = a[dif], publicado = b[dif])
  }
  # Diferenca conhecida e documentada (TRANSFERENCIA.md, secao 2): duas
  # contagens de atividades exclusivas diferem em uma unidade porque a
  # normalizacao junta enunciados que so diferem em caixa ou espacamento.
  conhecidas <- if (col == "N_ativ_especificas") c("262615", "325115") else character(0)
  inesperadas <- setdiff(indice$CBO[dif], conhecidas)
  registrar("C. publicado", paste("coluna", col),
            paste(sum(dif), "diferencas"),
            if (length(conhecidas)) "ate 2 conhecidas (262615, 325115)" else "0 diferencas",
            length(inesperadas) == 0)
}
if (length(diferencas)) {
  gravar_csv(do.call(rbind, diferencas),
             file.path(CAMINHOS$saida, "diferencas_vs_publicado.csv"))
}

# ------------------------------------------------------------------------------
# D. Casos de controle
# ------------------------------------------------------------------------------

for (i in seq_len(nrow(CASOS_CONTROLE))) {
  cc <- CASOS_CONTROLE[i, ]
  ob <- indice[[cc$coluna]][indice$CBO == cc$CBO]
  registrar("D. controle", paste(cc$CBO, cc$coluna), round(ob, 3), cc$esperado,
            length(ob) == 1 && abs(ob - cc$esperado) < 0.001)
}

# ------------------------------------------------------------------------------
# Resultado
# ------------------------------------------------------------------------------

gravar_csv(validacao, file.path(CAMINHOS$saida, "validacao.csv"))
cat("\n")
print(validacao[, c("bloco", "teste", "obtido", "esperado", "situacao")],
      row.names = FALSE, right = FALSE)
n_falhas <- sum(validacao$situacao != "ok")
cat(sprintf("\n%d verificacoes, %d falhas\n", nrow(validacao), n_falhas))
if (n_falhas > 0 && PARAR_SE_DIVERGIR) {
  stop("Validacao falhou em ", n_falhas, " verificacoes. Ver ",
       file.path(CAMINHOS$saida, "validacao.csv"),
       ". Investigar antes de usar a saida.")
}
