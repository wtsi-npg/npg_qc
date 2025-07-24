#!/usr/bin/env bash

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
printf "GTCK_IRODS_ZONE: %s\n" "${GTCK_IRODS_ZONE}"
printf "GTCK_STATIC_DATA_DIR: %s\n" "${GTCK_STATIC_DATA_DIR}"
printf "GTCK_SEQUENOM_GT_DATA: %s\n" "${GTCK_SEQUENOM_GT_DATA}"
printf "GTCK_AIX_DATA: %s\n" "${GTCK_AIX_DATA}"
printf "GTCK_HDR_DATA: %s\n" "${GTCK_HDR_DATA}"

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

prev_dttag="$(cat latest_combined_file.txt)"
dttag="$(cat latest_processed_plex_list.txt)"
plex=(qc cgp ddd)

#######################################################
# first check that all required input files are present
#######################################################
infile=${GTCK_SEQUENOM_GT_DATA}
if [ ! -e "${infile}" ]
then
  printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
  exit 1
fi
infile=${GTCK_AIX_DATA}
if [ ! -e "${infile}" ]
then
  printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
  exit 1
fi
infile=${GTCK_HDR_DATA}
if [ ! -e "${infile}" ]
then
  printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
  exit 1
fi
not_empty=0
for zone in ${GTCK_IRODS_ZONE}
do
  for qc_set in "${plex[@]}"
  do
    infile="fluidigm_${qc_set}_${zone}_gt_${prev_dttag}_to_${dttag}_subset.tsv"

    if [ ! -e "${infile}" ]
    then
      printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
      exit 1
    fi

    if [ -s "${infile}" ]
    then
      ((not_empty++))
      printf "================\nIncrement for input file %s\n===============\n" "${infile}"
    fi
  done 
done 

###########################
# produce the combined file
###########################
if [ ${not_empty} -gt 0 ]
then
  prev_combo_tsv=sequenom_fluidigm_combo_sgd_"${prev_dttag}".tsv
  new_combo_tsv=sequenom_fluidigm_combo_sgd_"${dttag}".tsv

  # the previous data file must at least contain header lines
  if [ ! -s "${prev_combo_tsv}" ]
  then
    printf "================\nNot producing new combined genotype data file - failed to find non-empty previous data file %s\n===============\n" "${prev_combo_tsv}"
    exit 1
  fi

  printf "Combining previous data %s with " "${prev_combo_tsv}"; printf "%s " fluidigm_{qc,cgp,ddd}_"${GTCK_IRODS_ZONE}"_gt_"${prev_dttag}"_to_"${dttag}".tsv; printf "to produce %s\n" "${dttag}" "${new_combo_tsv}"
  cp -iv "${prev_combo_tsv}" "${new_combo_tsv}"
  for zone in ${GTCK_IRODS_ZONE}
  do
    cat fluidigm_{qc,cgp,ddd}_"${zone}"_gt_"${prev_dttag}"_to_"${dttag}"_subset.tsv >> "${new_combo_tsv}"
  done

  ##########################
  # pack it to binary format
  ##########################
  gt_pack -o "sequenom_fluidigm_combo_sgd_${dttag}" -s 1 -P "${GTCK_AIX_DATA}" "${new_combo_tsv}"

  cp -v latest_processed_plex_list.txt latest_combined_file.txt

else
  printf "No updates for qc,cgp,ddd at %s\n" "${dttag}"
fi

printf "Done: gtck_combine_gt_data_incremental\n"
