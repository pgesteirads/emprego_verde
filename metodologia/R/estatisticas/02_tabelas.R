# ==============================================================================
# ESTATÍSTICAS DESCRITIVAS COM A PNADc - 02. TABELAS
# ==============================================================================
#
# Oito blocos, todos com o peso amostral V1028 e restritos aos ocupados cujo
# grupo da COD tem índice (cerca de 99% do total):
#
#   b1  conteúdo verde médio, margem extensiva e distribuição (verde, marrom e
#       líquido)
#   b2  perfil sociodemográfico
#   b3  qualidade do emprego (informalidade, renda, horas, prêmio descritivo)
#   b4  classificação híbrida ocupação x setor (CNAE verde, neutra, marrom)
#   b5  território (região, UF, Nordeste)
#   b6  transição justa (perfil das ocupações de alta intensidade marrom)
#   b7  evolução 2012-2024 (índice com pesos fixos, decomposição shift-share)
#   b8  desigualdade (índice por décimo de renda e índice de concentração)
#
# Grava um CSV por tabela em metodologia/saida/estatisticas/ e um xlsx com
# todas as tabelas (estatisticas_descritivas.xlsx, não versionado).
#
# Os resultados são preliminares: o índice usa os rótulos de atividade da
# rodada de setembro de 2026, anterior à classificação humana.
# ==============================================================================

etapa("Estatísticas 02. Tabelas")

TAB <- list()   # todas as tabelas, na ordem em que são gravadas
guarda <- function(nome, df) { TAB[[nome]] <<- df; gravar_csv(df, file.path(DIR_EST, paste0(nome, ".csv"))) }

d <- pn[pn$com_indice, ]

# ------------------------------------------------------------------------------
# Auxiliares
# ------------------------------------------------------------------------------
# Agrega médias ponderadas de 'vars' por grupos 'by' (NA ignorado variável a variável)
agrega <- function(d, by, vars, w = d$V1028) {
  key <- if (length(by)) do.call(paste, c(lapply(by, function(b) d[[b]]), sep = "\r")) else rep("", nrow(d))
  out <- data.frame(KEY = sort(unique(key)), stringsAsFactors = FALSE)
  out$N_AMOSTRA <- as.integer(rowsum(rep(1, nrow(d)), key)[out$KEY, 1])
  out$OCUPADOS_MIL <- round(rowsum(w, key)[out$KEY, 1] / 1e3, 1)
  for (v in vars) {
    y <- d[[v]]; ok <- !is.na(y)
    nm <- rowsum(ifelse(ok, w * y, 0), key)[out$KEY, 1]
    dn <- rowsum(ifelse(ok, w, 0), key)[out$KEY, 1]
    out[[v]] <- nm / dn
  }
  if (length(by)) {
    partes <- do.call(rbind, strsplit(out$KEY, "\r", fixed = TRUE))
    for (i in seq_along(by)) out[[by[i]]] <- partes[, i]
  }
  out[, c(by, setdiff(names(out), c("KEY", by)))]
}
wquant <- function(y, w, p = 0.5) {
  ok <- !is.na(y); if (!any(ok)) return(NA_real_)
  o <- order(y[ok]); cw <- cumsum(w[ok][o]) / sum(w[ok]); y[ok][o][which(cw >= p)[1]]
}
pct_no_ano <- function(t, col = "OCUPADOS_MIL", ano = "Ano") 100 * t[[col]] / ave(t[[col]], t[[ano]], FUN = sum)
arred <- function(df, d = 5) { for (v in names(df)) if (is.double(df[[v]])) df[[v]] <- round(df[[v]], d); df }

d$margem_verde  <- 100 * (d$verde_ano > 0)
d$margem_marrom <- 100 * (d$marrom_ano > 0)
d$alta_verde    <- 100 * d$verde_intenso
d$alta_marrom   <- 100 * d$marrom_intenso
VARS_IDX <- c("verde_ano", "marrom_ano", "liquido_ano", "margem_verde", "margem_marrom",
              "alta_verde", "alta_marrom")
