# ==============================================================================
# PONTE CBO 2002 -> COD (PNADc) - 05. NOTA METODOLOGICA (WORD)
# ==============================================================================
# Gera metodologia/Nota_metodologica_ponte_CBO_COD.docx com os numeros
# calculados nas etapas 01 a 04 (nenhum numero e digitado a mao).
# Formato: Times New Roman 12, A4, margens ABNT, titulos em negrito.
# Requer: source("metodologia/R/ponte/_run_ponte.R") antes.
# ==============================================================================

etapa("Ponte 05. Nota metodologica")
for (p in c("officer", "flextable")) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "https://cloud.r-project.org")
}
library(officer)

FONTE <- "Times New Roman"
fmt <- function(x, d = 0) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
pct <- function(x, d = 1) paste0(fmt(x, d), "%")

# ------------------------------------------------------------------------------
# Numeros
# ------------------------------------------------------------------------------
ord_rota <- c("tabua_ocupacao", "tabua_familia", "manual_familia", "manual_cod")
melhor_rota <- tapply(match(ponte$ROTA, ord_rota), ponte$CBO2002, min)
cbo_por_rota <- table(factor(ord_rota[melhor_rota], levels = ord_rota))
pares_por_rota <- table(factor(ponte$ROTA, levels = ord_rota))
n_cod_cbo <- table(ponte$CBO2002)
tab_pares <- ponte[ponte$ROTA %in% ord_rota[1:2], ]
i24 <- indice_cod[indice_cod$ANO_RAIS == max(ANOS_RAIS), ]
man_fam <- ler_csv(ARQ_PONTE$manual_fam)
man_cod <- ler_csv(ARQ_PONTE$manual_cod)
gs <- ler_csv(file.path(DIR_PONTE_SAI, "grupos_sem_indice.csv"))
gs$OCUPADOS_MIL <- num(gs$OCUPADOS_MIL)
cob24 <- cob[cob$ANO_PNADC == max(cob$ANO_PNADC), ]
x24 <- pn[pn$Ano == max(pn$Ano), ]
media_verde <- weighted.mean(i24$Verde_amplo[match(x24$V4010, i24$COD)], x24$V1028, na.rm = TRUE)
media_marrom <- weighted.mean(i24$Marrom[match(x24$V4010, i24$COD)], x24$V1028, na.rm = TRUE)
pv_cod <- ponte$COD[ponte$CBO2002 == "732140"]
pv_i <- i24[i24$COD %in% pv_cod, ]
rais_tot <- aggregate(VINCULOS ~ ANO, data = rais, FUN = sum)

# ------------------------------------------------------------------------------
# Auxiliares de formatacao
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
p_  <- function(...) { doc <<- body_add_fpar(doc, fpar(ftext(paste0(...), tx), fp_p = par_corpo)) }
h_  <- function(t)   { doc <<- body_add_fpar(doc, fpar(ftext(t, txb), fp_p = par_secao)) }
fonte_tab <- function(t) {
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
  doc <<- flextable::body_add_flextable(doc, ft, align = "left")
}

# ------------------------------------------------------------------------------
# Texto
# ------------------------------------------------------------------------------
doc <- body_add_fpar(doc, fpar(ftext(paste("NOTA METODOLÓGICA: CORRESPONDÊNCIA ENTRE A CBO 2002 E A",
  "CLASSIFICAÇÃO DE OCUPAÇÕES PARA PESQUISAS DOMICILIARES (COD) PARA APLICAÇÃO DO ÍNDICE DE",
  "ESVERDEAMENTO OCUPACIONAL À PNAD CONTÍNUA"), txb), fp_p = par_titulo))
doc <- body_add_fpar(doc, fpar(ftext(paste("Projeto Green Skills. Macroplan e Instituto de Economia da UFRJ.",
  paste0("Versão preliminar, ", format(Sys.Date(), "%d/%m/%Y"), ".")), tx), fp_p = par_titulo))

