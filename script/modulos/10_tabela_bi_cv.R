###############################################################################
#                                                                             #
#   EMPREGO VERDE - 10. TABELA BI COM COEFICIENTE DE VARIAÇÃO (EXECUÇÃO)      #
#                                                                             #
#   Acrescenta à tabela BI o coeficiente de variação (CV) e o conceito de    #
#   precisão do IBGE para as medidas "ocupados" e "renda_media".             #
#                                                                             #
#   POR QUE O DESENHO AMOSTRAL IMPORTA                                        #
#   A PNADc é amostra complexa (estratos + conglomerados + pesos). O erro-    #
#   padrão - e portanto o CV - TEM que considerar o desenho; o cálculo        #
#   ingênuo (amostra aleatória simples) subestima o erro. Aqui o desenho é    #
#   declarado com survey/srvyr:                                               #
#       ids = UPA, strata = Estrato, weights = V1028, nest = TRUE             #
#   e o CV sai de survey_total()/survey_mean() com vartype = "cv".            #
#                                                                             #
#   CLASSIFICAÇÃO DE PRECISÃO (IBGE, Diretoria de Pesquisas)                  #
#       Z  CV = 0           Exata                                             #
#       A  CV até 5%        Ótima                                            #
#       B  CV > 5 a 15%     Boa                                               #
#       C  CV > 15 a 30%    Razoável                                         #
#       D  CV > 30 a 50%    Pouco precisa                                     #
#       E  CV > 50%         Imprecisa                                         #
#   Células sem caso suficiente para estimar o erro ficam com CV/conceito NA. #
#                                                                             #
#   SAÍDA: mesma tabela do módulo 09 + colunas extras `cv` e `conceito`.     #
#   (cv/conceito preenchidos só para ocupados e renda_media; NA nas demais.)  #
#                                                                             #
#   ATENÇÃO: script de EXECUÇÃO. Requer base_pnadc (mód. 05) e tabela_bi      #
#   (mód. 09). É computacionalmente pesado (svyby por ano × nível × abertura).#
#   Dependências: 00_config.R, 05_preparar_dados.R, 09_tabela_bi.R.          #
#                                                                             #
###############################################################################

message("  Calculando coeficiente de variação (CV) da tabela BI...")

# Estratos com uma única UPA (lonely PSU) não permitem estimar variância;
# "adjust" evita erro e trata de forma conservadora.
options(survey.lonely.psu = "adjust")


# --- Classificação do CV (%) no conceito de precisão do IBGE ---

classificar_cv <- function(cv_pct) {
  dplyr::case_when(
    !is.finite(cv_pct) ~ NA_character_,
    cv_pct == 0        ~ "Z (Exata)",
    cv_pct <= 5        ~ "A (Ótima)",
    cv_pct <= 15       ~ "B (Boa)",
    cv_pct <= 30       ~ "C (Razoável)",
    cv_pct <= 50       ~ "D (Pouco precisa)",
    TRUE               ~ "E (Imprecisa)"
  )
}


# --- Cálculo do CV por célula, com base no desenho amostral ---
# Retorna um data.frame longo com chaves compatíveis com a tabela do módulo 09:
#   Ano | localidade | tipo_abertura | abertura | cv | conceito
# (apenas para os indicadores "ocupados" e "renda_media")

