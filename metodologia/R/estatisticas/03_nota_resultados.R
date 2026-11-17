# ==============================================================================
# ESTATÍSTICAS DESCRITIVAS COM A PNADc - 03. NOTA DE RESULTADOS (WORD)
# ==============================================================================
# Gera metodologia/Estatisticas_descritivas_indice_PNADc.docx com as tabelas
# principais de cada bloco. Todos os números vêm das tabelas da etapa 02.
# Formato: Times New Roman 12, A4, margens ABNT, títulos em negrito.
# ==============================================================================

etapa("Estatísticas 03. Nota de resultados")
for (p in c("officer", "flextable")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "https://cloud.r-project.org")
}
library(officer)

FONTE <- "Times New Roman"
fmt <- function(x, d = 0) formatC(as.numeric(x), format = "f", digits = d, big.mark = ".", decimal.mark = ",")
pct <- function(x, d = 1) paste0(fmt(x, d), "%")
f3  <- function(x) fmt(x, 4)

# ------------------------------------------------------------------------------
# Números
# ------------------------------------------------------------------------------
n1   <- TAB$b1_nacional
n1f  <- n1[n1$ANO == ANO_FOCO, ]; n1i <- n1[n1$ANO == min(ANOS_PNADC), ]
conc <- TAB$b1_concentracao_2024
top_v <- TAB$b1_principais_grupos_2024[TAB$b1_principais_grupos_2024$INDICE == "verde", ]
top_m <- TAB$b1_principais_grupos_2024[TAB$b1_principais_grupos_2024$INDICE == "marrom", ]
pf   <- TAB$b2_perfil[TAB$b2_perfil$ANO == as.character(ANO_FOCO), ]
qf   <- TAB$b3_qualidade[TAB$b3_qualidade$ANO == ANO_FOCO & TAB$b3_qualidade$RECORTE == "Intensidade da ocupação", ]
prf  <- TAB$b3_premio_salarial[TAB$b3_premio_salarial$ANO == ANO_FOCO, ]
hm   <- TAB$b4_hibrida_matriz[TAB$b4_hibrida_matriz$ANO == as.character(ANO_FOCO), ]
tr   <- TAB$b5_territorio[TAB$b5_territorio$ANO == as.character(ANO_FOCO), ]
tj   <- TAB$b6_perfil_comparado[TAB$b6_perfil_comparado$ANO == as.character(ANO_FOCO), ]
ev   <- TAB$b7_serie
ss   <- TAB$b7_shift_share_setor
de   <- TAB$b8_decimos_renda[TAB$b8_decimos_renda$ANO == as.character(ANO_FOCO), ]
cc   <- TAB$b8_concentracao

# parcela das atividades verdes sobre lixo, resíduos e reciclagem (rótulos atuais)
atv <- ler_csv(file.path(CAMINHOS$saida, "atividades_por_ocupacao.csv"))
atv_v <- atv[atv$Classe == "VERDE", ]
pct_residuos <- 100 * mean(grepl("lixo|res[ií]duo|entulho|recicl|coleta seletiva|reutiliz|sucata",
                                 atv_v$Atividade, ignore.case = TRUE))

g <- function(df, grupo, col) df[[col]][df$GRUPO == grupo]
ss_tot <- function(ind, per, comp) ss$VALOR[ss$INDICE == ind & ss$PERIODO == per & ss$GRUPO == "Total" & ss$COMPONENTE == comp]

# ------------------------------------------------------------------------------
# Auxiliares de formatação (mesmo padrão da nota da ponte)
# ------------------------------------------------------------------------------
tx  <- fp_text(font.family = FONTE, font.size = 12)
txb <- fp_text(font.family = FONTE, font.size = 12, bold = TRUE)
par_corpo  <- fp_par(text.align = "justify", line_spacing = 1.5, padding.bottom = 6)
par_titulo <- fp_par(text.align = "center", line_spacing = 1.5, padding.bottom = 12)
par_secao  <- fp_par(text.align = "left", line_spacing = 1.5, padding.top = 12, padding.bottom = 6,
                     keep_with_next = TRUE)
doc <- read_docx()
doc <- docx_set_paragraph_style(doc, style_id = "Normal", style_name = "Normal",
                                fp_p = par_corpo, fp_t = fp_text_lite(font.family = FONTE, font.size = 12))
