###############################################################################
#                                                                             #
#   EMPREGO VERDE - SCRIPT CONSOLIDADO                                        #
#                                                                             #
#   Projeto de análise de emprego verde no Brasil usando dados da PNADc       #
#   e classificações verdes de atividades (CNAE) e ocupações (CBO).           #
#                                                                             #
#   Este script consolida os seguintes scripts originais:                     #
#     - leitura_pnadc_trim_4.R      (Etapa 1)                                #
#     - gerando_class_verde.R       (Etapa 2)                                #
#     - gerando_class_verde_ocupacao.R (Etapa 2 - ocupação)                  #
#     - tratamento_base_dados.R     (Etapa 3)                                #
#     - exercicio_2025.R / pnadc.R  (Etapa 4 - análise principal)            #
#                                                                             #
#   Estrutura:                                                                #
#     0. Configurações e parâmetros globais                                   #
#     1. Leitura dos microdados da PNADc                                      #
#     2. Geração das classificações verdes (CNAE e CBO)                       #
#     3. Tratamento da base de dados                                          #
#     4. Inclusão de variáveis derivadas                                      #
#     5. Funções auxiliares para tabelas                                       #
#     6. Geração de tabelas descritivas                                       #
#     7. Geração de gráficos                                                  #
#     8. Exportação de resultados                                             #
#                                                                             #
###############################################################################


# =============================================================================
# 0. CONFIGURAÇÕES E PARÂMETROS GLOBAIS
# =============================================================================

options(encoding = "latin1")
options(scipen = 999)
options(digits = 3)

# --- Instalação e carregamento de pacotes ---

if (!require("librarian")) install.packages("librarian")

librarian::shelf(
  # Manipulação de dados
  tidyverse, data.table, janitor, glue,
  # Leitura/escrita de arquivos
  arrow, haven, rio, readxl, writexl, openxlsx,
  # PNADc
  PNADcIBGE,
  # Survey / pesos
  survey, srvyr, spatstat,
  # Banco de dados (BigQuery / RAIS)
  dbplyr, bigrquery,
  # Tabelas e relatórios
  gt, pander,
  # Visualização
  ggplot2, scales, RColorBrewer, treemapify,
  # Geoespacial
  geobr, sf,
  # Utilidades
  here, Hmisc
)

rm(list = ls())
gc()

# --- Parâmetros do exercício ---
# Altere aqui os anos, trimestres e classificação desejada

ANOS_ANALISE    <- c(2014, 2016, 2019, 2024)
TRIMESTRE       <- 4
ANO_INICIAL     <- 2014
ANO_FINAL       <- 2024

# Classificação verde escolhida (opções na planilha Harmonizacao.xlsx):
#   "class_verde_cnae20", "class_verde_cnae20_alternativo",
#   "class_verde_cnae20_alternativo_adm_pub", "class_verde_definitiva"
CLASS_ESCOLHIDA <- "class_verde_definitiva"

# Níveis das classificações verdes (para ordenar fatores)
NIVEIS_CLASS_ATIV  <- c("Brown", "Neutral", "Green")
CORES_CLASS_ATIV   <- c("Brown" = "chocolate", "Neutral" = "lightblue", "Green" = "darkgreen")

# Caminhos
CAMINHO_DADOS_REFERENCIA <- here("dados", "referencia")
CAMINHO_DADOS_PROCESSADOS <- here("dados", "processados")
CAMINHO_PNADC_TRIM      <- here("dados", "pnadc_trim")
CAMINHO_PRODUTOS_TAB    <- here("produtos", "tabelas")
CAMINHO_PRODUTOS_GRAF   <- here("produtos", "graficos")

# Aliases para compatibilidade com código legado
CAMINHO_DADOS_ORIGINAL  <- CAMINHO_DADOS_REFERENCIA
CAMINHO_DADOS_FINAL     <- CAMINHO_DADOS_PROCESSADOS

# Caminho dos microdados brutos do IBGE (dentro do projeto)
# Veja dados/microdados_ibge/LEIA-ME.txt para instruções de como popular esta pasta
CAMINHO_MICRODADOS_TRIM  <- here("dados", "microdados_ibge", "trimestral")
CAMINHO_DEFLATOR         <- here("dados", "microdados_ibge", "trimestral", "deflator_PNADC_2025_trimestral_040506.xls")

# Variáveis de interesse da PNADc
VARS_PNADC <- list(
  id           = c("Ano", "Trimestre", "UF", "Capital", "UPA", "Estrato", "V1008", "V1014", "V1028"),
  genero       = c("V2007"),
  cor          = c("V2010"),
  ocupacao     = c("V4010", "VD4009", "VD4002", "VD4012", "V4032"),
  escolaridade = c("VD3004", "VD3005"),
  idade        = c("V2009"),
  regiao       = c("V1022", "RM_RIDE", "UF"),
  atividade    = c("V4013"),
  renda        = c("VD4016")
)

VARS_VEC <- unique(unname(unlist(VARS_PNADC)))

# Parâmetros para desagregação SCN (proporções da TRU)
SCN_PROPORCOES <- list(
  list(cnae_alvo = "01999",           scn_1 = "0191", scn_2 = "0192", prop_1 = 0.534),
  list(cnae_alvo = c("07001","07002"), scn_1 = "0791", scn_2 = "0792", prop_1 = 0.495),
  list(cnae_alvo = c("20010","20090"), scn_1 = "2091", scn_2 = "2092", prop_1 = 0.526)
)


# =============================================================================
# 1. LEITURA DOS MICRODADOS DA PNADc
# =============================================================================
# Esta etapa lê os microdados brutos da PNADc e salva em formato parquet.
# Rode APENAS se os arquivos parquet ainda não existirem na pasta de dados.
# Após a primeira execução, os parquets ficam disponíveis para uso direto.

# --- Leitura PNADc Trimestral (4o trimestre) ---