renomeia_idx <- function(t) {
  nm <- c(verde_ano = "VERDE_MEDIO", marrom_ano = "MARROM_MEDIO", liquido_ano = "LIQUIDO_MEDIO",
          margem_verde = "MARGEM_VERDE_PCT", margem_marrom = "MARGEM_MARROM_PCT",
          alta_verde = "PCT_ALTA_VERDE", alta_marrom = "PCT_ALTA_MARROM",
          Ano = "ANO")
  names(t)[names(t) %in% names(nm)] <- nm[names(t)[names(t) %in% names(nm)]]
  t
}

# ------------------------------------------------------------------------------
# Bloco 1. Conteúdo verde médio, margem extensiva e distribuição
# ------------------------------------------------------------------------------
cob <- data.frame(Ano = ANOS_PNADC,
                  OCUPADOS_TOTAL_MIL = round(tapply(pn$V1028, pn$Ano, sum) / 1e3, 1),
                  COBERTURA_PCT = round(100 * tapply(pn$V1028 * pn$com_indice, pn$Ano, sum) /
                                          tapply(pn$V1028, pn$Ano, sum), 2))
b1 <- agrega(d, "Ano", c(VARS_IDX, "verde_esp_ano", "marrom_esp_ano"))
b1$Ano <- as.integer(b1$Ano)
b1 <- merge(cob, b1, by = "Ano")
b1$VERDE_MEDIANA <- sapply(b1$Ano, function(a) wquant(d$verde_ano[d$Ano == a], d$V1028[d$Ano == a], .5))
b1$VERDE_P90     <- sapply(b1$Ano, function(a) wquant(d$verde_ano[d$Ano == a], d$V1028[d$Ano == a], .9))
b1$MARROM_P90    <- sapply(b1$Ano, function(a) wquant(d$marrom_ano[d$Ano == a], d$V1028[d$Ano == a], .9))
ep <- ep_nacional
b1$VERDE_EP  <- ep$ep[ep$INDICADOR == "Índice verde médio"][match(b1$Ano, ep$ANO[ep$INDICADOR == "Índice verde médio"])]
b1$MARROM_EP <- ep$ep[ep$INDICADOR == "Índice marrom médio"][match(b1$Ano, ep$ANO[ep$INDICADOR == "Índice marrom médio"])]
b1$MARGEM_VERDE_EP <- 100 * ep$ep[ep$INDICADOR == "Margem extensiva verde (%)"][match(b1$Ano, ep$ANO[ep$INDICADOR == "Margem extensiva verde (%)"])]
b1 <- renomeia_idx(b1)
names(b1)[names(b1) == "verde_esp_ano"]  <- "VERDE_ESPECIFICO_MEDIO"
names(b1)[names(b1) == "marrom_esp_ano"] <- "MARROM_ESPECIFICO_MEDIO"
b1$RAIS_PESOS <- sapply(b1$ANO, ano_ref)
guarda("b1_nacional", arred(b1))

# distribuição dos ocupados por faixa do índice
FAIXAS <- c(-Inf, 0, 0.01, 0.02, 0.03, 0.05, 0.10, Inf)
ROT_FAIXAS <- c("0 (nenhuma atividade)", "até 0,01", "0,01 a 0,02", "0,02 a 0,03", "0,03 a 0,05",
                "0,05 a 0,10", "acima de 0,10")
faixa <- function(x) as.character(cut(x, FAIXAS, labels = ROT_FAIXAS))
d$faixa_verde  <- faixa(d$verde_ano)
d$faixa_marrom <- faixa(d$marrom_ano)
fx <- rbind(
  transform(agrega(d, c("Ano", "faixa_verde"), "verde_ano"), INDICE = "verde")[, c("INDICE", "Ano", "faixa_verde", "N_AMOSTRA", "OCUPADOS_MIL")],
  setNames(transform(agrega(d, c("Ano", "faixa_marrom"), "marrom_ano"), INDICE = "marrom")[, c("INDICE", "Ano", "faixa_marrom", "N_AMOSTRA", "OCUPADOS_MIL")],
           c("INDICE", "Ano", "faixa_verde", "N_AMOSTRA", "OCUPADOS_MIL")))
