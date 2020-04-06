Illimuna Sequencing Data QC at WSI

Most of data produced by Illumina sequencers go though manual assessment,
which takes place after the run data went through the analysis pipeline,
which is run by the Institute's core bioinformatics team, and before the
data are deposited in the institute's archive. Metrics that are necessary
for QC assessment are produced during the analysis.

The manual QC assessment is peformed by a special team within Sequencing
Operations. Success of the sequencing process and quality of individual
or pooled libraries is assesed separately. The criteria applied during
the assessment do not necessary reflect all complexity of research
projects and end-user requirements. After the data are archived, end users
often perform their own assessment and are able to save its outcome in the
database that supports the QC process. The outcome of these assessments is
exported to the Institute's warehouse database as 1 for a pass and 0 for a
fail.

QC Outcomes Columns in the Warehouse Database
=====================================
table                    column name
=====================================
iseq_run_lane_metrics    qc_seq
iseq_product_metrics     qc_seq
iseq_product_metrics     qc_lib
iseq_product_metrics     qc_user
iseq_product_metrics     qc

qc_seq  - assessment of sequencing process and pool deplexing level,
          granularity level - lane of a flowcell, performed by the
          manual QC team
qc_lib  - assessment of library quality, granularity - individual
          product (lane, plex or a merged product), performed by the
          manual QC team
qc_user - assessment of product usability for a particular research
          project, performed either manually by the end user
          representative or automatically using criteria agreed with
          the project owners
qc      - an overall value for a product; a fail if any of the above
          qc outcomes are a fail, a pass if qc_user outcome is a pass
          or, when the qc user outcome is not defined, when both qc_lib
          and qc_seq are a pass, undefined if both qc_user and qc_lib
          are undefined and qc_seq is a pass

Other relevant code repositories: https://github.com/wtsi-npg/ml_warehouse,
https://github.com/wtsi-npg/npg_ml_warehouse


