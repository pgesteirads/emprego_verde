###############################################################################
#                                                                             #
#   EMPREGO VERDE - 06. GERAÇÃO DE TABELAS (EXECUÇÃO)                         #
#                                                                             #
#   Constrói todas as tabelas descritivas e demográficas a partir de         #
#   base_pnadc. Deixa no ambiente global os objetos consumidos pelos          #
#   módulos 07 (gráficos) e 08 (exportação):                                  #
#     tabelas_class, tabelas_ativ, tabelas_setor, tabelas_ocup,               #
#     tabela_demog_wide, tabela_renda_wide, tabela_palma_wide, tabela_scn,    #
#     tabela_ocupados_total, renda_*_wide, palma_*_wide, vars_tabela,         #
#     aberturas_demog, anos_graf, e a função gerar_matriz_ocup_ativ().        #
#                                                                             #
#   ATENÇÃO: script de EXECUÇÃO. Requer base_pnadc e cnae_verde (módulo 05).  #
#   Dependências: 00_config.R, 04_funcoes_tabelas.R, 05_preparar_dados.R.     #
#   Origem: emprego_verde_consolidado.R, seção 6a.                            #
#                                                                             #
###############################################################################

message("  Gerando tabelas descritivas...")

# Variáveis para as tabelas descritivas
vars_tabela <- list(
  genero               = c("V2007"),
  cor                  = c("V2010"),
  ocupacao             = "formalidade",
  escolaridade_classif = c("VD3004"),
  escolaridade_anos    = c("VD3005"),
  idade                = c("V2009"),
  regiao_urbano_rural  = "V1022",
  regiao_metrop        = "regiao_metrop",
  regiao_uf            = "UF",
  regiao               = "regiao",
  renda_log_dev        = c("renda_log_dev"),
  renda_percentil      = c("renda_percentil"),
  renda_log_var        = c("renda_log_var"),
  renda_media          = c("renda_media")
)

# Tabelas por classificação verde
tabelas_class <- gerar_tabelas_descritivas(base_pnadc, vars_tabela,
                                           var_grupo = "class_verde_atividade")

# Tabelas por atividade (V4013)
tabelas_ativ <- gerar_tabelas_descritivas(base_pnadc, vars_tabela,
                                          var_grupo = "V4013")

# Tabelas por setor (setor_cnae20_cod)
tabelas_setor <- gerar_tabelas_descritivas(base_pnadc, vars_tabela,
                                           var_grupo = "setor_cnae20_cod")


# --- Tabelas demográficas comparativas ---

aberturas_demog <- c(
  "Gênero"                  = "V2007",
  "Raça"                    = "V2010",
  "Formalidade"             = "formalidade",
  "Contribuição para prev." = "VD4012",
  "Escolaridade"            = "escolaridade",
  "Faixa etária"            = "faixa_etaria",
  "Urbano x Rural"          = "V1022"
)

# Tabela demográfica (totais e percentuais)
tabela_demog_wide <- tabela_demografica(
  .data       = base_pnadc,
  ano_inicial = ANO_INICIAL,
  ano_final   = ANO_FINAL,
  aberturas   = aberturas_demog,
  var_setor   = "class_verde_setor",
  filtro      = quote(VD4002 == "Pessoas ocupadas")
)

# Tabela demográfica (renda média)
tabela_renda_wide <- tabela_demografica_renda(
  .data       = base_pnadc,
  ano_inicial = ANO_INICIAL,
  ano_final   = ANO_FINAL,
  aberturas   = aberturas_demog,
  var_setor   = "class_verde_atividade",
  filtro      = quote(VD4002 == "Pessoas ocupadas")
)

# Tabela demográfica (Índice de Palma)
tabela_palma_wide <- tabela_demografica_palma(
  .data       = base_pnadc,
  ano_inicial = ANO_INICIAL,
  ano_final   = ANO_FINAL,
  aberturas   = aberturas_demog,
  var_setor   = "class_verde_atividade",
  filtro      = quote(VD4002 == "Pessoas ocupadas")
)


# --- Tabela de ocupados por SCN e classificação verde ---

