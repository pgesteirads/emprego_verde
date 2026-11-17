# ==============================================================================
# ESTATÍSTICAS DESCRITIVAS - 04. PLANILHA PARA O GRUPO DE PESQUISA
# ==============================================================================
# Lê as tabelas gravadas por 02_tabelas.R (metodologia/saida/estatisticas/*.csv)
# e monta uma versão formatada para leitura, só com os anos 2012, 2016, 2019 e
# 2024, com os anos em colunas:
#
#   metodologia/saida/estatisticas/estatisticas_descritivas_grupo.xlsx
#
# Cada aba traz título, nota de leitura, cabeçalho em verde escuro com fonte
# branca em negrito e a fonte dos dados. A aba "Leia-me" tem o sumário com
# links, os conceitos e as ressalvas.
# ==============================================================================

etapa("Estatísticas 04. Planilha para o grupo de pesquisa")

# Permite rodar este script sozinho, depois de 00_config.R e funcoes.R, sem
# reler os microdados: o que vem de 01_base_analitica.R é recuperado dos CSVs.
if (!exists("DIR_EST")) DIR_EST <- file.path(CAMINHOS$saida, "estatisticas")
if (!exists("LIMIAR_VERDE") || !exists("LIMIAR_MARROM")) local({
  md <- ler_csv(file.path(DIR_EST, "metadados.csv"))
  lim <- function(item) as.numeric(sub(" .*", "", md$VALOR[md$ITEM == item]))
  LIMIAR_VERDE  <<- lim("Limiar de alta intensidade verde")
  LIMIAR_MARROM <<- lim("Limiar de alta intensidade marrom")
})
if (!exists("GRANDES_GRUPOS")) local({
  tc <- ler_csv(file.path(CAMINHOS$insumos, "ponte", "cod_titulos_ibge.csv"))
  tc <- tc[tc$NIVEL == "grande_grupo", ]
  GRANDES_GRUPOS <<- setNames(tc$TITULO, tc$COD)
})

ANOS_G <- c(2012, 2016, 2019, 2024)
PER_G  <- c("2012-2016", "2016-2019", "2019-2024", "2012-2024")
COR_CAB <- "#1B5E20"; COR_FAIXA <- "#EEF5EE"; COR_LINHA <- "#D9D9D9"
FONTE_TXT <- paste("Fonte: PNAD Contínua (IBGE), 4º trimestre; RAIS (MTE); índice de esverdeamento",
                   "ocupacional preliminar. Elaboração própria.")
ARQ_GRUPO <- file.path(DIR_EST, "estatisticas_descritivas_grupo.xlsx")

# --- Leitura -------------------------------------------------------------------
lt <- function(nm) {
  x <- ler_csv(file.path(DIR_EST, paste0(nm, ".csv")))
  for (v in setdiff(names(x), c("COD", "ANO", "PERIODO"))) {
    y <- suppressWarnings(as.numeric(sub(",", ".", x[[v]], fixed = TRUE)))
    if (identical(is.na(y), is.na(x[[v]]))) x[[v]] <- y
  }
  if ("ANO" %in% names(x)) x$ANO <- as.integer(x$ANO)
  x
}
caixa_frase <- function(s) paste0(substr(s, 1, 1), tolower(substring(s, 2)))
nome_idx <- function(s) c(verde = "Verde", marrom = "Marrom")[s]

# --- Dicionário de indicadores: rótulo legível e formato ------------------------
FMT <- c(ind = "0.0000", pct = "0.0", mil = "#,##0.0", int = "#,##0", rs = "#,##0",
         dec1 = "0.0", dec2 = "0.00", dec3 = "0.000", x1e4 = "0.0", ano = "0", ep = "0.00000")
IND <- list(
  OCUPADOS_MIL = c("Ocupados (mil)", "mil"),
  N_AMOSTRA = c("Observações na amostra", "int"),
  VERDE_MEDIO = c("Índice verde médio", "ind"),
  MARROM_MEDIO = c("Índice marrom médio", "ind"),
  LIQUIDO_MEDIO = c("Índice líquido médio (verde menos marrom)", "ind"),
  MARGEM_VERDE_PCT = c("Com alguma atividade verde (%)", "pct"),
  MARGEM_MARROM_PCT = c("Com alguma atividade marrom (%)", "pct"),
  PCT_ALTA_VERDE = c("Em ocupação de alta intensidade verde (%)", "pct"),
  PCT_ALTA_MARROM = c("Em ocupação de alta intensidade marrom (%)", "pct"),
  COMPOSICAO_ALTA_VERDE_PCT = c("Distribuição dos ocupados de alta intensidade verde (%)", "pct"),
  COMPOSICAO_ALTA_MARROM_PCT = c("Distribuição dos ocupados de alta intensidade marrom (%)", "pct"),
  COMPOSICAO_TOTAL_PCT = c("Distribuição do total de ocupados (%)", "pct"),
  PCT_OCUPADOS = c("Participação nos ocupados (%)", "pct"),
  RENDA_MEDIA = c("Renda média do trabalho principal (R$)", "rs"),
  INFORMALIDADE_PCT = c("Informalidade (%)", "pct"),
  CONTRIBUI_PREVIDENCIA_PCT = c("Contribui para a previdência (%)", "pct"),
  RENDA_MEDIANA = c("Renda mediana do trabalho principal (R$)", "rs"),
  HORAS_SEMANAIS_MEDIAS = c("Horas semanais médias", "dec1"),
  RENDA_HORA_MEDIA = c("Renda média por hora (R$)", "dec2"),
  RENDA_HORA_MEDIANA = c("Renda mediana por hora (R$)", "dec2"),
  MULHER_PCT = c("Mulheres (%)", "pct"),
  PPI_PCT = c("Pretos, pardos e indígenas (%)", "pct"),
  IDADE = c("Idade média (anos)", "dec1"),
  JOVEM_PCT = c("De 14 a 24 anos (%)", "pct"),
  IDOSO_PCT = c("Com 50 anos ou mais (%)", "pct"),
  FUND_INC_PCT = c("Até fundamental incompleto (%)", "pct"),
  SUPERIOR_PCT = c("Superior completo (%)", "pct"),
  INFORMAL_PCT = c("Informais (%)", "pct"),
  CONTRIBUI_PCT = c("Contribuem para a previdência (%)", "pct"),
  RENDA_REAL = c("Renda média do trabalho principal (R$)", "rs"),
  HORAS = c("Horas semanais médias", "dec1"),
  RURAL_PCT = c("Moram em área rural (%)", "pct"),
  NORDESTE_PCT = c("Moram no Nordeste (%)", "pct"),
  SETOR_MARROM_PCT = c("Trabalham em setor marrom (%)", "pct"),
  VERDE_ANO = c("Índice verde médio", "ind"),
  MARROM_ANO = c("Índice marrom médio", "ind")
)
rot <- function(v) IND[[v]][1]
fmt_de <- function(v) IND[[v]][2]

