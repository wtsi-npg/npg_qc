#!/usr/bin/env bash

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

prev_dttag="$(cat latest_combined_file.txt)"
dttag="$(cat latest_plex_list.txt)"
plex=(qc cgp ddd)

######################################
# generate plex list increment subsets
######################################
for zone in ${GTCK_IRODS_ZONE} # single value or space-delimited list
do
  for qc_set in "${plex[@]}"
  do
    printf "Producing plex list increment subset for %s_%s\n" "${qc_set}" "${zone}";
    comm -13 \
      <(cat fluidigm_"${qc_set}"_"${zone}"_baton_plex_list_"${prev_dttag}".txt | grep -E "\"(collection|data_object)\":" | tr -d " \t\"," | tr ":" "\t" | while read -r k v
        do
          printf "%s" "${v}"
          if [ "${k}" == "collection" ]
          then
            printf "/"; else printf "\n"
          fi
        done | sort) \
      <(cat fluidigm_"${qc_set}"_"${zone}"_baton_plex_list_"${dttag}".txt | grep -E "\"(collection|data_object)\":" | tr -d " \t\"," | tr ":" "\t" | while read -r k v
        do
          printf "%s" "${v}"
            if [ "${k}" == "collection" ]
            then
              printf "/"
            else
              printf "\n"
            fi
          done | sort) \
    > fluidigm_"${qc_set}"_"${zone}"_plex_"${prev_dttag}"_to_"${dttag}"_increment.txt
  done
done

##############################################################################################################
# produce sample, fluidigm gt csv file lists. It has also been assumed here that the changes are all additions
##############################################################################################################
for zone in ${GTCK_IRODS_ZONE} # single value or space-delimited list
do
  for qc_set in "${plex[@]}"
  do
    cat fluidigm_"${qc_set}"_"${zone}"_plex_"${prev_dttag}"_to_"${dttag}"_increment.txt | while read -r fgtf
    do
      sn=$(imeta -z seq ls -d "${fgtf}" | grep -A1 "sample$" | tail -1 | tr -d " \t" | cut -d':' -f2)
      if [ -z "${sn}" ]
      then
        sn="NOSAMPLE"
      fi
      printf "%s\t%s\n" "${sn}" "${fgtf}"
    done > fluidigm_"${qc_set}"_"${zone}"_fpl_sn_"${prev_dttag}"_to_"${dttag}"_subset.tsv
  done
done

###################################
# produce genotypes tsv for subsets
###################################
for zone in ${GTCK_IRODS_ZONE} # single value or space-delimited list
do
  for qc_set in "${plex[@]}"
  do
    grep -v NOSAMPLE fluidigm_"${qc_set}"_"${zone}"_fpl_sn_"${prev_dttag}"_to_"${dttag}"_subset.tsv | while read -r sn fpgt
    do
      printf '{"avus":[{"attribute":"sample", "value":"%s"}], "data":"%s"}\n' \
        "${sn}" \
        "$(iget "${fpgt}" - | sed -e "s/\t/\\\t/g" -e "s/$/\\\n/g" | tr -d "\n")"
    done | reformat_fluidigm_snp26_results_irods.pl -s 2> fluidigm_"${qc_set}"_"${zone}"_gt_"${prev_dttag}"_to_"${dttag}"_subset.err > fluidigm_"${qc_set}"_"${zone}"_gt_"${prev_dttag}"_to_"${dttag}"_subset.tsv
  done
done

cp -v latest_plex_list.txt latest_processed_plex_list.txt

printf "Done: gtck_extract_incremental_fluidigm_data_from_irods\n"