ler_pnadc_trimestral <- function(anos = 2012:2024,
                                 caminho_microdados = CAMINHO_MICRODADOS_TRIM,
                                 caminho_saida = CAMINHO_PNADC_TRIM) {

  lista_arquivos <- list.files(path = caminho_microdados, full.names = TRUE)

  arquivos_input <- lista_arquivos[str_detect(lista_arquivos, "(?=.*txt)(?=.*input)")]
  arquivos_dict  <- lista_arquivos[str_detect(lista_arquivos, "(?=.*dicionario)")]

  for (ano in anos) {
    arquivo_saida <- glue("{caminho_saida}/pnadc_04{ano}.parquet")
    if (file.exists(arquivo_saida)) {
      message(glue("  [SKIP] {arquivo_saida} já existe."))
      next
    }

    message(glue("  Lendo PNADc trimestral {ano}..."))

    arquivos_micro <- lista_arquivos[
      !str_detect(lista_arquivos, "input") &
        str_detect(lista_arquivos, sprintf("PNADC_\\d{2}%s\\.txt$", ano))
    ]

    df <- read_pnadc(microdata = arquivos_micro, input_txt = arquivos_input) %>%
      pnadc_labeller(dictionary.file = arquivos_dict)

    arrow::write_parquet(df, arquivo_saida)
    message(glue("  [OK] Salvo: {arquivo_saida}"))
  }
}

# DESCOMENTE para executar a leitura (necessário apenas na primeira vez):
# ler_pnadc_trimestral()


# =============================================================================
# 2. GERAÇÃO DAS CLASSIFICAÇÕES VERDES
# =============================================================================

# --- 2a. Classificação verde das atividades (CNAE) ---
# Gera a tabela classif_cnae_verde.xlsx a partir da planilha de harmonização
# e dados da RAIS (BigQuery). Rode apenas se o arquivo não existir.