# --- Pivô: uma linha por combinação de ids, uma coluna por ano ------------------
larga <- function(d, ids, chave, niveis) {
  d <- d[d[[chave]] %in% niveis, , drop = FALSE]
  k <- do.call(paste, c(unname(as.list(d[ids])), sep = "\r"))
  u <- unique(k)
  list(ids = d[match(u, k), ids, drop = FALSE],
       bloco = function(var) {
         m <- sapply(niveis, function(n) { s <- d[[chave]] == n; d[[var]][s][match(u, k[s])] })
         m <- matrix(m, nrow = length(u)); colnames(m) <- as.character(niveis); m
       })
}
blocos_larga <- function(p, vars, rotulos = NULL) {
  lapply(seq_along(vars), function(i) list(
    rotulo = if (is.null(rotulos)) rot(vars[i]) else rotulos[i],
    m = p$bloco(vars[i]), fmt = fmt_de(vars[i])))
}
# Bloco de uma coluna só (tabelas sem anos)
col1 <- function(rotulo, x, fmt) list(rotulo = rotulo, m = matrix(x, ncol = 1, dimnames = list(NULL, rotulo)), fmt = fmt)

# --- Estilos -------------------------------------------------------------------
st_titulo <- openxlsx::createStyle(fontSize = 13, textDecoration = "bold", fontColour = COR_CAB)
st_nota   <- openxlsx::createStyle(fontSize = 9, fontColour = "#404040", wrapText = TRUE, valign = "top")
st_fonte  <- openxlsx::createStyle(fontSize = 8, textDecoration = "italic", fontColour = "#595959")
st_link   <- openxlsx::createStyle(fontSize = 9, fontColour = "#1F4E79", textDecoration = "underline")
st_cab    <- openxlsx::createStyle(fgFill = COR_CAB, fontColour = "#FFFFFF", textDecoration = "bold",
                                   halign = "center", valign = "center", wrapText = TRUE,
                                   border = "TopBottomLeftRight", borderColour = "#FFFFFF")
st_cab_id <- openxlsx::createStyle(fgFill = COR_CAB, fontColour = "#FFFFFF", textDecoration = "bold",
                                   halign = "left", valign = "center", wrapText = TRUE,
                                   border = "TopBottomLeftRight", borderColour = "#FFFFFF")
st_corpo  <- openxlsx::createStyle(fontSize = 10, valign = "center", border = "bottom", borderColour = COR_LINHA)
st_faixa  <- openxlsx::createStyle(fgFill = COR_FAIXA)
st_id     <- openxlsx::createStyle(halign = "left", wrapText = TRUE)
st_grupo  <- openxlsx::createStyle(border = "top", borderColour = COR_CAB, borderStyle = "medium")
st_bloco  <- openxlsx::createStyle(border = "left", borderColour = "#A5C8A5")
st_num    <- lapply(FMT, function(f) openxlsx::createStyle(numFmt = f, halign = "right"))

wb <- openxlsx::createWorkbook()
openxlsx::modifyBaseFont(wb, fontSize = 10, fontName = "Calibri")
SUMARIO <- list()