h_("1. Objetivo")
p_("Esta nota descreve como o índice de esverdeamento ocupacional, construído para as ocupações da ",
   "Classificação Brasileira de Ocupações (CBO 2002), foi transposto para a classificação de ocupações ",
   "usada na PNAD Contínua, de modo a permitir estatísticas descritivas do mercado de trabalho com essa ",
   "pesquisa. O procedimento é chamado aqui de ponte. Registram-se as fontes, as regras de ligação, a forma ",
   "de agregação, a cobertura obtida e as limitações que decorrem da transposição.")

h_("2. O problema de compatibilização")
p_("O índice é calculado para cada ocupação da CBO 2002, no nível de seis dígitos, a partir das atividades ",
   "descritas no Perfil Ocupacional. Cobre ", fmt(nrow(indice)), " ocupações, das quais ",
   fmt(sum(indice$Reportavel == "sim")), " são reportáveis, isto é, têm ao menos ", MINIMO_ATIVIDADES,
   " atividades descritas. A RAIS registra a ocupação nessa mesma classificação. A PNAD Contínua, por sua ",
   "vez, registra a ocupação do trabalho principal (variável V4010) pela Classificação de Ocupações para ",
   "Pesquisas Domiciliares (COD), com quatro dígitos, derivada da Classificação Internacional Uniforme de ",
   "Ocupações de 2008 (CIUO-08, ou ISCO-08) com adaptações para o caso brasileiro, como os grupos próprios ",
   "das forças armadas, das polícias militares e dos corpos de bombeiros militares.")
p_("Não foi localizada tabela oficial de correspondência entre a CBO 2002 e a COD. A ponte foi, portanto, ",
   "construída a partir das tábuas oficiais disponíveis, encadeadas, e complementada por ligações manuais ",
   "nos casos em que as tábuas não alcançam. Como a COD reproduz os códigos da CIUO-08 para quase todos os ",
   "grupos, considerou-se que um código da CIUO-08 corresponde ao grupo da COD de mesmo código. Dos ",
   fmt(length(unique(pn$V4010))), " códigos de ocupação observados na PNAD Contínua entre 2014 e 2024, ",
   "apenas nove não existem na CIUO-08: o código de ocupações mal definidas, os seis grupos militares e ",
   "dois grupos próprios da COD.")

h_("3. Fontes")
p_("a) Índice de esverdeamento por ocupação da CBO 2002, produzido pelo pipeline do projeto ",
   "(metodologia/R/_run_indice.R), em sua versão preliminar, com os rótulos de atividade da rodada de ",
   "setembro de 2026.")
p_("b) Tábua de conversão CBO 2002, CBO 94 e CIUO-88, publicada pelo Ministério do Trabalho, tal como ",
   "sistematizada no relatório de compatibilização CBO 2002 e O*NET do projeto. Liga ",
   fmt(length(unique(cbo_ciuo$CBO2002))), " ocupações da CBO 2002 a grupos da CIUO-88, seja diretamente, ",
   "seja por herança da família ocupacional.")
p_("c) Tabela de correspondência entre a CIUO-88 e a CIUO-08, publicada pela Organização Internacional ",
   "do Trabalho, com ", fmt(nrow(ciuo_isco)), " pares de grupos e a indicação de correspondência parcial.")
p_("d) RAIS, número de vínculos ativos em 31 de dezembro por ocupação da CBO 2002, para os anos de ",
   paste(ANOS_RAIS, collapse = ", "), ", obtida na Base dos Dados (BigQuery). Os totais são de ",
   paste(paste0(fmt(rais_tot$VINCULOS / 1e6, 1), " milhões em ", rais_tot$ANO), collapse = ", "), ".")
p_("e) PNAD Contínua, microdados do quarto trimestre, variáveis V4010 (ocupação) e V1028 (peso amostral).")

h_("4. Construção da ponte")
p_("Cada ocupação da CBO 2002 foi ligada a um ou mais grupos da COD por quatro rotas, aplicadas em ordem ",
   "de preferência. Quando o mesmo par de ocupação e grupo resulta de mais de uma rota, prevalece a primeira.")
p_("Rota 1, tábua oficial com ligação da própria ocupação: a ocupação da CBO 2002 é ligada a um grupo da ",
   "CIUO-88 pela tábua do Ministério do Trabalho; esse grupo é ligado aos grupos da CIUO-08 pela tabela da ",
   "OIT; cada grupo da CIUO-08 corresponde ao grupo da COD de mesmo código.")
