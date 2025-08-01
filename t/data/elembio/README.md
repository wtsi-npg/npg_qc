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
- 20250620_AV244103_NT1856569G has an R1 but no R2
- 20250718_AV244103_NT1859538L_NT1859675T has two lanes with mostly differing samples
  between them
- 20250625_AV244103_NT1857425S a two-lane run with one-library the same pool
  in each lane

Corresponding manifest JSON files are also found there.

The code to generate the smaller RunStats.json is found in
`/t/scripts/simplify_aviti_runstats.pl`. It rather crudely removes data not
pertinent to npg_qc at time of writing, such as per base cycle statistics.
