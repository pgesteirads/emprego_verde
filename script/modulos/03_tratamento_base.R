###############################################################################
#                                                                             #
#   EMPREGO VERDE - 03. TRATAMENTO DA BASE E VARIÁVEIS DERIVADAS              #
#                                                                             #
#   Define as funções que constroem a base analítica:                        #
#     - tratar_base_pnadc()           : seleciona vars, aplica deflator       #
#     - incluir_variaveis_derivadas() : setor, formalidade, classif. verde,   #
#                                       renda deflacionada, SCN, etc.         #
#     - desagregar_scn()              : desagrega CNAEs por proporção da TRU  #
#                                                                             #
#   Dependências: 00_config.R, 02_classificacoes_verdes.R                     #
#     (gerar_classificacao_verde_cnae, carregar_classificacao_verde_cbo).     #
#   Origem: emprego_verde_consolidado.R, seções 3 e 4.                        #
#                                                                             #
###############################################################################

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
  # essas colunas - era a causa de o erro "setor_cnae20_cod não existe".

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
        idade <= 24 ~ "14-24",
        idade <= 39 ~ "25-39",
        idade <= 59 ~ "40-59",
        idade >= 60 ~ "60+"
      ),
      faixa_etaria = factor(faixa_etaria, levels = c("14-24", "25-39", "40-59", "60+"))
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
