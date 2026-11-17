# ==============================================================================
# ESTATÍSTICAS DESCRITIVAS COM A PNADc - 01. BASE ANALÍTICA
# ==============================================================================
#
# Monta a base de ocupados do 4º trimestre de cada ano (2012 a 2024) com o
# índice de esverdeamento do grupo da COD de cada pessoa.
#
# Entradas (nenhuma depende de rodar o pipeline do índice de novo):
#   dados/pnadc_trim/pnadc_04AAAA.parquet     microdados trimestrais do IBGE
#   dados/deflator/deflator_PNADC_2025_trimestral_070809.xls  deflator do IBGE
#   dados/processados/classif_cnae_verde.xlsx classificação verde das CNAE
#   metodologia/saida/ponte/indice_por_cod.csv índice por grupo da COD
#
# Duas versões do índice por pessoa:
#   *_ano   pesos da RAIS do ano mais próximo (2014, 2016, 2019 ou 2024).
#           Usada nos cortes de cada ano.
#   *_fixo  pesos da RAIS de 2024 em todos os anos. Usada na evolução
#           2012-2024, para que a mudança venha só da composição do emprego.
#
# Também calcula o erro-padrão das médias nacionais com os 200 pesos
# replicados (bootstrap) da PNADc, ano a ano, sem guardar os pesos na base.
# ==============================================================================

etapa("Estatísticas 01. Base analítica")

ANOS_PNADC <- 2012:2024
ANOS_RAIS  <- c(2014, 2016, 2019, 2024)
ANO_FOCO   <- 2024
DIR_EST    <- file.path(CAMINHOS$saida, "estatisticas")
dir.create(DIR_EST, showWarnings = FALSE, recursive = TRUE)

ano_ref <- function(a) ANOS_RAIS[which.min(abs(ANOS_RAIS - a))]

# --- Índice por grupo da COD -------------------------------------------------
ic <- ler_csv(file.path(CAMINHOS$saida, "ponte", "indice_por_cod.csv"))
COL_IDX <- c("Verde_amplo", "Marrom", "Liquido", "Verde_especifico", "Marrom_especifico")
for (v in c("ANO_RAIS", COL_IDX)) ic[[v]] <- num(ic[[v]])
ic <- ic[!is.na(ic$Verde_amplo), ]
NOMES_IDX <- c(Verde_amplo = "verde", Marrom = "marrom", Liquido = "liquido",
               Verde_especifico = "verde_esp", Marrom_especifico = "marrom_esp")

# --- Deflator do IBGE para rendimento habitual, 4º trimestre (out-nov-dez) ----
# Leva os valores a reais do último trimestre do arquivo (jul-ago-set de 2025).
ARQ_DEFLATOR <- file.path(RAIZ, "dados", "deflator", "deflator_PNADC_2025_trimestral_070809.xls")
defl <- as.data.frame(readxl::read_xls(ARQ_DEFLATOR))
defl <- defl[defl$trim == "10-11-12", c("Ano", "UF", "Habitual")]
defl <- data.frame(Ano = as.integer(defl$Ano), uf = as.numeric(defl$UF), Habitual = defl$Habitual)

# --- Classificação verde das atividades (CNAE domiciliar) --------------------
cnae <- as.data.frame(readxl::read_excel(file.path(RAIZ, "dados", "processados",
                                                   "classif_cnae_verde.xlsx")))
cnae$classe_setor <- c(Green = "Verde", Brown = "Marrom", Neutral = "Neutra")[cnae$class_verde_atividade]

REGIOES <- c("1" = "Norte", "2" = "Nordeste", "3" = "Sudeste", "4" = "Sul", "5" = "Centro-Oeste")
GRANDES_GRUPOS <- c("0" = "Forças armadas, policiais e bombeiros", "1" = "Diretores e gerentes",
                    "2" = "Profissionais das ciências e intelectuais",
                    "3" = "Técnicos e profissionais de nível médio",
                    "4" = "Trabalhadores de apoio administrativo",
                    "5" = "Serviços, vendedores dos comércios e mercados",
                    "6" = "Agropecuária, florestais, caça e pesca",
                    "7" = "Indústria, construção, artes mecânicas e outros ofícios",
                    "8" = "Operadores de instalações e máquinas e montadores",
                    "9" = "Ocupações elementares")

VARS <- c("Ano", "UF", "Estrato", "V1022", "V1028", "V2007", "V2009", "V2010", "VD3004",
          "VD4002", "VD4009", "VD4012", "V4019", "V4010", "V4013", "V4039", "VD4016")

