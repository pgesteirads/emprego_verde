
# ===========================================================================
# tabelas_dos_graficos.R
# ---------------------------------------------------------------------------
# Este script gera TODAS as tabelas que alimentam os gráficos do
# exercicio_2025.R e as exporta para Excel (.xlsx).
#
# PREMISSA: rode ANTES toda a parte de preparação de dados do
#           exercicio_2025.R (até a seção "# Gráficos"), de modo que os
#           objetos  base_pnadc, tabelas_class, cnae_verde, anos_graf
#           já existam no ambiente.
# ===========================================================================

library(tidyverse)
library(writexl)
library(spatstat)    # weighted.quantile / weighted.var

# Diretório de saída -------------------------------------------------------

dir_out <- "produtos/tabelas/tabelas_graficos"
if (!dir.exists(dir_out)) dir.create(dir_out, recursive = TRUE)

# anos_graf (replica a lógica do script original) --------------------------
anos_graf <- c(
  as.numeric(base_pnadc$Ano) %>% sort() %>% head(1),
  as.numeric(base_pnadc$Ano) %>% sort() %>% tail(1)
)

# =========================================================================
# 1) Boxplot da Renda (Log) por Classificação Verde
#    Gráfico: "Boxplot of Log Income by Green Classification"
#    Arquivo salvo: renda_percentil.png
# =========================================================================

tab_01_boxplot_renda <- tabelas_class[["renda_percentil"]] %>%
  ungroup() %>%
  filter(Ano %in% anos_graf)

write_xlsx(tab_01_boxplot_renda,
           file.path(dir_out, "01_boxplot_renda_percentil.xlsx"))


# =========================================================================
# 2) Renda Média por Ano e Classificação Verde
#    Gráfico: "Average Income by Year and Classification"
#    Arquivo salvo: renda_media_class.png
# =========================================================================

tab_02_renda_media <- base_pnadc %>%
  select(V1028, class_verde_atividade, Ano, renda_hab_def) %>%
  filter(!is.na(class_verde_atividade)) %>%
  group_by(Ano, class_verde_atividade) %>%
  summarise(renda_media = weighted.mean(x = renda_hab_def, w = V1028, na.rm = TRUE),
            .groups = "drop")

write_xlsx(tab_02_renda_media,
           file.path(dir_out, "02_renda_media_por_classif.xlsx"))


# =========================================================================
# 3) Histograma da Renda
#    Gráfico: "Logarithmic Income Histogram"
#    Arquivo salvo: hist_renda.png
#    Nota: o histograma usa dados brutos; exportamos a distribuição resumida
#          (bins de 5000) para reprodutibilidade.
# =========================================================================

tab_03_hist_renda <- base_pnadc %>%
  select(V1028, class_verde_atividade, Ano, renda_hab_def) %>%
  filter(!is.na(class_verde_atividade),
         Ano %in% anos_graf) %>%
  mutate(faixa_renda = cut(renda_hab_def,
                           breaks = seq(0, 250000, by = 5000),
                           include.lowest = TRUE, right = FALSE)) %>%
  group_by(Ano, class_verde_atividade, faixa_renda) %>%
  summarise(freq_ponderada = sum(V1028, na.rm = TRUE),
            .groups = "drop")

write_xlsx(tab_03_hist_renda,
           file.path(dir_out, "03_histograma_renda.xlsx"))


# =========================================================================
# 4–6) Mapas por UF — Brown, Neutral e Green
#      Gráficos: "Proportion of Brown/Neutral/Green Jobs by State (UF)"
#      Arquivos salvos: mapa_empregos_sujos.png, mapa_empregos_limpos.png,
#                       mapa_empregos_verdes.png
# =========================================================================

tab_04_mapa_uf <- tabelas_class[["regiao_uf"]] %>%
  ungroup() %>%
  filter(Ano %in% anos_graf)

# Exporta tudo junto (as 3 classificações); cada mapa é um filtro
write_xlsx(tab_04_mapa_uf,
           file.path(dir_out, "04_mapa_uf_todas_classif.xlsx"))

