# Transferência da medida de esverdeamento ocupacional

Este documento registra o que não está em nenhum outro arquivo do repositório: por que o
indicador é construído como é, o que foi tentado e descartado, e quais pendências continuam
abertas. Ele existe porque a construção da medida aconteceu em uma conversa de trabalho que
não é transferível entre contas, e porque o ambiente de processamento onde o pipeline foi
executado é efêmero e já foi reciclado.

Autoria do trabalho: Valéria Pero, Kaio Vital da Costa e Pedro Gesteira.
Execução do indicador: setembro de 2026. Este registro: novembro de 2026.

## 1. Em uma página

O objetivo é medir, de forma contínua, quanto do conteúdo de trabalho de cada ocupação
brasileira consiste em reduzir impacto ambiental, e quanto consiste em aumentá-lo.

A medida é construída pela **abordagem de conteúdo de tarefas**, aplicada diretamente às
descrições de atividade do Perfil Ocupacional da CBO 2002. Para cada ocupação, o índice é a
razão entre o número de atividades de uma classe e o número total de atividades daquela
ocupação. São três dimensões (verde, marrom, líquido) e duas versões (ampla, calculada sobre
todas as atividades, e restrita, calculada só sobre as atividades exclusivas da ocupação
dentro da sua família).

O procedimento tem duas peças, e a distinção entre elas é a decisão de desenho mais
importante do trabalho:

- um **dicionário de 183 termos** (`metodologia/lexico.py`), que varre o corpus e **apenas
  gera candidatos**;
- uma **rubrica de classificação** (`metodologia/RUBRICA.md`), que decide a classe de cada
  atividade candidata pela leitura do enunciado.

O dicionário não classifica. Cerca de um quinto das suas capturas não tem conteúdo ambiental.
Quem tratar o dicionário como classificador reproduz o erro que este desenho existe para
evitar, e o resultado continuará sendo um número entre zero e um, aparentemente plausível.

## 2. O que está em cada arquivo

**Fonte canônica dos resultados**

- `analise_cbo_onnet/Esverdeamento_ocupacional_CBO2002.xlsx`: dez abas: o índice das 2.700
  ocupações, o dicionário com as expressões de busca, as 24 exceções, os 15 termos
  descartados, a classificação das 1.870 atividades com as duas passagens e a marcação de
  arbitragem, o detalhe dos Testes 1 e 2, o ranking e um resumo de 58 indicadores. Se houver
  divergência entre esta planilha e qualquer outro arquivo, esta planilha prevalece.

**Documentação do método**

- `Nota_metodologica_esverdeamento_ocupacional.docx` (e `.pdf`): 29 páginas, dez seções.
  Fundamentação conceitual, a revisão em relação a Winkler et al. (2024), o procedimento
  executado em cinco etapas, os quatro testes de validação, a articulação com competências,
  as delimitações. É o documento a circular com terceiros.
- `produtos/apresentacoes/Esverdeamento_ocupacional_apresentacao.html` (e `.pdf`): 18
  slides, versão de apresentação. **Atenção: `produtos/apresentacoes/` está no `.gitignore`,
  logo esses arquivos não estão versionados.** Existem apenas na pasta.

**Pipeline reprodutível (reconstruído em novembro de 2026)**

- `metodologia/RUBRICA.md`: o critério de classificação. Quatro classes, seis casos de NEUTRO
  obrigatório, regras de decisão, protocolo de duas passagens. **É o arquivo mais importante
  desta pasta.** A planilha mostra o resultado da classificação; só a rubrica mostra a regra.
- `metodologia/lexico.py`: os 183 termos como código executável, com as 24 exceções e os 15
  descartados. Reconstruído a partir da planilha e validado: reproduz 1.868 das 1.870
  atividades candidatas. As duas que faltam são justamente as suprimidas por regra de exceção,
  mantidas na base rotuladas como NEUTRO.
- `metodologia/rotulos_atividade.json`: as 1.870 atividades com a classe final, o resultado
  de cada passagem e a marcação de arbitragem.
