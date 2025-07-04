# Elembio test data

## Heavily abbreviated RunStats.json files

Each JSON file has been truncated to only 6 samples (The default 4 controls,
2 named samples), and all data pertaining to cycles and histograms has been
reduced to empty lists so that the files are conveniently small.

Some of the originals are 100 MB or larger and strain JSON tools and text
editors.

- 20250401_AV244103_NT1853579T is a 600 cycle run with one lane and more than one barcode per sample
- 20240416_AV234003_16AprilSGEB2_2x300_NT1799722A is a 600 cycle run with one lane in use
- 20250225_AV244103_NT1850075L_NT1850808B_repeat3 has the single indexed samples
  that appear in both lanes

Corresponding manifest JSON files are also found there.

The code to generate the smaller RunStats.json is found in
`/t/scripts/simplify_aviti_runstats.pl`. It rather crudely removes data not
pertinent to npg_qc at time of writing, such as per base cycle statistics.