gerar_classificacao_verde_cnae <- function(class_escolhida = CLASS_ESCOLHIDA,
                                           anos_rais = c(2012, 2016, 2019, 2021)) {

  arquivo_saida <- file.path(CAMINHO_DADOS_FINAL, "classif_cnae_verde.xlsx")

  if (file.exists(arquivo_saida)) {
    message("  [SKIP] classif_cnae_verde.xlsx já existe.")
    return(read_xlsx(arquivo_saida))
  }

  message("  Gerando classificação verde CNAE...")

  # --- Puxar dados da RAIS via BigQuery ---
  arquivo_rais <- file.path(CAMINHO_DADOS_FINAL, "rais_vinculos.csv")

  if (file.exists(arquivo_rais)) {
    rais_vinculos <- read.csv(arquivo_rais) %>% select(-X)
  } else {
    message("    Conectando ao BigQuery para baixar RAIS...")
    con_rais <- dbConnect(bigquery(),
                          project = "basedosdados",
                          dataset = "br_me_rais",
                          billing = "emprego-verde")

    rais_microdados <- tbl(con_rais, "microdados_vinculos")

    rais_vinculos <- rais_microdados %>%
      select(ano, vinculo_ativo_3112, cnae_2_subclasse) %>%
      filter(ano %in% anos_rais, vinculo_ativo_3112 == 1) %>%
      group_by(ano, cnae_2_subclasse) %>%
      summarise(qtd_emprego = n()) %>%
      collect()

    # Converter subclasse (7 dígitos) para atividade (5 dígitos)
    rais_vinculos <- rais_vinculos %>%
      mutate(cnae_2_subclasse = str_extract(cnae_2_subclasse, "^\\d{5}")) %>%
      group_by(ano, cnae_2_subclasse) %>%
      summarise(qtd_emprego = sum(qtd_emprego)) %>%
      ungroup() %>%
      pivot_wider(names_from = ano, values_from = qtd_emprego, names_glue = "qtd_emprego_{ano}")

    write.csv(rais_vinculos, arquivo_rais)
  }

  # --- Ler e processar classificações verdes ---
  todas_classificacoes <- c("class_verde_cnae20", "class_verde_cnae20_alternativo",
                            "class_verde_cnae20_alternativo_adm_pub", "class_verde_definitiva")
  classificacoes_remover <- setdiff(todas_classificacoes, class_escolhida)

  class_verde_cnae20 <- read_xlsx(
    path = file.path(CAMINHO_DADOS_ORIGINAL, "Harmonizacao.xlsx"),
    col_names = TRUE,
    sheet = "ativ_cnaedom X ativ_cnae20"
  ) %>%
    select(-OBS, -all_of(classificacoes_remover)) %>%
    mutate(cnae20_atividade_codigo = str_replace_all(cnae20_atividade_codigo, "[-.]", "")) %>%
    rename("class_verde_cnae20" = all_of(class_escolhida))

  # Guardar info de setor antes de desduplicar

  class_verde_setor_cnae20 <- class_verde_cnae20 %>%
    select(V4013, cnae20_atividade_codigo, setor_cnae20_cod, setor_cnae20)

  # --- Resolver atividades duplicadas com classificações divergentes ---
  # Critério: manter a classificação da atividade com maior qtd de emprego

  class_verde_cnae20 <- class_verde_cnae20 %>%
    group_by(V4013, CNAE20.DOMICILIO.NOME) %>%
    mutate(cnae20_atividade_codigo = as.numeric(cnae20_atividade_codigo)) %>%
    left_join(rais_vinculos, by = c("cnae20_atividade_codigo" = "cnae_2_subclasse"))

  colunas_emprego <- names(rais_vinculos)[str_detect(names(rais_vinculos), "qtd_emprego")]
  primeira_coluna_per <- paste0(colunas_emprego[1], "_per")

  class_verde_cnae20 <- class_verde_cnae20 %>%
    mutate(across(all_of(colunas_emprego),
                  ~ (.x / sum(.x, na.rm = TRUE)) * 100,
                  .names = "{col}_per")) %>%
    group_by(V4013) %>%
    slice_max(order_by = !!sym(primeira_coluna_per))

  # --- Classificar setores ---
  class_verde_setor_cnae20 <- class_verde_setor_cnae20 %>%
    left_join(class_verde_cnae20 %>%
                select(V4013, class_verde_cnae20, all_of(colunas_emprego))) %>%
    select(-V4013) %>%
    distinct() %>%
    group_by(setor_cnae20_cod, setor_cnae20, class_verde_cnae20) %>%
    summarise(across(all_of(colunas_emprego), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
    filter(!is.na(!!sym(colunas_emprego[1]))) %>%
    group_by(setor_cnae20_cod) %>%
    slice_max(order_by = !!sym(colunas_emprego[1]))

  # --- Montar tabela final cnae_verde ---
  cnae_verde <- read_xlsx(
    path = file.path(CAMINHO_DADOS_ORIGINAL, "Harmonizacao.xlsx"),
    col_names = TRUE,
    sheet = "class_verde_cnaedom"
  ) %>%
    left_join(
      class_verde_cnae20 %>%
        select(V4013, class_verde_cnae20) %>%
        rename(class_verde_atividade = class_verde_cnae20),
      by = c("cnaedom_cod" = "V4013")
    ) %>%
    left_join(
      class_verde_setor_cnae20 %>%
        select(setor_cnae20_cod, class_verde_cnae20) %>%
        rename(class_verde_setor = class_verde_cnae20),
      by = "setor_cnae20_cod"
    ) %>%
    select(-class_verde_cnaedom, -class_verde_setor_cnae20) %>%
    relocate(class_verde_atividade, .before = setor_cnae20_cod)

  write_xlsx(cnae_verde, path = arquivo_saida)
  message(glue("  [OK] Salvo: {arquivo_saida}"))

  return(cnae_verde)
}


# --- 2b. Classificação verde das ocupações (CBO) ---
# Baseada em Caruso (2010). Retorna tabela de CBO domiciliar x classificação verde.

carregar_classificacao_verde_cbo <- function() {
  tab_caruso <- import(
    file.path(CAMINHO_DADOS_ORIGINAL, "cbodom_classverde_caruso.xlsx"),
    col_types = c("text", "text")
  ) %>%
    clean_names() %>%
    mutate(cod_ocupacao = str_sub(cod_ocupacao, 1, 4))

  return(tab_caruso)
}


# =============================================================================
# 3. TRATAMENTO DA BASE DE DADOS
# =============================================================================
# Seleciona variáveis, aplica deflator e salva base tratada.

tratar_base_pnadc <- function(anos = ANOS_ANALISE,
                              caminho_deflator = CAMINHO_DEFLATOR) {

  arquivo_saida <- here("dados", "base_pnadc_tratada_trimestral_4.parquet")

  if (file.exists(arquivo_saida)) {
    message("  [SKIP] Base tratada já existe. Carregando...")
    return(arrow::read_parquet(arquivo_saida))
  }

  message("  Tratando base PNADc...")

  # Ler parquets trimestrais
  base_pnadc <- arrow::open_dataset(list.files(CAMINHO_PNADC_TRIM, full.names = TRUE)) %>%
    select(all_of(VARS_VEC)) %>%
    filter(Ano %in% anos) %>%
    collect()

  # Incluir nomes das UFs
  uf_nome <- read_xlsx(here("dados", "uf_nome.xlsx"))
  base_pnadc <- base_pnadc %>% left_join(uf_nome)

  # Aplicar deflator
  deflator <- read_xls(caminho_deflator) %>%
    rename(Ano = Ano, Trimestre = trim, uf = UF) %>%
    filter(Trimestre %in% c("01-02-03", "04-05-06", "07-08-09", "10-11-12")) %>%
    mutate(
      uf = as.numeric(uf),
      Trimestre = as.character(match(Trimestre, c("01-02-03", "04-05-06", "07-08-09", "10-11-12")))
    ) %>%
    select(Ano, Trimestre, uf, Habitual)

  base_pnadc <- base_pnadc %>% left_join(deflator)

  arrow::write_parquet(base_pnadc, arquivo_saida)
  message(glue("  [OK] Salvo: {arquivo_saida}"))

  return(base_pnadc)
}


# =============================================================================
# 4. INCLUSÃO DE VARIÁVEIS DERIVADAS
# =============================================================================
# Adiciona à base: setor CNAE, região, formalidade, cor agrupada,
# região metropolitana, classificação verde (atividade e ocupação),
# renda deflacionada, escolaridade agrupada, faixa etária e SCN.

incluir_variaveis_derivadas <- function(base_pnadc) {

  message("  Incluindo variáveis derivadas...")

  # --- Setor CNAE 2.0 ---
  # As colunas de setor (setor_cnae20_cod, setor_cnae20_nome, cnaedom_nome e
  # class_verde_setor) são incluídas mais abaixo, a partir de `cnae_verde`, que
  # é a fonte autoritativa. A leitura da 1a aba de Harmonizacao.xlsx foi
  # removida porque aquela aba ("CNAEDom2.0 x CNAE2.0 x Harmoniz") não contém
  # essas colunas — era a causa de o erro "setor_cnae20_cod não existe".

  # --- Região geográfica ---
  uf_regiao <- read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "uf_regiao.xlsx"), col_names = TRUE)
  base_pnadc <- left_join(base_pnadc, uf_regiao) %>%
    relocate(regiao, .after = UF)

  # --- Formalidade ---
  base_pnadc <- base_pnadc %>%
    mutate(
      vd4009_txt = str_squish(VD4009),
      formalidade = case_when(
        is.na(VD4009) & is.na(V4032)                                                              ~ "Ocupado sem informação",
        vd4009_txt == "Trabalhador familiar auxiliar" & is.na(V4032)                               ~ "Ocupado sem informação",
        vd4009_txt == "Empregado no setor privado com carteira de trabalho assinada" & is.na(V4032) ~ "Formal",
        vd4009_txt == "Trabalhador doméstico com carteira de trabalho assinada" & is.na(V4032)      ~ "Formal",
        vd4009_txt == "Empregado no setor público com carteira de trabalho assinada" & is.na(V4032) ~ "Formal",
        vd4009_txt == "Militar e servidor estatutário" & is.na(V4032)                               ~ "Formal",
        vd4009_txt == "Conta-própria" & V4032 == "Não"    ~ "Informal - Conta própria",
        vd4009_txt == "Conta-própria" & V4032 == "Sim"    ~ "Formal",
        vd4009_txt == "Empregador" & V4032 == "Sim"       ~ "Formal",
        vd4009_txt == "Empregador" & V4032 == "Não"       ~ "Informal",
        vd4009_txt == "Empregado no setor privado sem carteira de trabalho assinada" & V4032 == "Não" ~ "Informal - Sem carteira",
        vd4009_txt == "Empregado no setor privado sem carteira de trabalho assinada" & V4032 == "Sim" ~ "Formal",
        vd4009_txt == "Empregado no setor público sem carteira de trabalho assinada" & V4032 == "Sim" ~ "Informal - Sem carteira",
        vd4009_txt == "Empregado no setor público sem carteira de trabalho assinada" & V4032 == "Não" ~ "Informal",
        vd4009_txt == "Trabalhador doméstico sem carteira de trabalho assinada" & V4032 == "Não"       ~ "Informal",
        vd4009_txt == "Trabalhador doméstico sem carteira de trabalho assinada" & V4032 == "Sim"       ~ "Formal",
        TRUE ~ "Ocupado sem informação"
      ),
      formalidade = factor(formalidade,
                           levels = c("Formal", "Informal - Sem carteira",
                                      "Informal - Conta própria", "Informal",
                                      "Ocupado sem informação"))
    ) %>%
    select(-vd4009_txt) %>%
    relocate(formalidade, .after = V4032)

  # --- Cor/raça agrupada ---
  base_pnadc <- base_pnadc %>%
    mutate(V2010 = case_when(
      V2010 %in% c("Branca", "Amarela")           ~ "Brancos e Amarelos",
      V2010 %in% c("Preta", "Parda", "Indígena")  ~ "Pretos, Pardos e Indígenas",
      TRUE                                         ~ "Ignorado"
    ))

  # --- Região metropolitana ---
  base_pnadc <- base_pnadc %>%
    mutate(regiao_metrop = if_else(str_detect(RM_RIDE, "Região"), "Sim", "Não"))

  # --- Classificação verde por atividade (CNAE) ---
  cnae_verde <- gerar_classificacao_verde_cnae()

  # Remove colunas se já existirem (para reprocessamento)
  cols_remover <- intersect(c("cnaedom_nome", "class_verde_atividade",
                               "setor_cnae20_cod", "setor_cnae20_nome", "class_verde_setor"),
                            colnames(base_pnadc))
  if (length(cols_remover) > 0) {
    base_pnadc <- base_pnadc %>% select(-all_of(cols_remover))
  }

  base_pnadc <- base_pnadc %>%
    left_join(cnae_verde %>% select(cnaedom_cod, cnaedom_nome, class_verde_atividade,
                                    setor_cnae20_cod, setor_cnae20_nome, class_verde_setor),
              by = c("V4013" = "cnaedom_cod"))

  # --- Classificação verde por ocupação (CBO - Caruso 2010) ---
  tab_caruso <- carregar_classificacao_verde_cbo()
  base_pnadc <- base_pnadc %>%
    left_join(tab_caruso, by = c("V4010" = "cod_ocupacao"))

  # --- Renda habitual deflacionada ---
  base_pnadc <- base_pnadc %>%
    mutate(renda_hab_def = VD4016 * Habitual)

  # --- Quartis de renda e medidas de dispersão ---
  base_pnadc <- base_pnadc %>%
    mutate(renda_percentil = cut(
      renda_hab_def,
      breaks = weighted.quantile(renda_hab_def, w = V1028, probs = seq(0, 1, by = 0.25), na.rm = TRUE),
      labels = c("Q1", "Q2", "Q3", "Q4"),
      include.lowest = TRUE
    )) %>%
    group_by(Ano, class_verde_atividade) %>%
    mutate(
      renda_log_var = as.vector(weighted.var(log(renda_hab_def), w = V1028, na.rm = TRUE)),
      renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def), w = V1028, na.rm = TRUE)))
    ) %>%
    ungroup()

  # --- Escolaridade agrupada ---
  base_pnadc <- base_pnadc %>%
    mutate(
      escolaridade = fct_collapse(
        VD3004,
        "Fundamental incompleto" = c("Sem instrução e menos de 1 ano de estudo",
                                     "Fundamental incompleto ou equivalente"),
        "Fundamental completo"   = "Fundamental completo ou equivalente",
        "Médio completo"         = "Médio completo ou equivalente",
        "Superior completo"      = "Superior completo"
      ) %>%
        fct_relevel("Fundamental incompleto", "Fundamental completo",
                    "Médio completo", "Superior completo")
    )

  # --- Faixa etária ---
  base_pnadc <- base_pnadc %>%
    mutate(idade = as.integer(V2009)) %>%
    filter(!is.na(idade), idade >= 14) %>%
    mutate(
      faixa_etaria = case_when(
        idade <= 24 ~ "14–24",
        idade <= 39 ~ "25–39",
        idade <= 59 ~ "40–59",
        idade >= 60 ~ "60+"
      ),
      faixa_etaria = factor(faixa_etaria, levels = c("14–24", "25–39", "40–59", "60+"))
    )

  # --- Categorias SCN ---
  scn <- read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "Tradutor_KF.xlsx"),
                   sheet = "CNAEDOM X SCN") %>%
    select("V4013" = 1, 5)

  base_pnadc <- base_pnadc %>% left_join(scn)

  # Educação e Saúde: componente público vs privado
  posicoes_publicas <- c("Militar e servidor estatutário",
                         "Empregado no setor público com carteira de trabalho assinada",
                         "Empregado no setor público sem carteira de trabalho assinada")

  base_pnadc <- base_pnadc %>%
    mutate(SCN = case_when(
      V4013 %in% c("85011","85012","85013","85014","85021","85029") &  VD4009 %in% posicoes_publicas ~ "8591",
      V4013 %in% c("85011","85012","85013","85014","85021","85029") & !VD4009 %in% posicoes_publicas ~ "8592",
      V4013 %in% c("86001","86002","86003","86004","86009","87000") &  VD4009 %in% posicoes_publicas ~ "8691",
      V4013 %in% c("86001","86002","86003","86004","86009","87000") & !VD4009 %in% posicoes_publicas ~ "8692",
      TRUE ~ SCN
    ))

  # Desagregar CNAEs por proporções da TRU (Agricultura, Mineração, Química)
  base_pnadc <- desagregar_scn(base_pnadc, SCN_PROPORCOES)

  # Nome SCN
  nome_scn <- read_xlsx(file.path(CAMINHO_DADOS_ORIGINAL, "Tradutor_KF.xlsx"),
                        sheet = "CNAE x Harm x SCN") %>%
    select("SCN" = 5, "NomeSCN" = 6) %>%
    distinct() %>%
    filter(row_number() != 42)

  base_pnadc <- base_pnadc %>% left_join(nome_scn)

  message("  [OK] Variáveis derivadas incluídas.")
  return(base_pnadc)
}