names(fx)[3] <- "FAIXA_DO_INDICE"
fx$PCT_OCUPADOS <- 100 * fx$OCUPADOS_MIL / ave(fx$OCUPADOS_MIL, fx$INDICE, fx$Ano, FUN = sum)
fx <- fx[order(fx$INDICE, fx$Ano, match(fx$FAIXA_DO_INDICE, ROT_FAIXAS)), ]
names(fx)[2] <- "ANO"
guarda("b1_faixas_indice", arred(fx, 2))

# concentração: décimos de ocupados ordenados pelo índice, no ano de foco
concentra <- function(y, w, nome) {
  o <- order(y); y <- y[o]; w <- w[o]; cw <- cumsum(w) / sum(w)
  dec <- pmin(10L, as.integer(ceiling(cw * 10 - 1e-9)))
  data.frame(INDICE = nome, DECIMO_DE_OCUPADOS = 1:10,
             INDICE_MINIMO = tapply(y, dec, min), INDICE_MAXIMO = tapply(y, dec, max),
             INDICE_MEDIO = tapply(y * w, dec, sum) / tapply(w, dec, sum),
             PCT_DO_CONTEUDO_TOTAL = 100 * tapply(y * w, dec, sum) / sum(y * w))
}
f <- d$Ano == ANO_FOCO
guarda("b1_concentracao_2024", arred(rbind(concentra(d$verde_ano[f], d$V1028[f], "verde"),
                                           concentra(d$marrom_ano[f], d$V1028[f], "marrom"))))

# grupos da COD que mais contribuem para o conteúdo verde e marrom total
contrib <- function(var, n = 25) {
  x <- d[f, ]
  t <- agrega(x, "V4010", var)
  t$CONTEUDO <- t$OCUPADOS_MIL * t[[var]]
  t$PCT_DO_CONTEUDO_TOTAL <- 100 * t$CONTEUDO / sum(t$CONTEUDO)
  t$PCT_OCUPADOS <- 100 * t$OCUPADOS_MIL / sum(t$OCUPADOS_MIL)
  t <- t[order(-t$CONTEUDO), ][seq_len(n), ]
  data.frame(INDICE = sub("_ano", "", var), COD = t$V4010,
             TITULO = ic$TITULO_COD[match(t$V4010, ic$COD)],
             OCUPADOS_MIL = t$OCUPADOS_MIL, PCT_OCUPADOS = t$PCT_OCUPADOS,
             INDICE_DO_GRUPO = t[[var]], PCT_DO_CONTEUDO_TOTAL = t$PCT_DO_CONTEUDO_TOTAL,
             PCT_ACUMULADO = cumsum(t$PCT_DO_CONTEUDO_TOTAL))
}
guarda("b1_principais_grupos_2024", arred(rbind(contrib("verde_ano"), contrib("marrom_ano"))))

# ------------------------------------------------------------------------------
# Bloco 2. Perfil sociodemográfico
# ------------------------------------------------------------------------------
DIMENSOES <- c(sexo = "Sexo", cor = "Cor ou raça", faixa_etaria = "Idade",
               escolaridade = "Escolaridade", regiao = "Região", situacao = "Situação do domicílio")
perfil <- do.call(rbind, lapply(names(DIMENSOES), function(v) {
  x <- d[!is.na(d[[v]]), ]
  t <- agrega(x, c("Ano", v), VARS_IDX)
  # composição: parcela dos ocupados de alta intensidade que está na categoria
  wv <- rowsum(x$V1028 * x$verde_intenso, paste(x$Ano, x[[v]]))
  wm <- rowsum(x$V1028 * x$marrom_intenso, paste(x$Ano, x[[v]]))
  k <- paste(t$Ano, t[[v]])
  t$COMPOSICAO_ALTA_VERDE_PCT  <- 100 * wv[k, 1] / ave(wv[k, 1], t$Ano, FUN = sum)
  t$COMPOSICAO_ALTA_MARROM_PCT <- 100 * wm[k, 1] / ave(wm[k, 1], t$Ano, FUN = sum)
  t$COMPOSICAO_TOTAL_PCT <- pct_no_ano(t)
  data.frame(DIMENSAO = unname(DIMENSOES[v]), CATEGORIA = t[[v]], t[, setdiff(names(t), v)],
             stringsAsFactors = FALSE, check.names = FALSE)
}))
guarda("b2_perfil", arred(renomeia_idx(perfil)))