- `metodologia/construir_indice.R` e `metodologia/construir_indice.py`: refazem o índice do
  zero a partir do Perfil Ocupacional, em R ou em Python. As duas versões foram executadas
  sobre os 192.745 registros e produzem resultado idêntico entre si. Contra a planilha, as
  2.700 ocupações coincidem em todos os índices; a única diferença são 2 contagens de
  atividades exclusivas (ocupações 262615 e 325115) que diferem em uma unidade, sem efeito em
  nenhum índice, porque a normalização do pipeline junta enunciados que só diferem em caixa ou
  espaçamento. Pela mesma razão, o pipeline conta 50.874 enunciados distintos e 1.866
  candidatos, contra 50.952 e 1.868 na nota. A versão em R lê o dicionário e os rótulos
  diretamente da planilha canônica; a versão em Python usa `lexico.py` e
  `rotulos_atividade.json`. Uso em R: abrir `emprego_verde.Rproj` e rodar
  `source("metodologia/construir_indice.R")`.

**Fontes primárias**

- `analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - PerfilOcupacional.csv`: 192.745 registros de
  atividade, 2.700 ocupações. Não versionado (`.gitignore` exclui `*.csv`).
- `analise_cbo_onnet/QBQ_microdados.xlsx`: Quadro Brasileiro de Qualificações, usado no
  Teste 3.
- `green skills - bibliografia/`: 24 PDFs. A literatura que fundamenta o desenho.

**Perdido com o ambiente de processamento, e reconstruível se necessário**

Os objetos serializados intermediários (`perfil.pkl`, `qbq.pkl`, `indices.pkl`,
`qbq_index.pkl`), os arquivos de julgamento das duas passagens em formato bruto, a rotulagem
dos 2.413 conceitos de conhecimento do QBQ e o script que gera o `.docx` da nota. Todos
derivam de fontes que estão na pasta. O único item cuja reconstrução custa trabalho real é a
rotulagem do QBQ, porque exige refazer a classificação daqueles 2.413 conceitos.

## 3. Por que não seguimos Winkler et al. (2024), como o projeto previa

O projeto, na seção 4.2, previa importar a classificação de ocupações verdes do O*NET
norte-americano para a CBO, por encadeamento de tábuas de correspondência. A equipe construiu
essa tábua (CBO → CIUO-88 → ISCO-08 → SOC 2010 → SOC 2018) e a avaliou. O resultado está no
`Relatorio_CBO2002_x_ONET.docx`. Três limitações motivaram a revisão:

1. **A premissa de equivalência de conteúdo.** Winkler et al. reconhecem explicitamente que o
   método supõe que o conteúdo de tarefas de uma ocupação é idêntico ao dos Estados Unidos, e
   que isso é "quase certamente problemático" para países menos desenvolvidos.
2. **A qualidade da tábua.** Apenas 253 das 2.185 ocupações vinculadas têm correspondência
   unívoca; a mediana é de 4 códigos SOC por ocupação da CBO e o máximo é 40. A literatura
   registra que a mesma base produz 17 ou 39 por cento de emprego verde no Reino Unido
   dependendo da tábua escolhida (Valero et al., 2021).
3. **A resolução.** Winkler et al. aplicam a medida a dois dígitos da ISCO. O projeto precisa
   de seis dígitos da CBO, porque é assim que a RAIS codifica.

**O caso que decidiu a questão, e a sua causa real.** A ocupação 732140, instalador de
sistemas fotovoltaicos, não é vinculada pela tábua ao código SOC 47-2231 (Solar Photovoltaic
Installers). O encadeamento a distribui entre reparadores de eletrônicos e instaladores de
telecomunicações.

Registre-se a causa correta, porque a explicação intuitiva está errada e já circulou em versão
anterior do material: **não se trata de a ocupação ser recente e herdar o código da família.**
A verificação nos dados mostra que a 732140 recebe o mesmo código CIUO-88 (7245, eletricistas
e reparadores de linhas) que todas as suas sete ocupações irmãs da família 7321. A causa é que
a CIUO-88 é de 1988 e não tem categoria para instalação de sistemas fotovoltaicos, atividade
que não existia como categoria estatística naquele momento. É defasagem da classificação de
destino, não do percurso. Consequência prática: **migrar para a CIUO-08 não resolveria o
caso**, porque a classificação internacional continua em quatro dígitos e continua sem
categoria específica.

