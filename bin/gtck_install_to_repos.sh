#!/usr/bin/env bash

# $VERSION = '0';

GTCK_REPOS_ROOT="${GTCK_REPOS_ROOT:-/nfs/srpipe_references/genotypes /lustre/scratch109/srpipe/genotypes /lustre/scratch110/srpipe/genotypes}"

printf '*** gtck_install_to_repos.sh ***\n'

if [[ ! -e latest_combined_file.txt ]]
then
  echo "Not installing genotype data files to repository - no latest_combined_file.txt"
  exit 0
fi

if [[ -e latest_combined_file.txt ]] && cmp -s latest_combined_file.txt latest_repos_install.txt
then
  echo "Not installing genotype data files to repository - no new data (latest_combined_file.txt and latest_repos_install.txt are the same)"
  exit 0
fi

dttag="$(cat latest_combined_file.txt)"

for repos_root in ${GTCK_REPOS_ROOT} # single value or space-delimited list
do
  for ext in aix bin six
  do
    infile="sequenom_fluidigm_combo_sgd_${dttag}.${ext}"
    archive_outfile="${repos_root}/archive/sequenom_fluidigm_combo_sgd_${dttag}.${ext}.bz2"
    printf "Archiving %s to to %s\n" "${infile}" "${archive_outfile}"
    bzip2 -c sequenom_fluidigm_combo_sgd_"${dttag}"."${ext}" > "${archive_outfile}"

    outfile="${repos_root}/sequenom_fluidigm_combo_sgd.${ext}"
    printf "Updating current data (source: %s, target: %s)\n\n" "${infile}" "${outfile}"
    cp -uv "${infile}" "${outfile}"
  done
done

cp -v latest_combined_file.txt latest_repos_install.txt

printf "Done: gtck_install_to_repos\n"