p_("Rota 2, tábua oficial com ligação herdada da família: igual à anterior, mas a ligação entre a ocupação ",
   "e a CIUO-88 é a da sua família ocupacional, porque a tábua não traz a ocupação individualmente.")
p_("Rota 3, ligação manual por família: ", fmt(nrow(man_fam)), " famílias da CBO 2002, com ",
   fmt(sum(indice$Familia %in% man_fam$COD_FAMILIA)), " ocupações, não constam da tábua oficial, em geral ",
   "por terem sido criadas ou desmembradas depois dela. Foram ligadas a grupos da COD pela comparação dos ",
   "títulos. Exemplos: as famílias da polícia militar e dos corpos de bombeiros militares foram ligadas aos ",
   "grupos militares próprios da COD; Engenheiros ambientais e afins, ao grupo 2143 (engenheiros ambientais); ",
   "Trabalhadores da coleta e seleção de material reciclável, ao grupo 9612 (classificadores de resíduos). ",
   "A lista completa, com o critério, está em metodologia/insumos/ponte/ligacoes_manuais_familia.csv.")
p_("Rota 4, ligação manual pelo lado da COD: depois das três rotas anteriores, ", fmt(nrow(man_cod)),
   " grupos da COD presentes na PNAD Contínua continuavam sem nenhuma ocupação ligada. Foram ligados a ",
   "famílias da CBO 2002 pela comparação dos títulos. Exemplos: trabalhadores de cuidados pessoais a ",
   "domicílio, ligados à família Cuidadores de crianças, jovens, adultos e idosos; agentes comunitários de ",
   "saúde, à família Trabalhadores em serviços de promoção e apoio à saúde; trabalhadores elementares da ",
   "pecuária, às famílias de tratadores e trabalhadores na pecuária. A lista está em ",
   "metodologia/insumos/ponte/ligacoes_manuais_cod.csv.")
p_("As ligações manuais das rotas 3 e 4 são uma proposta inicial, feita pela leitura dos títulos, e devem ",
   "ser revisadas pela equipe antes do uso definitivo.")

tab_(data.frame(
  Rota = c("1. Tábua, ligação da ocupação", "2. Tábua, ligação da família", "3. Manual por família da CBO",
           "4. Manual pelo grupo da COD", "Total"),
  `Pares ocupação x grupo` = fmt(c(pares_por_rota, sum(pares_por_rota))),
  `Ocupações cuja melhor ligação é desta rota` = fmt(c(cbo_por_rota, sum(cbo_por_rota))),
  check.names = FALSE),
  "Tabela 1. Ligações entre ocupações da CBO 2002 e grupos da COD, por rota", c(2.6, 1.5, 2.0))
fonte_tab("Fonte: elaboração própria.")

p_("Todas as ", fmt(nrow(indice)), " ocupações da CBO 2002 receberam ao menos uma ligação. A relação não ",
   "é unívoca: ", fmt(sum(n_cod_cbo == 1)), " ocupações se ligam a um único grupo da COD, ",
   fmt(sum(n_cod_cbo %in% 2:3)), " a dois ou três e ", fmt(sum(n_cod_cbo >= 4)), " a quatro ou mais, com ",
   "máximo de ", max(n_cod_cbo), ". A multiplicidade vem sobretudo da passagem da CIUO-88 para a CIUO-08: ",
   "dos ", fmt(nrow(tab_pares)), " pares obtidos pelas tábuas, ", fmt(sum(tab_pares$PARCIAL == "sim")),
   " correspondem a correspondências parciais, nas quais apenas parte do grupo de origem pertence ao grupo ",
   "de destino.")

h_("5. Agregação do índice para os grupos da COD")
p_("O índice de cada grupo da COD é a média dos índices das ocupações da CBO 2002 ligadas a ele, ",
   "ponderada pelo número de vínculos da RAIS de cada ocupação. Quando uma ocupação se liga a k grupos, seus ",
   "vínculos são divididos igualmente entre eles, de modo que cada ocupação contribui, no conjunto da ponte, ",
   "com o seu emprego total, sem duplicação. Só entram as ocupações reportáveis. Em termos formais, para o ",
   "grupo g, o índice é a soma, sobre as ocupações c ligadas a g, de w(c) multiplicado por I(c), dividida ",
   "pela soma de w(c), em que I(c) é o índice da ocupação e w(c) é o número de vínculos da ocupação dividido ",
   "pelo número de grupos aos quais ela se liga.")
