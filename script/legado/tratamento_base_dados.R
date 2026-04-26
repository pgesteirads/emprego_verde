#Construção da base utilizada para o exercicio de 2025

# Variaveis de interesse --------------------------------------------------

vars <- list(
  id = c("Ano","Trimestre","UF","Capital", "UPA", "Estrato", "V1008", "V1014", "V1028") 
  ,genero = c("V2007")
  ,cor = c("V2010")
  ,ocupacao = c("V4010","VD4009","VD4002","VD4012","V4032", "VD4002")
  ,escolaridade = c("VD3004","VD3005")
  ,idade = c("V2009")
  ,regiao = c("V1022","RM_RIDE","UF")
  ,atividade = c("V4013"),
  renda = c("VD4016"))

vars_vec <- unname(unlist(vars))

anos <- c(2014,2016,2019,2024)

trimestres <- c(4)

# PNADc -------------------------------------------------------------------

base_pnadc <- 
  arrow::open_dataset(list.files("dados/pnadc_trim/", full.names = TRUE)) %>% 
  select(vars_vec) %>% 
  filter(Ano %in% anos) %>% 
  collect()

uf_nome <- readxl::read_xlsx("dados/uf_nome.xlsx")

base_pnadc <- base_pnadc %>% left_join(y = uf_nome)

caminho_deflator <- "C:\\Users\\Pedro Gesteira\\OneDrive - Macroplan\\pnadc\\trimestral\\4\\dados_original\\deflator_PNADC_2025_trimestral_040506.xls"

deflator <- readxl::read_xls(caminho_deflator) %>% rename("Ano" = Ano, "Trimestre" = trim, "uf" = UF) %>% 
  filter(Trimestre %in% c("01-02-03", "04-05-06", "07-08-09", "10-11-12")) %>% 
  mutate(uf = as.numeric(uf),
         Trimestre = as.character(match(Trimestre, c("01-02-03", "04-05-06", "07-08-09", "10-11-12")))) %>% 
  select(Ano, Trimestre, uf, Habitual)

base_pnadc <- base_pnadc %>% left_join(deflator)

arrow::write_parquet(base_pnadc, "dados/base_pnadc_tratada_trimestral_4.parquet")