# --- Escrita de uma aba --------------------------------------------------------
# ids: data.frame com os nomes legíveis das colunas de identificação.
# blocos: lista de list(rotulo, m = matriz com colnames = subcolunas, fmt), em
#   que fmt é um formato só ou um vetor com um formato por linha.
escreve <- function(aba, titulo, nota, ids, blocos, larg_id = NULL, nota_extra = NULL) {
  openxlsx::addWorksheet(wb, aba, gridLines = FALSE)
  SUMARIO[[length(SUMARIO) + 1]] <<- c(aba, titulo)
  ni <- ncol(ids); n <- nrow(ids)
  nc <- ni + sum(sapply(blocos, function(b) ncol(b$m)))
  r_cab <- 5; r0 <- r_cab + 2
  # título, nota e link para o sumário
  openxlsx::writeData(wb, aba, titulo, startRow = 1, startCol = 1)
  openxlsx::addStyle(wb, aba, st_titulo, rows = 1, cols = 1)
  # larguras das colunas
  if (is.null(larg_id)) larg_id <- sapply(seq_len(ni), function(j)
    min(55, max(12, nchar(names(ids)[j]) + 2, max(c(0, nchar(as.character(ids[[j]]))), na.rm = TRUE) + 2)))
  larg_num <- unlist(lapply(blocos, function(b) rep(if (ncol(b$m) == 1) 14 else 10.5, ncol(b$m))))
  larg <- c(larg_id, larg_num)
  # a nota ocupa no máximo cerca de 150 caracteres de largura, para caber na tela
  ate <- max(1, sum(cumsum(larg) <= 150))
  openxlsx::writeData(wb, aba, nota, startRow = 2, startCol = 1)
  openxlsx::mergeCells(wb, aba, cols = 1:ate, rows = 2)
  openxlsx::addStyle(wb, aba, st_nota, rows = 2, cols = 1)
  openxlsx::setRowHeights(wb, aba, 2, 12.5 * max(1, ceiling(nchar(nota) / (sum(larg[1:ate]) * 1.05))) + 4)
  link <- openxlsx::makeHyperlinkString(sheet = "Leia-me", row = 1, col = 1, text = "Voltar ao sumário")
  openxlsx::writeFormula(wb, aba, link, startRow = 3, startCol = 1)
  openxlsx::addStyle(wb, aba, st_link, rows = 3, cols = 1)
  # cabeçalho em duas linhas: indicador e subcoluna (ano ou período)
  for (j in seq_len(ni)) {
    openxlsx::writeData(wb, aba, names(ids)[j], startRow = r_cab, startCol = j)
    openxlsx::mergeCells(wb, aba, cols = j, rows = r_cab:(r_cab + 1))
  }
  col <- ni + 1
  for (b in blocos) {
    k <- ncol(b$m); cs <- col:(col + k - 1)
    if (k == 1) {
      openxlsx::writeData(wb, aba, b$rotulo, startRow = r_cab, startCol = col)
      openxlsx::mergeCells(wb, aba, cols = col, rows = r_cab:(r_cab + 1))
    } else {
      openxlsx::writeData(wb, aba, b$rotulo, startRow = r_cab, startCol = col)
      openxlsx::mergeCells(wb, aba, cols = cs, rows = r_cab)
      openxlsx::writeData(wb, aba, t(colnames(b$m)), startRow = r_cab + 1, startCol = col, colNames = FALSE)
    }
    b$cols <- cs; col <- col + k
  }
  openxlsx::addStyle(wb, aba, st_cab_id, rows = r_cab:(r_cab + 1), cols = 1:ni, gridExpand = TRUE)
  if (nc > ni) openxlsx::addStyle(wb, aba, st_cab, rows = r_cab:(r_cab + 1), cols = (ni + 1):nc, gridExpand = TRUE)
  texto_longo <- max(c(0, nchar(unlist(lapply(blocos, function(b) if (ncol(b$m) > 1) "" else b$rotulo)))))
  openxlsx::setRowHeights(wb, aba, r_cab, if (texto_longo > 14 || any(sapply(blocos, function(b) nchar(b$rotulo) > 11 * ncol(b$m)))) 42 else 22)
  sub_longo <- any(unlist(lapply(blocos, function(b) if (ncol(b$m) > 1) nchar(colnames(b$m)) > 10 else FALSE)))
  openxlsx::setRowHeights(wb, aba, r_cab + 1, if (sub_longo) 30 else 18)
  # corpo
  if (n > 0) {
    linhas <- r0:(r0 + n - 1)
    # códigos da COD como número com quatro dígitos (evita o aviso de número como texto)
    cod <- grep("^Código", names(ids))
    for (j in cod) ids[[j]] <- as.numeric(ids[[j]])
    openxlsx::writeData(wb, aba, ids, startRow = r0, startCol = 1, colNames = FALSE)
    if (length(cod)) openxlsx::addStyle(wb, aba, openxlsx::createStyle(numFmt = "0000", halign = "left"),
                                        rows = linhas, cols = cod, gridExpand = TRUE, stack = TRUE)
    col <- ni + 1
    for (b in blocos) {
      m <- b$m; k <- ncol(m)
      openxlsx::writeData(wb, aba, as.data.frame(m), startRow = r0, startCol = col, colNames = FALSE)
      if (!is.null(b$fmt_col)) {
        for (j in seq_len(k)) openxlsx::addStyle(wb, aba, st_num[[b$fmt_col[j]]], rows = linhas,
                                                 cols = col + j - 1, gridExpand = TRUE, stack = TRUE)
      } else {
        f <- rep_len(b$fmt, n)
        for (ff in unique(f)) openxlsx::addStyle(wb, aba, st_num[[ff]], rows = linhas[f == ff],
                                                 cols = col:(col + k - 1), gridExpand = TRUE, stack = TRUE)
      }
      if (col > ni + 1) openxlsx::addStyle(wb, aba, st_bloco, rows = c(r_cab + 1, linhas), cols = col,
                                           gridExpand = TRUE, stack = TRUE)
      col <- col + k
    }
    openxlsx::addStyle(wb, aba, st_corpo, rows = linhas, cols = 1:nc, gridExpand = TRUE, stack = TRUE)
    openxlsx::addStyle(wb, aba, st_id, rows = linhas, cols = 1:ni, gridExpand = TRUE, stack = TRUE)
    par <- linhas[seq_len(n) %% 2 == 0]
    if (length(par)) openxlsx::addStyle(wb, aba, st_faixa, rows = par, cols = 1:nc, gridExpand = TRUE, stack = TRUE)
    # linha verde quando muda o primeiro identificador (início de um novo grupo)
    if (ni > 1) {
      g <- ids[[1]]; muda <- which(c(FALSE, g[-1] != g[-n]))
      if (length(muda)) openxlsx::addStyle(wb, aba, st_grupo, rows = linhas[muda], cols = 1:nc,
                                           gridExpand = TRUE, stack = TRUE)
    }
  }
  # fonte e notas
  rf <- r0 + n + 1
  for (txt in c(nota_extra, FONTE_TXT)) {
    openxlsx::writeData(wb, aba, txt, startRow = rf, startCol = 1)
    openxlsx::addStyle(wb, aba, st_fonte, rows = rf, cols = 1); rf <- rf + 1
  }
  # larguras e painéis congelados
  openxlsx::setColWidths(wb, aba, cols = 1:nc, widths = larg)
  openxlsx::freezePane(wb, aba, firstActiveRow = r0, firstActiveCol = ni + 1)
  openxlsx::pageSetup(wb, aba, orientation = "landscape", fitToWidth = TRUE, fitToHeight = FALSE)
}

nota_anos <- "Anos em colunas: 4º trimestre de 2012, 2016, 2019 e 2024."
nota_ind  <- paste("O índice de uma ocupação é a parcela das suas atividades classificadas como verdes (ou marrons);",
                   "os valores são médias ponderadas pelos ocupados.")
nota_alta <- sprintf(paste("Alta intensidade: índice da ocupação igual ou acima do 90º percentil dos ocupados em 2024",
                           "(verde: %s; marrom: %s), limiar mantido fixo em todos os anos."),
                     format(LIMIAR_VERDE, decimal.mark = ",", digits = 4),
                     format(LIMIAR_MARROM, decimal.mark = ",", digits = 4))
VARS_PADRAO <- c("OCUPADOS_MIL", "VERDE_MEDIO", "MARROM_MEDIO", "LIQUIDO_MEDIO", "MARGEM_VERDE_PCT",
                 "MARGEM_MARROM_PCT", "PCT_ALTA_VERDE", "PCT_ALTA_MARROM")

# ==============================================================================
# Abas
# ==============================================================================

# 1.1 Brasil -------------------------------------------------------------------
b1 <- lt("b1_nacional")
lin <- list(
  c("Cobertura", "OCUPADOS_TOTAL_MIL", "Ocupados, total (mil)", "mil"),
  c("Cobertura", "OCUPADOS_MIL", "Ocupados com índice (mil)", "mil"),
  c("Cobertura", "COBERTURA_PCT", "Cobertura do índice (% dos ocupados)", "dec1"),
  c("Cobertura", "N_AMOSTRA", "Observações na amostra", "int"),
  c("Cobertura", "RAIS_PESOS", "Ano da RAIS usado nos pesos da ponte", "ano"),
  c("Índice verde", "VERDE_MEDIO", "Índice verde médio", "ind"),
  c("Índice verde", "VERDE_EP", "Erro-padrão do índice verde médio", "ep"),
  c("Índice verde", "VERDE_MEDIANA", "Mediana do índice verde", "ind"),
  c("Índice verde", "VERDE_P90", "90º percentil do índice verde", "ind"),
  c("Índice verde", "MARGEM_VERDE_PCT", "Com alguma atividade verde (%)", "pct"),
  c("Índice verde", "MARGEM_VERDE_EP", "Erro-padrão da parcela com alguma atividade verde (p.p.)", "dec2"),
  c("Índice verde", "PCT_ALTA_VERDE", "Em ocupação de alta intensidade verde (%)", "pct"),
  c("Índice verde", "VERDE_ESPECIFICO_MEDIO", "Índice verde específico médio", "ind"),
  c("Índice marrom", "MARROM_MEDIO", "Índice marrom médio", "ind"),
  c("Índice marrom", "MARROM_EP", "Erro-padrão do índice marrom médio", "ep"),
  c("Índice marrom", "MARROM_P90", "90º percentil do índice marrom", "ind"),
  c("Índice marrom", "MARGEM_MARROM_PCT", "Com alguma atividade marrom (%)", "pct"),
  c("Índice marrom", "PCT_ALTA_MARROM", "Em ocupação de alta intensidade marrom (%)", "pct"),
  c("Índice marrom", "MARROM_ESPECIFICO_MEDIO", "Índice marrom específico médio", "ind"),
  c("Índice líquido", "LIQUIDO_MEDIO", "Índice líquido médio (verde menos marrom)", "ind"))