tabela_scn <- base_pnadc %>%
  filter(Ano %in% ANO_FINAL, VD4002 == "Pessoas ocupadas") %>%
  group_by(Ano, SCN, class_verde_atividade) %>%
  summarise(tot_ocup = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = c(Ano, class_verde_atividade), values_from = tot_ocup, values_fill = 0) %>%
  left_join(
    read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "Tradutor_KF.xlsx"),
              sheet = "CNAE x Harm x SCN") %>%
      select("SCN" = 5, "NomeSCN" = 6) %>% distinct() %>% filter(row_number() != 42)
  ) %>%
  select(SCN, NomeSCN, everything())


# --- Total de ocupados por classificação verde ---

tabela_ocupados_total <- base_pnadc %>%
  filter(VD4002 == "Pessoas ocupadas") %>%
  group_by(Ano, class_verde_setor) %>%
  summarise(tot_ocup = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = class_verde_setor, values_from = tot_ocup, values_fill = 0) %>%
  rename_with(~ paste0(.x, "_total"), -Ano) %>%
  mutate(total_geral = rowSums(across(ends_with("_total")), na.rm = TRUE)) %>%
  mutate(across(ends_with("_total"), ~ .x / total_geral, .names = "{.col}_percentual"))


# --- Renda média por classificação verde e formalidade ---

dados_renda <- base_pnadc %>%
  filter(Ano %in% c(ANO_INICIAL, ANO_FINAL), !is.na(renda_hab_def), renda_hab_def > 0)

renda_class_verde_wide <- dados_renda %>%
  group_by(Ano, class_verde_atividade) %>%
  summarise(renda_media = weighted.mean(renda_hab_def, V1028, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = class_verde_atividade, values_from = renda_media) %>%
  arrange(Ano)

renda_formal_setor_wide <- dados_renda %>%
  group_by(formalidade, class_verde_atividade, Ano) %>%
  summarise(renda_media = weighted.mean(renda_hab_def, V1028, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = c(class_verde_atividade, Ano), values_from = renda_media,
              names_sep = "_", values_fill = NA_real_) %>%
  arrange(formalidade)


# --- Palma por classificação verde e formalidade ---

palma_class_wide <- dados_renda %>%
  group_by(Ano, class_verde_atividade) %>%
  summarise(palma = indice_palma(renda_hab_def, V1028), .groups = "drop") %>%
  pivot_wider(names_from = class_verde_atividade, values_from = palma) %>%
  arrange(Ano)

palma_formal_wide <- dados_renda %>%
  group_by(formalidade, class_verde_atividade, Ano) %>%
  summarise(palma = indice_palma(renda_hab_def, V1028), .groups = "drop") %>%
  pivot_wider(names_from = c(class_verde_atividade, Ano), values_from = palma,
              names_sep = "_", values_fill = NA_real_) %>%
  arrange(formalidade)


# --- Tabelas por ocupação verde (Caruso) ---

tabelas_ocup <- gerar_tabelas_descritivas(
  base_pnadc %>% filter(Ano %in% c(ANO_INICIAL, ANO_FINAL)),
  vars_tabela[1:10],
  var_grupo = "class_verde_ocup"
)


# --- Matriz ocupação x atividade (função; usada no módulo 08) ---

gerar_matriz_ocup_ativ <- function(base, ano_i, ano_f) {
  fazer_xtab <- function(ano) {
    xtabs(V1028 ~ setor_cnae20_nome + class_verde_ocup, data = base %>% filter(Ano == ano)) %>%
      as.data.frame() %>%
      pivot_wider(names_from = class_verde_ocup, values_from = Freq) %>%
      mutate(across(where(is.numeric), ~ .x / rowSums(pick(where(is.numeric))), .names = "prop_{.col}")) %>%
      rename_with(~ paste(.x, ano, sep = "_"), .cols = -setor_cnae20_nome)
  }

  full_join(fazer_xtab(ano_i), fazer_xtab(ano_f), by = "setor_cnae20_nome") %>%
    left_join(cnae_verde %>% select(setor_cnae20_nome, class_verde_setor) %>% distinct()) %>%
    relocate(class_verde_setor, .after = setor_cnae20_nome) %>%
    mutate(across(where(is.numeric), ~ round(100 * .x, digits = 2)))
}
