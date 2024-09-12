<!-- Space: NPG -->
<!-- Parent: Illumina Sequencing -->
<!-- Title: C->A short read sequencing substitution metrics -->

<!-- Macro: :box:([^:]+):([^:]*):(.+):
     Template: ac:box
     Icon: true
     Name: ${1}
     Title: ${2}
     Body: ${3} -->

:box:info:Note:This page is automatically generated; any edits will be overwritten:

###### Repository information

<!-- Include: includes/repo-metadata.md -->

# C->A short read sequencing substitution metrics

- Author - Irina Abnizova

## Background

The current generation of short-read sequencing technologies requires reliable measures of data quality. Such measures are especially important for variant calling. However, in the particular case of SNP calling, a great number of false-positive SNPs may be obtained. One needs to distinguish putative SNPs from sequencing or other errors. We found that not only the probability of sequencing errors (i.e. the quality value) is important to distinguish an FP-SNP but also other patterns of biased contribution of a particular substitution, e.g. a symmetry of substitution counts between direct and reverse (Illumina technology) reads, symmetry of reverse-complement strands, unusual proportion of Tv to Ti substitutions etc . We developed several  straight-forward, easy-to-compute metrics, which point to possible artefacts of high/low quality variant calls.
There are known error tendencies for Illumina technology:

### Library preparation: High  quality substitutions
- Adaptor and other contamination
- End repairs. Are there any enzyme motif preferences? This normally occurs when C has been deaminated via oxidative damage to a U. During repair enzymes recognise this as a T and add an A when repairing the other strand by a fill in method using a polymerase..
- PCR substitutions
- G-oxidation (C->A)
- Not exact reference of sequenced organism (any technology)

### On machine: Low quality substitutions (easier to deal -discard! )
- Dye label cross-talk (A-C and G-T channels for old Illumina releases)
- Phasing inaccuracy
- Degrading to the end of read
- G-quenching  (a tendency of a miscall of the bases directly preceded by G)- now almost gone for HX 

### Flow Cell surface 
- Problems on a tile surface (bubbles)
- C-flare
- Consequences of the above:  change of error types (for Low Quality) with each new Illumina release and machine type, e.g.
- Context dependency (GGC- GGT  patterns)
- HX- inflated X-talk and phasing/prephasing
- Dependence on next nucleotide instead of previous

Here we will deal only with high Q (Q+30) substitutions, which usually reflect library preparation problems.

# Notation.
Any substitution is defined by the nucleotide called and the corresponding nucleotide in a reference genome; this reference nucleotide is obtained after mapping the called read to the reference genome. There are 12 possible substitution types of substitutions: A> C, A> G, A> T, C> A, C> G, C> T, G> A, G> C, G> T, T> A, T> C and T> G. The first letter for each pair is what it is in a reference, and the second letter stands for what was called by sequencing. 

While analysing substitutions, we noticed some intriguing facts, such as: 

Certain substitution patterns and substitution types occur much more frequently than others and are common between organisms and runs. These observations inspired us to perform a systematic analysis of Illumina mis-matches/substitutions and to see which substitution types and substitution patterns are persistent between different lanes, runs, organisms, CG-contents and machines for Illumina sequencing. 
In studying the substitution context, we aimed to learn if an identity of previous and next  bases affects the substitution type and frequency.

## Method

For each data set (typically cram file), we collected all bases giving a mismatch with the reference genome after mapping the sequenced reads. We restricted our analysis to single nucleotide substitutions. To learn which substitution type is significantly frequent, we computed the frequencies for all 12 substitution types for runs and organisms, taking account of their nucleotide contents and normalizing them. Here we call substitution significantly frequent, if it deviates more than 2 standard deviations over mean values, thus having p < 0.05. We assume that substitution frequencies follow normal distribution.

We analysed substitutions with respect to their following features: 
(1) Quality of a substitution base call per reverse and forward Illumina reads.
(2) Frequency of a DNA substitution pattern within its context, namely identity of a base called and its preceding and next nucleotides in a sequenced read.
 In addition, we analysed other error’s features, which could reveal artifacts. Thus, we studied 
(3) Tile, genome, cycle distribution of substitutions, also separately per read.
(4) Symmetry between forward and reverse substitution counts, arriving after Illumina sequencing, e.g. CA and GT,  CT and GT.
(5) Symmetry between Illumina forward (Read1) and reverse (Read2) sequencing reads.
In our analysis we used the following observations:
SNPs are usually observed as double-stranded frequency peaks of high Purity substitutions at some particular genome positions, given that coverage is sufficient. 
Sequencing errors are typically accumulated at the end of read, while SNPs are distributed uniformly across a read. 

### Metrics for high Q substitutions

The result was a set of metrics which help to point to possible artefacts. The metrics below are computed for raw substitution values, not processed through variant calling QC. These high Q metrics reflect library preparation problems.

 We assume that for humans the majority of high quality substitutions (Q+30) are SNPs. Small fraction of Ti (TC,GA,CT,AG) can be PCR errors, arriving from enzyme infidelity. For phiX, Ti are mainly PCR errors. For organisms with not very known reference genomes they can be reference errors as well.
