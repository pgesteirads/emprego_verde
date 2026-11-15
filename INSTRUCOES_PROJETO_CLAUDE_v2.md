# Projeto Empregos Verdes e Green Skills no Brasil

## 1. O que é o projeto

Pesquisa aplicada da Macroplan com o Instituto de Economia da UFRJ sobre o mercado de trabalho brasileiro sob a ótica ambiental. Equipe central: Valéria Pero (coordenação), Kaio Vital da Costa e Pedro Gesteira. Na proposta ao iCS entram também Adriana Fontes (Mapa de Demandas, oferta formativa) e Fabrício Pitombo (UFBA, componentes setoriais). Pedro responde por tudo o que é base de dados e implementação computacional.

Pasta local do projeto: `C:\Users\Pedro Gesteira\OneDrive - Macroplan\Documentos\emprego_verde`. Todos os caminhos abaixo são relativos a ela.

O trabalho tem três frentes:

1. **Dimensão setorial (consolidada).** Classificação das atividades (CNAE Domiciliar, via CNAE 2.0) em verde, neutra (rótulo original "limpa") e marrom (rótulo original "ambientalmente sensível"), aplicada à PNAD Contínua do 4º trimestre de 2014, 2016, 2019 e 2024. Base: Moscon, Costa, Pero e Gesteira (2024). Pipeline em R: `script/modulos/` (ponto de entrada `_run_pipeline.R`) e `script/emprego_verde_consolidado.R`. Scripts em `script/legado/` não devem ser usados.
2. **Dimensão ocupacional (concluída e validada).** Índice contínuo de esverdeamento de cada ocupação da CBO 2002, pela abordagem de conteúdo de tarefas aplicada ao Perfil Ocupacional (192.745 registros, 2.700 ocupações, 2.672 reportáveis). Pertence ao projeto nacional "Green skills no Brasil: classificação híbrida, dinâmica do mercado de trabalho e implicações de política pública" (`Projeto Green SKills (1).docx`).
3. **Proposta ao Instituto Clima e Sociedade (em refinamento para contratação).** Chamada "Empregos Verdes e Transição Justa", Tema 1. Título: "Reconfiguração do trabalho na transição energética e industrial no Nordeste: competências verdes, desigualdades e demanda por qualificação". Aplica a classificação híbrida ao Nordeste e acrescenta competências (QBQ), oferta formativa (Mapa de Demandas) e insumo-produto regional. Detalhes na seção 3.

## 2. Decisões metodológicas já tomadas (não reabrir sem motivo explícito)

- **Tarefas como abordagem principal.** O índice é a razão entre atividades de uma classe e o total de atividades da ocupação no Perfil Ocupacional. Três dimensões (verde, marrom, líquida) e duas versões (ampla, sobre todas as atividades; restrita, sobre as atividades exclusivas da ocupação na família).
- **Winkler et al. (2024) abandonado como rota principal.** A importação do O*NET por tábuas perde resolução, depende de tábuas de baixa qualidade e supõe conteúdo ocupacional idêntico ao dos EUA. Caso emblemático: 732140 (instalador fotovoltaico). A causa é a CIUO-88, de 1988, não ter categoria fotovoltaica, e não herança de código da família; migrar para a CIUO-08 não resolve.
- **O dicionário gera candidatos; a rubrica classifica.** Cada atividade capturada é lida e classificada em VERDE, POTENCIAL, MARROM ou NEUTRO conforme `metodologia/RUBRICA.md`, em duas passagens independentes com arbitragem. Nunca atribuir classe pelo termo que capturou. Cerca de um quinto das capturas é NEUTRO.
- **Competências são o próximo passo, não substituto.** O QBQ é a base de competências nativa da CBO. Articulação prevista: regressão dos escores do QBQ contra o índice de tarefas, com efeitos fixos de família (Vona et al., 2018).
- **Agregação sempre ponderada pelo emprego** (RAIS, CBO a seis dígitos), nunca por média simples. A RAIS é a base de referência; a PNAD Contínua fica para informalidade, demografia e mobilidade, em nível de família ocupacional, com a perda de resolução documentada.
- **O índice é nacional por ocupação.** Variação territorial vem da composição ocupacional e setorial local, não de conteúdo distinto da mesma ocupação em lugares diferentes.
- **Qualificação de uso (auditoria de recall).** O índice verde estrito é estimativa pontual; o marrom e as medidas que incluem POTENCIAL são limites inferiores. Não usar as 28 ocupações não reportáveis (menos de 15 atividades).

