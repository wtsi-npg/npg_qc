#!/usr/local/bin/bash

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

# first check that all required input files are present
infile="current_sequenom_gt.tsv"
if [ ! -e "${infile}" ]
then
    printf "================\nNot producing new combined genotype data file - failed to find input file %s\n===============\n" "${infile}"
fi
if [ ! -e "hdr_snp26.tsv" ]
then
    printf "================\nNot producing new combined genotype data file - failed to find input file hdr_snp26.tsv\n===============\n"
fi
# Note: qc_set and zone set are specified both here and in the concatenation command below
for zone in seq
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

# produce the combined file
printf "Combining current_sequenom_gt.tsv "; printf "%s " "fluidigm_{qc,cgp,ddd}_seq_gt_${dttag}.tsv"; printf "to produce sequenom_fluidigm_combo_sgd_%s.tsv\n" "${dttag}"

# Note: qc_set and zone set are specified both here and in the for loop above
cat hdr_snp26.tsv <(tail -n +2 current_sequenom_gt.tsv | cut -f2-) "fluidigm_{qc,cgp,ddd}_seq_gt_${dttag}.tsv" > "sequenom_fluidigm_combo_sgd_${dttag}.tsv"

gt_pack -o "sequenom_fluidigm_combo_sgd_${dttag}" -s 1 -P /nfs/srpipe_references/genotypes/sgd.aix "sequenom_fluidigm_combo_sgd_${dttag}.tsv"

cp -v latest_processed_plex_list.txt latest_combined_file.txt

printf "Done\n"