For each cram file (sample/tag) we compute the following metrics in the corresponding file having names of run, lane and tag, e.g. 40088_1#1_metrics.txt. Below in Table 1 we show an example.

Table 1. The example of the metric output from C2A check.
```
#C2A related stats and metrics for a tag 
TiTv_class   0.46
TiTv_meCA   1.58
fracH   0.27
oxoGHbias  0.07
symGT_CA 0.07
sym_ct_ga 0.11
sym_ag_tc 0.00
cvTi 0.05
GT_Ti 3.57
GT_meTi 3.49
level -1
art_oxH 3.49
predict 3
```

Below are the short explanation of each one of the metrics in Table1:

1/ TiTv_class   is  the ratio of transition substitution,Ti, counts (number of TC,GA,CT,AG) to transvertion, Tv, counts. These are the most frequent SNPs in the human genome.

One would expect for random mutation, Ti/Tv=0.5. It is known (1000Genome.org) for human WGS Ti/Tv~2.1, while for WES Ti/Tv ~ 3. If it is amplicon sequencing for particularly highly mutable genes, this ratio might be even larger.

Therefore, in our example we unexpectedly have too high a count of Tv (TiTv_class = 0.46).

2/ TiTv_meCA   = TiTv where count of CA+GT is taken as if it were mean across other Tv (AC,AT, CG, GC, TA, TG )

If it were only CA/GT inflated, then TiTv_meCA   will be close to 2.1. Which in our example is almost true: TiTv_meCA =  1.58. It gives us extra hints to be sceptical of CA/GT counts.

3/ fracH  is a fraction of all high Q (Q+30) substitutions within all substitutions, per read 1 or read 2. Healthy  fraction of Q+30 for humans will be around 0.22.
 
If it is inflated (e.g. fracH = 0.27 is too high in our example),  it is likely that some substitutions misbehave.

4/ oxoGHbias  0.07 shows how similar CA to GT counts are within each read.  BROAD paper 2012 showed that when we have oxoG contamination, these counts are often not equal within read, and even read-specific.

Actually, oxoGHbias =  0.07 is not very bad here…However, the other metrics (e.g. GT_Ti= 3.57 and GT_meTi = 3.49 here) are very warning here, see further.

5/ symGT_CA = 0.07 shows how symmetrical CA and GT counts are within each read.
In our example they have the same value (symGT_CA = 0.07), but it is not often the case.

The next two are metrics for Ti symmetry within a read: they should be symmetrical (which is manifested by a very small value close to zero) if everything is ok.

6/ sym_ct_ga 0.11 here

Is a little too high. It might indicate an unequal amount of CT and GA substitutions, which is not possible for real double stranded SNPs. It is likely there are some single stranded Ti here. If it is artefact or biological signal only those who created the library can tell. 
It might be a PCR error.

7/ sym_ag_tc 0.00

It looks fair: same amount of AG and TC, exactly as expected for a decent double-stranded SNPs.

8/ cvTi is a coefficient of variation across all Ti substitutions (TC,GA,CT,AG ), which is computed by formula:
        
cvTi=std(Ti)/mean(Ti)

We computed cvTi separately for each read 1 and read2, than took the maximal one.
It shows a variability of Ti counts, which ideally should be very small for DNA sequencing (for RNA it might be a little inflated AG and TC). 

cvTi = 0.05 is ok here.

9/ The next two metrics are very C2A related: GT_Ti 

GT_Ti is computed as a maximum between (i) ratio of GT counts to TC and (ii) ratio CA to GA.
An idea behind that is that it should be significantly less abundant than corresponding Ti. Therefore, when C2A is not there, this ratio is usually less than 0.5.
GT_Ti 3.57 is very high.

10/ GT_meTi 3.49

GT_meTi is similar to GT_Ti, but a little more general. It is computed as a maximum between (i) ratio of GT counts to mean(Ti) and (ii) ratio CA to mean(Ti). Ideally it is also less than 0.5.

GT_meTi = 3.49 is very high.


11/ Level is positive, if it was known, and we predicted blindly. Negative level means it was not known in advance.

12/ art_oxH here correspond to GT_meTi (in case of asymmetrical GT a little more than CA)
       art_oxH = 3.49 is very high.
This metric is used to compute the likelihood of C2A and its  predicted level.
```
predicted level - is approximated by the following values of where 'thr' = 0.8 ;
                 = 0, if  art_oxH < thr                 (not present)
                 = 1, if  thr <= art_oxH < thr+0.2      (low)
                 = 2, if  thr+0.2 <= art_oxH < thr+0.6  (medium)
                 = 3, if art_oxH > thr+0.6              (high)
```

### Warnings 

Our method is based on very raw counts, and does not really depend on a sequence depth. However, the experimental methods (variant calls and filtering in Jone’s and Adam’s labs) used to ‘train’ it do depend on the sequencing depth. So far our predictions corresponded to the not very deep sequencing experiments (~10x, ~15x ?). Therefore, our conclusions/predictions might need a depth adjustment.

