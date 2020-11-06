#!/usr/bin/env bash

# Exit on error
set -e -o pipefail

# $VERSION = '0';

if [[ -e latest_plex_list.txt ]] && [[ -e latest_combined_file.txt ]] && ! cmp -s latest_plex_list.txt latest_combined_file.txt
then
  echo "Run appears to be in progress (contents of latest_plex_list.txt and latest_combined_file.txt differ)"
  exit 0
fi

# extract lists of relevant data_object names
gtck_genplexlist.sh

# extract the genotype data from iRODS, reformat it to common (tsv) format
gtck_extract_fluidigm_data_from_irods.sh

# combine the consistently formatted data files from the previous step, and convert the result to binary format
gtck_combine_gt_data.sh

# copy the final outputs to the archive and update the live data in the repository
gtck_install_to_repos.sh

printf "Done\n"