b1g <- b1[match(ANOS_G, b1$ANO), ]
m <- t(sapply(lin, function(l) b1g[[l[2]]])); colnames(m) <- ANOS_G
escreve("1.1 Brasil", "Tabela 1.1. Indicadores nacionais do índice de esverdeamento ocupacional",
        paste(nota_ind, nota_alta, "O índice específico usa só as atividades exclusivas da ocupação dentro da",
              "sua família da CBO. Erros-padrão calculados com os 200 pesos replicados da PNADc.", nota_anos),
        data.frame(Tema = sapply(lin, `[`, 1), Indicador = sapply(lin, `[`, 3), check.names = FALSE),
        list(list(rotulo = "Ano", m = m, fmt = sapply(lin, `[`, 4))), larg_id = c(16, 58))

# 1.2 Faixas do índice ----------------------------------------------------------
fx <- lt("b1_faixas_indice")
fx <- fx[order(match(fx$INDICE, c("verde", "marrom"))), ]
fx$INDICE <- nome_idx(fx$INDICE)
p <- larga(fx, c("INDICE", "FAIXA_DO_INDICE"), "ANO", ANOS_G)
escreve("1.2 Faixas do índice", "Tabela 1.2. Distribuição dos ocupados por faixa do índice",
        paste("Faixas do índice da ocupação (parcela das atividades que são verdes ou marrons).", nota_anos),
        setNames(p$ids, c("Índice", "Faixa do índice")),
        blocos_larga(p, c("PCT_OCUPADOS", "OCUPADOS_MIL"), c("Participação nos ocupados (%)", "Ocupados (mil)")))

# 1.3 Concentração 2024 ---------------------------------------------------------
cc <- lt("b1_concentracao_2024")
cv <- cc[cc$INDICE == "verde", ]; cm <- cc[cc$INDICE == "marrom", ]
sub4 <- function(x) { m <- as.matrix(x[, c("INDICE_MINIMO", "INDICE_MAXIMO", "INDICE_MEDIO", "PCT_DO_CONTEUDO_TOTAL")])
  colnames(m) <- c("Mínimo", "Máximo", "Médio", "% do conteúdo total"); m }
escreve("1.3 Concentração 2024", "Tabela 1.3. Concentração do conteúdo verde e marrom entre os ocupados, 2024",
        paste("Os ocupados de 2024 são ordenados pelo índice da sua ocupação e divididos em dez grupos de mesmo tamanho",
              "(décimos). A última coluna de cada índice mostra a parcela do conteúdo total que cabe a cada décimo."),
        data.frame(`Décimo de ocupados` = cv$DECIMO_DE_OCUPADOS, check.names = FALSE),
        list(list(rotulo = "Índice verde", m = sub4(cv), fmt_col = c("ind", "ind", "ind", "pct")),
             list(rotulo = "Índice marrom", m = sub4(cm), fmt_col = c("ind", "ind", "ind", "pct"))),
        larg_id = 14)

# 1.4 Principais grupos 2024 ----------------------------------------------------
pg <- lt("b1_principais_grupos_2024")
pg <- pg[order(match(pg$INDICE, c("verde", "marrom"))), ]
escreve("1.4 Principais grupos 2024", "Tabela 1.4. Grupos ocupacionais com maior parcela do conteúdo verde e marrom, 2024",
        paste("Os 25 grupos de base da COD que mais contribuem para o conteúdo verde e para o conteúdo marrom.",
              "Contribuição = ocupados do grupo x índice do grupo, em % do total."),
        data.frame(Índice = nome_idx(pg$INDICE), `Código COD` = pg$COD, `Grupo de base da COD` = pg$TITULO, check.names = FALSE),
        list(col1("Ocupados (mil)", pg$OCUPADOS_MIL, "mil"),
             col1("Participação nos ocupados (%)", pg$PCT_OCUPADOS, "dec2"),
             col1("Índice do grupo", pg$INDICE_DO_GRUPO, "ind"),
             col1("Parcela do conteúdo total (%)", pg$PCT_DO_CONTEUDO_TOTAL, "pct"),
             col1("Parcela acumulada (%)", pg$PCT_ACUMULADO, "pct")),
        larg_id = c(10, 10, 60))

# 2 Perfil ----------------------------------------------------------------------
pf <- lt("b2_perfil")
p <- larga(pf, c("DIMENSAO", "CATEGORIA"), "ANO", ANOS_G)
escreve("2 Perfil", "Tabela 2. Índice e alta intensidade por perfil sociodemográfico",
        paste(nota_ind, nota_alta, "As colunas de distribuição somam 100% dentro de cada dimensão e mostram a",
              "composição dos ocupados de alta intensidade comparada com a do total.", nota_anos),
        setNames(p$ids, c("Dimensão", "Categoria")),
        blocos_larga(p, c(VARS_PADRAO, "COMPOSICAO_ALTA_VERDE_PCT", "COMPOSICAO_ALTA_MARROM_PCT", "COMPOSICAO_TOTAL_PCT")),
        larg_id = c(20, 28))

# 3.1 Qualidade do emprego ------------------------------------------------------
qq <- lt("b3_qualidade")
ORD_FAIXA <- c("0 (nenhuma atividade)", "até 0,01", "0,01 a 0,02", "0,02 a 0,03", "0,03 a 0,05", "0,05 a 0,10", "acima de 0,10")
qq <- qq[order(match(qq$RECORTE, c("Intensidade da ocupação", "Faixa do índice verde", "Faixa do índice marrom")),
               match(qq$GRUPO, c("Alta intensidade verde", "Alta intensidade marrom", "Alta intensidade verde e marrom",
                                 "Demais ocupações", "Total", ORD_FAIXA))), ]
