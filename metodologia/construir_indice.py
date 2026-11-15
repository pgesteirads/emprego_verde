# -*- coding: utf-8 -*-
"""Reconstroi o indice de esverdeamento ocupacional a partir das fontes primarias.

Ha versao equivalente em R: construir_indice.R. As duas produzem resultado
identico, verificado sobre o corpus completo.

O que este script faz
---------------------
Le o Perfil Ocupacional da CBO 2002, aplica o lexico para gerar atividades
candidatas, junta os rotulos de classe ja decididos conforme RUBRICA.md e
recalcula todos os indices reportados na nota metodologica.

Uso
---
    python construir_indice.py

Entradas (caminhos relativos a raiz do repositorio, ver CAMINHOS abaixo)
-----------------------------------------------------------------------
    analise_cbo_onnet/ESTRUTURA CBO/CBO2002 - PerfilOcupacional.csv
        Fonte primaria. 192.745 registros de atividade. Nao versionado no git
        (o .gitignore exclui *.csv); baixar do portal da CBO do Ministerio do
        Trabalho e Emprego ou obter na pasta do projeto.
    metodologia/lexico.py
        183 termos, 24 regras de excecao, 15 termos descartados.
    metodologia/rotulos_atividade.json
        1.870 atividades distintas com a classe final decidida.

Saida
-----
    metodologia/saida/indice_por_ocupacao.csv
    metodologia/saida/candidatos_sem_rotulo.csv   (se houver; ver abaixo)

Sobre atividades sem rotulo
---------------------------
Se o lexico capturar uma atividade que nao esta em rotulos_atividade.json, ela
NAO entra no indice e e listada em candidatos_sem_rotulo.csv. Isso deve dar
lista vazia sobre o corpus original. Lista nao vazia significa uma de duas
coisas: o corpus mudou (nova versao da CBO), ou o lexico foi alterado. Em
qualquer dos dois casos as novas atividades precisam passar pelo protocolo de
duas passagens da RUBRICA.md antes de serem incorporadas. Nao atribua classe
pelo termo que capturou: foi justamente isso que o desenho descartou.

Numeros de referencia para conferencia (nota metodologica, secao 5)
-------------------------------------------------------------------
    registros de atividade                       192.745
    ocupacoes cobertas                             2.700
    enunciados distintos      50.952 na nota; 50.874 neste script
    atividades candidatas      1.868 na nota;  1.866 neste script
        (a diferenca vem da normalizacao de caixa e espacos na chave de
        juncao; nao afeta nenhum indice)
    ocupacoes reportaveis (n >= 15)                2.672
    rotulos: VERDE 825 | POTENCIAL 348 | MARROM 311 | NEUTRO 386
    indice verde: mediana 0,0081 | p90 0,0417 | maximo 0,2750
    margem extensiva verde 51,2% | marrom 10,5%
    ocupacoes sem atividade exclusiva na familia     981
    topo: 862310 com 0,2750 | base: 811620 com -0,4000
"""

import csv
import json
import os
import sys
import statistics

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lexico  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)

CAMINHOS = {
    'perfil': os.path.join(RAIZ, 'analise_cbo_onnet', 'ESTRUTURA CBO',
                           'CBO2002 - PerfilOcupacional.csv'),
    'rotulos': os.path.join(AQUI, 'rotulos_atividade.json'),
    'saida': os.path.join(AQUI, 'saida'),
}

# Numero minimo de atividades descritas para que o indice seja reportado.
# Abaixo disso a razao assume valores discretos muito espacados. Decisao
# documentada na secao 9 da nota metodologica; revisavel.
MINIMO_ATIVIDADES = 15


def ler_perfil(caminho):
    """Retorna lista de (cod_ocupacao, nome_ocupacao, cod_familia, nome_atividade).

    O arquivo da CBO e separado por ponto e virgula e vem em latin-1. As duas
    codificacoes sao tentadas porque versoes do portal variam.
    """
    for enc in ('latin-1', 'utf-8-sig'):
        try:
            with open(caminho, encoding=enc, newline='') as f:
                amostra = f.read(8192)
                f.seek(0)
                sep = ';' if amostra.count(';') > amostra.count(',') else ','
                linhas = list(csv.DictReader(f, delimiter=sep))
            break
        except UnicodeDecodeError:
            continue
    else:
        raise SystemExit('nao foi possivel decodificar %s' % caminho)

    if not linhas:
        raise SystemExit('arquivo vazio: %s' % caminho)

    cols = {c.upper().strip(): c for c in linhas[0]}

    def col(*alternativas):
        for a in alternativas:
            if a in cols:
                return cols[a]
        raise SystemExit('coluna nao encontrada (tentadas: %s). Colunas do '
                         'arquivo: %s' % (', '.join(alternativas),
                                          ', '.join(sorted(cols))))

    c_ocu = col('COD_OCUPACAO', 'CODIGO', 'COD')
    c_ati = col('NOME_ATIVIDADE', 'ATIVIDADE', 'TITULO')
    c_fam = col('COD_FAMILIA', 'FAMILIA')
    try:
        c_nom = col('NOME_OCUPACAO', 'TITULO_OCUPACAO')
    except SystemExit:
        c_nom = None

    out = []
    for r in linhas:
        cod = (r[c_ocu] or '').strip()
        ati = (r[c_ati] or '').strip()
        if not cod or not ati:
            continue
        out.append((cod.zfill(6), (r[c_nom] or '').strip() if c_nom else '',
                    (r[c_fam] or '').strip().zfill(4), ati))
    return out


def chave(texto):
    """Chave de juncao entre o corpus e os rotulos: texto normalizado."""
    return ' '.join(lexico.normalizar(texto).split())