# --- Função auxiliar: desagregar SCN por proporção ponderada ---

desagregar_scn <- function(base, lista_proporcoes) {

  for (params in lista_proporcoes) {
    cnae_alvo <- params$cnae_alvo
    scn_1     <- params$scn_1
    scn_2     <- params$scn_2
    prop_1    <- params$prop_1

    base <- base %>%
      mutate(.id = row_number(), V4013 = as.character(V4013), SCN = as.character(SCN))

    base_alvo <- base %>% filter(V4013 %in% cnae_alvo)
    base_rest <- base %>% filter(!(V4013 %in% cnae_alvo))

    if (nrow(base_alvo) > 0) {
      total_w   <- sum(base_alvo$V1028, na.rm = TRUE)
      target    <- prop_1 * total_w

      base_alvo <- base_alvo %>%
        mutate(.u = runif(n())) %>%
        arrange(.u) %>%
        mutate(.cumw = cumsum(V1028))

      k <- which(base_alvo$.cumw >= target)[1]

      if (is.na(k)) {
        base_alvo <- base_alvo %>% mutate(SCN = scn_1)
      } else {
        cum_prev <- if (k == 1) 0 else base_alvo$.cumw[k - 1]
        w_k      <- base_alvo$V1028[k]

        err_if_1 <- abs((cum_prev + w_k) - target)
        err_if_2 <- abs(cum_prev - target)
        boundary_to_1 <- err_if_1 <= err_if_2

        base_alvo <- base_alvo %>%
          mutate(SCN = case_when(
            row_number() < k ~ scn_1,
            row_number() > k ~ scn_2,
            TRUE ~ if_else(boundary_to_1, scn_1, scn_2)
          ))
      }

      base <- bind_rows(base_rest, base_alvo %>% select(-.u, -.cumw)) %>%
        arrange(.id) %>%
        select(-.id)
    } else {
      base <- base %>% select(-.id)
    }
  }

  return(base)
}