p <- larga(qq, c("RECORTE", "GRUPO"), "ANO", ANOS_G)
escreve("3.1 Qualidade do emprego", "Tabela 3.1. Qualidade do emprego por intensidade e faixa do índice",
        paste("Renda do trabalho principal habitual em reais de julho a setembro de 2025 (deflator do IBGE).",
              "Informalidade pela definição do IBGE: empregados e domésticos sem carteira, conta-própria e",
              "empregadores sem CNPJ e trabalhadores familiares auxiliares.", nota_alta, nota_anos),
        setNames(p$ids, c("Recorte", "Grupo")),
        blocos_larga(p, c("OCUPADOS_MIL", "INFORMALIDADE_PCT", "CONTRIBUI_PREVIDENCIA_PCT", "RENDA_MEDIA",
                          "RENDA_MEDIANA", "HORAS_SEMANAIS_MEDIAS", "RENDA_HORA_MEDIA", "RENDA_HORA_MEDIANA")),
        larg_id = c(24, 32),
        nota_extra = "Informalidade em branco em 2012: a PNADc só pergunta sobre o CNPJ (V4019) a partir de 2015.")

# 3.2 Prêmio salarial -----------------------------------------------------------
pr <- lt("b3_premio_salarial")
pr <- pr[order(match(pr$INDICE, c("verde", "marrom"))), ]
pr$INDICE <- nome_idx(pr$INDICE)
p <- larga(pr, c("INDICE", "ESPECIFICACAO"), "ANO", ANOS_G)
bl <- blocos_larga(p, c("VARIACAO_PCT_POR_PONTO", "COEF", "EP_LM", "R2", "N_AMOSTRA"),
                   c("Variação da renda por hora para 1 ponto a mais no índice (%)", "Coeficiente",
                     "Erro-padrão (MQO)", "R²", "Observações"))
bl[[1]]$fmt <- "dec2"; bl[[2]]$fmt <- "ind"; bl[[3]]$fmt <- "ep"; bl[[4]]$fmt <- "dec3"; bl[[5]]$fmt <- "int"
escreve("3.2 Prêmio salarial", "Tabela 3.2. Diferencial de renda por hora associado ao índice",
        paste("Regressão por mínimos quadrados ponderados do log da renda por hora sobre o índice x 100 (um ponto =",
              "um ponto percentual das atividades). Controles pessoais e regionais: sexo, idade, idade ao quadrado,",
              "cor ou raça, escolaridade, UF e situação do domicílio. A última especificação acrescenta informalidade",
              "e setor. Associação descritiva, sem interpretação causal; o erro-padrão não considera o desenho amostral.",
              nota_anos),
        setNames(p$ids, c("Índice", "Especificação")), bl, larg_id = c(10, 32),
        nota_extra = "Em 2012 a última especificação não inclui informalidade (indisponível antes de 2015).")

# 4.1 Classificação híbrida -----------------------------------------------------
hm <- lt("b4_hibrida_matriz")
hm <- hm[order(match(hm$GRUPO_OCUPACAO, c("Alta intensidade verde", "Alta intensidade marrom",
                                          "Alta intensidade verde e marrom", "Demais ocupações")),
               match(hm$CLASSE_SETOR, c("Verde", "Marrom", "Neutra"))), ]
p <- larga(hm, c("GRUPO_OCUPACAO", "CLASSE_SETOR"), "ANO", ANOS_G)
escreve("4.1 Ocupação x setor", "Tabela 4.1. Classificação híbrida: intensidade da ocupação x classe do setor",
        paste("Cruza a intensidade verde ou marrom da ocupação com a classificação verde, marrom ou neutra do setor",
              "de atividade (CNAE Domiciliar).", nota_alta, nota_anos),
        setNames(p$ids, c("Intensidade da ocupação", "Classe do setor")),
        blocos_larga(p, c("OCUPADOS_MIL", "PCT_OCUPADOS_DO_ANO", "PCT_DENTRO_DA_CLASSE_SETOR"),
                     c("Ocupados (mil)", "% dos ocupados do ano", "% dentro da classe do setor")) |>
          Map(f = function(b, fm) { b$fmt <- fm; b }, fm = c("mil", "pct", "pct")),
        larg_id = c(32, 16))

# 4.2 Classe do setor -----------------------------------------------------------
cs <- lt("b4_por_classe_setor")
cs <- cs[order(match(cs$CLASSE_SETOR, c("Verde", "Marrom", "Neutra"))), ]
p <- larga(cs, "CLASSE_SETOR", "ANO", ANOS_G)
escreve("4.2 Classe do setor", "Tabela 4.2. Índice por classe do setor de atividade",
        paste(nota_ind, nota_alta, nota_anos), setNames(p$ids, "Classe do setor"),
        blocos_larga(p, c("PCT_OCUPADOS", VARS_PADRAO)), larg_id = 16)

# 4.3 Setores CNAE --------------------------------------------------------------
sz <- lt("b4_por_setor")
sz$SETOR_CNAE <- caixa_frase(sz$SETOR_CNAE)
sz <- sz[order(sz$SETOR_CNAE), ]
p <- larga(sz, "SETOR_CNAE", "ANO", ANOS_G)
escreve("4.3 Setores CNAE", "Tabela 4.3. Índice por setor de atividade (divisão da CNAE Domiciliar)",
        paste(nota_ind, nota_alta, "Setores com poucas observações na amostra devem ser lidos com cautela.", nota_anos),
        setNames(p$ids, "Setor de atividade"),
        blocos_larga(p, c("PCT_OCUPADOS", VARS_PADRAO, "N_AMOSTRA")), larg_id = 55)

# 5.1 Território ----------------------------------------------------------------
tr <- lt("b5_territorio")
tr$NIVEL[tr$NIVEL == "Nordeste e demais"] <- "Nordeste e demais regiões"
tr$REGIAO[is.na(tr$REGIAO)] <- ""
tr <- tr[order(match(tr$NIVEL, c("Região", "Nordeste e demais regiões", "UF")), tr$REGIAO, tr$UNIDADE == "Demais regiões", tr$UNIDADE), ]
p <- larga(tr, c("NIVEL", "REGIAO", "UNIDADE"), "ANO", ANOS_G)
escreve("5.1 Regiões e UFs", "Tabela 5.1. Índice por grande região e unidade da federação",
        paste(nota_ind, nota_alta, nota_anos), setNames(p$ids, c("Nível", "Região", "Unidade")),
        blocos_larga(p, c(VARS_PADRAO, "N_AMOSTRA")), larg_id = c(24, 14, 22))

