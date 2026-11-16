###############################################################################
#                                                                             #
#   EMPREGO VERDE - 12. OCUPADOS POR SCN E CLASSIFICACAO VERDE (2012-2024)    #
#                                                                             #
#   Gera a tabela "Total de ocupados por SCN e classificacao verde" para      #
#   TODOS os anos com PNADc 4o trimestre disponiveis em dados/pnadc_trim/,    #
#   e nao apenas para ANO_FINAL (como faz o modulo 06).                       #
#                                                                             #
#   Script independente: le direto dos parquets trimestrais (so as colunas    #
#   necessarias), sem depender de base_pnadc_tratada_trimestral_4.parquet,    #
#   que so contem os anos de ANOS_ANALISE.                                    #
#                                                                             #
#   Mesmas regras do modulo 03:                                               #
#     - CNAE-Dom -> SCN via Tradutor_KF.xlsx (aba "CNAEDOM X SCN")            #
#     - Educacao e Saude separadas em publico/privado pela posicao (VD4009)   #
#     - Agricultura/Pecuaria, Mineracao e Quimica divididas pelas proporcoes  #
#       da TRU (SCN_PROPORCOES), via desagregar_scn()                         #
#   Diferenca: a desagregacao e feita ANO A ANO (cada ano respeita a          #
#   proporcao da TRU) e com semente fixa, para ser reprodutivel.              #
#                                                                             #
#   Uso: source("script/modulos/12_tabela_scn_todos_anos.R")                  #
#   Saida: analise_scn/ocupados_scn_classif_verde_2012_2024.xlsx              #
#                                                                             #
###############################################################################

# (00_config.R executa rm(list = ls()), por isso os caminhos sao montados inline)
source(here::here("script", "modulos", "00_config.R"), encoding = "latin1")
source(here("script", "modulos", "02_classificacoes_verdes.R"), encoding = "latin1")
source(here("script", "modulos", "03_tratamento_base.R"), encoding = "latin1")

set.seed(20241231)

# --- Leitura (somente colunas necessarias, todos os anos) ---
base <- arrow::open_dataset(list.files(CAMINHO_PNADC_TRIM, full.names = TRUE,
                                       pattern = "\\.parquet$")) %>%
  select(Ano, V1028, VD4002, V4013, VD4009, V2009) %>%
  filter(VD4002 == "Pessoas ocupadas") %>%
  collect() %>%
  mutate(V4013 = as.character(V4013), idade = as.integer(V2009)) %>%
  filter(!is.na(idade), idade >= 14)   # mesmo filtro do modulo 03

anos <- sort(unique(base$Ano))
message(glue("  Anos encontrados: {paste(anos, collapse = ', ')}"))

# --- Classificacao verde da atividade ---
cnae_verde <- gerar_classificacao_verde_cnae()
base <- base %>%
  left_join(cnae_verde %>% select(cnaedom_cod, class_verde_atividade),
            by = c("V4013" = "cnaedom_cod"))

# --- SCN ---
scn <- read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "Tradutor_KF.xlsx"),
                 sheet = "CNAEDOM X SCN") %>%
  select("V4013" = 1, "SCN" = 5) %>%
  mutate(V4013 = as.character(V4013), SCN = as.character(SCN))

base <- base %>% left_join(scn, by = "V4013")

posicoes_publicas <- c("Militar e servidor estatutário",
                       "Empregado no setor público com carteira de trabalho assinada",
                       "Empregado no setor público sem carteira de trabalho assinada")
cnae_educ  <- c("85011","85012","85013","85014","85021","85029")
cnae_saude <- c("86001","86002","86003","86004","86009","87000")

base <- base %>%
  mutate(SCN = case_when(
    V4013 %in% cnae_educ  &  VD4009 %in% posicoes_publicas ~ "8591",
    V4013 %in% cnae_educ  & !VD4009 %in% posicoes_publicas ~ "8592",
    V4013 %in% cnae_saude &  VD4009 %in% posicoes_publicas ~ "8691",
    V4013 %in% cnae_saude & !VD4009 %in% posicoes_publicas ~ "8692",
    TRUE ~ SCN
  ))

# Desagregacao pelas proporcoes da TRU, ano a ano
base <- base %>%
  group_split(Ano) %>%
  map(~ desagregar_scn(.x, SCN_PROPORCOES)) %>%
  bind_rows()

nome_scn <- read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "Tradutor_KF.xlsx"),
                      sheet = "CNAE x Harm x SCN") %>%
  select("SCN" = 5, "NomeSCN" = 6) %>%
  distinct() %>%
  filter(row_number() != 42) %>%
  mutate(SCN = as.character(SCN))

# --- Tabelas ---
tab_long <- base %>%
  mutate(class_verde_atividade = coalesce(class_verde_atividade, "Sem classificação")) %>%
  group_by(Ano, SCN, class_verde_atividade) %>%
  summarise(ocupados = sum(V1028, na.rm = TRUE), .groups = "drop") %>%
  left_join(nome_scn, by = "SCN") %>%
  select(Ano, SCN, NomeSCN, class_verde_atividade, ocupados) %>%
  arrange(Ano, SCN, class_verde_atividade)

ordem_class <- c("Brown", "Neutral", "Green", "Sem classificação")

# Formato igual ao da tabela original (colunas Ano_Classificacao)
tab_wide <- tab_long %>%
  mutate(class_verde_atividade = factor(class_verde_atividade, levels = ordem_class)) %>%
  arrange(Ano, class_verde_atividade) %>%
  pivot_wider(id_cols = c(SCN, NomeSCN),
              names_from = c(Ano, class_verde_atividade),
              values_from = ocupados, values_fill = 0) %>%
  arrange(SCN)

# Totais por ano e classificacao (conferencia)
tab_totais <- tab_long %>%
  group_by(Ano, class_verde_atividade) %>%
  summarise(ocupados = sum(ocupados), .groups = "drop") %>%
  pivot_wider(names_from = class_verde_atividade, values_from = ocupados, values_fill = 0) %>%
  select(Ano, any_of(ordem_class)) %>%
  mutate(Total = rowSums(across(-Ano)))

notas <- tibble(Nota = c(
  "Fonte: PNAD Contínua, 4º trimestre de cada ano (IBGE). Ocupados de 14 anos ou mais, ponderados por V1028.",
  "Classificação verde da atividade: class_verde_definitiva (Harmonizacao.xlsx), via classif_cnae_verde.xlsx.",
  "Tradução CNAE-Dom -> SCN: Tradutor_KF.xlsx. Educação e Saúde separadas em público/privado pela posição na ocupação (VD4009).",
  "Agricultura/Pecuária (01999), Mineração (07001/07002) e Química (20010/20090) divididas pelas proporções da TRU (0,534 / 0,495 / 0,526), por sorteio ponderado ano a ano (semente 20241231).",
  "'Sem classificação' = atividades mal definidas/sem código CNAE-Dom na harmonização.",
  "Gerado por script/modulos/12_tabela_scn_todos_anos.R."
))

dir.create(here("analise_scn"), showWarnings = FALSE)
arquivo_saida <- here("analise_scn", glue("ocupados_scn_classif_verde_{min(anos)}_{max(anos)}.xlsx"))
writexl::write_xlsx(list(
  "SCN x classif (wide)" = tab_wide,
  "SCN x classif (long)" = tab_long,
  "Totais por ano"       = tab_totais,
  "Notas"                = notas
), arquivo_saida)

message(glue("  [OK] Salvo: {arquivo_saida}"))
print(tab_totais)