# Média ponderada e erro-padrão por pesos replicados (bootstrap da PNADc)
media_ep <- function(y, w, wr) {
  ok <- !is.na(y)
  est <- sum(w[ok] * y[ok]) / sum(w[ok])
  rep <- colSums(wr[ok, , drop = FALSE] * y[ok]) / colSums(wr[ok, , drop = FALSE])
  c(est = est, ep = sqrt(mean((rep - mean(rep))^2)))
}

ler_ano <- function(a) {
  arq <- file.path(RAIZ, "dados", "pnadc_trim", sprintf("pnadc_04%d.parquet", a))
  d <- as.data.frame(arrow::read_parquet(arq, col_select = tidyselect::all_of(c(VARS, sprintf("V1028%03d", 1:200)))))
  d <- d[!is.na(d$VD4002) & d$VD4002 == "Pessoas ocupadas", ]
  for (v in names(d)) if (is.factor(d[[v]])) d[[v]] <- as.character(d[[v]])
  d$Ano <- as.integer(d$Ano)
  d$uf <- as.numeric(substr(d$Estrato, 1, 2))

  # índice: pesos da RAIS do ano mais próximo e pesos fixos de 2024
  i_ano  <- ic[ic$ANO_RAIS == ano_ref(a), ]
  i_fixo <- ic[ic$ANO_RAIS == max(ANOS_RAIS), ]
  m1 <- match(d$V4010, i_ano$COD); m2 <- match(d$V4010, i_fixo$COD)
  for (v in COL_IDX) {
    d[[paste0(NOMES_IDX[v], "_ano")]]  <- i_ano[[v]][m1]
    d[[paste0(NOMES_IDX[v], "_fixo")]] <- i_fixo[[v]][m2]
  }

  # erro-padrão das médias nacionais (só ocupados com índice)
  wr <- as.matrix(d[, sprintf("V1028%03d", 1:200)])
  ep <- rbind(
    c(ANO = a, INDICADOR = 1, media_ep(d$verde_ano, d$V1028, wr)),
    c(ANO = a, INDICADOR = 2, media_ep(d$marrom_ano, d$V1028, wr)),
    c(ANO = a, INDICADOR = 3, media_ep(as.numeric(d$verde_ano > 0), d$V1028, wr)),
    c(ANO = a, INDICADOR = 4, media_ep(as.numeric(d$marrom_ano > 0), d$V1028, wr)),
    c(ANO = a, INDICADOR = 5, media_ep(d$liquido_ano, d$V1028, wr)))
  d <- d[, !grepl("^V1028[0-9]{3}$", names(d))]
  list(d = d, ep = ep)
}

lido <- lapply(ANOS_PNADC, function(a) { cat("  lendo", a, "\n"); ler_ano(a) })
pn <- do.call(rbind, lapply(lido, `[[`, "d"))
ep_nacional <- as.data.frame(do.call(rbind, lapply(lido, `[[`, "ep")))
ep_nacional$INDICADOR <- c("Índice verde médio", "Índice marrom médio",
                           "Margem extensiva verde (%)", "Margem extensiva marrom (%)",
                           "Índice líquido médio")[ep_nacional$INDICADOR]
rm(lido); invisible(gc())

# --- Variáveis derivadas ------------------------------------------------------
pn <- merge(pn, defl, by.x = c("Ano", "uf"), by.y = c("Ano", "uf"), all.x = TRUE)
pn$regiao   <- unname(REGIOES[substr(pn$uf, 1, 1)])
pn$nordeste <- ifelse(pn$regiao == "Nordeste", "Nordeste", "Demais regiões")
pn$sexo     <- pn$V2007
pn$cor      <- ifelse(pn$V2010 %in% c("Preta", "Parda", "Indígena"), "Pretos, pardos e indígenas",
               ifelse(pn$V2010 %in% c("Branca", "Amarela"), "Brancos e amarelos", NA))
pn$idade    <- as.integer(pn$V2009)
pn$faixa_etaria <- cut(pn$idade, c(-Inf, 24, 39, 59, Inf), labels = c("14 a 24", "25 a 39", "40 a 59", "60 ou mais"))
pn$faixa_etaria <- as.character(pn$faixa_etaria)
pn$escolaridade <- ifelse(grepl("^Sem instru|^Fundamental incompleto", pn$VD3004), "Até fundamental incompleto",
                   ifelse(grepl("^Fundamental completo|^Médio incompleto", pn$VD3004), "Fundamental completo",
                   ifelse(grepl("^Médio completo|^Superior incompleto", pn$VD3004), "Médio completo",
                   ifelse(grepl("^Superior completo", pn$VD3004), "Superior completo", NA))))