# ------------------------------------------------------------------------------
# Bloco 3. Qualidade do emprego
# ------------------------------------------------------------------------------
d$informal_pct  <- 100 * d$informal
d$contribui_pct <- 100 * d$contribui
VARS_Q <- c("informal_pct", "contribui_pct", "renda_real", "horas", "renda_hora")
qual <- function(x, by) {
  t <- agrega(x, by, VARS_Q)
  k <- do.call(paste, c(lapply(by, function(b) x[[b]]), sep = "\r"))
  kt <- do.call(paste, c(lapply(by, function(b) t[[b]]), sep = "\r"))
  med <- tapply(seq_len(nrow(x)), k, function(i) wquant(x$renda_real[i], x$V1028[i]))
  medh <- tapply(seq_len(nrow(x)), k, function(i) wquant(x$renda_hora[i], x$V1028[i]))
  t$RENDA_MEDIANA <- med[kt]; t$RENDA_HORA_MEDIANA <- medh[kt]
  t
}
x_tot <- d; x_tot$grupo_intensidade <- "Total"
q1 <- qual(rbind(d, x_tot), c("Ano", "grupo_intensidade"))
names(q1)[names(q1) == "grupo_intensidade"] <- "GRUPO"
q1$RECORTE <- "Intensidade da ocupação"
q2 <- qual(d, c("Ano", "faixa_verde")); names(q2)[names(q2) == "faixa_verde"] <- "GRUPO"
q2$RECORTE <- "Faixa do índice verde"
q3 <- qual(d, c("Ano", "faixa_marrom")); names(q3)[names(q3) == "faixa_marrom"] <- "GRUPO"
q3$RECORTE <- "Faixa do índice marrom"
qq <- rbind(q1, q2, q3)
qq <- qq[, c("RECORTE", "Ano", "GRUPO", setdiff(names(qq), c("RECORTE", "Ano", "GRUPO")))]
names(qq) <- sub("^informal_pct$", "INFORMALIDADE_PCT", names(qq))
names(qq) <- sub("^contribui_pct$", "CONTRIBUI_PREVIDENCIA_PCT", names(qq))
names(qq) <- sub("^renda_real$", "RENDA_MEDIA", names(qq))
names(qq) <- sub("^horas$", "HORAS_SEMANAIS_MEDIAS", names(qq))
names(qq) <- sub("^renda_hora$", "RENDA_HORA_MEDIA", names(qq))
names(qq)[names(qq) == "Ano"] <- "ANO"
guarda("b3_qualidade", arred(qq, 2))

# Prêmio salarial descritivo: log da renda-hora contra o índice (em pontos de
# 0,01, isto é, 1 ponto percentual das atividades), sem e com controles.
# Mínimos quadrados ponderados por V1028; o erro-padrão é o do lm e não leva
# em conta o desenho amostral (é indicativo).
premio <- do.call(rbind, lapply(ANOS_PNADC, function(a) {
  x <- d[d$Ano == a & !is.na(d$renda_hora) & !is.na(d$escolaridade) & !is.na(d$cor), ]
  x$lw <- log(x$renda_hora)
  x$v100 <- 100 * x$verde_ano; x$m100 <- 100 * x$marrom_ano
  ctrl1 <- "sexo + idade + I(idade^2) + cor + escolaridade + factor(uf) + situacao"
  ctrl2 <- paste(ctrl1, if (all(is.na(x$informal))) "+ setor" else "+ informal + setor")
  esp <- list("Bruto" = "", "Controles pessoais e regionais" = ctrl1,
              "Mais informalidade e setor" = ctrl2)
  do.call(rbind, lapply(c(v100 = "verde", m100 = "marrom"), function(ind) {
    var <- if (ind == "verde") "v100" else "m100"
    do.call(rbind, lapply(names(esp), function(e) {
      fml <- as.formula(paste("lw ~", var, if (nzchar(esp[[e]])) paste("+", esp[[e]]) else ""))
      fit <- lm(fml, data = x, weights = V1028)
      s <- summary(fit)$coefficients
      data.frame(ANO = a, INDICE = ind, ESPECIFICACAO = e, N_AMOSTRA = nobs(fit),
                 COEF = s[var, 1], EP_LM = s[var, 2],
                 VARIACAO_PCT_POR_PONTO = 100 * (exp(s[var, 1]) - 1),
                 R2 = summary(fit)$r.squared)
    }))
  }))
}))
guarda("b3_premio_salarial", arred(premio))

