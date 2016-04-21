===========================
Items from Year 2015 List
===========================

#. Grunt configuration for tasks
#. Use minified javascript files with random names - will force the browser to fetch newly released javascript
#. Deal with failed but should be charged scenario
#. It's currently not immediately obvious if data has been subject to a split but important if say human split has been incorrectly selected for a mouse study (or not selected for a pathogen study contaminated with human). Could be determined just using the flagstats file names.

===============================================
Items from Plex-level Manual QC Document (2015)
===============================================

Indication of Charge in Manual QC
  #. An interface (GUI widgets) for making alternative charge suggestions will be displayed once a final decision for a lane is registered.
  #. By default a pass means a charge and a fail means no charge.
  #. The additional interface only has to be used if alternative charge decisions have to be communicated.
  #. The charge decisions will be stored in the QC database (maintained by NPG). Currently there is no mechanism to communicate these decisions. The SeqQC display will give indication of the charge decision

Target file level release flag
  #. Release flags will be provided per target file.
  #. The initial value will be true if either manual qc is pass or a charge is made.
  #. A GUI will be provided to update (overwrite) the value.

==============================
Items from existing RT tickets
==============================
#. VerifyBamId highlighting RT#488816
#. Display number of times a library has been sequenced
#. Return of the collapser RT#517381

=============================
Other discussed topics (2015)
=============================
#. Auto-suggests (aiming towards implementation of auto pass/fail in at least some cases - SMT re-requested 2016).
#. RNA autoqc suite
#. Display samtools stats plots, especially indel per cycle plots.
#. 'Library' complete - library plex data ready to merge (or merged data ready to be picked up by downstream analysts). Requires further clarification/discussion.
#. Fix usage of numbers with and without QC fail reads from flagstats files - for bam_flagstats. To allow correct display of %mapped on QC pages (requires GCLP approval).
#. Ref match - only show top 10 or 20 matches by default, but allow access to full report.

==============================================
Selected items from git project issues (2016)
==============================================
#. SeqQC - Create a light weight controller to provide data for what is qc-able in a page. It should work using the same/similar queries to those used for reporting current manual QC outcomes. Query the controller to take decisions about when to generate manual qc widgets in client side. (#319)
#. SeqQC run page: display lib qc stats (num_passed:num_undef:num_failed) for a lane (#281)

=========================================
ISSUES TO CONSIDER WHEN PLANNING A CHANGE
=========================================
#. The API used to change the qc outcomes manually does not validate lib outcomes against lane outcomes, making any combinations possible. The GUI interface that is used during the qc process imposes some constraints, see https://github.com/wtsi-npg/npg_qc/blob/devel/lib/npg_qc/mqc/outcomes.pm. This discrepancy reflects current business needs. The behaviour of the API should not be changed inadvertendly.




