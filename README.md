# QC Checks and Metrics for Illumina Next Generation Sequencing Data

## Listing of Directories

### lib

 - npg_qc::Schema namespace - DBIx ORM
 - npg_qc::illumina namespace - db loaders for Illumina QC metrics
 - npg_qc::autoqc namespace - WSI core sequencing pipeline in-house
     QC checks and storage of QC metrics
 - npg_qc::mqc - evaluation and reporting of QC metrics

### bin

Perl scripts which are deployed to the production environment

### scripts

Supplementary scripts, not deployed

### t

Tests, test data, supplementary scripts and modules for testing

### npg_qc_viewer

Source code for the web server that displays the QC metrics

### docs

Documentation, useful code snippets

## NPG QC database

### Legacy Data

QC metrics and evaluation outcomes for all production Illumina sequencing runs
are stored in a relational database. This database has four legacy tables,
`recipe_file`, `run_and_pair`, `run_info`, `run_recipe`, for which we do not
generate ORM classes. No code is using these tables. The data is kept for
auditing perposes. The size of these tables is small in comparison with the size
of the rest of the tables. The overhead of moving these old tables to a different
storage is not justified.