# ------------------------------------------------------------------------------
# Bloco 4. Classificação híbrida ocupação x setor
# ------------------------------------------------------------------------------
h <- agrega(d, c("Ano", "grupo_intensidade", "classe_setor"), character(0))
h$PCT_OCUPADOS_DO_ANO <- pct_no_ano(h)
h$PCT_DENTRO_DA_CLASSE_SETOR <- 100 * h$OCUPADOS_MIL / ave(h$OCUPADOS_MIL, h$Ano, h$classe_setor, FUN = sum)
names(h)[1:3] <- c("ANO", "GRUPO_OCUPACAO", "CLASSE_SETOR")
guarda("b4_hibrida_matriz", arred(h, 2))

hs <- agrega(d, c("Ano", "classe_setor"), VARS_IDX)
hs$PCT_OCUPADOS <- pct_no_ano(hs)
names(hs)[2] <- "CLASSE_SETOR"
guarda("b4_por_classe_setor", arred(renomeia_idx(hs)))

hz <- agrega(d, c("Ano", "setor"), VARS_IDX)
hz$PCT_OCUPADOS <- pct_no_ano(hz)
names(hz)[2] <- "SETOR_CNAE"
guarda("b4_por_setor", arred(renomeia_idx(hz)))

# ------------------------------------------------------------------------------
# Bloco 5. Território
# ------------------------------------------------------------------------------
tr_agr <- function(col, nivel) {
  t <- agrega(d, c("Ano", col), VARS_IDX); names(t)[2] <- "UNIDADE"; t$NIVEL <- nivel; t
}
tr <- rbind(tr_agr("regiao", "Região"), tr_agr("UF", "UF"), tr_agr("nordeste", "Nordeste e demais"))
tr$REGIAO <- ifelse(tr$NIVEL == "UF", d$regiao[match(tr$UNIDADE, d$UF)], NA)
tr <- tr[, c("NIVEL", "REGIAO", "Ano", "UNIDADE", setdiff(names(tr), c("NIVEL", "REGIAO", "Ano", "UNIDADE")))]
guarda("b5_territorio", arred(renomeia_idx(tr)))

# Nordeste: situação do domicílio e intensidade
ne <- agrega(d, c("Ano", "nordeste", "situacao"), VARS_IDX)
names(ne)[2:3] <- c("RECORTE", "SITUACAO")
guarda("b5_nordeste_situacao", arred(renomeia_idx(ne)))

# Principais grupos verdes no Nordeste e no Brasil (ano de foco)
contrib_reg <- function(x, nome, var = "verde_ano", n = 15) {
  t <- agrega(x, "V4010", var); t$CONTEUDO <- t$OCUPADOS_MIL * t[[var]]
  t$PCT <- 100 * t$CONTEUDO / sum(t$CONTEUDO); t <- t[order(-t$CONTEUDO), ][seq_len(n), ]
  data.frame(RECORTE = nome, INDICE = sub("_ano", "", var), POSICAO = seq_len(n), COD = t$V4010,
             TITULO = ic$TITULO_COD[match(t$V4010, ic$COD)], OCUPADOS_MIL = t$OCUPADOS_MIL,
             INDICE_DO_GRUPO = t[[var]], PCT_DO_CONTEUDO = t$PCT)
}
guarda("b5_principais_grupos_regiao_2024", arred(rbind(
  contrib_reg(d[f, ], "Brasil"), contrib_reg(d[f & d$regiao == "Nordeste", ], "Nordeste"),
  contrib_reg(d[f, ], "Brasil", "marrom_ano"), contrib_reg(d[f & d$regiao == "Nordeste", ], "Nordeste", "marrom_ano"))))