## 3. Proposta iCS: estado e decisões

- **Versão de referência do texto:** `proposta_ics/proposta_iCS_v6.docx` (setembro de 2026). v4 e v5 estão superadas.
- **Decisões posteriores à v6** (registradas no documento do projeto `claude/avaliacao_roteiro_REFA_orcamento_out2026.md`): duração de 12 meses (jan a dez de 2027); 8 entregas, com E1 (nota, índice e base) até M4 e uma reunião de apresentação do índice e da base aos demais projetos da carteira em M5; R$ 500.000 no total, sendo R$ 416.666 de custos diretos e R$ 83.334 de overhead (10% IE-UFRJ e 10% fundação, sobre custos diretos). As versões de trabalho do roteiro, da REFA e do orçamento (sufixo `_TEMPORARIO_PEDRO`) não estão nesta pasta; os arquivos em `proposta_ics/documentos_auxilio_ics/` são modelos do iCS.
- **Papel na carteira.** O iCS quer o projeto como base analítica comum da carteira de Empregos Verdes (`Direcionamentos_ iCS_UFRJ.docx`). Os demais projetos (FAPESE/UFS + Instituto E+, SENAI-CE, WayCarbon/ICLEI, AYA/Systemiq, LCA) devem usar classificações, recortes e projeções da UFRJ, sem dependência formal (`Carteira_TdR.xlsx`, aba Interfaces UFRJ). Daí a importância de documentação, guia de uso e formatos abertos.
- **Fronteira de financiamento.** O índice nacional, o dicionário e a validação são insumo pré-existente do projeto nacional. O apoio do iCS financia a territorialização, o Mapa de Demandas adaptado, a matriz demanda × oferta, o insumo-produto regional, a priorização de lacunas e a interlocução com o GT5 do Fórum Powershoring. Nenhuma rubrica pode corresponder a trabalho já executado.
- **Ponto focal no iCS:** Telma Pinheiro. Sistema: Fluxx, com tabela de resultados e entregas (REFA).
- **Em aberto:** alinhar o escopo da v6 (4 módulos, camada QBQ, Discussion Paper, caderno de tabelas A a G, fichas-síntese, base 2.0 com DOI) com o roteiro e a REFA (Power BI, policy brief de 3 mil palavras); título idêntico ao do Fluxx ("demanda por" × "demanda de" qualificação); menção à RAIS identificada no roteiro, contra a RAIS pública na proposta; dados do Fluxx e autodeclarações de diversidade; valores unitários do orçamento e a reserva técnica; prazo, já que a v6 diz 8 meses e o slide de estratégia do iCS (setembro) mostra a UFRJ em jan a ago de 2027.

## 4. Vocabulário fixo

- Usar "índice de esverdeamento" (não "green skill score").
- **Atenção à palavra "amplo", que a nota usa em dois sentidos.** (a) Pelo denominador: versão ampla (todas as atividades) × versão restrita (atividades exclusivas). (b) Pelas classes: verde estrito (só VERDE) × verde com potencial (VERDE + POTENCIAL; coluna `Verde_amplo_broad` da planilha). Ao escrever, dizer sempre qual dos dois sentidos está em jogo; o sentido (b) é o limite superior da medida verde e, ao mesmo tempo, subestimado pela auditoria de recall.
- Setorial: verde, neutra, marrom (rótulos originais "limpa" e "ambientalmente sensível" apenas quando se citar a fonte).

## 5. O que ler, conforme a tarefa

**Frente ocupacional:** `TRANSFERENCIA.md` (decisões, mapa de arquivos, pendências); `HISTORICO_CONVERSA_ESVERDEAMENTO.md` (percurso); `metodologia/RUBRICA.md` (o documento mais importante da metodologia); `Nota_metodologica_esverdeamento_ocupacional.docx` (versão para terceiros); `analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx` (fonte canônica; em divergência com qualquer outro arquivo, prevalece). Para refazer o índice: `source("metodologia/construir_indice.R")` com o `emprego_verde.Rproj` aberto, ou `metodologia/construir_indice.py`; conferir o bloco de verificação e investigar qualquer `DIVERGE`.