# Se preferir separados:
write_xlsx(tab_04_mapa_uf %>% filter(class_verde_atividade == "Brown"),
           file.path(dir_out, "04a_mapa_uf_brown.xlsx"))
write_xlsx(tab_04_mapa_uf %>% filter(class_verde_atividade == "Neutral"),
           file.path(dir_out, "04b_mapa_uf_neutral.xlsx"))
write_xlsx(tab_04_mapa_uf %>% filter(class_verde_atividade == "Green"),
           file.path(dir_out, "04c_mapa_uf_green.xlsx"))


# =========================================================================
# 7) Grandes Regiões — proporção por classificação
#    Gráfico: "Proportion of occupied by Region and Classification Type"
#    Arquivo salvo: regiao_por_classif.png
# =========================================================================

tab_07_regioes <- tabelas_class[["regiao"]] %>%
  filter(Ano %in% anos_graf) %>%
  group_by(Ano, regiao) %>%
  mutate(freq = n * 100 / sum(n, na.rm = TRUE)) %>%
  ungroup()

write_xlsx(tab_07_regioes,
           file.path(dir_out, "07_regioes_por_classif.xlsx"))


# =========================================================================
# 8–10) Evolução da qtd de ocupados por tipo (Green / Neutral / Brown)
#       Gráficos: qtd_ocupados_verdes.png, qtd_ocupados_Neutrals.png,
#                 qtd_ocupados_sujas.png
# =========================================================================

tab_08_10_ocup_por_tipo <- tabelas_class[["ocupacao"]] %>%
  filter(!is.na(formalidade)) %>%
  summarise(n = sum(n), .groups = "drop") %>%
  ungroup()

write_xlsx(tab_08_10_ocup_por_tipo,
           file.path(dir_out, "08_10_qtd_ocupados_por_tipo.xlsx"))

# Separados por classificação:
write_xlsx(tab_08_10_ocup_por_tipo %>% filter(class_verde_atividade == "Green") %>% select(-class_verde_atividade),
           file.path(dir_out, "08_qtd_ocupados_green.xlsx"))
write_xlsx(tab_08_10_ocup_por_tipo %>% filter(class_verde_atividade == "Neutral") %>% select(-class_verde_atividade),
           file.path(dir_out, "09_qtd_ocupados_neutral.xlsx"))
write_xlsx(tab_08_10_ocup_por_tipo %>% filter(class_verde_atividade == "Brown") %>% select(-class_verde_atividade),
           file.path(dir_out, "10_qtd_ocupados_brown.xlsx"))


# =========================================================================
# 11) Evolução da qtd de ocupados — todas as classificações juntas
#     Gráfico: "Number of Employed Persons by Classification"
#     Arquivo salvo: qtd_ocupados_por_classif.png
# =========================================================================

tab_11_qtd_ocup_classif <- tabelas_class[["ocupacao"]] %>%
  filter(!is.na(formalidade)) %>%
  summarise(n = sum(n), .groups = "drop") %>%
  ungroup()

write_xlsx(tab_11_qtd_ocup_classif,
           file.path(dir_out, "11_qtd_ocupados_todas_classif.xlsx"))


# =========================================================================
# 12) Proporção de ocupados por classificação (barras empilhadas)
#     Gráfico: "Proportion of Employed Persons by Classification"
#     Arquivo salvo: prop_ocupados_por_classif.png
# =========================================================================

tab_12_prop_ocup <- tabelas_class[["ocupacao"]] %>%
  filter(!is.na(formalidade)) %>%
  summarise(n = sum(n), .groups = "drop") %>%
  mutate(freq = (n / sum(n)) * 100) %>%
  ungroup()

write_xlsx(tab_12_prop_ocup,
           file.path(dir_out, "12_prop_ocupados_por_classif.xlsx"))


# =========================================================================
# 13) Proporção de ocupados por formalidade e classificação
#     Gráfico: "Proportion of Employed Persons by Employment Formality"
#     Arquivo salvo: prop_formalidade_classif.png
# =========================================================================

