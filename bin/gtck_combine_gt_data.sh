#!/usr/local/bin/bash

# $VERSION = '0';

GTCK_IRODS_ZONE="${GTCK_IRODS_ZONE:-seq}"
GTCK_STATIC_DATA_DIR="${GTCK_STATIC_DATA_DIR:-/nfs/srpipe_references/genotypes/data_prep/static_data}"

# GTCK_AIX_DATA - location of aix file, which specifies the allele order for heterozygous calls for the SNP set
GTCK_AIX_FILE="${GTCK_AIX_FILE:-W30467_sgd_reference.aix}"
GTCK_AIX_DATA="${GTCK_AIX_DATA:-${GTCK_STATIC_DATA_DIR}/${GTCK_AIX_FILE}}"

# GTCK_SEQUENOM_GT_DATA - location of Sequenom genotype results in tsv format
GTCK_SEQUENOM_GT_FILE="${GTCK_SEQUENOM_GT_FILE:-current_sequenom_gt.tsv}"
GTCK_SEQUENOM_GT_DATA="${GTCK_SEQUENOM_DATA:-${GTCK_STATIC_DATA_DIR}/${GTCK_SEQUENOM_GT_FILE}}"

# GTCK_HDR_DATA - location of tsv header for combined file
GTCK_HDR_FILE="${GTCK_HDR_FILE:-W30467_snp26_hdr_reference.tsv}"
GTCK_HDR_DATA="${GTCK_HDR_DATA:-${GTCK_STATIC_DATA_DIR}/${GTCK_HDR_FILE}}"

printf '*** gtck_combine_gt_data.sh ***\n'
printf "GTCK_IRODS_ZONE: %s\n" ${GTCK_IRODS_ZONE}
printf "GTCK_STATIC_DATA_DIR: %s\n" ${GTCK_STATIC_DATA_DIR}
printf "GTCK_SEQUENOM_GT_DATA: %s\n" ${GTCK_SEQUENOM_GT_DATA}
printf "GTCK_AIX_DATA: %s\n" ${GTCK_AIX_DATA}
printf "GTCK_HDR_DATA: %s\n" ${GTCK_HDR_DATA}

if [[ ! -e latest_processed_plex_list.txt ]]
then
  echo "Not producing new combined genotype data file - no latest_processed_plex_list.txt"
  exit 0
fi

if [[ -e latest_combined_file.txt ]] && cmp -s latest_processed_plex_list.txt latest_combined_file.txt
then
  echo "Not producing new combined genotype data file - no new data (latest_processed_plex_list.txt and latest_combined_file.txt are the same)"
  exit 0
fi

dttag="$(cat latest_processed_plex_list.txt)"

#######################################################
# first check that all required input files are present
#######################################################
infile=${GTCK_SEQUENOM_GT_DATA}
if [ ! -e "${infile}" ]
then
  printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
  exit 1
fi
infile=${GTCK_HDR_DATA}
if [ ! -e "${infile}" ]
then
  printf "================\nNot producing new combined genotype data file - failed to find input file hdr_snp26.tsv\n===============\n"
  exit 1
fi
for zone in ${GTCK_IRODS_ZONE}
do
  for qc_set in qc cgp ddd
  do
    infile="fluidigm_${qc_set}_${zone}_gt_${dttag}.tsv"

    if [ ! -e "${infile}" ]
    then
      printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
      exit 1
    fi
  done 
done 

###########################
# produce the combined file
###########################
printf "Combining current_sequenom_gt.tsv "; printf "%s " "fluidigm_{qc,cgp,ddd}_{zones}_gt_${dttag}.tsv"; printf "to produce sequenom_fluidigm_combo_sgd_%s.tsv\n" "${dttag}"
cat hdr_snp26.tsv <(tail -n +2 current_sequenom_gt.tsv | cut -f2-) > "sequenom_fluidigm_combo_sgd_${dttag}.tsv"
for zone in ${GTCK_IRODS_ZONE}
do
  cat fluidigm_{qc,cgp,ddd}_${zone}_gt_${dttag}.tsv >> "sequenom_fluidigm_combo_sgd_${dttag}.tsv"
done

##########################
# pack it to binary format
##########################
gt_pack -o "sequenom_fluidigm_combo_sgd_${dttag}" -s 1 -P ${GTCK_AIX_DATA} "sequenom_fluidigm_combo_sgd_${dttag}.tsv"

cp -v latest_processed_plex_list.txt latest_combined_file.txt

printf "Done\n"