**Proposta iCS:** `proposta_ics/proposta_iCS_v6.docx`; `proposta_ics/TdR_Empregos Verdes_Transicao_Justa.pdf`; `proposta_ics/documentos_auxilio_ics/Direcionamentos_ iCS_UFRJ.docx`, `Carteira_TdR.xlsx`, `Carteira_Projeto.xlsx` e `2609 Empregos Verdes -estrategia e implementacao.pdf`; `proposta_ics/Preparacao_reuniao_iCS_ajustes_set2026.docx`; `proposta_ics/Mapa de demandas.pdf` (metodologia Setec/MEC e Sedese/MG); o documento do projeto sobre roteiro, REFA e orçamento.

**Frente setorial:** `README.md` e `documentacao_projeto_emprego_verde.docx` (ambos de abril de 2026; a parte sobre a dimensão ocupacional via Caruso está desatualizada).

**Bibliografia:** `green skills - bibliografia/` (24 PDFs). Centrais: Granata e Posadas (2024), EU (2022) sobre a rotulagem da ESCO, Vona (2021, o guia do JRC, arquivo "Guide for a Task-based approach"). Janser (2019) e Vona, Marin, Consoli e Popp (2018, JAERE) são referências centrais mas **não estão na pasta**; o arquivo nomeado "vona (2018)" é outro texto (Climate Policy, sobre aceitabilidade política).

## 6. Arquivos com defeito ou que exigem cuidado

- `dados/referencia/cbo02_classverde_caruso.xlsx`: rótulos defeituosos (catador de material reciclável como não verde, gerente financeiro como verde). Não usar. O Teste 1 usou o arquivo de família (`cbodom_...`). A citação candidata é Caruso (2010, OIT), mas não está verificado que o arquivo deriva desse estudo.
- `analise_cbo_onnet/QBQ_CBO_prototipo_esverdeamento.xlsx`: protótipo superado pela planilha canônica.
- `Preparacao_reuniao_iCS_ajustes_set2026.docx`: diz que 981 ocupações sem atividade exclusiva são 37,7%; a planilha registra 36,3% (981 de 2.700).
- `produtos/apresentacoes/` está no `.gitignore`; a apresentação e outros produtos não estão versionados. O último commit é de abril de 2026; `metodologia/` e os documentos de novembro ainda não foram commitados.

## 7. Pendências abertas

- Teste de validação com a base de tarefas do O*NET (executar localmente).
- Refazer e ampliar a rotulagem dos 2.413 conceitos de conhecimento do QBQ (perdida com o ambiente de processamento) para o indicador de competências.
- Aplicar o índice à RAIS com ponderação pelo emprego; depois à PNAD Contínua.
- Decidir se a rubrica será ancorada em instrumentos normativos brasileiros.
- Decidir a versão-manchete para o Nordeste (verde estrito ou com potencial), dado o peso do emprego agropecuário.
- Decidir se a dimensão marrom ganha ampliação do dicionário ou fica declarada como limite inferior.

## 8. Preferências de trabalho e de escrita

- Idioma: português do Brasil. Registro acadêmico e impessoal, técnico, mas didático e claro. Pedro retoma temas após intervalos: explicar termos técnicos na primeira ocorrência.
- **Nunca usar travessões longos (— ou –) em nenhum texto.** Usar vírgula, dois-pontos, parênteses ou reescrever a frase.
- Documentos Word: Times New Roman 12 em todo o documento, título em negrito e caixa alta, texto corrido com bullets apenas pontuais, margens ABNT (superior, inferior e esquerda 3 cm; direita 2 cm), A4.
- Apresentações: HTML navegável com fundo preto, inclusive na impressão em PDF.
- Entregas: gravar os arquivos na pasta do projeto, ao lado das fontes. Não publicar como página web ou Artifact sem pedido expresso.
- Antes de afirmar uma causa, verificar nos dados. Separar sempre o que foi verificado do que é inferência.
- Números citados em textos vêm da planilha canônica ou de cálculo verificável, nunca de memória.
- Reportar defeitos encontrados em arquivos de referência, mesmo quando não foram pedidos.