# =============================================================================
# 5. FUNÇÕES AUXILIARES PARA TABELAS
# =============================================================================

# --- 5a. Função genérica: gera tabela descritiva por agrupamento ---
# Usada para gerar tabelas_class, tabelas_ativ e tabelas_setor de forma
# parametrizada, eliminando a repetição massiva de código.

gerar_tabelas_descritivas <- function(base, vars_tabela, var_grupo,
                                      niveis_factor = NIVEIS_CLASS_ATIV,
                                      filtro_grupo = TRUE) {

  vars_vec <- unlist(unname(vars_tabela))

  tabelas <- map(vars_vec, function(i) {

    # Filtro inicial: remover NAs do grupo se necessário
    df <- if (filtro_grupo) base %>% filter(!is.na(!!sym(var_grupo))) else base

    if (i == "renda_log_dev") {
      df %>%
        group_by(Ano, !!sym(var_grupo)) %>%
        summarise(renda_log_dev = as.vector(sqrt(weighted.var(log(renda_hab_def), w = V1028, na.rm = TRUE))),
                  .groups = "drop") %>%
        pivot_wider(names_from = Ano, values_from = renda_log_dev)

    } else if (i == "renda_percentil") {
      df %>%
        group_by(Ano, !!sym(var_grupo)) %>%
        summarise(
          Min = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0, na.rm = TRUE)),
          Q1  = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.25, na.rm = TRUE)),
          Q2  = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.50, na.rm = TRUE)),
          Q3  = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 0.75, na.rm = TRUE)),
          Max = as.vector(weighted.quantile(log(renda_hab_def), w = V1028, probs = 1, na.rm = TRUE)),
          .groups = "drop"
        )

    } else if (i == "renda_log_var") {
      df %>%
        group_by(Ano, !!sym(var_grupo)) %>%
        summarise(renda_log_var = as.vector(weighted.var(log(renda_hab_def), w = V1028, na.rm = TRUE)),
                  .groups = "drop") %>%
        pivot_wider(names_from = Ano, values_from = renda_log_var)

    } else if (i == "renda_media") {
      df %>%
        filter(!is.na(formalidade)) %>%
        group_by(Ano, !!sym(var_grupo)) %>%
        summarise(renda_media = weighted.mean(renda_hab_def, w = V1028, na.rm = TRUE),
                  .groups = "drop")

    } else if (i == "UF") {
      df %>%
        group_by(Ano, !!sym(i), !!sym(var_grupo)) %>%
        summarise(n = sum(V1028), .groups = "drop_last") %>%
        mutate(freq = (n / sum(n)) * 100) %>%
        ungroup()

    } else if (i == "formalidade") {
      df %>%
        filter(!is.na(formalidade)) %>%
        group_by(Ano, formalidade, !!sym(var_grupo)) %>%
        summarise(n = sum(V1028), .groups = "drop_last") %>%
        mutate(freq = (n / sum(n)) * 100) %>%
        ungroup()

    } else {
      df %>%
        group_by(Ano, !!sym(var_grupo), !!sym(i)) %>%
        summarise(n = sum(V1028), .groups = "drop_last") %>%
        mutate(freq = (n / sum(n)) * 100) %>%
        ungroup()
    }
  })

  names(tabelas) <- names(vars_tabela)
  return(tabelas)
}


