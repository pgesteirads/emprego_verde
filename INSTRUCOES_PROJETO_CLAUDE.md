# Projeto Emprego Verde e Green Skills no Brasil

## O que é o projeto

Pesquisa aplicada da Macroplan em parceria com o Instituto de Economia da UFRJ sobre o mercado de trabalho brasileiro sob a ótica ambiental. Equipe: Valéria Pero, Kaio Vital da Costa e Pedro Gesteira. O projeto em curso intitula-se "Green skills no Brasil: classificação híbrida, dinâmica do mercado de trabalho e implicações de política pública" (proposta em `Projeto Green SKills (1).docx`).

O projeto tem duas frentes, que se combinam numa classificação híbrida:

1. **Dimensão setorial (consolidada).** Classificação das atividades econômicas (CNAE) em verde, neutra (rótulo original "limpa") e marrom (rótulo original "ambientalmente sensível"), aplicada aos microdados da PNAD Contínua do 4º trimestre de 2014, 2016, 2019 e 2024 para traçar o perfil sociodemográfico dos trabalhadores. Pipeline em R (`script/emprego_verde_consolidado.R` e `script/modulos/`), documentado no `README.md`. Base de Moscon et al. (2024).
2. **Dimensão ocupacional (frente atual).** Medida contínua de esverdeamento de cada ocupação da CBO 2002, construída pela abordagem de conteúdo de tarefas (Granata e Posadas, 2024; Vona et al., 2018; Janser, 2019). Já construída e validada para 2.700 ocupações. É o foco do trabalho neste momento.

## Decisões metodológicas já tomadas (não reabrir sem motivo explícito)

- **Abordagem de tarefas como principal.** A medida é a razão entre atividades verdes (ou marrons) e o total de atividades descritas da ocupação no Perfil Ocupacional da CBO 2002. Três dimensões (verde, marrom, líquida) e duas versões (ampla, sobre todas as atividades; restrita, sobre as atividades exclusivas da ocupação dentro da família).
- **Winkler et al. (2024) foi abandonado como rota principal.** A importação do O*NET por tábuas de correspondência perde resolução, depende de tábuas de baixa qualidade e supõe conteúdo ocupacional idêntico ao dos EUA. O caso emblemático é a ocupação 732140 (instalador de sistemas fotovoltaicos), que a tábua distribui entre reparadores de eletrônicos; a causa é a CIUO-88 de 1988 não ter categoria fotovoltaica, e não herança de código da família.
- **O dicionário gera candidatos; a rubrica classifica.** Cada atividade capturada pelo dicionário é lida e classificada em VERDE, POTENCIAL, MARROM ou NEUTRO conforme `metodologia/RUBRICA.md`, em duas passagens independentes com arbitragem. Nunca atribuir classe pelo termo que capturou.
- **Competências são o próximo passo, não substituto.** O Quadro Brasileiro de Qualificações (QBQ) é a base de competências nativa da CBO. A articulação prevista é a regressão dos escores do QBQ contra o índice de tarefas, à maneira de Vona et al. (2018).
- **Agregação sempre ponderada pelo emprego** (RAIS, CBO a seis dígitos), nunca por média simples. A PNAD Contínua usa CBO Domiciliar e implica perda de resolução, a ser documentada.
- **Qualificação de uso:** o índice verde é estimativa pontual; o marrom e o amplo são limites inferiores (resultado da auditoria de recall).

## Arquivos a ler antes de trabalhar na frente ocupacional

1. `TRANSFERENCIA.md` (raiz): histórico de decisões, o que está em cada arquivo, pendências.
2. `HISTORICO_CONVERSA_ESVERDEAMENTO.md` (raiz): registro detalhado de tudo o que foi feito na construção da medida.
3. `metodologia/RUBRICA.md`: o critério de classificação. É o documento mais importante da metodologia.
4. `Nota_metodologica_esverdeamento_ocupacional.docx`: a versão para circular com terceiros.
5. `analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx`: fonte canônica dos resultados. Em caso de divergência com qualquer outro arquivo, prevalece.

Para refazer o índice: `source("metodologia/construir_indice.R")` com o `emprego_verde.Rproj` aberto (há versão equivalente em Python). O script imprime um bloco de conferência contra os números da nota.

Bibliografia em `green skills - bibliografia/` (24 PDFs). Os três textos centrais: Granata e Posadas (2024), EU (2022) sobre a rotulagem verde da ESCO, Janser (2019).

## Pendências abertas

- Teste de validação com a base de tarefas do O*NET (bloqueado anteriormente por restrição de rede; executar localmente).
- `dados/referencia/cbo02_classverde_caruso.xlsx` tem rótulos defeituosos (catador de material reciclável como não verde, gerente financeiro como verde). Não usar até verificar procedência. O arquivo de nível familiar (`cbodom_...`) é o que foi usado.
- Refazer a rotulagem dos conhecimentos do QBQ para construir o indicador de competências.
- Decidir se a rubrica será ancorada em instrumentos normativos brasileiros.

## Preferências de trabalho e de escrita

- Idioma: português do Brasil.
- Registro: acadêmico e impessoal, técnico e científico, mas didático e claro. O usuário às vezes retoma temas após intervalos; explicar termos técnicos quando aparecerem pela primeira vez.
- **Nunca usar travessões longos (— ou –) em nenhum texto.** Usar vírgula, dois-pontos, parênteses ou reescrever a frase.
- Documentos Word: Times New Roman 12 em todo o documento, título em negrito e caixa alta, texto corrido com bullets apenas pontuais, margens ABNT (superior, inferior e esquerda 3 cm, direita 2 cm), A4.
- Apresentações: HTML navegável com fundo preto, inclusive na impressão em PDF.
- Entregas: gravar os arquivos na pasta do projeto, ao lado das fontes. Não publicar como página web ou Artifact sem pedido expresso.
- Antes de afirmar uma causa, verificar nos dados. Separar sempre o que foi verificado do que é inferência.
- Reportar defeitos encontrados em arquivos de referência, mesmo quando não foram pedidos.
- Números citados em textos devem vir da planilha canônica ou de cálculo verificável, nunca de memória.
