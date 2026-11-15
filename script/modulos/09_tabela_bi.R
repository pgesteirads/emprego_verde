###############################################################################
#                                                                             #
#   EMPREGO VERDE - 09. TABELA ÚNICA PARA BI (EXECUÇÃO)                       #
#                                                                             #
#   Consolida TODAS as medidas produzidas numa única tabela longa (tidy),    #
#   pronta para BI. Estrutura de 5 colunas:                                   #
#                                                                             #
#     Ano | localidade | tipo_abertura | abertura | valor                    #
#                                                                             #
#   onde "tipo_abertura" codifica 4 dimensões separadas por " | ":           #
#     <nível geográfico> | <variável de abertura> | <classif. verde> | <medida>
#                                                                             #
#   Níveis geográficos : Brasil, Grande Região, UF                           #
#   Medidas            : ocupados, prop_no_grupo, prop_economia, renda_media  #
#                                                                             #
#   Substitui (versão limpa e integrada) o antigo legado/gera_tabela_bi.R,   #
#   que gerava o arquivo "possibilidade para o BI.xlsx". Aqui reutiliza-se a  #
#   coluna `regiao` da base e o `base_pnadc` já tratado pelo módulo 05.       #
#                                                                             #
#   OBS ENCODING: arquivo salvo em UTF-8. As poucas strings funcionais
#   acentuadas usam escapes \u (ex.: "Sem classifica\u00e7\u00e3o"),
#   para sair corretas mesmo se o arquivo for sourced como latin1.
#
#   ATENÇÃO: script de EXECUÇÃO. Requer base_pnadc (módulo 05).              #
#   Dependências: 00_config.R, 05_preparar_dados.R.                          #
#                                                                             #
###############################################################################

message("  Gerando tabela \u00fanica para BI...")

# Variáveis de abertura incluídas na tabela BI.
# (Evite incluir "idade" cru: explode a cardinalidade.)
ABERTURAS_BI <- c("faixa_etaria", "escolaridade", "formalidade",
                  "V2007", "V2010", "SCN",
                  "setor_cnae20_nome",   # abertura por setor (~87 categorias)
                  "cnaedom_nome")        # abertura por atividade (~223 categorias)

# Incluir registros sem classificação verde como categoria "Sem classificação"?
INCLUIR_SEM_CLASSIF_BI <- TRUE


# --- Média ponderada robusta (ignora NA e pesos não positivos) ---

wmean_safe <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}


# --- Função principal: empilha indicadores por localidade ---

gerar_tabela_bi <- function(base,
                            tipo_aberturas = ABERTURAS_BI,
                            peso_col = "V1028",
                            renda_col = "renda_hab_def",
                            incluir_sem_classif = INCLUIR_SEM_CLASSIF_BI) {

  # Base padronizada
  df2 <- base %>%
    mutate(
      Ano = as.character(.data[["Ano"]]),
      localidade_uf     = as.character(.data[["UF"]]),
      localidade_regiao = as.character(.data[["regiao"]]),
      class_verde_atividade = as.character(.data[["class_verde_atividade"]]),
      .peso  = as.numeric(.data[[peso_col]]),
      .renda = as.numeric(.data[[renda_col]])
    )

  if (incluir_sem_classif) {
    df2 <- df2 %>%
      mutate(class_verde_atividade = ifelse(
        is.na(class_verde_atividade) | class_verde_atividade == "",
        "Sem classificação", class_verde_atividade))
  } else {
    df2 <- df2 %>% filter(!is.na(class_verde_atividade), class_verde_atividade != "")
  }

  # Calcula indicadores para um nível geográfico
  calc_nivel <- function(df_in, localidade_vec, nivel_tag) {

    df_loc <- df_in %>%
      mutate(localidade = localidade_vec, nivel_localidade = nivel_tag) %>%
      filter(!is.na(localidade), localidade != "")

    # Denominador da "economia total" por ano/localidade
    tot_economia <- df_loc %>%
      group_by(Ano, nivel_localidade, localidade) %>%
      summarise(ocupados_economia = sum(.peso, na.rm = TRUE), .groups = "drop")

    # Loop por variável de abertura
    map_dfr(tipo_aberturas, function(var) {
      df_loc %>%
        mutate(tipo_abertura = var, abertura = as.character(.data[[var]])) %>%
        filter(!is.na(abertura), abertura != "") %>%
        group_by(Ano, nivel_localidade, localidade, tipo_abertura, abertura, class_verde_atividade) %>%
        summarise(
          ocupados    = sum(.peso, na.rm = TRUE),
          renda_media = wmean_safe(.renda, .peso),
          .groups = "drop"
        ) %>%
        group_by(Ano, nivel_localidade, localidade, tipo_abertura, abertura) %>%
        mutate(prop_no_grupo = ocupados / sum(ocupados, na.rm = TRUE)) %>%
        ungroup() %>%
        left_join(tot_economia, by = c("Ano", "nivel_localidade", "localidade")) %>%
        mutate(prop_economia = ocupados / ocupados_economia) %>%
        select(Ano, nivel_localidade, localidade, tipo_abertura, abertura,
               class_verde_atividade, ocupados, prop_no_grupo, prop_economia, renda_media)
    })
  }

  # 3 níveis: UF, Grande Região, Brasil
  res_uf <- calc_nivel(df2, localidade_vec = df2$localidade_uf,     nivel_tag = "UF")
  res_gr <- calc_nivel(df2, localidade_vec = df2$localidade_regiao, nivel_tag = "Grande Regiao")
  res_br <- calc_nivel(df2, localidade_vec = rep("Brasil", nrow(df2)), nivel_tag = "Brasil")

  res_all <- bind_rows(res_uf, res_gr, res_br)

  # Empilha as 4 medidas numa coluna "valor"
  res_long <- res_all %>%
    pivot_longer(
      cols = c(ocupados, prop_no_grupo, prop_economia, renda_media),
      names_to = "indicador",
      values_to = "valor"
    )

  # Colapsa para as 5 colunas finais do BI
  res_long %>%
    mutate(tipo_abertura = paste(nivel_localidade, tipo_abertura,
                                 class_verde_atividade, indicador, sep = " | ")) %>%
    select(Ano, localidade, tipo_abertura, abertura, valor)
}


# --- Execução: gerar e exportar ---

tabela_bi <- gerar_tabela_bi(base_pnadc)


writexl::write_xlsx(tabela_bi,
                    path = file.path(CAMINHO_PRODUTOS_TAB, "tabela_BI.xlsx"))

message(glue("  [OK] Salvo: {file.path(CAMINHO_PRODUTOS_TAB, 'tabela_BI.xlsx')} ",
             "({nrow(tabela_bi)} linhas)"))