# --- 5b. Tabela demográfica comparativa (dois anos, com aberturas) ---

tabela_demografica <- function(.data, ano_inicial, ano_final, aberturas,
                               var_ano = "Ano", var_peso = "V1028",
                               var_setor = "class_verde_setor",
                               filtro = NULL, em_pct = TRUE,
                               fill_zero = TRUE, setor_em_wide = TRUE) {

  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))

  faz_bloco <- function(var_cat, lbl_abertura) {
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(total = sum(.data[[var_peso]], na.rm = TRUE), .groups = "drop_last") %>%
      group_by(.data[[var_ano]], .data[[var_setor]]) %>%
      mutate(total_abertura = sum(total, na.rm = TRUE),
             pct = if (em_pct) 100 * total / total_abertura else total / total_abertura) %>%
      ungroup() %>%
      rename(Ano = !!var_ano, setor = !!var_setor, categoria = !!var_cat) %>%
      mutate(Ano = as.integer(Ano), abertura = lbl_abertura)

    if (fill_zero) {
      cats    <- df %>% distinct(!!sym(var_cat))  %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)

      grid <- expand_grid(Ano = as.integer(c(ano_inicial, ano_final)),
                          setor = setores, categoria = cats) %>%
        mutate(abertura = lbl_abertura)

      bloco <- grid %>%
        left_join(bloco, by = c("Ano", "setor", "categoria", "abertura")) %>%
        mutate(total = replace_na(total, 0)) %>%
        group_by(Ano, setor) %>%
        mutate(
          total_abertura = if_else(is.na(total_abertura), sum(total, na.rm = TRUE), total_abertura),
          pct = if (em_pct) if_else(total_abertura > 0, 100 * total / total_abertura, 0)
          else if_else(total_abertura > 0, total / total_abertura, 0)
        ) %>%
        ungroup()
    }

    # Pivotar para wide
    bloco_w <- bloco %>%
      select(abertura, setor, categoria, Ano, total, pct) %>%
      pivot_wider(names_from = Ano, values_from = c(total, pct), names_sep = "_")

    if (setor_em_wide) {
      cols_value <- c(paste0("total_", ano_inicial), paste0("pct_", ano_inicial),
                      paste0("total_", ano_final),   paste0("pct_", ano_final))
      bloco_w <- bloco_w %>%
        pivot_wider(names_from = setor, values_from = all_of(cols_value),
                    names_glue = "{setor}_{.value}")

      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_cols <- unlist(lapply(setores_ord, function(s) paste0(s, "_", cols_value)))
      bloco_w <- bloco_w %>% select(abertura, categoria, any_of(ordem_cols))
    }
    bloco_w
  }

  imap_dfr(aberturas, faz_bloco) %>% arrange(abertura, categoria)
}


# --- 5c. Tabela demográfica de renda média ---

tabela_demografica_renda <- function(.data, ano_inicial, ano_final, aberturas,
                                     var_ano = "Ano", var_peso = "V1028",
                                     var_setor = "class_verde_atividade",
                                     var_renda = "renda_hab_def",
                                     filtro = NULL, fill_missing = TRUE,
                                     setor_em_wide = TRUE) {

  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))

  faz_bloco <- function(var_cat, lbl_abertura) {
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(
        w_sum  = sum(.data[[var_peso]] * (!is.na(.data[[var_renda]])), na.rm = TRUE),
        w_ySum = sum(.data[[var_peso]] * .data[[var_renda]], na.rm = TRUE),
        renda_media = if_else(w_sum > 0, w_ySum / w_sum, NA_real_),
        .groups = "drop"
      ) %>%
      rename(Ano = !!var_ano, setor = !!var_setor, categoria = !!var_cat) %>%
      mutate(Ano = as.integer(Ano), abertura = lbl_abertura) %>%
      select(abertura, Ano, setor, categoria, renda_media)

    if (fill_missing) {
      cats    <- df %>% distinct(!!sym(var_cat))   %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)

      grid <- expand_grid(Ano = as.integer(c(ano_inicial, ano_final)),
                          setor = setores, categoria = cats) %>%
        mutate(abertura = lbl_abertura)

      bloco <- grid %>% left_join(bloco, by = c("abertura", "Ano", "setor", "categoria"))
    }

    bloco_w <- bloco %>%
      pivot_wider(names_from = Ano, values_from = renda_media, names_prefix = "renda_media_")

    if (setor_em_wide) {
      cols_value <- c(paste0("renda_media_", ano_inicial), paste0("renda_media_", ano_final))
      bloco_w <- bloco_w %>%
        pivot_wider(names_from = setor, values_from = all_of(cols_value),
                    names_glue = "{setor}_{.value}")

      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_cols <- unlist(lapply(setores_ord, function(s) paste0(s, "_", cols_value)))
      bloco_w <- bloco_w %>% select(abertura, categoria, any_of(ordem_cols))
    }
    bloco_w
  }

  imap_dfr(aberturas, faz_bloco) %>% arrange(abertura, categoria)
}


# --- 5d. Índice de Palma ponderado ---

indice_palma <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & is.finite(x) & is.finite(w) & (w > 0)
  if (!any(ok)) return(NA_real_)

  x <- x[ok]; w <- w[ok]
  if (length(x) < 2) return(NA_real_)

  qs <- tryCatch(
    Hmisc::wtd.quantile(x, weights = w, probs = c(0.40, 0.90), na.rm = TRUE, type = "quantile"),
    error = function(e) rep(NA_real_, 2)
  )

  p40 <- unname(qs[1]); p90 <- unname(qs[2])
  if (is.na(p40) || is.na(p90) || p40 <= 0) return(NA_real_)

  idx_pobres <- x <= p40; idx_ricos <- x >= p90
  if (!any(idx_pobres) || !any(idx_ricos)) return(NA_real_)

  renda_pobres <- sum(x[idx_pobres] * w[idx_pobres], na.rm = TRUE)
  renda_ricos  <- sum(x[idx_ricos]  * w[idx_ricos],  na.rm = TRUE)

  if (!is.finite(renda_pobres) || renda_pobres <= 0) return(NA_real_)
  renda_ricos / renda_pobres
}