p_("A ponderação segue a orientação do projeto de nunca agregar o índice por média simples: um grupo que ",
   "reúne uma ocupação verde com poucos trabalhadores e uma ocupação sem conteúdo verde com muitos ",
   "trabalhadores deve refletir a composição do emprego. Foram calculadas versões com os pesos da RAIS de ",
   paste(ANOS_RAIS, collapse = ", "), "; cada ano da PNAD Contínua usa os pesos do ano da RAIS mais próximo. ",
   "Dos ", fmt(sum(!is.na(i24$Verde_amplo))), " grupos com índice na versão de ", max(ANOS_RAIS), ", ",
   fmt(sum(i24$PONDERACAO == "rais")), " foram ponderados pela RAIS e ", fmt(sum(i24$PONDERACAO == "media_simples")),
   ", sem nenhum vínculo formal nas ocupações ligadas, receberam a média simples, com marca no arquivo de saída.")
p_("São agregadas todas as dimensões do índice: verde estrito, verde com potencial, marrom e líquido, nas ",
   "versões ampla (todas as atividades) e específica (atividades exclusivas da ocupação na família).")

h_("6. Cobertura e primeiros resultados")
tab_(data.frame(
  `Ano da PNAD Contínua` = cob$ANO_PNADC, `Ano da RAIS (pesos)` = cob$ANO_RAIS,
  `Grupos da COD observados` = cob$COD_NA_PNADC, `Grupos com índice` = cob$COD_COM_INDICE,
  `Ocupados (mil)` = fmt(cob$OCUPADOS_MIL), `Ocupados cobertos` = pct(cob$COBERTURA_PCT),
  check.names = FALSE),
  "Tabela 2. Cobertura da ponte na PNAD Contínua, quarto trimestre", c(1.0, 1.0, 1.1, 1.0, 1.0, 1.0))
fonte_tab("Fonte: elaboração própria a partir da PNAD Contínua (IBGE) e da RAIS.")
p_("A ponte atribui índice a ", pct(cob24$COBERTURA_PCT), " dos ocupados de ", cob24$ANO_PNADC,
   ". Os grupos sem índice são de três tipos. As forças armadas (", fmt(sum(gs$OCUPADOS_MIL[gs$COD %in% c("0110", "0210")])),
   " mil ocupados) não têm atividades descritas no Perfil Ocupacional, e por isso não há índice a transpor. ",
   "O grupo 6225 (", fmt(gs$OCUPADOS_MIL[gs$COD == "6225"]), " mil ocupados), próprio da COD e situado entre os ",
   "trabalhadores qualificados da agropecuária e da pesca, não teve o título verificado e ficou sem ligação até ",
   "que se confirme a sua definição. Os demais são grupos pequenos sem ocupação correspondente identificada, ",
   "listados em metodologia/saida/ponte/grupos_sem_indice.csv.")
p_("Como primeira leitura, a média do índice verde estrito ponderada pelos ocupados de ", cob24$ANO_PNADC,
   " é de ", fmt(media_verde, 4), ", e a do índice marrom, de ", fmt(media_marrom, 4), ". Os maiores índices ",
   "verdes por grupo estão em profissionais de proteção ambiental, trabalhadores de isolamento, geólogos, ",
   "assessores agropecuários e florestais e coletores e classificadores de resíduos; os maiores índices ",
   "marrons, em pedreiros, operadores de máquinas de produtos minerais e cimento, canteiros, produtores de ",
   "lavouras e trabalhadores da mineração. Esses números são preliminares (seção 7).")

