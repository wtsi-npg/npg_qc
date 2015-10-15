#!/usr/local/bin/bash

# Exit on error
set -o pipefail

# $VERSION = '0';

GTCK_IRODS_ZONE="${GTCK_IRODS_ZONE:-seq}"

printf '*** gtck_extract_fluidigm_data_from_irods.sh ***\n'

if [[ ! -e latest_plex_list.txt ]]
then
  echo "Not running extract_fluidigm_data_from_irods - no latest_plex_list.txt"
  exit 0
fi

if [[ -e latest_processed_plex_list.txt ]] && cmp -s latest_plex_list.txt latest_processed_plex_list.txt
then
  echo "Not running extract_fluidigm_data_from_irods - no new data (latest_plex_list.txt and latest_processed_plex_list.txt are the same)"
  exit 0
fi

dttag="$(cat latest_plex_list.txt)"

for zone in ${GTCK_IRODS_ZONE} # single value or space-delimited list
do
  for qc_set in qc cgp ddd
  do
    infile="fluidigm_${qc_set}_${zone}_baton_plex_list_${dttag}.txt"
    outfile_base="fluidigm_${qc_set}_${zone}_gt_${dttag}"

    if [ -e "${infile}" ]
    then
      printf "================\nProcessing plex list %s, output to %s.tsv\n===============\n" "${infile}" "${outfile_base}"
      (irodsEnvFile=$HOME/.irods/.irodsEnv-${zone}_gtck baton-get --avu --unbuffered --silent) < "${infile}" | grep -v '^The client/server socket connection has been renewed$' | reformat_fluidigm_snp26_results_irods.pl -s 2> "${outfile_base}.err" > "${outfile_base}.tsv"

      if [ $? -ne 0 ]
      then
        printf "\n**** ERROR: failed to extract and reformat data for qc_set ${qc_set} - see %s/${outfile_base}.err for more detailed information\n\n" `pwd`
        exit -2
      fi

      printf "================\nProcessed plex list %s\n===============\n" "${infile}"
    else
      printf "================\nFailed to find expected plex list %s, skipping\n===============\n" "${infile}"
    fi
  done 
done 

cp -v latest_plex_list.txt latest_processed_plex_list.txt

printf "Done\n"