calcular_cv_bi <- function(base,
                           tipo_aberturas = ABERTURAS_BI,
                           peso_col  = "V1028",
                           renda_col = "renda_hab_def",
                           incluir_sem_classif = INCLUIR_SEM_CLASSIF_BI) {

  base2 <- base %>%
    mutate(
      Ano        = as.character(.data[["Ano"]]),
      loc_uf     = as.character(.data[["UF"]]),
      loc_regiao = as.character(.data[["regiao"]]),
      class_verde_atividade = as.character(.data[["class_verde_atividade"]]),
      renda_bi   = as.numeric(.data[[renda_col]]),
      peso_bi    = as.numeric(.data[[peso_col]])
    )

  if (incluir_sem_classif) {
    base2 <- base2 %>%
      mutate(class_verde_atividade = ifelse(
        is.na(class_verde_atividade) | class_verde_atividade == "",
        "Sem classificação", class_verde_atividade))
  } else {
    base2 <- base2 %>% filter(!is.na(class_verde_atividade), class_verde_atividade != "")
  }

  # Definição dos 3 níveis geográficos (loc = NULL -> Brasil)
  niveis <- list(
    list(tag = "UF",            loc = "loc_uf"),
    list(tag = "Grande Regiao", loc = "loc_regiao"),
    list(tag = "Brasil",        loc = NULL)
  )

  anos <- sort(unique(base2$Ano))
  blocos <- list()

  for (ano in anos) {
    dados_ano <- base2 %>% filter(Ano == ano)
    if (nrow(dados_ano) == 0) next

    # Desenho amostral declarado por ano (evita confundir UPA/Estrato entre anos)
    desenho_ano <- dados_ano %>%
      srvyr::as_survey_design(ids = UPA, strata = Estrato,
                              weights = peso_bi, nest = TRUE)

    for (nv in niveis) {
      # Coluna de localidade conforme o nível
      if (is.null(nv$loc)) {
        desenho_nv <- desenho_ano %>% mutate(localidade = "Brasil")
      } else {
        desenho_nv <- desenho_ano %>% mutate(localidade = !!sym(nv$loc))
        desenho_nv <- desenho_nv %>% filter(!is.na(localidade) & localidade != "")
      }

      for (var in tipo_aberturas) {

        bloco <- tryCatch({
          desenho_nv %>%
            filter(!is.na(!!sym(var))) %>%
            group_by(localidade, !!sym(var), class_verde_atividade) %>%
            summarise(
              ocupados    = survey_total(vartype = "cv", na.rm = TRUE),
              renda_media = survey_mean(!!sym(renda_col), vartype = "cv", na.rm = TRUE),
              .groups = "drop"
            ) %>%
            as_tibble() %>%
            rename(abertura = !!sym(var)) %>%
            transmute(
              Ano        = ano,
              localidade = as.character(localidade),
              nivel      = nv$tag,
              var_abert  = var,
              abertura   = as.character(abertura),
              class_verde_atividade,
              ocupados    = 100 * ocupados_cv,     # CV em %
              renda_media = 100 * renda_media_cv    # CV em %
            )
        }, error = function(e) {
          message(glue("    [aviso] CV não calculado para {ano}/{nv$tag}/{var}: ",
                       conditionMessage(e)))
          NULL
        })

        if (!is.null(bloco)) blocos[[length(blocos) + 1]] <- bloco
      }
    }
  }

  cv_wide <- bind_rows(blocos)
  if (nrow(cv_wide) == 0) return(cv_wide)

  # Empilha os dois indicadores e monta a chave tipo_abertura do módulo 09
  cv_wide %>%
    pivot_longer(c(ocupados, renda_media),
                 names_to = "indicador", values_to = "cv") %>%
    mutate(
      conceito      = classificar_cv(cv),
      tipo_abertura = paste(nivel, var_abert, class_verde_atividade, indicador, sep = " | ")
    ) %>%
    select(Ano, localidade, tipo_abertura, abertura, cv, conceito)
}


# --- Execução: calcular CV e juntar como colunas extras à tabela_bi (mód. 09) ---

cv_bi <- calcular_cv_bi(base_pnadc)

tabela_bi_cv <- tabela_bi %>%
  mutate(Ano = as.character(Ano), abertura = as.character(abertura)) %>%
  left_join(cv_bi, by = c("Ano", "localidade", "tipo_abertura", "abertura"))

writexl::write_xlsx(tabela_bi_cv,
                    path = file.path(CAMINHO_PRODUTOS_TAB, "tabela_BI_cv.xlsx"))

message(glue("  [OK] Salvo: {file.path(CAMINHO_PRODUTOS_TAB, 'tabela_BI_cv.xlsx')} ",
             "({nrow(tabela_bi_cv)} linhas; CV preenchido p/ ocupados e renda_media)"))