# 5.2 Nordeste urbano e rural ---------------------------------------------------
ne <- lt("b5_nordeste_situacao")
ne <- ne[order(match(ne$RECORTE, c("Nordeste", "Demais regiões")), ne$SITUACAO), ]
p <- larga(ne, c("RECORTE", "SITUACAO"), "ANO", ANOS_G)
escreve("5.2 Nordeste urbano e rural", "Tabela 5.2. Nordeste e demais regiões, por situação do domicílio",
        paste(nota_ind, nota_alta, nota_anos), setNames(p$ids, c("Recorte", "Situação do domicílio")),
        blocos_larga(p, c(VARS_PADRAO, "N_AMOSTRA")), larg_id = c(16, 12))

# 5.3 Principais grupos por região, 2024 ---------------------------------------
gr <- lt("b5_principais_grupos_regiao_2024")
gr <- gr[order(match(gr$RECORTE, c("Brasil", "Nordeste")), match(gr$INDICE, c("verde", "marrom")), gr$POSICAO), ]
escreve("5.3 Grupos Brasil e Nordeste", "Tabela 5.3. Principais grupos ocupacionais no Brasil e no Nordeste, 2024",
        paste("Os 15 grupos de base da COD que mais contribuem para o conteúdo verde e para o conteúdo marrom em cada recorte.",
              "Contribuição = ocupados do grupo x índice do grupo, em % do total do recorte."),
        data.frame(Recorte = gr$RECORTE, Índice = nome_idx(gr$INDICE), Posição = gr$POSICAO,
                   `Código COD` = gr$COD, `Grupo de base da COD` = gr$TITULO, check.names = FALSE),
        list(col1("Ocupados (mil)", gr$OCUPADOS_MIL, "mil"), col1("Índice do grupo", gr$INDICE_DO_GRUPO, "ind"),
             col1("Parcela do conteúdo (%)", gr$PCT_DO_CONTEUDO, "pct")),
        larg_id = c(12, 9, 9, 10, 60))

# 6.1 Transição justa: perfil comparado -----------------------------------------
pc <- lt("b6_perfil_comparado")
grupos <- c("Alta intensidade verde", "Alta intensidade marrom", "Alta intensidade verde e marrom",
            "Demais ocupações", "Total")
vars6 <- c("OCUPADOS_MIL", "N_AMOSTRA", "MULHER_PCT", "PPI_PCT", "IDADE", "JOVEM_PCT", "IDOSO_PCT",
           "FUND_INC_PCT", "SUPERIOR_PCT", "INFORMAL_PCT", "CONTRIBUI_PCT", "RENDA_REAL", "HORAS",
           "RURAL_PCT", "NORDESTE_PCT", "SETOR_MARROM_PCT", "VERDE_ANO", "MARROM_ANO")
bl <- lapply(grupos, function(g) {
  x <- pc[pc$GRUPO == g, ]; x <- x[match(ANOS_G, x$ANO), ]
  m <- t(sapply(vars6, function(v) x[[v]])); colnames(m) <- ANOS_G
  list(rotulo = g, m = m, fmt = sapply(vars6, fmt_de))
})
escreve("6.1 Transição justa", "Tabela 6.1. Perfil dos ocupados por intensidade verde e marrom da ocupação",
        paste("Compara quem está em ocupações de alta intensidade marrom (mais expostas à transição) com quem está em",
              "ocupações de alta intensidade verde e com o total.", nota_alta,
              "Renda em reais de julho a setembro de 2025.", nota_anos),
        data.frame(Indicador = sapply(vars6, rot), check.names = FALSE), bl, larg_id = 40,
        nota_extra = "Informais em branco em 2012: a PNADc só pergunta sobre o CNPJ (V4019) a partir de 2015.")

# 6.2 Grupos marrons, 2024 ------------------------------------------------------
gm <- lt("b6_grupos_marrons_2024")
escreve("6.2 Grupos marrons 2024", "Tabela 6.2. Perfil dos maiores grupos ocupacionais de alta intensidade marrom, 2024",
        "Grupos de base da COD de alta intensidade marrom com mais ocupados em 2024. Renda em reais de julho a setembro de 2025.",
        data.frame(`Código COD` = gm$COD, `Grupo de base da COD` = gm$TITULO, check.names = FALSE),
        lapply(vars6, function(v) col1(rot(v), gm[[v]], fmt_de(v))), larg_id = c(10, 50))

# 7.1 Evolução ------------------------------------------------------------------
ev <- lt("b7_serie"); evg <- ev[match(ANOS_G, ev$ANO), ]
lin <- list(c("OCUPADOS_MIL", "Ocupados com índice (mil)", "mil"),
            c("VERDE_MEDIO", "Índice verde médio", "ind"), c("MARROM_MEDIO", "Índice marrom médio", "ind"),
            c("LIQUIDO_MEDIO", "Índice líquido médio (verde menos marrom)", "ind"),
            c("MARGEM_VERDE_PCT", "Com alguma atividade verde (%)", "pct"),
            c("MARGEM_MARROM_PCT", "Com alguma atividade marrom (%)", "pct"),
            c("PCT_ALTA_VERDE", "Em ocupação de alta intensidade verde (%)", "pct"),
            c("PCT_ALTA_MARROM", "Em ocupação de alta intensidade marrom (%)", "pct"),
            c("OCUPADOS_ALTA_VERDE_MIL", "Ocupados de alta intensidade verde (mil)", "mil"),
            c("OCUPADOS_ALTA_MARROM_MIL", "Ocupados de alta intensidade marrom (mil)", "mil"),
            c("VERDE_PESOS_DO_ANO", "Para comparação: índice verde médio com os pesos da RAIS do ano", "ind"),
            c("MARROM_PESOS_DO_ANO", "Para comparação: índice marrom médio com os pesos da RAIS do ano", "ind"))
m <- t(sapply(lin, function(l) evg[[l[1]]])); colnames(m) <- ANOS_G
escreve("7.1 Evolução", "Tabela 7.1. Evolução dos indicadores com o índice de pesos fixos",
        paste("Para isolar a mudança na estrutura do emprego, o índice de cada grupo da COD é calculado com os pesos",
              "da RAIS 2024 em todos os anos. As duas últimas linhas usam os pesos da RAIS mais próxima de cada ano.",
              nota_alta, nota_anos),
        data.frame(Indicador = sapply(lin, `[`, 2), check.names = FALSE),
        list(list(rotulo = "Ano", m = m, fmt = sapply(lin, `[`, 3))), larg_id = 62)

# 7.2 Decomposição da variação --------------------------------------------------
ss <- lt("b7_shift_share_setor")
comp <- c("Índice inicial", "Índice final", "Variação total", "Entre (participação dos setores)",
          "Dentro (composição ocupacional)")
