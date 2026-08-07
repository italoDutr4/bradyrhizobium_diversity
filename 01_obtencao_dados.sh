#!/bin/bash
# =============================================================================
# 01_obtencao_dados.sh
#
# Obtencao de dados brutos - genomas de Bradyrhizobium (NCBI)
#
# Objetivo: baixar a lista de todos os assemblies de Bradyrhizobium
# disponiveis no NCBI, extrair os metadados relevantes (qualidade, host,
# localizacao geografica, nivel de montagem) para uma tabela, e (apos a
# curadoria em R - ver 01_curadoria_metadados.R) baixar os arquivos de
# genoma/proteina dos accessions finais selecionados.
#
# Pre-requisito: ambiente conda "bradyrhizobium" ja criado e ativado, com
# ncbi-datasets-cli e entrez-direct instalados (ver secao 0 abaixo, rodar
# so na primeira vez).
#
# Como rodar:
#   chmod +x 01_obtencao_dados.sh   (so na primeira vez)
#   bash 01_obtencao_dados.sh
#
# Observacao: este script foi dividido em blocos numerados. Os blocos 4 e 6
# (download efetivo de genomas) sao demorados e dependem da tabela curada em
# R ja estar pronta (accessions_finais.txt) - rode-os separadamente, nao como
# parte de uma execucao automatica de ponta a ponta.
# =============================================================================

set -e  # interrompe o script se algum comando falhar, em vez de seguir adiante

echo "===== 01_obtencao_dados.sh ====="

## ---- 0. Configuracao do ambiente (rodar so na primeira vez) ---------------
## Descomente as linhas abaixo caso o ambiente ainda nao exista.
##
## conda create -n bradyrhizobium -c conda-forge -c bioconda \
##   ncbi-datasets-cli entrez-direct -y

echo ""
echo "--- Ativando ambiente conda 'bradyrhizobium' ---"
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate bradyrhizobium

## ---- 1. Baixar a lista bruta de todos os genomas do taxon -----------------

echo ""
echo "--- Bloco 1: consultando NCBI por todos os assemblies de Bradyrhizobium ---"
datasets summary genome taxon "Bradyrhizobium" --as-json-lines \
  > bradyrhizobium_genomes.jsonl

echo "Total de registros brutos:"
wc -l bradyrhizobium_genomes.jsonl

## ---- 2. Converter para tabela com os campos relevantes --------------------

echo ""
echo "--- Bloco 2: gerando tabela de diagnostico (qualidade, host, pais, nivel) ---"
dataformat tsv genome --inputfile bradyrhizobium_genomes.jsonl \
  --fields accession,assminfo-level,assminfo-atypicalis-atypical,source_database,checkm-completeness,checkm-contamination,assminfo-biosample-host,assminfo-biosample-geo-loc-name,assminfo-biosample-isolation-source,assminfo-biosample-lat-lon,organism-name \
  > bradyrhizobium_diagnostico.tsv

echo "Tabela gerada: bradyrhizobium_diagnostico.tsv"
head -n 5 bradyrhizobium_diagnostico.tsv

## ---- 3. Estimativa de tamanho em disco antes do download ------------------
## Util para planejar espaco antes do download efetivo (bloco 6).

echo ""
echo "--- Bloco 3: extraindo tamanho de sequencia de cada genoma (para estimativa de espaco) ---"
dataformat tsv genome --inputfile bradyrhizobium_genomes.jsonl \
  --fields accession,assmstats-total-sequence-len \
  > tamanhos_genomas.tsv

echo "Tabela gerada: tamanhos_genomas.tsv"
echo "(o calculo do total estimado em GB e feito em R - ver bradyrhizobium_analise.Rmd, Etapa 7)"

## ---- 4. [PAUSA MANUAL] Curadoria em R ---------------------------------------
## A partir daqui, a tabela bradyrhizobium_diagnostico.tsv deve ser processada
## em R (desduplicacao GCF/GCA, filtro de qualidade, padronizacao de pais e
## hospedeiro - ver 01_curadoria_metadados.R ou bradyrhizobium_analise.Rmd).
##
## Isso gera o arquivo "accessions_finais.txt", necessario para o bloco 6
## abaixo. NAO prossiga para o bloco 6 sem esse arquivo pronto.

echo ""
echo "===== Blocos 1-3 concluidos ====="
echo "Proximo passo: rodar a curadoria em R (01_curadoria_metadados.R) para"
echo "gerar accessions_finais.txt antes de prosseguir para o download dos genomas."
echo ""
echo "Para rodar o download dos genomas (bloco 6), execute separadamente:"
echo "  bash 01_obtencao_dados.sh --download-genomas"
echo ""

## ---- 5. Verificacao de espaco em disco -------------------------------------

if [ "$1" == "--download-genomas" ]; then

  echo "--- Verificando espaco livre em disco ---"
  df -h ~

  ## ---- 6. Download dos genomas selecionados --------------------------------
  ## IMPORTANTE: recomenda-se rodar este bloco dentro de uma sessao tmux,
  ## para proteger o download contra quedas de conexao/fechamento do terminal:
  ##
  ##   tmux new -s download_bradyrhizobium
  ##   bash 01_obtencao_dados.sh --download-genomas
  ##   (Ctrl+b, depois d, para "detach")
  ##
  ## Se o download falhar (erro de stream/zip corrompido - ja ocorreu em
  ## tentativas anteriores), apague o zip parcial e rode de novo:
  ##   rm bradyrhizobium_genomes.zip

  echo ""
  echo "--- Bloco 6: baixando genomas selecionados (accessions_finais.txt) ---"

  if [ ! -f accessions_finais.txt ]; then
    echo "ERRO: accessions_finais.txt nao encontrado."
    echo "Rode a curadoria em R primeiro (01_curadoria_metadados.R)."
    exit 1
  fi

  datasets download genome accession --inputfile accessions_finais.txt \
    --include genome,protein,seq-report \
    --filename bradyrhizobium_genomes.zip

  echo ""
  echo "--- Bloco 7: extraindo arquivos baixados ---"
  unzip bradyrhizobium_genomes.zip -d bradyrhizobium_genomes/

  echo ""
  echo "--- Conferencia: numero de genomas efetivamente baixados ---"
  n_baixados=$(find bradyrhizobium_genomes/ncbi_dataset/data/ -name "*.fna" | wc -l)
  n_esperado=$(wc -l < accessions_finais.txt)
  echo "Baixados: $n_baixados  |  Esperado: $n_esperado"

  if [ "$n_baixados" -ne "$n_esperado" ]; then
    echo "AVISO: numero de genomas baixados difere do esperado. Investigar accessions faltantes."
  fi

fi

echo ""
echo "===== Fim do script ====="