def main():
    perfil = ler_perfil(CAMINHOS['perfil'])
    rotulos_raw = json.load(open(CAMINHOS['rotulos'], encoding='utf-8'))
    rotulos = {chave(r['atividade']): r['classe'] for r in rotulos_raw}

    print('registros de atividade: %d' % len(perfil))
    distintos = {chave(a) for _, _, _, a in perfil}
    print('enunciados distintos: %d' % len(distintos))

    # ---- varredura do lexico: so os enunciados distintos, por economia ----
    candidatos = {k for k in distintos if lexico.casar(k)}
    print('atividades candidatas: %d' % len(candidatos))

    sem_rotulo = sorted(candidatos - set(rotulos))
    if sem_rotulo:
        print('ATENCAO: %d atividades candidatas sem rotulo. Ver '
              'saida/candidatos_sem_rotulo.csv' % len(sem_rotulo))

    # ---- contagem por ocupacao ----
    ocup = {}
    fam_ativ = {}   # familia -> {chave: numero de ocupacoes da familia que a usam}
    for cod, nome, fam, ati in perfil:
        k = chave(ati)
        o = ocup.setdefault(cod, {'nome': nome, 'familia': fam, 'ativ': set(),
                                  'n': 0})
        if nome and not o['nome']:
            o['nome'] = nome
        o['n'] += 1
        o['ativ'].add(k)
        fam_ativ.setdefault(fam, {}).setdefault(k, set()).add(cod)

    linhas = []
    for cod, o in sorted(ocup.items()):
        n = o['n']
        classes = [rotulos.get(k) for k in o['ativ']]
        nv = sum(1 for c in classes if c == 'VERDE')
        np_ = sum(1 for c in classes if c == 'POTENCIAL')
        nm = sum(1 for c in classes if c == 'MARROM')

        # atividades exclusivas: usadas por esta ocupacao e por nenhuma outra
        # da mesma familia. Aproximacao empirica da nocao de tarefa especifica
        # de Vona et al. (2018), que a CBO nao marca.
        usos = fam_ativ.get(o['familia'], {})
        excl = [k for k in o['ativ'] if len(usos.get(k, ())) <= 1]
        ne = len(excl)
        cls_e = [rotulos.get(k) for k in excl]
        nve = sum(1 for c in cls_e if c == 'VERDE')
        nme = sum(1 for c in cls_e if c == 'MARROM')

        def r(x, d):
            return round(x / d, 5) if d else None

        linhas.append({
            'CBO': cod,
            'Ocupacao': o['nome'],
            'Familia': o['familia'],
            'N_atividades': n,
            'Reportavel': 'sim' if n >= MINIMO_ATIVIDADES else 'nao',
            'Verde_amplo': r(nv, n),
            'Verde_amplo_broad': r(nv + np_, n),
            'Marrom': r(nm, n),
            'Liquido': r(nv - nm, n),
            'Liquido_broad': r(nv + np_ - nm, n),
            'N_ativ_verdes': nv,
            'N_ativ_potenciais': np_,
            'N_ativ_marrons': nm,
            'N_ativ_especificas': ne,
            'Verde_especifico': r(nve, ne),
            'Marrom_especifico': r(nme, ne),
            'Liquido_especifico': r(nve - nme, ne),
        })

    os.makedirs(CAMINHOS['saida'], exist_ok=True)
    destino = os.path.join(CAMINHOS['saida'], 'indice_por_ocupacao.csv')
    with open(destino, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(linhas[0]), delimiter=';')
        w.writeheader()
        w.writerows(linhas)

    if sem_rotulo:
        with open(os.path.join(CAMINHOS['saida'], 'candidatos_sem_rotulo.csv'),
                  'w', encoding='utf-8-sig', newline='') as f:
            w = csv.writer(f, delimiter=';')
            w.writerow(['Atividade', 'Termos_que_capturaram'])
            for k in sem_rotulo:
                w.writerow([k, '|'.join(lexico.casar(k))])

    # ---- conferencia contra os numeros de referencia ----
    rep = [x for x in linhas if x['Reportavel'] == 'sim']
    v = sorted(x['Verde_amplo'] for x in rep)
    sem_excl = sum(1 for x in linhas
                   if x['N_ativ_especificas'] == 0
                   and len(fam_ativ.get(x['Familia'], {})) > 0)

    def pct(p):
        return v[min(len(v) - 1, int(len(v) * p / 100))]

    print('')
    print('%-42s %12s %12s' % ('', 'obtido', 'referencia'))
    conf = [
        ('ocupacoes cobertas', len(linhas), 2700),
        ('ocupacoes reportaveis', len(rep), 2672),
        ('margem extensiva verde (%)',
         round(100 * sum(1 for x in rep if x['Verde_amplo'] > 0) / len(rep), 1), 51.2),
        ('margem extensiva marrom (%)',
         round(100 * sum(1 for x in rep if x['Marrom'] > 0) / len(rep), 1), 10.5),
        ('indice verde mediana', round(statistics.median(v), 4), 0.0081),
        ('indice verde p90', round(pct(90), 4), 0.0417),
        ('indice verde maximo', round(max(v), 4), 0.275),
        ('ocupacoes sem atividade exclusiva', sem_excl, 981),
    ]
    for rotulo, obtido, ref in conf:
        marca = 'ok' if abs(float(obtido) - float(ref)) <= max(0.0002, abs(ref) * 0.01) else 'DIVERGE'
        print('%-42s %12s %12s  %s' % (rotulo, obtido, ref, marca))

    print('')
    print('escrito: %s' % destino)


if __name__ == '__main__':
    main()
