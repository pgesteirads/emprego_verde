# Protocolo da classificação humana das atividades (pré-registro)

**Situação: RASCUNHO.** Vale como pré-registro quando os campos `[DEFINIR]` forem preenchidos e o
arquivo for enviado ao Git **antes** de qualquer codificador abrir a planilha principal. Desvios
posteriores vão para a seção 11, com data e motivo.

Este protocolo substitui, como caminho adotado, o da classificação por painel de modelos
(`PROTOCOLO_CLASSIFICACAO.md`), que fica arquivado como alternativa não executada.
Código: `metodologia/R/humana/`. Rubrica: `metodologia/RUBRICA.md`.

## 1. Objetivo

Classificar, por leitura humana independente, as atividades candidatas do Perfil Ocupacional da
CBO 2002 nas quatro classes da rubrica (VERDE, POTENCIAL, MARROM, NEUTRO), substituindo os rótulos
da rodada de setembro de 2026, e medir o que o dicionário deixa de capturar (auditoria de recall).

## 2. Codificadores

| Código | Nome |
|---|---|
| C1 | `[DEFINIR]` |
| C2 | `[DEFINIR]` |
| C3 | `[DEFINIR]` |

Os três são autores do estudo e conhecem o método, o que se declara no artigo. As salvaguardas
estão na seção 5.

## 3. Itens

- **Classificação principal:** todas as atividades distintas capturadas pelo dicionário
  (`insumos/dicionario.csv` com `excecoes.csv`), após normalização. Na versão atual, 1.866.
- **Calibração:** 40 dessas atividades, sorteadas com estratificação pela classe sugerida pelo
  termo do dicionário (para que a amostra cubra os quatro tipos de captura). Semente: 20261117.
  Elas saem da planilha principal; sua classe final é a decidida na reunião de calibração.
- **Repetições escondidas:** 5% das atividades da planilha principal (sorteio próprio para cada
  codificador, semente 20261118) reaparecem em outra posição, para medir a consistência de cada
  codificador consigo mesmo. A primeira resposta é a que conta na classificação.
- **Auditoria de recall:** 800 atividades sorteadas entre as **não** capturadas pelo dicionário.
  Semente: 20261119.

## 4. Planilhas

Cada codificador recebe três arquivos Excel (calibração, principal e recall), com as atividades
numa ordem sorteada só para ele, identificadas apenas pelo número da linha. Colunas a preencher:

- **CLASSE**, por lista suspensa: VERDE, POTENCIAL, MARROM ou NEUTRO;
- **REGRA**, por lista suspensa: o trecho da rubrica aplicado (VERDE, POTENCIAL, MARROM,
  NEUTRO_1 a NEUTRO_6 ou NEUTRO_CONSERVADOR). Deve ser compatível com a classe;
- **OBSERVAÇÃO**, opcional, para dúvidas.

## 5. Salvaguardas de independência

- A planilha mostra só o enunciado. **Não mostra** a ocupação, o termo do dicionário que capturou
  a atividade nem a classe de setembro.
- Nenhum codificador abre, durante a classificação, os arquivos `metodologia/insumos/rotulos_atividade.csv`,
  `metodologia/saida/atividades_por_ocupacao.csv`, a planilha canônica de setembro nem as planilhas
  dos outros.
- **Ninguém conversa sobre itens específicos** até os três entregarem a planilha principal.
  Dúvidas sobre a rubrica vão para a coluna de observação.
- A classe que cada codificador atribuiu sozinho é guardada sem alteração. As reuniões mudam
  apenas a classe final.

## 6. Etapas e prazos

| Etapa | Prazo |
|---|---|
| Calibração individual (40 itens) | `[DEFINIR]` |
| Reunião de calibração; ajustes na rubrica, se houver, registrados no histórico de alterações dela | `[DEFINIR]` |
| Classificação principal (cerca de 1.917 linhas por pessoa) | `[DEFINIR]` |
| Auditoria de recall (800 linhas por pessoa) | `[DEFINIR]` |
| Reuniões de decisão conjunta | `[DEFINIR]` |

Depois da reunião de calibração, a rubrica não muda até o fim da classificação principal.

## 7. Decisão das divergências

Regra escolhida: `[DEFINIR: A ou B]`.

- **Opção A:** toda atividade sem unanimidade vai para a reunião.
- **Opção B:** a unanimidade e a maioria de 2 contra 1 decidem, exceto quando a divergência
  opõe VERDE a NEUTRO; essas, e as divisões em três classes, vão para a reunião.

Em qualquer opção, as atividades que aparecem em 10 ou mais ocupações são conferidas na reunião
mesmo quando houver unanimidade, porque um erro nelas se propaga pelo índice.

Na reunião, a decisão é por consenso, aplicando a rubrica, com justificativa escrita. Sem
consenso, `[DEFINIR: por exemplo, prevalece a maioria, com o voto vencido registrado]`.

## 8. Medidas a reportar

- Concordância e kappa de Cohen para cada par de codificadores; kappa de Fleiss dos três; tanto na
  calibração quanto na classificação principal.
- Consistência de cada codificador nas repetições escondidas.
- Número de atividades levadas à reunião e quantas mudaram em relação à maioria.
- Concordância entre os rótulos finais e os de setembro (classificação por modelo), como medida
  descritiva de estabilidade.
- Auditoria de recall: falsos negativos por consenso (os três atribuem classe diferente de NEUTRO)
  e pela união (ao menos um atribui), por classe.

## 9. Uso dos resultados

Os rótulos finais vão para `insumos/rotulos_atividade_humana.csv`. A troca do insumo do índice
é feita num commit próprio, com atualização dos valores de conferência da nota em
`metodologia/R/00_config.R`. Os falsos negativos da auditoria de recall alimentam a discussão
sobre ampliar o dicionário, que, se feita, exige nova rodada de classificação para as novas
candidatas, pelo mesmo protocolo.

## 10. Teste 2 (julgamento holístico)

Fora do escopo deste protocolo. Recomenda-se que seja feito por avaliadores que não participaram
desta classificação: `[DEFINIR]`.

## 11. Desvios do protocolo

| Data | Mudança | Motivo |
|---|---|---|
| | | |