tab_13_formal_classif <- tabelas_class[["ocupacao"]] %>%
  filter(Ano %in% anos_graf,
         !is.na(formalidade)) %>%
  mutate(freq = n / sum(n) * 100)

write_xlsx(tab_13_formal_classif,
           file.path(dir_out, "13_prop_formalidade_classif.xlsx"))


# =========================================================================
# 14–16) Treemaps de ocupações — Brown, Neutral, Green (Ano = 2024)
#        Gráficos: arvore_ocup_sujas.png, arvore_ocup_Neutrals.png,
#                  arvore_ocup_verdes.png
# =========================================================================

gerar_treemap_tab <- function(classif) {
  base_pnadc %>%
    select(cnaedom_nome, formalidade, Ano, V1028, class_verde_atividade, setor_cnae20_nome) %>%
    filter(!is.na(formalidade),
           class_verde_atividade == classif,
           Ano == 2024) %>%
    group_by(setor_cnae20_nome, cnaedom_nome) %>%
    summarise(qtd = round(sum(V1028)), .groups = "drop") %>%
    ungroup() %>%
    mutate(pct = round(qtd / sum(qtd) * 100, 2))
}

tab_14_treemap_brown   <- gerar_treemap_tab("Brown")
tab_15_treemap_neutral <- gerar_treemap_tab("Neutral")
tab_16_treemap_green   <- gerar_treemap_tab("Green")

write_xlsx(tab_14_treemap_brown,
           file.path(dir_out, "14_treemap_brown_2024.xlsx"))
write_xlsx(tab_15_treemap_neutral,
           file.path(dir_out, "15_treemap_neutral_2024.xlsx"))
write_xlsx(tab_16_treemap_green,
           file.path(dir_out, "16_treemap_green_2024.xlsx"))


# =========================================================================
# 17) Formalidade por classificação (segunda versão do gráfico)
#     Gráfico: "Proporção de ocupados segundo a formalidade da ocupação"
#     Arquivo salvo: prop_formalidade_classif.png (sobrescreve)
#     Nota: mesma tabela que #13, mas com label em português.
# =========================================================================

tab_17_formalidade <- tabelas_class[["ocupacao"]] %>%
  filter(Ano %in% anos_graf,
         !is.na(formalidade)) %>%
  mutate(freq = n / sum(n) * 100)

write_xlsx(tab_17_formalidade,
           file.path(dir_out, "17_formalidade_classif_v2.xlsx"))


# =========================================================================
# 18) Cor/Raça por classificação
#     Gráfico: "Proportion of Employed Persons by Race/Color and Classification"
#     Arquivo salvo: prop_cor_classif.png
# =========================================================================

tab_18_cor <- tabelas_class[["cor"]] %>%
  filter(Ano %in% anos_graf,
         V2010 != "Ignorado")

write_xlsx(tab_18_cor,
           file.path(dir_out, "18_cor_por_classif.xlsx"))


# =========================================================================
# 19) Escolaridade (faixas agrupadas) por classificação
#     Gráfico: "Proportion of Employed Persons by Educational Attainment"
#     Arquivo salvo: prop_esc_classif.png
# =========================================================================

tab_19_escolaridade <- base_pnadc %>%
  select(Ano, V1028, class_verde_atividade, VD3004) %>%
  filter(Ano %in% anos_graf,
         !is.na(class_verde_atividade)) %>%
  mutate(VD3004 = case_when(
    VD3004 == "Sem instrução e menos de 1 ano de estudo" |
      VD3004 == "Fundamental incompleto ou equivalente" ~ "Fundamental Incompleto",
    VD3004 == "Fundamental completo ou equivalente" |
      VD3004 == "Médio incompleto ou equivalente" ~ "Fundamental Completo",
    VD3004 == "Médio completo ou equivalente" |
      VD3004 == "Superior incompleto ou equivalente" ~ "Médio Completo",
    TRUE ~ "Superior Completo"
  )) %>%
  mutate(VD3004 = factor(VD3004,
                         levels = c("Fundamental Incompleto", "Fundamental Completo",
                                    "Médio Completo", "Superior Completo"))) %>%
  group_by(Ano, class_verde_atividade, VD3004) %>%
  summarise(qtd = sum(V1028), .groups = "drop_last") %>%
  mutate(freq = qtd / sum(qtd) * 100) %>%
  ungroup()