# --- 5e. Tabela demográfica do Índice de Palma ---

tabela_demografica_palma <- function(.data, ano_inicial, ano_final, aberturas,
                                     var_ano = "Ano", var_peso = "V1028",
                                     var_setor = "class_verde_atividade",
                                     var_renda = "renda_hab_def",
                                     filtro = NULL, fill_missing = TRUE,
                                     setor_em_wide = TRUE) {

  df <- .data %>%
    { if (!is.null(filtro)) filter(., !!filtro) else . } %>%
    mutate(!!var_ano := as.integer(.data[[var_ano]])) %>%
    filter(.data[[var_ano]] %in% c(ano_inicial, ano_final))

  faz_bloco <- function(var_cat, lbl_abertura) {
    bloco <- df %>%
      group_by(.data[[var_ano]], .data[[var_setor]], .data[[var_cat]], .drop = FALSE) %>%
      summarise(palma = indice_palma(.data[[var_renda]], .data[[var_peso]]),
                .groups = "drop") %>%
      rename(Ano = !!var_ano, setor = !!var_setor, categoria = !!var_cat) %>%
      mutate(Ano = as.integer(Ano), abertura = lbl_abertura) %>%
      select(abertura, Ano, setor, categoria, palma)

    if (fill_missing) {
      cats    <- df %>% distinct(!!sym(var_cat))   %>% pull(1)
      setores <- df %>% distinct(!!sym(var_setor)) %>% pull(1)

      grid <- expand_grid(Ano = as.integer(c(ano_inicial, ano_final)),
                          setor = setores, categoria = cats) %>%
        mutate(abertura = lbl_abertura)

      bloco <- grid %>% left_join(bloco, by = c("abertura", "Ano", "setor", "categoria"))
    }

    bloco_w <- bloco %>%
      pivot_wider(names_from = Ano, values_from = palma, names_prefix = "palma_")

    if (setor_em_wide) {
      cols_value <- c(paste0("palma_", ano_inicial), paste0("palma_", ano_final))
      bloco_w <- bloco_w %>%
        pivot_wider(names_from = setor, values_from = all_of(cols_value),
                    names_glue = "{setor}_{.value}")

      setores_ord <- df %>% distinct(!!sym(var_setor)) %>% pull(1)
      ordem_cols <- unlist(lapply(setores_ord, function(s) paste0(s, "_", cols_value)))
      bloco_w <- bloco_w %>% select(abertura, categoria, any_of(ordem_cols))
    }
    bloco_w
  }

  imap_dfr(aberturas, faz_bloco) %>% arrange(abertura, categoria)
}


# --- 5f. Formatação Excel (workbook openxlsx) ---

sanitize_sheet <- function(x) {
  x <- gsub("[:\\\\/?*\\[\\]]", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(substr(x, 1, 31))
  ifelse(nchar(x) == 0, "Aba", x)
}

apply_number_formats <- function(wb, sheet, df) {
  cols_total <- grep("_total_", names(df))
  cols_pct   <- grep("_pct_",   names(df))

  if (length(cols_pct) > 0) {
    need_divide <- any(suppressWarnings(sapply(df[cols_pct], function(x) max(x, na.rm = TRUE))) > 1)
    if (need_divide) for (j in cols_pct) df[[j]] <- df[[j]] / 100
  }

  writeData(wb, sheet, df, withFilter = TRUE)
  addStyle(wb, sheet, createStyle(textDecoration = "bold"),
           rows = 1, cols = 1:ncol(df), gridExpand = TRUE)

  if (length(cols_total) > 0)
    addStyle(wb, sheet, createStyle(numFmt = "0"),
             rows = 2:(nrow(df) + 1), cols = cols_total, gridExpand = TRUE)

  if (length(cols_pct) > 0)
    addStyle(wb, sheet, createStyle(numFmt = "0.0%"),
             rows = 2:(nrow(df) + 1), cols = cols_pct, gridExpand = TRUE)

  setColWidths(wb, sheet, cols = 1:ncol(df), widths = "auto")
  freezePane(wb, sheet, firstActiveRow = 2, firstActiveCol = 1)
  invisible(df)
}

salvar_excel_formatado <- function(wb, caminho) {
  saveWorkbook(wb, caminho, overwrite = TRUE)
  message(glue("  [OK] Salvo: {caminho}"))
}


# =============================================================================
# 6. EXECUÇÃO PRINCIPAL - CARREGAR E PREPARAR DADOS
# =============================================================================

message("=== INÍCIO DA EXECUÇÃO ===")

# Etapa 3: Tratar base
base_pnadc <- tratar_base_pnadc()

# Etapa 4: Incluir variáveis derivadas
base_pnadc <- incluir_variaveis_derivadas(base_pnadc)

# Carregar cnae_verde para uso nas exportações
cnae_verde <- read_xlsx(file.path(CAMINHO_DADOS_FINAL, "classif_cnae_verde.xlsx"))


# =============================================================================
# 6a. GERAÇÃO DE TABELAS DESCRITIVAS
# =============================================================================

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


# --- Matriz ocupação x atividade ---

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


# =============================================================================
# 7. GRÁFICOS
# =============================================================================

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
  geom_col(width = 0.5, color = "black", position = "fill") +
  geom_label(aes(label = paste0(round(freq), "%")),
             position = position_fill(vjust = 0.5), size = 2.5, fill = "white") +
  facet_wrap(~Ano) +
  scale_fill_manual(values = c("Green" = "#1b9e77", "Brown" = "#d95f02", "Neutral" = "#7570b3")) +
  tema_padrao +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1))+
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


# =============================================================================
# 8. EXPORTAÇÃO DE RESULTADOS
# =============================================================================

message("  Exportando resultados...")

# --- 8a. Tabelas descritivas em Excel ---

write.xlsx(tabelas_class,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_class.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_ativ,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_ativ.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_setor,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_setor.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)