p_ <- function(...) { doc <<- body_add_fpar(doc, fpar(ftext(paste0(...), tx), fp_p = par_corpo)) }
h_ <- function(t)   { doc <<- body_add_fpar(doc, fpar(ftext(t, txb), fp_p = par_secao)) }
fonte_tab <- function(t = "Fonte: PNAD Contínua (IBGE), 4º trimestre; índice preliminar de esverdeamento ocupacional. Elaboração própria.") {
  doc <<- body_add_fpar(doc, fpar(ftext(t, fp_text(font.family = FONTE, font.size = 10)),
                                  fp_p = fp_par(text.align = "left", padding.bottom = 10)))
}
tab_ <- function(df, titulo, larguras) {
  doc <<- body_add_fpar(doc, fpar(ftext(titulo, txb),
                                  fp_p = fp_par(text.align = "left", padding.top = 6, keep_with_next = TRUE)))
  ft <- flextable::flextable(df)
  ft <- flextable::font(ft, fontname = FONTE, part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::border_remove(ft)
  b <- officer::fp_border(width = 0.75)
  ft <- flextable::hline_top(ft, border = b, part = "header")
  ft <- flextable::hline_bottom(ft, border = b, part = "header")
  ft <- flextable::hline_bottom(ft, border = b, part = "body")
  ft <- flextable::width(ft, width = larguras)
  ft <- flextable::align(ft, j = 1, align = "left", part = "all")
  ft <- flextable::align(ft, j = seq_len(ncol(df))[-1], align = "right", part = "all")
  doc <<- flextable::body_add_flextable(doc, ft, align = "left")
  fonte_tab()
}
GRUPOS <- c("Alta intensidade verde", "Alta intensidade marrom", "Alta intensidade verde e marrom",
            "Demais ocupações", "Total")

# ------------------------------------------------------------------------------
# Texto
# ------------------------------------------------------------------------------
doc <- body_add_fpar(doc, fpar(ftext("ESTATÍSTICAS DESCRITIVAS DO ÍNDICE DE ESVERDEAMENTO OCUPACIONAL NA PNAD CONTÍNUA", txb),
                               fp_p = par_titulo))
doc <- body_add_fpar(doc, fpar(ftext("Resultados preliminares, anteriores à classificação humana das atividades", tx),
                               fp_p = par_titulo))

h_("1. OBJETIVO E ADVERTÊNCIA")
p_("Esta nota reúne as primeiras estatísticas descritivas da medida contínua de esverdeamento ocupacional ",
   "aplicada aos ocupados da PNAD Contínua, no 4º trimestre de cada ano entre ", min(ANOS_PNADC), " e ", ANO_FOCO, ". ",
   "O índice de cada ocupação é a parcela das suas atividades classificadas como verdes (ou marrons) na CBO 2002, ",
   "levado aos grupos da COD pela ponte descrita na nota metodológica própria.")
p_("Os resultados são preliminares. Os rótulos das atividades ainda são os da rodada de setembro de 2026 e serão ",
   "substituídos pela classificação humana da equipe. Um ponto pesa sobre a leitura de tudo o que segue: ",
   pct(pct_residuos), " das atividades hoje rotuladas como verdes tratam de lixo, resíduos, entulho ou reciclagem. ",
   "Por isso ocupações como serventes de obras, faxineiros e trabalhadores domésticos aparecem com conteúdo verde ",
   "relevante. A revisão humana deve decidir, à luz da rubrica, quais dessas tarefas têm de fato propósito ambiental. ",
   "Os perfis de escolaridade, renda e informalidade descritos abaixo dependem muito dessa decisão.")

h_("2. DADOS E DEFINIÇÕES")
p_("População: ocupados cujo grupo da COD recebeu índice, ", pct(n1f$COBERTURA_PCT), " dos ocupados em ", ANO_FOCO,
   " e no mínimo ", pct(min(n1$COBERTURA_PCT)), " em todos os anos. Todas as estimativas usam o peso amostral V1028. ",
   "Os erros-padrão das médias nacionais usam os 200 pesos replicados da pesquisa.")
p_("Índice médio: média ponderada do índice entre os ocupados. Margem extensiva: parcela dos ocupados em ",
   "ocupações com pelo menos uma atividade verde (ou marrom). Alta intensidade: ocupações cujo índice está no ",
   "decil superior da distribuição dos ocupados em ", ANO_FOCO, ", o que corresponde a índice verde de pelo menos ",
   f3(LIMIAR_VERDE), " e índice marrom de pelo menos ", f3(LIMIAR_MARROM), ". Os limiares ficam fixos em todos os anos. ",
   "Índice líquido: verde menos marrom.")
p_("Renda: rendimento habitual do trabalho principal, deflacionado pelo deflator do IBGE para reais do 3º trimestre de 2025. ",
   "Informalidade: definição do IBGE (empregados sem carteira no setor privado e no trabalho doméstico, conta-própria e ",
   "empregadores sem CNPJ, trabalhadores familiares auxiliares). Como o CNPJ só é perguntado desde o fim de 2015, a ",
   "informalidade não é calculada para 2012 a 2014. Setor verde, neutro ou marrom: classificação das CNAE usada no projeto.")

h_("3. CONTEÚDO VERDE MÉDIO, MARGEM EXTENSIVA E DISTRIBUIÇÃO")
p_("Em ", ANO_FOCO, ", o índice verde médio dos ocupados foi de ", f3(n1f$VERDE_MEDIO), " (erro-padrão de ",
   fmt(n1f$VERDE_EP, 5), "): em média, cerca de ", fmt(100 * n1f$VERDE_MEDIO, 1), "% das atividades da ocupação de um ",
   "trabalhador são verdes. O índice marrom médio foi de ", f3(n1f$MARROM_MEDIO), ". A margem extensiva é ampla: ",
   pct(n1f$MARGEM_VERDE_PCT), " dos ocupados estão em ocupações com alguma atividade verde, e ",
   pct(n1f$MARGEM_MARROM_PCT), " em ocupações com alguma atividade marrom. O conteúdo é concentrado: o décimo ",
   "de ocupados com maior índice verde reúne ", pct(conc$PCT_DO_CONTEUDO_TOTAL[conc$INDICE == "verde" & conc$DECIMO_DE_OCUPADOS == 10]),
   " de todo o conteúdo verde, e o décimo mais marrom, ",
   pct(conc$PCT_DO_CONTEUDO_TOTAL[conc$INDICE == "marrom" & conc$DECIMO_DE_OCUPADOS == 10]), " do conteúdo marrom.")
t1 <- n1[n1$ANO %in% c(2012, 2016, 2019, 2024), ]
tab_(data.frame(Indicador = c("Ocupados com índice (milhões)", "Índice verde médio", "Erro-padrão",
                              "Margem extensiva verde (%)", "Alta intensidade verde (%)",
                              "Índice marrom médio", "Margem extensiva marrom (%)", "Alta intensidade marrom (%)",
                              "Índice líquido médio"),
                sapply(seq_len(nrow(t1)), function(i) with(t1[i, ], c(
                  fmt(OCUPADOS_TOTAL_MIL * COBERTURA_PCT / 1e5, 1), f3(VERDE_MEDIO), fmt(VERDE_EP, 5),
                  fmt(MARGEM_VERDE_PCT, 1), fmt(PCT_ALTA_VERDE, 1), f3(MARROM_MEDIO), fmt(MARGEM_MARROM_PCT, 1),
                  fmt(PCT_ALTA_MARROM, 1), f3(LIQUIDO_MEDIO)))) |> `colnames<-`(t1$ANO), check.names = FALSE),
     "Tabela 1. Indicadores nacionais, anos selecionados", c(2.6, rep(0.85, 4)))
p_("Os grupos da COD que mais contribuem para o conteúdo verde total em ", ANO_FOCO, " são: ",
   paste0(top_v$TITULO[1:5], " (", pct(top_v$PCT_DO_CONTEUDO_TOTAL[1:5]), ")", collapse = "; "),
   ". Juntos, os dez primeiros somam ", pct(top_v$PCT_ACUMULADO[10]), ". No marrom, a concentração é maior: ",
   paste0(top_m$TITULO[1:3], " (", pct(top_m$PCT_DO_CONTEUDO_TOTAL[1:3]), ")", collapse = "; "),
   " somam ", pct(top_m$PCT_ACUMULADO[3]), ". Os títulos dos grupos estão na língua da classificação da OIT.")

h_("4. PERFIL SOCIODEMOGRÁFICO")
pv <- function(dim, cat, col) pf[[col]][pf$DIMENSAO == dim & pf$CATEGORIA == cat]
p_("O índice verde médio é maior entre homens (", f3(pv("Sexo", "Homem", "VERDE_MEDIO")), ") do que entre mulheres (",
   f3(pv("Sexo", "Mulher", "VERDE_MEDIO")), "), entre pretos, pardos e indígenas (",
   f3(pv("Cor ou raça", "Pretos, pardos e indígenas", "VERDE_MEDIO")), ") do que entre brancos e amarelos (",
   f3(pv("Cor ou raça", "Brancos e amarelos", "VERDE_MEDIO")), "), no meio rural e entre os menos escolarizados. ",
   "O gradiente educacional é invertido em relação ao que a literatura internacional costuma encontrar: o índice ",
   "verde médio cai de ", f3(pv("Escolaridade", "Até fundamental incompleto", "VERDE_MEDIO")),
   " entre quem não completou o fundamental para ", f3(pv("Escolaridade", "Superior completo", "VERDE_MEDIO")),
   " entre os graduados. Esse resultado decorre em boa parte do peso das atividades ligadas a resíduos, ",
   "discutido na seção 1. O conteúdo marrom é ainda mais masculino: homens são ",
   pct(pv("Sexo", "Homem", "COMPOSICAO_ALTA_MARROM_PCT")), " dos ocupados de alta intensidade marrom, contados também os que têm alta intensidade verde.")
dims <- c("Sexo", "Cor ou raça", "Idade", "Escolaridade", "Situação do domicílio")
t2 <- pf[pf$DIMENSAO %in% dims, ]
t2 <- t2[order(match(t2$DIMENSAO, dims)), ]
tab_(data.frame(Categoria = t2$CATEGORIA, `Ocupados (%)` = fmt(t2$COMPOSICAO_TOTAL_PCT, 1),
                `Índice verde` = f3(t2$VERDE_MEDIO), `Índice marrom` = f3(t2$MARROM_MEDIO),
                `Alta verde (%)` = fmt(t2$PCT_ALTA_VERDE, 1), `Alta marrom (%)` = fmt(t2$PCT_ALTA_MARROM, 1),
                check.names = FALSE),
     paste0("Tabela 2. Índice médio e alta intensidade por perfil, ", ANO_FOCO), c(2.2, rep(0.85, 5)))

h_("5. QUALIDADE DO EMPREGO")
p_("Os ocupados de alta intensidade verde têm informalidade de ", pct(g(qf, "Alta intensidade verde", "INFORMALIDADE_PCT")),
   ", abaixo da média nacional (", pct(g(qf, "Total", "INFORMALIDADE_PCT")), "), mas renda média de R$ ",
   fmt(g(qf, "Alta intensidade verde", "RENDA_MEDIA")), ", menor que a média (R$ ", fmt(g(qf, "Total", "RENDA_MEDIA")),
   "). Os de alta intensidade marrom são muito mais informais (", pct(g(qf, "Alta intensidade marrom", "INFORMALIDADE_PCT")),
   "). O grupo que combina alta intensidade verde e marrom, formado sobretudo por serventes de obras, trabalhadores braçais da agricultura e pintores, ",
   "é o mais precário: informalidade de ", pct(g(qf, "Alta intensidade verde e marrom", "INFORMALIDADE_PCT")),
   " e renda média de R$ ", fmt(g(qf, "Alta intensidade verde e marrom", "RENDA_MEDIA")), ".")
tab_(data.frame(Grupo = GRUPOS,
                `Ocupados (mil)` = fmt(sapply(GRUPOS, g, df = qf, col = "OCUPADOS_MIL")),
                `Informalidade (%)` = fmt(sapply(GRUPOS, g, df = qf, col = "INFORMALIDADE_PCT"), 1),
                `Renda média (R$)` = fmt(sapply(GRUPOS, g, df = qf, col = "RENDA_MEDIA")),
                `Renda mediana (R$)` = fmt(sapply(GRUPOS, g, df = qf, col = "RENDA_MEDIANA")),
                `Horas semanais` = fmt(sapply(GRUPOS, g, df = qf, col = "HORAS_SEMANAIS_MEDIAS"), 1),
                `Renda por hora (R$)` = fmt(sapply(GRUPOS, g, df = qf, col = "RENDA_HORA_MEDIA"), 2),
                check.names = FALSE),
     paste0("Tabela 3. Qualidade do emprego por intensidade da ocupação, ", ANO_FOCO), c(2.0, rep(0.75, 6)))
pr <- function(ind, esp) prf$VARIACAO_PCT_POR_PONTO[prf$INDICE == ind & prf$ESPECIFICACAO == esp]
p_("Prêmio salarial descritivo. Em uma regressão do logaritmo da renda por hora contra o índice, cada ponto ",
   "percentual a mais de atividades verdes na ocupação está associado a uma renda por hora ", fmt(abs(pr("verde", "Bruto")), 1),
   "% menor, sem controles. Com controles de sexo, idade, cor, escolaridade, UF e situação do domicílio, a diferença ",
   "cai para ", fmt(abs(pr("verde", "Controles pessoais e regionais")), 1), "%, e para ",
   fmt(abs(pr("verde", "Mais informalidade e setor")), 1), "% quando se acrescentam informalidade e setor. ",
   "É uma associação, não um efeito causal, e o sinal negativo reflete de novo a composição atual do conteúdo verde.")

h_("6. CLASSIFICAÇÃO HÍBRIDA: OCUPAÇÃO E SETOR")
hv <- function(go, cs) hm$OCUPADOS_MIL[hm$GRUPO_OCUPACAO == go & hm$CLASSE_SETOR == cs]
tot_av <- sum(hm$OCUPADOS_MIL[hm$GRUPO_OCUPACAO == "Alta intensidade verde"])
p_("Cruzar a ocupação com o setor mostra que o emprego verde pela ótica da ocupação e pela ótica do setor ",
   "se sobrepõem pouco. Dos ", fmt(tot_av), " mil ocupados de alta intensidade verde em ", ANO_FOCO, ", apenas ",
   pct(100 * hv("Alta intensidade verde", "Verde") / tot_av), " trabalham em setores classificados como verdes, e ",
   pct(100 * hv("Alta intensidade verde", "Marrom") / tot_av), " estão em setores marrons. Inversamente, a maior parte ",
   "dos ocupados em setores verdes está em ocupações sem alta intensidade verde.")
cls <- c("Verde", "Neutra", "Marrom")
mat <- t(sapply(GRUPOS[1:4], function(go) sapply(cls, function(cs) { v <- hv(go, cs); if (length(v)) v else 0 })))
tab_(data.frame(`Grupo da ocupação` = GRUPOS[1:4],
                `Setor verde` = fmt(mat[, "Verde"]), `Setor neutro` = fmt(mat[, "Neutra"]),
                `Setor marrom` = fmt(mat[, "Marrom"]), check.names = FALSE),
     paste0("Tabela 4. Ocupados (mil) por intensidade da ocupação e classe do setor, ", ANO_FOCO), c(2.6, 1.1, 1.1, 1.1))

h_("7. TERRITÓRIO")
tu <- tr[tr$NIVEL == "UF", ]; tu <- tu[order(-tu$VERDE_MEDIO), ]
n_ne_topo <- which(tu$REGIAO != "Nordeste")[1] - 1
tn <- function(u, col) tr[[col]][tr$NIVEL == "Nordeste e demais" & tr$UNIDADE == u]
p_("O Nordeste tem o maior índice verde médio entre as regiões (", f3(tn("Nordeste", "VERDE_MEDIO")),
   ", contra ", f3(tn("Demais regiões", "VERDE_MEDIO")), " no restante do país), e também índice marrom acima da média (",
   f3(tn("Nordeste", "MARROM_MEDIO")), " contra ", f3(tn("Demais regiões", "MARROM_MEDIO")), "). As ", c("duas","três","quatro","cinco","seis","sete","oito","nove","dez")[n_ne_topo - 1], " primeiras UFs ",
   "no índice verde são nordestinas, lideradas por ", paste(tu$UNIDADE[1:3], collapse = ", "), ". O Distrito Federal, ",
   "São Paulo e Rio de Janeiro estão entre os menores índices verdes e marrons.")
tab_(data.frame(UF = tu$UNIDADE, Região = tu$REGIAO, `Ocupados (mil)` = fmt(tu$OCUPADOS_MIL),
                `Índice verde` = f3(tu$VERDE_MEDIO), `Índice marrom` = f3(tu$MARROM_MEDIO),
                `Índice líquido` = f3(tu$LIQUIDO_MEDIO), check.names = FALSE),
     paste0("Tabela 5. Índice médio por UF, ", ANO_FOCO, ", em ordem decrescente do índice verde"),
     c(1.7, 1.2, 0.9, 0.85, 0.85, 0.85))

h_("8. TRANSIÇÃO JUSTA: QUEM ESTÁ NAS OCUPAÇÕES MARRONS")
p_("Os ", fmt(g(tj, "Alta intensidade marrom", "OCUPADOS_MIL")), " mil ocupados de alta intensidade marrom em ", ANO_FOCO,
   " são quase todos homens (", pct(100 - g(tj, "Alta intensidade marrom", "MULHER_PCT")), "), mais velhos que a média, ",
   pct(g(tj, "Alta intensidade marrom", "FUND_INC_PCT")), " não completaram o ensino fundamental, ",
   pct(g(tj, "Alta intensidade marrom", "INFORMAL_PCT")), " são informais e ", pct(g(tj, "Alta intensidade marrom", "RURAL_PCT")),
   " moram no meio rural. São sobretudo pedreiros, agricultores e motoristas de caminhão. É o grupo que mais ",
   "dependeria de políticas de requalificação e proteção numa transição para atividades de menor impacto ambiental.")
lin <- c("Ocupados (mil)", "Mulheres (%)", "Pretos, pardos e indígenas (%)", "Idade média", "Fundamental incompleto (%)",
         "Superior completo (%)", "Informais (%)", "Renda média (R$)", "Rural (%)", "Nordeste (%)", "Em setor marrom (%)")
colv <- c("OCUPADOS_MIL", "MULHER_PCT", "PPI_PCT", "IDADE", "FUND_INC_PCT", "SUPERIOR_PCT", "INFORMAL_PCT",
          "RENDA_REAL", "RURAL_PCT", "NORDESTE_PCT", "SETOR_MARROM_PCT")
gr6 <- c("Alta intensidade marrom", "Alta intensidade verde", "Total")
tab_(data.frame(Característica = lin,
                sapply(gr6, function(go) sapply(seq_along(colv), function(k)
                  fmt(g(tj, go, colv[k]), if (colv[k] %in% c("OCUPADOS_MIL", "RENDA_REAL")) 0 else 1))) |>
                  `colnames<-`(c("Alta marrom", "Alta verde", "Total")), check.names = FALSE),
     paste0("Tabela 6. Perfil dos ocupados de alta intensidade marrom e verde, ", ANO_FOCO), c(2.6, 1.1, 1.1, 1.1))

h_("9. EVOLUÇÃO 2012-2024")
e0 <- ev[ev$ANO == min(ev$ANO), ]; e1 <- ev[ev$ANO == max(ev$ANO), ]
p_("Para separar a mudança na composição do emprego de mudanças nos pesos da RAIS, esta seção usa o índice com ",
   "pesos de 2024 em todos os anos. Como o índice de cada ocupação é fixo, toda a variação vem da composição do emprego. ",
   "O índice verde médio caiu de ", f3(e0$VERDE_MEDIO), " em ", e0$ANO, " para ", f3(e1$VERDE_MEDIO), " em ", e1$ANO,
   ", e o marrom, de ", f3(e0$MARROM_MEDIO), " para ", f3(e1$MARROM_MEDIO), ". A queda do marrom é proporcionalmente maior (",
   fmt(100 * (e1$MARROM_MEDIO / e0$MARROM_MEDIO - 1), 0), "%, contra ", fmt(100 * (e1$VERDE_MEDIO / e0$VERDE_MEDIO - 1), 0),
   "% no verde), e o índice líquido subiu. Pela decomposição shift-share por setor, ",
   pct(100 * ss_tot("verde", "2012-2024", "Entre (participação dos setores)") / ss_tot("verde", "2012-2024", "Variação total"), 0),
   " da queda do verde e ",
   pct(100 * ss_tot("marrom", "2012-2024", "Entre (participação dos setores)") / ss_tot("marrom", "2012-2024", "Variação total"), 0),
   " da queda do marrom vêm da mudança no peso dos setores, com destaque para a perda de participação da construção de edifícios ",
   "e da agropecuária. O restante vem da mudança da composição ocupacional dentro dos setores.")
anos7 <- c(2012, 2014, 2016, 2019, 2020, 2022, 2024)
e7 <- ev[ev$ANO %in% anos7, ]
tab_(data.frame(Ano = as.character(e7$ANO), `Índice verde` = f3(e7$VERDE_MEDIO), `Índice marrom` = f3(e7$MARROM_MEDIO),
                `Índice líquido` = f3(e7$LIQUIDO_MEDIO), `Alta verde (mil)` = fmt(e7$OCUPADOS_ALTA_VERDE_MIL),
                `Alta marrom (mil)` = fmt(e7$OCUPADOS_ALTA_MARROM_MIL), check.names = FALSE),
     "Tabela 7. Evolução com índice de pesos fixos (RAIS 2024)", c(0.8, rep(1.0, 5)))
per <- sapply(PERIODOS, paste, collapse = "-")
tab_(data.frame(Período = per,
                `Verde: variação` = sapply(per, function(p) fmt(1e4 * ss_tot("verde", p, "Variação total"), 1)),
                `Verde: entre` = sapply(per, function(p) fmt(1e4 * ss_tot("verde", p, "Entre (participação dos setores)"), 1)),
                `Verde: dentro` = sapply(per, function(p) fmt(1e4 * ss_tot("verde", p, "Dentro (composição ocupacional)"), 1)),
                `Marrom: variação` = sapply(per, function(p) fmt(1e4 * ss_tot("marrom", p, "Variação total"), 1)),
                `Marrom: entre` = sapply(per, function(p) fmt(1e4 * ss_tot("marrom", p, "Entre (participação dos setores)"), 1)),
                `Marrom: dentro` = sapply(per, function(p) fmt(1e4 * ss_tot("marrom", p, "Dentro (composição ocupacional)"), 1)),
                check.names = FALSE),
     "Tabela 8. Decomposição shift-share por setor (variação do índice x 10.000)", c(1.0, rep(0.85, 6)))

h_("10. DESIGUALDADE")
p_("O conteúdo verde médio cai ao longo da distribuição de renda: de ", f3(de$VERDE_MEDIO[de$DECIMO_RENDA == 1]),
   " no décimo mais pobre para ", f3(de$VERDE_MEDIO[de$DECIMO_RENDA == 10]), " no mais rico, em ", ANO_FOCO,
   ". O índice de concentração do conteúdo verde ao longo da renda é negativo (", fmt(cc$CONCENTRACAO_VERDE[cc$ANO == ANO_FOCO], 3),
   "), assim como o do marrom (", fmt(cc$CONCENTRACAO_MARROM[cc$ANO == ANO_FOCO], 3), "): os dois estão mais presentes entre os ",
   "trabalhadores de menor renda. Esse padrão se mantém em todos os anos e também depende da revisão dos rótulos ",
   "de atividades ligadas a resíduos.")
tab_(data.frame(Décimo = as.character(de$DECIMO_RENDA), `Renda média (R$)` = fmt(de$RENDA_MEDIA),
                `Índice verde` = f3(de$VERDE_MEDIO), `Índice marrom` = f3(de$MARROM_MEDIO),
                `Alta verde (%)` = fmt(de$PCT_ALTA_VERDE, 1), `Alta marrom (%)` = fmt(de$PCT_ALTA_MARROM, 1),
                check.names = FALSE),
     paste0("Tabela 9. Índice médio por décimo de renda do trabalho principal, ", ANO_FOCO), c(0.8, rep(1.0, 5)))

h_("11. PRÓXIMOS PASSOS")
p_("Primeiro, concluir a classificação humana e rodar de novo o índice, a ponte e estas estatísticas. Os scripts ",
   "estão em metodologia/R/estatisticas/ e atualizam todas as tabelas e esta nota automaticamente. Segundo, ",
   "testar a sensibilidade dos resultados à exclusão das atividades de manejo rotineiro de lixo, que hoje dominam ",
   "o conteúdo verde. Terceiro, estimar intervalos de confiança pelo desenho amostral também para os cortes por ",
   "perfil e território. As tabelas completas, para todos os anos, estão em metodologia/saida/estatisticas/.")

# ------------------------------------------------------------------------------
# Página A4, margens ABNT
# ------------------------------------------------------------------------------
doc <- body_set_default_section(doc, prop_section(
  page_size = page_size(width = 21 / 2.54, height = 29.7 / 2.54, orient = "portrait"),
  page_margins = page_mar(top = 3 / 2.54, bottom = 3 / 2.54, left = 3 / 2.54, right = 2 / 2.54,
                          header = 0.5, footer = 0.5, gutter = 0)))
ARQ_NOTA_EST <- file.path(RAIZ, "metodologia", "Estatisticas_descritivas_indice_PNADc.docx")
print(doc, target = ARQ_NOTA_EST)
cat("nota gravada em", ARQ_NOTA_EST, "\n")
