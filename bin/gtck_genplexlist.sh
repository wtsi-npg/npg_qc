#!/usr/local/bin/bash

dttag="$(date +%Y%m%d%H%M%S)";
for zone in seq
do
  for qc_set in qc cgp ddd
  do
    printf "Generating data_object list for fluidigm_plex = %s\n" ${qc_set}
    jq -n "{avus: [{attribute: \"fluidigm_plex\", value: \"${qc_set}\"}]}" | baton-metaquery --zone ${zone} --unbuffered | jq . | egrep -v "^\[|\]$" | sed -e "s/^  \},$/  \}/" > fluidigm_${qc_set}_${zone}_baton_plex_list_${dttag}.txt
  done
done

echo "${dttag}" > latest_plex_list.txt

printf "Done\n"
