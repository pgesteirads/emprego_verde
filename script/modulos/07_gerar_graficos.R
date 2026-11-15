###############################################################################
#                                                                             #
#   EMPREGO VERDE - 07. GERAÇÃO DE GRÁFICOS (EXECUÇÃO)                        #
#                                                                             #
#   Gera e salva todos os gráficos (renda, mapas, regiões, ocupados,         #
#   formalidade, cor/raça, escolaridade, região metropolitana, urbano/rural, #
#   idade, gênero, treemaps) em CAMINHO_PRODUTOS_GRAF.                        #
#                                                                             #
#   ATENÇÃO: script de EXECUÇÃO. Requer base_pnadc, cnae_verde e tabelas_class
#   (módulos 05 e 06).                                                         #
#   Dependências: 00_config.R, 05_preparar_dados.R, 06_gerar_tabelas.R.       #
#   Origem: emprego_verde_consolidado.R, seção 7.                             #
#                                                                             #
###############################################################################

message("  Gerando gráficos...")

anos_graf <- c(ANO_INICIAL, ANO_FINAL)

# Tema padrão
tema_padrao <- theme_minimal() +
  theme(legend.position = "bottom")

# --- 7a. RENDA ---

## Boxplots de log-renda por classificação
ggplot(tabelas_class[["renda_percentil"]] %>% ungroup() %>% filter(Ano %in% anos_graf),
       aes(x = class_verde_atividade, y = Q2, fill = class_verde_atividade)) +
  geom_boxplot(aes(ymin = Min, lower = Q1, middle = Q2, upper = Q3, ymax = Max), stat = "identity") +
  facet_wrap(~Ano) +
  ylim(0, 13) +
  tema_padrao +
  theme(legend.position = "none") +
  scale_fill_manual(values = c("chocolate", "lightblue", "darkgreen")) +
  labs(x = "Green classification", y = "Income (log)",
       title = glue("Boxplot of Log Income by Green Classification ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "renda_percentil.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


## Renda Média por classificação
ggplot(data = base_pnadc %>%
         filter(!is.na(class_verde_atividade)) %>%
         group_by(Ano, class_verde_atividade) %>%
         summarise(renda_media = weighted.mean(renda_hab_def, V1028, na.rm = TRUE), .groups = "drop") %>%
         group_by(class_verde_atividade) %>%
         mutate(rotulo = if_else(Ano %in% anos_graf, renda_media, NA_real_)),
       aes(x = Ano, y = renda_media, group = class_verde_atividade, colour = class_verde_atividade)) +
  geom_line(linewidth = 0.8) + geom_point() +
  geom_label(aes(label = round(rotulo)), size = 2.5, fill = "white", color = "black") +
  scale_color_manual(values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(title = "Average Income by Year and Classification", x = "Year", y = "Average income", color = "Classification")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "renda_media_class.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


## Histograma de renda
ggplot(data = base_pnadc %>%
         filter(!is.na(class_verde_atividade), Ano %in% anos_graf),
       aes(x = renda_hab_def, fill = class_verde_atividade), weight = V1028) +
  geom_histogram(binwidth = 5000, color = "black", alpha = 0.7) +
  facet_wrap(~ factor(class_verde_atividade, levels = NIVEIS_CLASS_ATIV), ncol = 1) +
  scale_fill_manual(values = CORES_CLASS_ATIV) +
  scale_y_log10(labels = label_number()) +
  scale_x_continuous(limits = c(0, 250000)) +
  tema_padrao +
  labs(title = glue("Logarithmic Income Histogram ({anos_graf[1]}-{anos_graf[2]})"),
       x = "Income", y = "Frequency", fill = "Classification")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "hist_renda.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7b. MAPAS ---

gerar_mapa_uf <- function(tabelas, class_valor, paleta, titulo) {
  dados_mapa <- tabelas[["regiao_uf"]] %>%
    ungroup() %>%
    filter(Ano %in% anos_graf, class_verde_atividade == class_valor) %>%
    mutate(name_state = make_clean_names(UF, allow_dupes = TRUE)) %>%
    left_join(geobr::read_state(year = 2019) %>%
                select(name_state) %>%
                mutate(name_state = make_clean_names(name_state))) %>%
    st_as_sf()

  limite <- c(min(dados_mapa$freq, na.rm = TRUE), max(dados_mapa$freq, na.rm = TRUE))

  ggplot() +
    geom_sf(data = dados_mapa, aes(fill = freq), color = NA, size = 0.15) +
    facet_grid(~Ano) +
    labs(subtitle = glue("{titulo} ({anos_graf[1]} - {anos_graf[2]})")) +
    scale_fill_distiller(palette = paleta, name = "", direction = 1, limits = limite) +
    theme_void()
}

gerar_mapa_uf(tabelas_class, "Brown",   "YlOrRd", "Proportion of Brown Jobs by State (UF)")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "mapa_empregos_sujos.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

gerar_mapa_uf(tabelas_class, "Neutral", "Blues",   "Proportion of Neutral Jobs by State (UF)")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "mapa_empregos_limpos.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

gerar_mapa_uf(tabelas_class, "Green",   "Greens",  "Proportion of Green Jobs by State (UF)")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "mapa_empregos_verdes.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7c. GRANDES REGIÕES ---

ggplot(
  data = tabelas_class[["regiao"]] %>%
    filter(Ano %in% anos_graf) %>%
    group_by(Ano, regiao) %>%
    mutate(freq = n * 100 / sum(n, na.rm = TRUE)),
  aes(x = regiao, y = freq, fill = class_verde_atividade)
) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  scale_fill_manual(values = c("Green" = "#1b9e77", "Brown" = "#d95f02", "Neutral" = "#7570b3")) +
  tema_padrao +
  labs(x = "Region", y = "Prop. (%)", fill = "Classification",
       title = glue("Proportion of Employed by Region ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "regiao_por_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7d. OCUPADOS ---

## Evolução por classificação (linhas)
ggplot(data = tabelas_class[["ocupacao"]] %>%
         filter(!is.na(formalidade)) %>%
         group_by(Ano, class_verde_atividade) %>%
         summarise(n = sum(n), .groups = "drop"),
       aes(x = Ano, y = n, color = class_verde_atividade, group = class_verde_atividade)) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  scale_color_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Number of Employed Persons",
       title = "Number of Employed Persons by Classification")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "qtd_ocupados_por_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

## Proporção empilhada
ggplot(data = tabelas_class[["ocupacao"]] %>%
         filter(!is.na(formalidade)) %>%
         group_by(Ano, class_verde_atividade) %>%
         summarise(n = sum(n), .groups = "drop") %>%
         group_by(Ano) %>%
         mutate(freq = (n / sum(n)) * 100),
       aes(x = Ano, y = freq, fill = class_verde_atividade)) +
  geom_bar(position = "stack", stat = "identity", color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  scale_fill_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Prop.", title = "Proportion of Employed Persons by Classification")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_ocupados_por_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

## Evolução individual por classificação (Green, Neutral, Brown)
for (cls in names(CORES_CLASS_ATIV)) {
  p <- ggplot(data = tabelas_class[["ocupacao"]] %>%
                filter(!is.na(formalidade)) %>%
                group_by(Ano, class_verde_atividade) %>%
                summarise(n = sum(n), .groups = "drop") %>%
                filter(class_verde_atividade == cls),
              aes(x = Ano, y = n, group = 1)) +
    geom_point(color = CORES_CLASS_ATIV[cls]) +
    geom_line(color = CORES_CLASS_ATIV[cls]) +
    scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
    tema_padrao +
    labs(x = "Year", y = "Number of employed", title = glue("Employed in {cls} occupations"))

  nome_arquivo <- tolower(cls)
  ggsave(file.path(CAMINHO_PRODUTOS_GRAF, glue("qtd_ocupados_{nome_arquivo}.png")),
         plot = p, bg = "white", dpi = 600, width = 8, height = 6)
}


# --- 7e. FORMALIDADE ---

ggplot(data = tabelas_class[["ocupacao"]] %>%
         filter(Ano %in% anos_graf, !is.na(formalidade)) %>%
         group_by(Ano, class_verde_atividade, formalidade) %>%
         summarise(n = sum(n), .groups = "drop") %>%
         group_by(Ano, class_verde_atividade) %>%
         mutate(freq = n / sum(n) * 100),
       aes(x = class_verde_atividade, y = freq, fill = formalidade)) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  tema_padrao +
  labs(x = "Classification", y = "Prop. (%)", fill = "Employment formality",
       title = glue("Proportion of Employed by Formality ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_formalidade_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7f. COR/RAÇA ---

ggplot(data = tabelas_class[["cor"]] %>%
         filter(Ano %in% anos_graf, V2010 != "Ignorado"),
       aes(x = class_verde_atividade, y = freq, fill = V2010)) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  scale_fill_discrete(labels = c("Brancos e Amarelos" = "White and Yellow",
                                 "Pretos, Pardos e Indígenas" = "Black and Indigenous")) +
  tema_padrao +
  labs(x = "Classification", y = "Prop. (%)", fill = "Race/Color",
       title = glue("Proportion by Race/Color and Classification ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_cor_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7g. ESCOLARIDADE ---

ggplot(data = base_pnadc %>%
         filter(Ano %in% anos_graf, !is.na(class_verde_atividade)) %>%
         mutate(VD3004 = case_when(
           VD3004 %in% c("Sem instrução e menos de 1 ano de estudo",
                         "Fundamental incompleto ou equivalente") ~ "Fundamental Incompleto",
           VD3004 %in% c("Fundamental completo ou equivalente",
                         "Médio incompleto ou equivalente")       ~ "Fundamental Completo",
           VD3004 %in% c("Médio completo ou equivalente",
                         "Superior incompleto ou equivalente")    ~ "Médio Completo",
           TRUE ~ "Superior Completo"
         )) %>%
         mutate(VD3004 = factor(VD3004,
                                levels = c("Fundamental Incompleto", "Fundamental Completo",
                                           "Médio Completo", "Superior Completo"))) %>%
         group_by(Ano, class_verde_atividade, VD3004) %>%
         summarise(qtd = sum(V1028), .groups = "drop_last") %>%
         mutate(freq = qtd / sum(qtd) * 100),
       aes(x = class_verde_atividade, y = freq, fill = VD3004)) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  scale_fill_discrete(labels = c("Fundamental Incompleto" = "Incomplete Primary",
                                 "Fundamental Completo"   = "Complete Primary",
                                 "Médio Completo"         = "Complete Secondary",
                                 "Superior Completo"      = "Complete Higher Ed.")) +
  tema_padrao +
  labs(x = "Classification", y = "Prop. (%)", fill = "Education",
       title = glue("Proportion by Educational Attainment ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_esc_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


## Escolaridade média ao longo do tempo
ggplot(data = tabelas_class[["escolaridade_anos"]] %>%
         mutate(VD3005 = as.integer(if_else(str_sub(VD3005, 1, 2) == "Se", "0", str_sub(VD3005, 1, 2)))) %>%
         group_by(Ano, class_verde_atividade) %>%
         summarise(esc_media = weighted.mean(VD3005, n), .groups = "drop") %>%
         mutate(cor_cls = CORES_CLASS_ATIV[class_verde_atividade]) %>%
         group_by(class_verde_atividade) %>%
         mutate(rotulo = if_else(Ano %in% anos_graf, esc_media, NA_real_)),
       aes(x = Ano, y = esc_media, group = class_verde_atividade, color = cor_cls)) +
  geom_point(size = 2) + geom_line(linewidth = 1) +
  geom_label(aes(label = round(rotulo)), size = 2.5, fill = "white", color = "black") +
  tema_padrao +
  labs(x = "Year", y = "Average Years of Schooling", color = "Classification",
       title = "Average Years of Schooling by Classification Type") +
  scale_color_identity(labels = c(darkgreen = "Green", lightblue = "Neutral", chocolate = "Brown"),
                       guide = "legend")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "escolaridade_media_por_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7h. REGIÃO METROPOLITANA ---

ggplot(data = tabelas_class[["regiao_metrop"]] %>% filter(Ano %in% anos_graf),
       aes(x = Ano, y = n, fill = class_verde_atividade)) +
  geom_bar(stat = "identity", position = "fill", colour = "black") +
  facet_grid(~regiao_metrop) +
  scale_fill_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Proportion", title = "Proportion of Employed by Metropolitan Region")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_regiao_metrop_barra.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_class[["regiao_metrop"]] %>% filter(Ano %in% anos_graf),
       aes(x = Ano, y = n, fill = class_verde_atividade)) +
  geom_bar(stat = "identity", position = "dodge", colour = "black") +
  facet_grid(~regiao_metrop) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  scale_fill_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Count", title = "Employed by Metropolitan Region")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "qtd_regiao_metrop_barra_lado.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7i. URBANO vs RURAL ---

ggplot(data = tabelas_class[["regiao_urbano_rural"]] %>% filter(Ano %in% anos_graf),
       aes(x = Ano, y = n, fill = class_verde_atividade)) +
  geom_col(colour = "black") +
  facet_grid(~V1022) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  scale_fill_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Count", title = "Employed by Area Type (Urban vs. Rural)")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "qtd_regiao_urbano_rural_empilhado.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)

ggplot(data = tabelas_class[["regiao_urbano_rural"]] %>% filter(Ano %in% anos_graf),
       aes(x = Ano, y = n, fill = class_verde_atividade)) +
  geom_bar(stat = "identity", position = "dodge", colour = "black") +
  facet_grid(~V1022) +
  scale_y_continuous(labels = function(x) format(x, scientific = FALSE)) +
  scale_fill_manual(name = "Classification", values = CORES_CLASS_ATIV) +
  tema_padrao +
  labs(x = "Year", y = "Count", title = "Number of Employed by Area Type (Urban vs. Rural)")
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "qtd_urbano_rural_barra.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7j. IDADE ---

ggplot(data = tabelas_class[["idade"]] %>%
         group_by(Ano, class_verde_atividade) %>%
         summarise(idade_media = weighted.mean(V2009, n), .groups = "drop") %>%
         mutate(cor_cls = CORES_CLASS_ATIV[class_verde_atividade]),
       aes(x = Ano, y = idade_media, group = class_verde_atividade, color = cor_cls)) +
  geom_point(size = 2) + geom_line(linewidth = 1) +
  labs(x = "Year", y = "Average Age", color = "Classification",
       title = "Average Age of Employed by Classification") +
  scale_color_identity(labels = c(darkgreen = "Green", lightblue = "Neutral", chocolate = "Brown"),
                       guide = "legend") +
  tema_padrao
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "idade_media_por_classif.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7k. GÊNERO ---

ggplot(data = tabelas_class[["genero"]] %>% filter(Ano %in% anos_graf),
       aes(x = class_verde_atividade, y = freq, fill = V2007)) +
  geom_col(width = 0.5, color = "black") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_stack(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  scale_fill_manual(name = "Gender", values = c("Homem" = "lightgreen", "Mulher" = "purple3"),
                    labels = c("Homem" = "Man", "Mulher" = "Woman")) +
  tema_padrao +
  labs(x = "Classification", y = "Prop. (%)",
       title = glue("Proportion of Men and Women by Classification ({anos_graf[1]}-{anos_graf[2]})"))
ggsave(file.path(CAMINHO_PRODUTOS_GRAF, "prop_genero_classif_alterna.png"),
       plot = last_plot(), bg = "white", dpi = 600, width = 8, height = 6)


# --- 7l. TREEMAPS DE ATIVIDADES ---

gerar_treemap <- function(base, class_valor, ano, nome_arquivo) {
  dados_tree <- base %>%
    filter(!is.na(formalidade), class_verde_atividade == class_valor, Ano == ano) %>%
    group_by(setor_cnae20_nome, cnaedom_nome) %>%
    summarise(qtd = round(sum(V1028)), .groups = "drop") %>%
    mutate(pct = sprintf("%d%%", round(qtd / sum(qtd) * 100)),
           rotulo = paste0(cnaedom_nome, "\n(", qtd, ")\n(", pct, ")"))

  total <- sum(dados_tree$qtd)

  ggplot(dados_tree, aes(area = qtd, fill = setor_cnae20_nome,
                         label = rotulo, subgroup = setor_cnae20_nome)) +
    geom_treemap() +
    geom_treemap_text(fontface = "italic", colour = "white", place = "centre",
                      grow = FALSE, reflow = TRUE) +
    geom_treemap_subgroup_border() +
    labs(caption = paste("Total:", total)) +
    theme(legend.position = "none", plot.caption = element_text(size = 25, hjust = 0))

  ggsave(file.path(CAMINHO_PRODUTOS_GRAF, nome_arquivo),
         plot = last_plot(), bg = "white", dpi = 800, width = 12, height = 8)
}

gerar_treemap(base_pnadc, "Brown",   ANO_FINAL, "arvore_ocup_sujas.png")
gerar_treemap(base_pnadc, "Neutral", ANO_FINAL, "arvore_ocup_Neutrals.png")
gerar_treemap(base_pnadc, "Green",   ANO_FINAL, "arvore_ocup_verdes.png")
