# Discussion Summary

The data sets and the script were reviewed by @nerdstrike, @mgcam and @ia1 mid
February 2022.

The selection by [Ct value](https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/926410/Understanding_Cycle_Threshold__Ct__in_SARS-CoV-2_RT-PCR_.pdf)
might introduce a bias. Since the data we want to normalise will not be subject
to selection, this selection might not be appropriate.

Since we will be normalising the worst -ve control (highest number of reads),
it might be better to use only one data point per lane (the worst -ve control)
when doing the regression analysis.

It is correct not to include data points with zero number of reads. They would
add weight to the low range without adding information to the model, and would
always pass QC in any event.

Not much threshold-breaking (1000+ reads) data in the dataset. This makes
fitting a regression line unstable in the currently decisive QC pass/fail
region. Expect a large confidence interval.

PhiX read counts had better scale linearly with the well occupancy.
We've only got 100% and 33%-ish sampled to justify it, the experiment was done
with v3 primer. It has to be repeated with the currently used primer paner.
The procedure of adding PhiX (manual or automatic) should be the same as is
planned for future production runs. At least 5 data points are needed for the
results to have statistical power.

An alternative way of setting the pass/fail threshold can be considered. It
can be based on a percentile of the distribution. That's effectively what
we'll be doing with this regression line interpolation. This suggestion needs
further work to clarify the details.

Distribution of the PhiX reads numbers has to be investigated as was done by
@ia1 in the past. If any outliers are detected, their significance should be
explored.

The proposed method should not be used for lanes with low degree of deplexing.
Data from such lanes should not be considered when generating a dataset for
computing the regression.

The proposed method can only be used if the number of PhiX reads in a lane is
within the pre-computed 'normal' range, which will have to be adapted for the
occupancy.

An option of using an aligned number of PhiX reads vs the number of reads after
deplexing should be investigated.
 
 

