#!/usr/local/bin/bash

# $VERSION = '0';

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

for zone in seq
do
  for qc_set in qc cgp ddd
  do
    infile="fluidigm_${qc_set}_${zone}_baton_plex_list_${dttag}.txt"
    outfile_base="fluidigm_${qc_set}_${zone}_gt_${dttag}"

    if [ -e "${infile}" ]
    then
      printf "================\nProcessing plex list %s, output to %s.tsv\n===============\n" "${infile}" "${outfile_base}"
      baton-get --avu --unbuffered < "${infile}" | reformat_fluidigm_snp26_results_irods.pl -s 2> "${outfile_base}.err" > "${outfile_base}.tsv"
      printf "================\nProcessed plex list %s\n===============\n" "${infile}"
    else
      printf "================\nFailed to find expected plex list %s, skipping\n===============\n" "${infile}"
    fi
  done 
done 

cp -v latest_plex_list.txt latest_processed_plex_list.txt

printf "Done\n"