rot_comp <- c("Índice no início do período", "Índice no fim do período", "Variação total",
              "Efeito entre setores (mudança no peso dos setores)",
              "Efeito dentro dos setores (mudança na composição ocupacional)")
tot <- ss[ss$GRUPO == "Total", ]
lin <- do.call(rbind, lapply(c("verde", "marrom"), function(ind) {
  v <- sapply(PER_G, function(pp) sapply(comp, function(cp)
    1e4 * tot$VALOR[tot$INDICE == ind & tot$PERIODO == pp & tot$COMPONENTE == cp]))
  ent <- ifelse(abs(v[3, ]) >= 1, 100 * v[4, ] / v[3, ], NA)  # parcela sem leitura útil quando a variação é quase nula
  data.frame(Índice = nome_idx(ind), Componente = c(rot_comp, "Parcela do efeito entre setores na variação (%)"),
             rbind(v, ent), check.names = FALSE, row.names = NULL)
}))
m <- as.matrix(lin[, PER_G]); colnames(m) <- PER_G
escreve("7.2 Decomposição", "Tabela 7.2. Decomposição da variação do índice médio por setor (shift-share)",
        paste("Variação do índice médio (pesos fixos da RAIS 2024) dividida em efeito entre setores (mudança na participação",
              "dos setores no emprego) e efeito dentro dos setores (mudança na composição ocupacional de cada setor).",
              "Forma simétrica, sem resíduo. Valores do índice multiplicados por 10.000."),
        lin[, c("Índice", "Componente")],
        list(list(rotulo = "Período", m = m, fmt = rep(c(rep("x1e4", 5), "pct"), 2))), larg_id = c(10, 58),
        nota_extra = "Parcela do efeito entre setores em branco quando a variação total é menor que 1 (x 10.000): nesse caso a razão não tem leitura útil.")

# 7.3 Decomposição por setor ----------------------------------------------------
sp <- ss[ss$GRUPO != "Total" & ss$PERIODO %in% PER_G, ]
sp$SETOR <- caixa_frase(sp$GRUPO)
setores <- sort(unique(sp$SETOR))
bl <- unlist(lapply(c("verde", "marrom"), function(ind) lapply(c("Entre", "Dentro"), function(cp) {
  m <- sapply(PER_G, function(pp) { x <- sp[sp$INDICE == ind & sp$COMPONENTE == cp & sp$PERIODO == pp, ]
    1e4 * x$VALOR[match(setores, x$SETOR)] })
  m <- matrix(m, ncol = length(PER_G)); colnames(m) <- PER_G
  list(rotulo = paste0(nome_idx(ind), ": efeito ", tolower(cp), if (cp == "Entre") " setores" else " do setor"),
       m = m, fmt = "x1e4")
})), recursive = FALSE)
escreve("7.3 Decomposição por setor", "Tabela 7.3. Contribuição de cada setor para a variação do índice médio",
        paste("Parcela de cada setor nos efeitos entre e dentro da Tabela 7.2 (a soma das linhas dá o total da Tabela 7.2).",
              "Valores do índice multiplicados por 10.000; negativos reduzem o índice."),
        data.frame(`Setor de atividade` = setores, check.names = FALSE), bl, larg_id = 55)

# 7.4 Grandes grupos ------------------------------------------------------------
cg <- lt("b7_contribuicao_grandes_grupos")
gg <- unname(GRANDES_GRUPOS[order(names(GRANDES_GRUPOS))])
gg <- gg[gg %in% cg$GRANDE_GRUPO]
pick <- function(ind, pp, v) { x <- cg[cg$INDICE == ind & cg$PERIODO == pp, ]; x[[v]][match(gg, x$GRANDE_GRUPO)] }
part <- cbind(pick("verde", "2012-2016", "PCT_OCUPADOS_INICIAL"), pick("verde", "2016-2019", "PCT_OCUPADOS_INICIAL"),
              pick("verde", "2019-2024", "PCT_OCUPADOS_INICIAL"), pick("verde", "2012-2024", "PCT_OCUPADOS_FINAL"))
colnames(part) <- ANOS_G
bl <- list(list(rotulo = "Participação nos ocupados (%)", m = part, fmt = "pct"))
for (ind in c("verde", "marrom")) {
  c1 <- sapply(PER_G, function(pp) 1e4 * pick(ind, pp, "CONTRIBUICAO")); colnames(c1) <- PER_G
  c2 <- sapply(PER_G, function(pp) pick(ind, pp, "PCT_DA_VARIACAO")); colnames(c2) <- PER_G
  c2[, abs(colSums(c1)) < 1] <- NA  # parcela sem leitura útil quando a variação é quase nula
  bl <- c(bl, list(list(rotulo = paste("Contribuição para a variação do índice", ind, "(x 10.000)"), m = c1, fmt = "x1e4"),
                   list(rotulo = paste("Parcela da variação do índice", ind, "(%)"), m = c2, fmt = "pct")))
}
escreve("7.4 Grandes grupos", "Tabela 7.4. Contribuição dos grandes grupos ocupacionais para a variação do índice",
        paste("Com o índice de pesos fixos, a variação do índice médio é a soma, por grupo de base da COD, da mudança na",
              "participação do grupo multiplicada pelo seu índice. Aqui os grupos de base são somados por grande grupo da COD.",
              "Valores do índice multiplicados por 10.000."),
        data.frame(`Grande grupo da COD` = gg, check.names = FALSE), bl, larg_id = 52,
        nota_extra = "Parcela da variação em branco quando a variação total é menor que 1 (x 10.000): nesse caso a razão não tem leitura útil.")

# 8.1 Décimos de renda ----------------------------------------------------------
de <- lt("b8_decimos_renda")
p <- larga(de, "DECIMO_RENDA", "ANO", ANOS_G)
escreve("8.1 Décimos de renda", "Tabela 8.1. Índice por décimo da renda do trabalho principal",
        paste("Décimos da renda habitual do trabalho principal entre os ocupados com renda positiva (1 = 10% mais pobres).",
              "Renda em reais de julho a setembro de 2025.", nota_ind, nota_alta, nota_anos),
        setNames(p$ids, "Décimo de renda"),
        blocos_larga(p, c("RENDA_MEDIA", VARS_PADRAO)), larg_id = 12)

# 8.2 Concentração na renda -----------------------------------------------------
co <- lt("b8_concentracao"); cog <- co[match(ANOS_G, co$ANO), ]
lin <- list(c("CONCENTRACAO_VERDE", "Índice verde"), c("CONCENTRACAO_MARROM", "Índice marrom"),
            c("CONCENTRACAO_ALTA_VERDE", "Alta intensidade verde"), c("CONCENTRACAO_ALTA_MARROM", "Alta intensidade marrom"))