pn$situacao <- pn$V1022

# Informalidade pela definição do IBGE: empregado sem carteira (setor privado
# e doméstico), conta-própria e empregador sem CNPJ, e trabalhador familiar
# auxiliar.
pos <- pn$VD4009
pn$informal <- as.numeric(
  grepl("privado sem carteira|doméstico sem carteira|familiar auxiliar", pos) |
  (grepl("^Conta-pr|^Empregador", pos) & !is.na(pn$V4019) & pn$V4019 == "Não"))
pn$informal[is.na(pos)] <- NA
# O registro no CNPJ (V4019) só existe a partir do 4º trimestre de 2015. Antes
# disso a informalidade não é comparável e fica sem valor, como na série do IBGE.
anos_sem_cnpj <- names(which(tapply(!is.na(pn$V4019), pn$Ano, sum) == 0))
pn$informal[pn$Ano %in% anos_sem_cnpj] <- NA
cat("anos sem V4019 (informalidade não calculada):", anos_sem_cnpj, "\n")
pn$contribui <- ifelse(is.na(pn$VD4012), NA, as.numeric(pn$VD4012 == "Contribuinte"))

pn$renda_real <- pn$VD4016 * pn$Habitual
pn$horas      <- pn$V4039
pn$renda_hora <- ifelse(pn$horas > 0 & pn$renda_real > 0, pn$renda_real / (pn$horas * 52 / 12), NA)

m <- match(pn$V4013, cnae$cnaedom_cod)
pn$classe_setor <- cnae$classe_setor[m]
pn$setor        <- cnae$setor_cnae20_nome[m]
pn$classe_setor[is.na(pn$classe_setor)] <- "Sem informação"
pn$setor[is.na(pn$setor)] <- "Sem informação"
pn$grande_grupo <- unname(GRANDES_GRUPOS[substr(pn$V4010, 1, 1)])

# Décimos da renda real do trabalho principal (entre quem tem renda > 0), por ano
pn$decimo_renda <- NA_integer_
for (a in ANOS_PNADC) {
  k <- which(pn$Ano == a & pn$renda_real > 0)
  o <- k[order(pn$renda_real[k])]
  cw <- cumsum(pn$V1028[o]) / sum(pn$V1028[o])
  pn$decimo_renda[o] <- pmin(10L, as.integer(ceiling(cw * 10 - 1e-9)))
}

# --- Ocupações de alta intensidade verde e marrom ------------------------------
# Limiar = 90º percentil da distribuição dos ocupados pelo índice em 2024,
# mantido fixo em todos os anos.
quantil_p <- function(y, w, p) {
  ok <- !is.na(y); o <- order(y[ok]); cw <- cumsum(w[ok][o]) / sum(w[ok])
  y[ok][o][which(cw >= p)[1]]
}
foco <- pn$Ano == ANO_FOCO
LIMIAR_VERDE  <- quantil_p(pn$verde_ano[foco],  pn$V1028[foco], 0.9)
LIMIAR_MARROM <- quantil_p(pn$marrom_ano[foco], pn$V1028[foco], 0.9)
grupo_int <- function(v, mr) {
  ifelse(is.na(v), NA,
  ifelse(v >= LIMIAR_VERDE & mr >= LIMIAR_MARROM, "Alta intensidade verde e marrom",
  ifelse(v >= LIMIAR_VERDE, "Alta intensidade verde",
  ifelse(mr >= LIMIAR_MARROM, "Alta intensidade marrom", "Demais ocupações"))))
}
pn$grupo_intensidade      <- grupo_int(pn$verde_ano, pn$marrom_ano)
pn$grupo_intensidade_fixo <- grupo_int(pn$verde_fixo, pn$marrom_fixo)
pn$verde_intenso  <- as.numeric(pn$verde_ano  >= LIMIAR_VERDE)
pn$marrom_intenso <- as.numeric(pn$marrom_ano >= LIMIAR_MARROM)

pn$com_indice <- !is.na(pn$verde_ano)
cat("ocupados lidos:", nrow(pn), "| limiar verde:", LIMIAR_VERDE, "| limiar marrom:", LIMIAR_MARROM, "\n")
cat("cobertura por ano (% dos ocupados com índice):\n")
print(round(100 * tapply(pn$V1028 * pn$com_indice, pn$Ano, sum) / tapply(pn$V1028, pn$Ano, sum), 2))
