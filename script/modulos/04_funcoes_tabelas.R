###############################################################################
#                                                                             #
#   EMPREGO VERDE - 04. FUNÇÕES AUXILIARES PARA TABELAS                       #
#                                                                             #
#   Funções (sem efeitos colaterais) usadas na geração de tabelas:           #
#     - gerar_tabelas_descritivas()     : tabela descritiva por agrupamento   #
#     - tabela_demografica()            : comparativo de dois anos            #
#     - tabela_demografica_renda()      : renda média comparativa            #
#     - indice_palma() / tabela_demografica_palma() : Índice de Palma        #
#     - sanitize_sheet / apply_number_formats / salvar_excel_formatado        #
#                                                                             #
#   Dependências: 00_config.R (NIVEIS_CLASS_ATIV).                            #
#   Origem: emprego_verde_consolidado.R, seção 5.                             #
#                                                                             #
###############################################################################

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