# ------------------------------------------------------------------------------
# Bloco 6. Transição justa: perfil das ocupações de alta intensidade marrom
# ------------------------------------------------------------------------------
d$mulher_pct   <- 100 * (d$sexo == "Mulher")
d$ppi_pct      <- 100 * (d$cor == "Pretos, pardos e indígenas")
d$fund_inc_pct <- 100 * (d$escolaridade == "Até fundamental incompleto")
d$superior_pct <- 100 * (d$escolaridade == "Superior completo")
d$rural_pct    <- 100 * (d$situacao == "Rural")
d$nordeste_pct <- 100 * (d$regiao == "Nordeste")
d$setor_marrom_pct <- 100 * (d$classe_setor == "Marrom")
d$jovem_pct    <- 100 * (d$idade <= 24)
d$idoso_pct    <- 100 * (d$idade >= 50)
VARS_P <- c("mulher_pct", "ppi_pct", "idade", "jovem_pct", "idoso_pct", "fund_inc_pct", "superior_pct",
            "informal_pct", "contribui_pct", "renda_real", "horas", "rural_pct", "nordeste_pct",
            "setor_marrom_pct", "verde_ano", "marrom_ano")
x_tot <- d; x_tot$grupo_intensidade <- "Total"
tj <- agrega(rbind(d, x_tot), c("Ano", "grupo_intensidade"), VARS_P)
names(tj) <- toupper(names(tj)); names(tj)[2] <- "GRUPO"
guarda("b6_perfil_comparado", arred(tj, 4))

# grupos da COD de alta intensidade marrom com mais ocupados (ano de foco)
x <- d[f & d$marrom_intenso == 1, ]
tg <- agrega(x, "V4010", VARS_P)
tg <- tg[order(-tg$OCUPADOS_MIL), ][seq_len(min(25, nrow(tg))), ]
tg$TITULO <- ic$TITULO_COD[match(tg$V4010, ic$COD)]
tg <- tg[, c("V4010", "TITULO", setdiff(names(tg), c("V4010", "TITULO")))]
names(tg) <- toupper(names(tg)); names(tg)[1] <- "COD"
guarda("b6_grupos_marrons_2024", arred(tg, 4))

# ------------------------------------------------------------------------------
# Bloco 7. Evolução 2012-2024 com o índice de pesos fixos (RAIS 2024)
# ------------------------------------------------------------------------------
dfx <- pn[!is.na(pn$verde_fixo), ]
dfx$alta_verde  <- 100 * (dfx$verde_fixo  >= LIMIAR_VERDE)
dfx$alta_marrom <- 100 * (dfx$marrom_fixo >= LIMIAR_MARROM)
dfx$margem_verde  <- 100 * (dfx$verde_fixo > 0)
dfx$margem_marrom <- 100 * (dfx$marrom_fixo > 0)
ev <- agrega(dfx, "Ano", c("verde_fixo", "marrom_fixo", "liquido_fixo", "margem_verde", "margem_marrom",
                           "alta_verde", "alta_marrom"))
ev$Ano <- as.integer(ev$Ano)
ev$VERDE_PESOS_DO_ANO  <- b1$VERDE_MEDIO[match(ev$Ano, b1$ANO)]
ev$MARROM_PESOS_DO_ANO <- b1$MARROM_MEDIO[match(ev$Ano, b1$ANO)]
ev$OCUPADOS_ALTA_VERDE_MIL  <- ev$OCUPADOS_MIL * ev$alta_verde / 100
ev$OCUPADOS_ALTA_MARROM_MIL <- ev$OCUPADOS_MIL * ev$alta_marrom / 100
names(ev) <- sub("^verde_fixo$", "VERDE_MEDIO", names(ev))
names(ev) <- sub("^marrom_fixo$", "MARROM_MEDIO", names(ev))
names(ev) <- sub("^liquido_fixo$", "LIQUIDO_MEDIO", names(ev))
guarda("b7_serie", arred(renomeia_idx(ev)))