h_("7. Limitações")
p_("a) Perda de resolução. A COD tem cerca de 430 grupos, contra 2.700 ocupações da CBO 2002 no índice. ",
   "Ocupações de conteúdo verde elevado ficam diluídas em grupos amplos. O caso que motivou a construção do ",
   "índice ilustra o ponto: o instalador de sistemas fotovoltaicos (CBO 732140), com índice verde de 0,101, ",
   "liga-se aos grupos ", paste(pv_i$COD, collapse = " e "), ", cujos índices agregados são ",
   paste(fmt(pv_i$Verde_amplo, 3), collapse = " e "), ". A PNAD Contínua mede bem o conteúdo verde médio ",
   "da força de trabalho e a sua distribuição entre grupos sociais e regiões, mas não identifica ocupações ",
   "verdes específicas; para isso, a referência é a RAIS, que usa a CBO 2002.")
p_("b) Defasagem da CIUO-88. A rota principal passa pela CIUO-88, classificação de 1988, que não tem ",
   "categorias para atividades surgidas depois, como a instalação fotovoltaica. Isso afeta a escolha dos grupos ",
   "de destino, não o índice de cada ocupação, que vem do Perfil Ocupacional.")
p_("c) Correspondências parciais. Quando uma ocupação se liga a vários grupos, seus vínculos são divididos ",
   "em partes iguais, porque não há informação sobre a proporção que corresponde a cada grupo. É uma hipótese ",
   "de trabalho, a ser testada em análise de sensibilidade.")
p_("d) Ligações manuais. As rotas 3 e 4 dependem de julgamento sobre títulos de ocupações e devem ser ",
   "revisadas pela equipe.")
p_("e) Pesos do emprego formal. A RAIS cobre o emprego formal. Dentro de cada grupo da COD, a composição ",
   "das ocupações entre os trabalhadores informais pode diferir da composição formal, sobretudo na ",
   "agropecuária, no trabalho doméstico e no comércio ambulante.")
p_("f) Índice fixo no tempo. O índice de cada ocupação não varia entre anos. Mudanças nas estatísticas ",
   "agregadas ao longo do tempo refletem apenas mudanças na composição do emprego, e não mudanças no ",
   "conteúdo das ocupações.")
p_("g) Caráter preliminar. Os rótulos de atividade que sustentam o índice serão substituídos pela ",
   "classificação humana em curso (protocolo em metodologia/PROTOCOLO_CLASSIFICACAO_HUMANA.md). A ponte ",
   "não precisa ser refeita: basta recalcular o índice e rodar de novo os scripts.")

h_("8. Reprodutibilidade")
p_("Todo o procedimento está em metodologia/R/ponte/ e é executado por source(\"metodologia/R/ponte/_run_ponte.R\"). ",
   "Os insumos ficam em metodologia/insumos/ponte/ (tábua CBO 2002 e CIUO-88, tabela CIUO-88 e CIUO-08, ",
   "ligações manuais e vínculos da RAIS), versionados no Git. As saídas ficam em metodologia/saida/ponte/: a ",
   "ponte com a rota de cada par (ponte_cbo2002_cod.csv), o índice por grupo da COD para cada ano da RAIS ",
   "(indice_por_cod.csv), a cobertura na PNAD Contínua (cobertura_pnadc.csv) e os grupos sem índice ",
   "(grupos_sem_indice.csv). Esta nota é gerada pelo script 05_nota_metodologica.R com os números calculados, ",
   "sem digitação manual.")

h_("9. Próximos passos")
p_("Revisar as ligações manuais; confirmar a definição do grupo 6225 na documentação da COD; testar a ",
   "sensibilidade dos resultados à regra de divisão dos vínculos nas correspondências múltiplas; e, com a ",
   "ponte validada, produzir as estatísticas descritivas com a PNAD Contínua.")

doc <- body_set_default_section(doc, prop_section(
  page_size = page_size(orient = "portrait", width = 21 / 2.54, height = 29.7 / 2.54),
  page_margins = page_mar(top = 3 / 2.54, bottom = 3 / 2.54, left = 3 / 2.54, right = 2 / 2.54,
                          header = 0.5, footer = 0.5, gutter = 0)))
destino_nota <- file.path(RAIZ, "metodologia", "Nota_metodologica_ponte_CBO_COD.docx")
print(doc, target = destino_nota)
cat("nota gravada em", destino_nota, "\n")