O Perfil Ocupacional da CBO, em contraste, registra 99 atividades para a 732140, das quais dez
mencionam conteúdo fotovoltaico explícito. O índice resolve o caso: 0,101 na versão ampla,
0,900 na versão restrita, contra 0,010 a 0,012 nas sete ocupações irmãs.

## 4. Por que a classificação é no nível da atividade, e não do termo

Esta é a diferença de desenho em relação a Granata e Posadas (2024), que atribuem a classe
diretamente pelo termo capturado. A razão é empírica e específica do português.

O caso decisivo é o substantivo **resíduo**. Compare:

- "Segregar resíduos de serviços de saúde": gestão de resíduos, VERDE;
- "Retirar resíduos de areia das peças": sobra a limpar de uma superfície, NEUTRO.

Os dois casam com a mesma expressão (`\bRESIDUO`). Nenhuma regra de exceção lexical separa os
dois usos de forma confiável, mas a leitura do enunciado os separa sem dificuldade. O mesmo
vale para **condições ambientais**, que na maior parte das ocorrências designa luz, temperatura
e umidade do local de trabalho, e para **riscos ambientais**, que no Brasil é o termo técnico
da NR-9 e do PPRA para agentes físicos, químicos e biológicos no ambiente laboral, sem nenhum
conteúdo de mitigação.

Dois outros achados da curadoria merecem registro:

- **A armadilha CIMENTO/CONHECIMENTO.** O termo `cimento`, pertinente ao conteúdo marrom da
  construção civil, está contido na palavra `conhecimento`. Aplicado sem fronteira de palavra,
  classificava como marrom praticamente todo o corpus (19.946 capturas espúrias na primeira
  varredura). Daí a exigência de fronteiras de palavra nas expressões. Casos análogos:
  `palavra`, `coquetel`, `coqueiro`.
- **A cláusula genérica de conformidade.** A fórmula que menciona preservação ambiental ao
  lado de saúde e segurança do trabalho aparece no bloco de competências pessoais de centenas
  de ocupações, sem descrever ação ambiental própria. Ela responde por 22,3 por cento das
  ocorrências do termo `ambiental` no corpus e, isoladamente, atribuiria conteúdo verde a 345
  ocupações que não executam nenhuma outra atividade ambiental. É o caso 1 de NEUTRO
  obrigatório da rubrica.

## 5. O que os quatro testes dizem, e como lê-los

| Teste | Resultado | Leitura |
|---|---|---|
| 1. Concordância com classificação binária de referência (famílias, n=443) | sensibilidade 71,0%, especificidade 42,9%, kappa 0,138, AUC 0,623, razão de médias 1,92 | Sinal na direção certa, concordância categórica fraca. Não é falha do índice: ver abaixo. |
| 2. Julgamento holístico independente (ocupações, n=170) | AUC 0,978 (verde) e 0,925 (marrom), correlação de postos 0,730, médias monótonas de −0,076 a +0,159 | Evidência de validade mais forte da bateria. |
| 3. Convergência com o QBQ (n=2.580) | Pearson 0,442 (verde), 0,573 (marrom), 0,449 (líquido) | Positiva em todas as dimensões. Magnitude moderada é o esperado: fontes relacionadas, não redundantes. |
| 4. Inspeção qualitativa dos extremos | topo em tratamento de efluentes, agroecologia e oceanografia; base em coqueria, concreto e lavra | Nenhuma das 30 posições de cada ponta carece de justificativa no conteúdo descrito. |

**O contraste entre os Testes 1 e 2 é o ponto a entender.** O mesmo índice tem concordância
fraca com uma classificação binária agregada em família e concordância muito forte com o
julgamento holístico no nível da ocupação. A explicação está na unidade de comparação: o
Teste 2 opera no nível em que o índice foi construído e com critério contínuo; o Teste 1 opera
em nível agregado e com critério dicotômico. A divergência mede o custo da agregação e da
dicotomização, não a qualidade do indicador. Esse é também o argumento para preferir a RAIS à
PNAD Contínua nas estimativas de referência.

**Qualificação de uso que decorre da auditoria de recall.** Sortearam-se 800 atividades entre
as não capturadas pelo dicionário. Foram encontrados 26 falsos negativos por consenso (3,3 por
cento), dos quais 17 POTENCIAL, 8 MARROM e apenas 1 VERDE. Portanto:

- o **índice verde é bem medido** e pode ser lido como estimativa pontual;
- o **índice marrom e o índice amplo são limites inferiores**, porque enunciados que descrevem
  etapas de processo industrial sem nomear insumo ou produto, e atividades agropecuárias e de
  reparo sem qualificador, escapam sistematicamente a um dicionário de vocabulário ambiental.

## 6. Defeito em arquivo de referência que está no repositório

`dados/referencia/cbo02_classverde_caruso.xlsx` tem rótulos incompatíveis com casos
inequívocos: classifica "Catador de material reciclável" como não verde e "Gerente financeiro"
como verde. A inversão sistemática dos rótulos não corrige o problema (kappa 0,068). Os dois
arquivos atribuídos à mesma origem (`cbo02_...` no nível da ocupação e `cbodom_...` no nível da
família) concordam entre si em apenas 45,5 por cento dos casos comparáveis.

O Teste 1 foi conduzido exclusivamente sobre o arquivo de nível familiar. **O arquivo de nível
ocupacional não deve ser usado em nenhuma etapa do projeto até que a sua procedência e
integridade sejam verificadas.** Além disso, a referência bibliográfica completa dessa
classificação não foi localizada; a nota metodológica a trata descritivamente, como
"classificação binária de referência disponível no acervo do projeto", justamente por isso.
Quem assumir deve estabelecer a citação correta ou substituir a referência.

## 7. Pendências abertas

1. **Teste do O*NET.** Granata e Posadas validam o método aplicando o dicionário à base de
   tarefas do O*NET e comparando com o Green Economy Program. O download foi bloqueado por
   política de rede no ambiente onde os outros testes rodaram. Executar localmente. Ressalva:
   a base do O*NET está em inglês, logo o teste afere a validade do desenho, não a do
   dicionário em português. Acrescentaria sobretudo o argumento de comparabilidade
   internacional.
2. **Ancoragem normativa.** A rubrica ancora-se em Granata e Posadas (2024) e no Cedefop
   (2012). Ancorar em instrumentos brasileiros de política ambiental e industrial é decisão de
   mérito ainda não tomada, e exigiria nova rodada de classificação, porque a rubrica é o
   documento que define o critério.
3. **Indicador de competências.** A rotulagem dos 2.413 conceitos de conhecimento do QBQ foi
   feita com finalidade de validação (Teste 3) e perdeu-se com o ambiente. Para servir de base
   a um indicador próprio, precisa ser refeita e ampliada. O procedimento é o mesmo das etapas
   2 a 4, aplicado a outro corpus. A seção 8.3 da nota descreve o exercício de maior alcance
   que isso habilita: identificar habilidades verdes por regressão dos escores do QBQ contra o
   índice de tarefas, à maneira de Vona et al. (2018), sem rotular competência alguma.
4. **Execução do pipeline reconstruído: resolvida.** As versões em R e em Python foram
   executadas sobre o corpus completo e reproduzem a planilha (ver seção 2). Ao rodar de
   novo, conferir o bloco de verificação que os scripts imprimem; se algum indicador aparecer
   como `DIVERGE`, investigar antes de usar a saída.
5. **Resolução intrafamília.** O índice de tarefas não varia em 38,4 por cento das famílias,
   contra 4,7 por cento no QBQ. Articular as duas fontes pode recuperar resolução nas 981
   ocupações em que o índice não distingue a ocupação das suas irmãs.
6. **Versionamento.** `produtos/apresentacoes/` está no `.gitignore` e a apresentação não está
   versionada. Avaliar abrir exceção para os produtos finais.

## 8. Se for preciso refazer a classificação do zero

Ordem de leitura: `metodologia/RUBRICA.md`, depois a seção 5 da nota metodológica, depois
`metodologia/lexico.py`. Da bibliografia, o essencial são três textos: Granata e Posadas (2024)
para o método de tarefas, EU (2022) para o protocolo de rotulagem em três etapas e a
justificativa da categoria neutra, e Janser (2019) para a dimensão marrom e o índice líquido.

O erro a não cometer é o já descrito: usar o dicionário como classificador. O segundo erro a
não cometer é agregar o índice por média simples. Se um agrupamento tem uma ocupação verde com
500 trabalhadores e uma não verde com 50 mil, a média simples atribui 0,5 e a ponderada
atribui 0,01.