# Shift-share por setor: variação do índice médio entre dois anos dividida em
# mudança na participação dos setores (entre) e mudança na composição
# ocupacional dentro de cada setor (dentro). Fórmula simétrica (média dos
# pesos dos dois anos), sem resíduo.
PERIODOS <- list(c(2012, 2024), c(2012, 2014), c(2014, 2016), c(2016, 2019), c(2019, 2024))
# Período extra usado só na planilha do grupo de pesquisa (anos 2012, 2016, 2019 e 2024)
PERIODOS_GRUPO <- list(c(2012, 2016))
shift_share <- function(var, por) {
  do.call(rbind, lapply(c(PERIODOS, PERIODOS_GRUPO), function(p) {
    g <- lapply(p, function(a) {
      x <- dfx[dfx$Ano == a, ]
      s <- tapply(x$V1028, x[[por]], sum); s <- s / sum(s)
      i <- tapply(x$V1028 * x[[var]], x[[por]], sum) / tapply(x$V1028, x[[por]], sum)
      list(s = s, i = i)
    })
    k <- union(names(g[[1]]$s), names(g[[2]]$s))
    s0 <- g[[1]]$s[k]; s1 <- g[[2]]$s[k]; i0 <- g[[1]]$i[k]; i1 <- g[[2]]$i[k]
    s0[is.na(s0)] <- 0; s1[is.na(s1)] <- 0; i0[is.na(i0)] <- i1[is.na(i0)]; i1[is.na(i1)] <- i0[is.na(i1)]
    tot0 <- sum(s0 * i0); tot1 <- sum(s1 * i1)
    entre <- (s1 - s0) * (i0 + i1) / 2; dentro <- (i1 - i0) * (s0 + s1) / 2
    rbind(
      data.frame(INDICE = sub("_fixo", "", var), DECOMPOSICAO = por, PERIODO = paste(p, collapse = "-"),
                 COMPONENTE = c("Índice inicial", "Índice final", "Variação total",
                                "Entre (participação dos setores)", "Dentro (composição ocupacional)"),
                 GRUPO = "Total", VALOR = c(tot0, tot1, tot1 - tot0, sum(entre), sum(dentro))),
      data.frame(INDICE = sub("_fixo", "", var), DECOMPOSICAO = por, PERIODO = paste(p, collapse = "-"),
                 COMPONENTE = rep(c("Entre", "Dentro"), each = length(k)), GRUPO = rep(k, 2),
                 VALOR = c(entre, dentro)))
  }))
}
ss <- rbind(shift_share("verde_fixo", "setor"), shift_share("marrom_fixo", "setor"))
ss$DECOMPOSICAO <- "Setor CNAE"
guarda("b7_shift_share_setor", arred(ss, 6))

# Contribuição dos grandes grupos ocupacionais: com o índice fixo, a variação
# é a soma de (mudança de participação do grupo da COD x seu índice).
contrib_gg <- do.call(rbind, lapply(c(PERIODOS, PERIODOS_GRUPO), function(p) {
  do.call(rbind, lapply(c("verde_fixo", "marrom_fixo"), function(var) {
    sh <- lapply(p, function(a) { x <- dfx[dfx$Ano == a, ]; s <- tapply(x$V1028, x$V4010, sum); s / sum(s) })
    k <- union(names(sh[[1]]), names(sh[[2]]))
    s0 <- sh[[1]][k]; s1 <- sh[[2]][k]; s0[is.na(s0)] <- 0; s1[is.na(s1)] <- 0
    idx <- ic[ic$ANO_RAIS == max(ANOS_RAIS), ]
    iv <- idx[[c(verde_fixo = "Verde_amplo", marrom_fixo = "Marrom")[var]]][match(k, idx$COD)]
    gg <- unname(GRANDES_GRUPOS[substr(k, 1, 1)])
    c0 <- tapply(s0, gg, sum); c1 <- tapply(s1, gg, sum)
    data.frame(INDICE = sub("_fixo", "", var), PERIODO = paste(p, collapse = "-"), GRANDE_GRUPO = names(c0),
               PCT_OCUPADOS_INICIAL = 100 * c0, PCT_OCUPADOS_FINAL = 100 * c1[names(c0)],
               CONTRIBUICAO = tapply((s1 - s0) * iv, gg, sum)[names(c0)])
  }))
}))
contrib_gg$PCT_DA_VARIACAO <- 100 * contrib_gg$CONTRIBUICAO /
  ave(contrib_gg$CONTRIBUICAO, contrib_gg$INDICE, contrib_gg$PERIODO, FUN = sum)