write.xlsx(tabelas_ocup,
           file = file.path(CAMINHO_PRODUTOS_TAB, "tabelas_ocup.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)


# --- 8b. Total de ocupados por classificação ---

writexl::write_xlsx(tabela_ocupados_total,
                    path = file.path(CAMINHO_PRODUTOS_TAB, "ocupados_por_classif.xlsx"))


# --- 8c. Total de ocupados por SCN ---

writexl::write_xlsx(tabela_scn, "Total de ocupados por SCN e classificação verde.xlsx")


# --- 8d. Tabela demográfica formatada ---

wb <- createWorkbook()

addWorksheet(wb, "Tabela Demográfica")
apply_number_formats(wb, "Tabela Demográfica", tabela_demog_wide)

abas <- tabela_demog_wide %>% distinct(abertura) %>% pull()
sheet_names <- make.unique(sanitize_sheet(abas), sep = " ")

for (i in seq_along(abas)) {
  df_sub <- tabela_demog_wide %>% filter(abertura == abas[i]) %>% select(-abertura)
  addWorksheet(wb, sheet_names[i])
  apply_number_formats(wb, sheet_names[i], df_sub)
}

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "tabela_demografica.xlsx"))


# --- 8e. Tabela de renda média ---

writexl::write_xlsx(tabela_renda_wide,
                    file.path(CAMINHO_PRODUTOS_TAB, "tabela_renda_wide.xlsx"))


# --- 8f. Renda média por classificação e formalidade ---

wb <- createWorkbook()
addWorksheet(wb, "Renda x Class (wide)")
addWorksheet(wb, "Renda x Setor x Ano")

writeData(wb, "Renda x Class (wide)", renda_class_verde_wide, withFilter = TRUE)
writeData(wb, "Renda x Setor x Ano", renda_formal_setor_wide, withFilter = TRUE)

estilo_hdr   <- createStyle(textDecoration = "bold")
estilo_moeda <- createStyle(numFmt = "R$ #,##0.00")

for (aba in c("Renda x Class (wide)", "Renda x Setor x Ano")) {
  addStyle(wb, aba, estilo_hdr, rows = 1, cols = 1:20, gridExpand = TRUE)
}

setColWidths(wb, "Renda x Class (wide)", cols = 1:ncol(renda_class_verde_wide), widths = "auto")
setColWidths(wb, "Renda x Setor x Ano", cols = 1:ncol(renda_formal_setor_wide), widths = "auto")

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "renda_media_class_formalidade.xlsx"))


# --- 8g. Índice de Palma ---

wb <- createWorkbook()
addWorksheet(wb, "Palma x Class")
addWorksheet(wb, "Palma x Setor x Ano")

writeData(wb, "Palma x Class", palma_class_wide, withFilter = TRUE)
writeData(wb, "Palma x Setor x Ano", palma_formal_wide, withFilter = TRUE)

estilo_num <- createStyle(numFmt = "0.00")

for (aba in c("Palma x Class", "Palma x Setor x Ano")) {
  addStyle(wb, aba, estilo_hdr, rows = 1, cols = 1:20, gridExpand = TRUE)
}

setColWidths(wb, "Palma x Class", cols = 1:ncol(palma_class_wide), widths = "auto")
setColWidths(wb, "Palma x Setor x Ano", cols = 1:ncol(palma_formal_wide), widths = "auto")

salvar_excel_formatado(wb, file.path(CAMINHO_PRODUTOS_TAB, "indice_palma.xlsx"))


# --- 8h. Tabela de Palma demográfica ---

writexl::write_xlsx(tabela_palma_wide,
                    file.path(CAMINHO_PRODUTOS_TAB, "tabela_palma_wide.xlsx"))


# --- 8i. Matriz setor x ocupação ---

matriz_ocup_ativ <- gerar_matriz_ocup_ativ(base_pnadc, ANO_INICIAL, ANO_FINAL)

write.xlsx(matriz_ocup_ativ,
           file = file.path(CAMINHO_PRODUTOS_TAB, "matriz_setor_ocup.xlsx"),
           keepNA = TRUE, overwrite = TRUE, colWidths = "auto", digits = 2)


# --- 8j. Tabela demográfica da ocupação verde (gt) ---

tabela_demo <- tabelas_ocup[1:min(10, length(tabelas_ocup))] %>%
  list_rbind(names_to = "caracteristica") %>%
  mutate(V2009 = as.character(V2009),
         descricao = coalesce(V2007, V2010, as.character(formalidade),
                              VD3004, VD3005, V2009, V1022, regiao_metrop, UF, regiao)) %>%
  select(caracteristica, descricao, everything(),
         -any_of(c("V2007", "V2010", "formalidade", "VD3004", "VD3005",
                    "V2009", "V1022", "regiao_metrop", "UF", "regiao"))) %>%
  filter(!(caracteristica %in% c("escolaridade_anos", "idade", "regiao_uf")))

write_xlsx(tabela_demo, path = file.path(CAMINHO_PRODUTOS_TAB, "tabela_demo.xlsx"))

# Tabela gt formatada (imagem PNG)
tabela_demo_gt <- tabela_demo %>%
  group_by(caracteristica) %>%
  gt(rowname_col = "descricao") %>%
  tab_spanner(label = as.character(ANO_INICIAL),
              columns = matches(paste0("_", ANO_INICIAL, "_"))) %>%
  tab_spanner(label = as.character(ANO_FINAL),
              columns = matches(paste0("_", ANO_FINAL, "_"))) %>%
  fmt_number(columns = starts_with("n"), scale_by = 0.000001, decimals = 2) %>%
  fmt_number(columns = starts_with("freq"), decimals = 2) %>%
  text_replace("NA", "-", locations = cells_body()) %>%
  text_transform(fn = function(x) paste(x, "mi"), locations = cells_body(columns = starts_with("n_"))) %>%
  text_transform(fn = function(x) paste0(x, "%"), locations = cells_body(columns = starts_with("freq")))

gt::gtsave(tabela_demo_gt, file.path(CAMINHO_PRODUTOS_TAB, "tabela_demo.png"))


message("=== EXECUÇÃO CONCLUÍDA COM SUCESSO ===")