write_xlsx(tab_19_escolaridade,
           file.path(dir_out, "19_escolaridade_por_classif.xlsx"))


# =========================================================================
# 20) Anos médios de escolaridade por classificação
#     Gráfico: "Average Years of Schooling of Employed Persons by Classification Type"
#     Arquivo salvo: escolaridade_media_por_classif.png
# =========================================================================

tab_20_esc_media <- tabelas_class[["escolaridade_anos"]] %>%
  mutate(VD3005 = str_sub(VD3005, 1, 2)) %>%
  mutate(VD3005 = ifelse(VD3005 == "Se", 0, VD3005)) %>%
  mutate(VD3005 = as.integer(VD3005)) %>%
  group_by(Ano, class_verde_atividade) %>%
  summarise(ano_medio_escolaridade = weighted.mean(VD3005, n),
            .groups = "drop")

write_xlsx(tab_20_esc_media,
           file.path(dir_out, "20_escolaridade_media_por_classif.xlsx"))


# =========================================================================
# 21–22) Região Metropolitana (empilhado e lado a lado)
#        Gráficos: "Proportion of Employed Persons by Metropolitan Region"
#        Arquivos salvos: prop_regiao_metrop_barra.png,
#                         qtd_regiao_metrop_barra_lado.png
# =========================================================================

tab_21_22_reg_metrop <- tabelas_class[["regiao_metrop"]] %>%
  filter(Ano %in% anos_graf)

write_xlsx(tab_21_22_reg_metrop,
           file.path(dir_out, "21_22_regiao_metropolitana.xlsx"))


# =========================================================================
# 23–24) Urbano x Rural (empilhado e lado a lado)
#        Gráficos: "Quantidade de ocupados segundo tipo da região (urbano x rural)"
#                  "Number of Employed Persons by Area Type (Urban vs. Rural)"
#        Arquivos salvos: qtd_regiao_urbano_rural_empilhado.png,
#                         qtd_urbano_rural_barra.png
# =========================================================================

tab_23_24_urbano_rural <- tabelas_class[["regiao_urbano_rural"]] %>%
  filter(Ano %in% anos_graf)

write_xlsx(tab_23_24_urbano_rural,
           file.path(dir_out, "23_24_urbano_rural.xlsx"))


# =========================================================================
# 25) Idade média por classificação
#     Gráfico: "Average Age of Employed Persons by Classification Type"
#     Arquivo salvo: idade_media_por_classif.png
# =========================================================================

tab_25_idade_media <- tabelas_class[["idade"]] %>%
  summarise(idade_media = weighted.mean(V2009, n), .groups = "drop") %>%
  ungroup()

write_xlsx(tab_25_idade_media,
           file.path(dir_out, "25_idade_media_por_classif.xlsx"))


# =========================================================================
# 26) Gênero por classificação
#     Gráfico: "Proportion of Men and Women by Classification Type"
#     Arquivo salvo: prop_genero_classif_alterna.png
# =========================================================================

tab_26_genero <- tabelas_class[["genero"]] %>%
  filter(Ano %in% anos_graf)

write_xlsx(tab_26_genero,
           file.path(dir_out, "26_genero_por_classif.xlsx"))


# =========================================================================
# FIM — Resumo
# =========================================================================

cat("\n============================================================\n")
cat("Tabelas exportadas com sucesso em:", dir_out, "\n")
cat("Total de arquivos gerados:", length(list.files(dir_out, pattern = "\\.xlsx$")), "\n")
cat("============================================================\n")