guarda("b7_contribuicao_grandes_grupos", arred(contrib_gg, 6))

# ------------------------------------------------------------------------------
# Bloco 8. Desigualdade: índice por décimo de renda
# ------------------------------------------------------------------------------
dr <- d[!is.na(d$decimo_renda), ]
de <- agrega(dr, c("Ano", "decimo_renda"), c(VARS_IDX, "renda_real"))
de$decimo_renda <- as.integer(de$decimo_renda)
de <- de[order(de$Ano, de$decimo_renda), ]
names(de)[names(de) == "decimo_renda"] <- "DECIMO_RENDA"
names(de)[names(de) == "renda_real"] <- "RENDA_MEDIA"
guarda("b8_decimos_renda", arred(renomeia_idx(de)))

# Índice de concentração (curva de concentração do conteúdo verde ao longo da
# renda): 2 x cov(índice, posição na renda) / média. Positivo = o conteúdo
# verde está mais presente entre os de maior renda.
conc <- do.call(rbind, lapply(ANOS_PNADC, function(a) {
  x <- dr[dr$Ano == a, ]; o <- order(x$renda_real); x <- x[o, ]
  w <- x$V1028 / sum(x$V1028); r <- cumsum(w) - w / 2
  ci <- function(y) { mu <- sum(w * y); 2 * sum(w * (y - mu) * (r - sum(w * r))) / mu }
  data.frame(ANO = a, CONCENTRACAO_VERDE = ci(x$verde_ano), CONCENTRACAO_MARROM = ci(x$marrom_ano),
             CONCENTRACAO_ALTA_VERDE = ci(x$verde_intenso), CONCENTRACAO_ALTA_MARROM = ci(x$marrom_intenso))
}))
guarda("b8_concentracao", arred(conc))

# ------------------------------------------------------------------------------
# Metadados e xlsx
# ------------------------------------------------------------------------------
meta <- data.frame(
  ITEM = c("Gerado em", "Anos da PNADc", "Trimestre", "Peso", "População",
           "Índice", "Pesos da RAIS nos cortes anuais", "Pesos da RAIS na evolução (b7)",
           "Limiar de alta intensidade verde", "Limiar de alta intensidade marrom",
           "Renda", "Informalidade", "Situação dos rótulos"),
  VALOR = c(format(Sys.time(), "%Y-%m-%d %H:%M"), paste(range(ANOS_PNADC), collapse = " a "), "4º",
            "V1028; erro-padrão das médias nacionais com os 200 pesos replicados",
            "Ocupados com grupo da COD que tem índice",
            "metodologia/saida/ponte/indice_por_cod.csv",
            "ano mais próximo entre 2014, 2016, 2019 e 2024", "2024 em todos os anos",
            sprintf("%.5f (90º percentil dos ocupados em %d)", LIMIAR_VERDE, ANO_FOCO),
            sprintf("%.5f (90º percentil dos ocupados em %d)", LIMIAR_MARROM, ANO_FOCO),
            "VD4016 x deflator Habitual do IBGE (R$ do período de referência do deflator)",
            "Definição do IBGE: sem carteira (privado e doméstico), conta-própria e empregador sem CNPJ, familiar auxiliar",
            "Preliminar: rótulos de setembro de 2026, anteriores à classificação humana"))
guarda("metadados", meta)

if (requireNamespace("openxlsx", quietly = TRUE)) {
  wb <- openxlsx::createWorkbook()
  for (nm in names(TAB)) {
    openxlsx::addWorksheet(wb, substr(nm, 1, 31))
    openxlsx::writeData(wb, substr(nm, 1, 31), TAB[[nm]])
  }
  openxlsx::saveWorkbook(wb, file.path(DIR_EST, "estatisticas_descritivas.xlsx"), overwrite = TRUE)
}
cat("tabelas gravadas em", DIR_EST, ":", length(TAB), "\n")