m <- t(sapply(lin, function(l) cog[[l[1]]])); colnames(m) <- ANOS_G
escreve("8.2 Concentração na renda", "Tabela 8.2. Índice de concentração ao longo da distribuição de renda",
        paste("Varia de -1 a 1. Valores negativos indicam que o conteúdo verde (ou marrom) está mais presente entre os",
              "trabalhadores de menor renda; positivos, entre os de maior renda.", nota_anos),
        data.frame(Indicador = sapply(lin, `[`, 2), check.names = FALSE),
        list(list(rotulo = "Ano", m = m, fmt = "dec3")), larg_id = 30)

# ==============================================================================
# Aba Leia-me (primeira aba)
# ==============================================================================
openxlsx::addWorksheet(wb, "Leia-me", gridLines = FALSE)
openxlsx::worksheetOrder(wb) <- c(length(names(wb)), seq_len(length(names(wb)) - 1))
st_secao <- openxlsx::createStyle(fontSize = 11, textDecoration = "bold", fontColour = COR_CAB,
                                  border = "bottom", borderColour = COR_CAB)
st_texto <- openxlsx::createStyle(fontSize = 10, wrapText = TRUE, valign = "top")
st_termo <- openxlsx::createStyle(fontSize = 10, textDecoration = "bold", valign = "top", wrapText = TRUE)
r <- 1
put <- function(txt, st, col = 1, merge = TRUE, altura = NULL) {
  openxlsx::writeData(wb, "Leia-me", txt, startRow = r, startCol = col)
  if (merge && col == 1) openxlsx::mergeCells(wb, "Leia-me", cols = 1:2, rows = r)
  openxlsx::addStyle(wb, "Leia-me", st, rows = r, cols = col)
  if (!is.null(altura)) openxlsx::setRowHeights(wb, "Leia-me", r, altura)
}
put("Estatísticas descritivas do índice de esverdeamento ocupacional com a PNAD Contínua", st_titulo); r <- r + 1
put(paste0("Versão preliminar para o grupo de pesquisa, gerada em ", format(Sys.Date(), "%d/%m/%Y"), "."), st_nota); r <- r + 2
put("Sobre esta planilha", st_secao); r <- r + 1
txt <- c(
  paste("O índice mede, para cada ocupação, a parcela das suas atividades descritas na CBO 2002 que é verde ou marrom.",
        "Ele é levado aos grupos da COD da PNAD Contínua por uma ponte CBO-COD ponderada pelos vínculos da RAIS e",
        "aplicado aos ocupados do 4º trimestre de cada ano."),
  paste("Esta versão mostra apenas 2012, 2016, 2019 e 2024, com os anos em colunas. A série anual completa (2012 a 2024)",
        "está nos arquivos CSV em metodologia/saida/estatisticas e na nota de resultados em Word."),
  paste("RESSALVA IMPORTANTE: os rótulos das atividades são preliminares, anteriores à classificação humana em curso.",
        "Cerca de metade das atividades classificadas como verdes trata de lixo, resíduos ou reciclagem, o que puxa o",
        "conteúdo verde para ocupações de baixa qualificação. Os resultados devem ser lidos como provisórios."))
for (x in txt) { put(x, st_texto, altura = 15 * ceiling(nchar(x) / 120)); r <- r + 1 }
r <- r + 1
put("Sumário", st_secao); r <- r + 1
for (s in SUMARIO) {
  openxlsx::writeFormula(wb, "Leia-me", openxlsx::makeHyperlinkString(sheet = s[1], row = 1, col = 1, text = s[1]),
                         startRow = r, startCol = 1)
  openxlsx::addStyle(wb, "Leia-me", st_link, rows = r, cols = 1)
  openxlsx::writeData(wb, "Leia-me", sub("^Tabela [0-9.]+\\. ", "", s[2]), startRow = r, startCol = 2)
  openxlsx::addStyle(wb, "Leia-me", st_texto, rows = r, cols = 2)
  r <- r + 1
}
r <- r + 1
put("Conceitos", st_secao); r <- r + 1
conc <- list(
  c("Índice verde (marrom)", "Parcela das atividades da ocupação classificadas como verdes (marrons). Varia de 0 a 1. Nas tabelas, é a média ponderada pelos ocupados."),
  c("Índice líquido", "Índice verde menos índice marrom."),
  c("Com alguma atividade verde (marrom)", "Parcela dos ocupados cuja ocupação tem pelo menos uma atividade verde (marrom): a margem extensiva."),
  c("Alta intensidade", sub("^Alta intensidade: í", "Í", nota_alta)),
  c("Índice específico", "Mesmo cálculo usando só as atividades exclusivas da ocupação dentro da sua família da CBO."),
  c("Pesos fixos", "Índice de cada grupo da COD calculado com os pesos da RAIS 2024 em todos os anos (usado nas tabelas 7.x)."),
  c("Classe do setor", "Classificação verde, marrom ou neutra da atividade econômica (CNAE Domiciliar) adotada no projeto."),
  c("Renda", "Renda habitual do trabalho principal (VD4016), em reais de julho a setembro de 2025, pelo deflator do IBGE."),
  c("Informalidade", "Definição do IBGE. Disponível a partir de 2015 (depende da pergunta sobre CNPJ, V4019)."),
  c("Peso amostral", "V1028. Erros-padrão das médias nacionais calculados com os 200 pesos replicados."),
  c("Grupos da COD", "Denominações oficiais da Classificação de Ocupações para Pesquisas Domiciliares (IBGE)."))
for (x in conc) {
  openxlsx::writeData(wb, "Leia-me", x[1], startRow = r, startCol = 1)
  openxlsx::addStyle(wb, "Leia-me", st_termo, rows = r, cols = 1)
  openxlsx::writeData(wb, "Leia-me", x[2], startRow = r, startCol = 2)
  openxlsx::addStyle(wb, "Leia-me", st_texto, rows = r, cols = 2)
  openxlsx::setRowHeights(wb, "Leia-me", r, 14 * ceiling(nchar(x[2]) / 95))
  r <- r + 1
}
r <- r + 1
put(FONTE_TXT, st_fonte)
openxlsx::setColWidths(wb, "Leia-me", cols = 1:2, widths = c(34, 100))
openxlsx::activeSheet(wb) <- 1

openxlsx::saveWorkbook(wb, ARQ_GRUPO, overwrite = TRUE)
cat("planilha do grupo gravada em", ARQ_GRUPO, "com", length(SUMARIO), "tabelas\n")
