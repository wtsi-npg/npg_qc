library(optparse, quietly=TRUE, verbose=FALSE)

rm(list=ls(all=TRUE))

option_list <- list(
    make_option("--mappable_bins", type="character", help="Mappable bins file []"),
    make_option("--sample_bin_counts", type="character", help="Sample bins count file []"),
    make_option("--output_dir", type="character", help="Directory to write results []"),
    make_option("--rscripts_dir", type="character", help="script directory[]"),
    make_option("--chromosomes", type="character", help="list of chromosomes[]"),
    make_option("--bin_size", type="character", help="read_length[]"),
    make_option("--sample_name", type="character", help="sample name[]"),
    make_option("--read_length", type="integer", help="bin size[]"),
    make_option("--gamma", type="integer", help="gamma value[]")
)

opt <- parse_args(OptionParser(option_list = option_list))

mappable_bins <- opt$mappable_bins
sample_bin_counts <- opt$sample_bin_counts
output_dir <- opt$output_dir
rscripts_dir <- opt$rscripts_dir
chr_list <- opt$chromosomes
bin_size <-opt$bin_size
sample_name <- opt$sample_name
read_length <- opt$read_length
gamma <- opt$gamma


library(GenomicRanges, quietly=TRUE, verbose=FALSE)
library(limma, quietly=TRUE, verbose=FALSE)


setwd(output_dir)
wd <- getwd()
common_file_name <- paste(bin_size, "_", read_length, "bases_", gamma, "gamma", sep = "")

message("Reading chromosomes list file")

chrom <- read.table(chr_list, header=F)
chrom <- as.vector(chrom[[1]])
num_chr <- length(chrom)


message("Reading MappableBINS file")

mappable_bins <- read.table(mappable_bins, header=F, sep="\t", col.names=c("interval", "GC", "abs"))
gc <- strsplit(as.character(mappable_bins$interval), split = ":")
gc <- do.call("rbind", gc)
startstop <- strsplit(gc[, 2], split = "-")
startstop <- do.call("rbind", startstop)
rownames(mappable_bins) <- paste(as.character(gc[, 1]), as.character(startstop[, 2]), sep = "_")


#############################################################################################################
# run specific sample
#############################################################################################################

message("Reading Input Sample file")

sample <- read.table(sample_bin_counts, header = T, sep = "\t")
rownames(sample) <- paste(as.character(sample$chromosome), as.character(sample$end), sep = "_")
same <- intersect(rownames(sample), rownames(mappable_bins))
sc <- cbind(sample[same, ], GC=mappable_bins[same, 2], abs=mappable_bins[same, 3])
sc_gc_filtered <- sc[as.numeric(sc$GC) > 0.28, ]


message("Perform GC-correction on raw log2ratio")

a <- as.numeric(sc_gc_filtered$test) + 1
ratio <- a/median(a)
logr_prior <- log2(ratio)
gc_plot <- sc_gc_filtered$GC

## apply loessfit to logr_prior and gc_]plot with different spans and store them

message("Apply loess fit")

fitgenome1 <- loessFit(logr_prior, gc_plot, span = 1)
fitgenome05 <- loessFit(logr_prior, gc_plot, span = 0.5)
fitgenome <- loessFit(logr_prior, gc_plot)

logr <- (logr_prior - fitgenome$fitted) -
        median((logr_prior - fitgenome$fitted)[as.character(sc_gc_filtered$chromosome) != "Y" &&
                                               as.character(sc_gc_filtered$chromosome) != "X"],
               na.rm = T)
logr[is.na(logr)] <- logr_prior[is.na(logr)]


## Looking at the plot can be helpful but not necessary for now
## print("Print loess fit plot")
##
## jpeg(paste(sample_name, "-LoessFit_on_LogRprior-", common_file_name,".jpg", sep = ""),
##      pointsize = 12, width = 1600, height = 900)
## par(mfrow = c(1, 2))
## plot(gc_plot, logr_prior, pch = 19, cex = 0.1, xlab = "GC-content",
##      main = paste(sample_name, "Genome-wide GCcontent-influence", sep = "_"))
## points(gc_plot, fitgenome1$fitted, pch = 19, cex = 0.5, col = "orange")
## points(gc_plot, fitgenome05$fitted, pch = 19, cex = 0.5, col = "pink")
## points(gc_plot, fitgenome$fitted, pch = 19, cex = 0.5, col = "red")
## abline(h = 0, col = "grey")
## plot(gc_plot, logr, pch = 19, cex = 0.1, xlab = "GC-content",
##      main = paste(sample_name, "Genome-wide GC-corrected", sep = "_"))
## points(gc_plot, fitgenome1$fitted - fitgenome$fitted, pch = 19, cex = 0.5, col = "orange")
## points(gc_plot, fitgenome05$fitted - fitgenome$fitted, pch = 19, cex = 0.5, col = "pink")
## abline(h = 0, col = "grey")
## dev.off()

chr <- sc_gc_filtered$chr
start <- sc_gc_filtered$start
end <- sc_gc_filtered$end
abs <- sc_gc_filtered$abs
sc_data <- cbind(chromosome=as.character(chr), position=start, log2=logr, end=end, abs=abs)

message("Storing sc_data into file")

## silly long name (slightly changed) saved for back-reference with original code
## sc_data_filename <- paste(sample_name, "-M30hits_vs_NoREFM30hits_GCcorrected-", common_file_name, ".txt", sep = "")
sc_data_filename <- paste(sample_name, "-logr_prefastpcf_gccorrected-", common_file_name, ".txt", sep = "")
write.table(sc_data, quote = F, col.names = T, row.names = F, sep = "\t", file = sc_data_filename)

## Write logr_prior and gc_plot to a file
## (Not being saved for now)
## logr_prior <- data.frame(logr_prior)
## gc_plot <- data.frame(gc_plot)
## row_data <- cbind(chr=as.character(chr), pos=start, end=end, LogR.post=logr, LogR.prior=logr_prior, GC=gc_plot)
## write.table(row_data, quote = F, col.names = T, row.names = F, sep = "\t",
##             file = paste(sample_name, ".PrePostGCfitLogR-", common_file_name, ".txt", sep = ""))


#############################################################################################################
## LogR Segmentation
#############################################################################################################

message("LogR segmentation")

source(file.path(rscripts_dir, "fastPCF.R"))
sc_data <- read.delim(sc_data_filename)
segmentation_table <- vector("list", length(chrom))
for (chr in 1:num_chr) {

    ## skip over the Y chromosome - but not very species agnostic!
    if (chrom[chr] == "Y" || chrom[chr] == "chrY") {
        next
    }

    pos <- sc_data$position[as.character(sc_data$chromosome) == chrom[chr]]
    pos_end <- sc_data$end[as.character(sc_data$chromosome) == chrom[chr]]
    pos_abs <- sc_data$abs[as.character(sc_data$chromosome) == chrom[chr]]
    data <- sc_data$log2[as.character(sc_data$chromosome) == chrom[chr]]
    y <- data[order(pos)][is.finite(data[order(pos)])]
    pos_select <- pos[order(pos)][is.finite(data[order(pos)])]
    pos_end_select <- pos_end[order(pos_end)][is.finite(data[order(pos_end)])]
    pos_abs_select <- pos_abs[order(pos_abs)][is.finite(data[order(pos_abs)])]
    sdev = getMad(y, k = 25)
    res = selectFastPcf(y, 3, gamma * sdev, T)

    if (is.na(res)) {
        print(paste("No results for chr ", chr, " in sample ", sample_name, sep = ""))
        quit(save = "no", status = 1, runLast = FALSE)
    }

    segments = res$yhat
    segmentation_table[[chr]] <- cbind(rep(chrom[chr], length(pos_select)),
                                       pos_select, y, segments, pos_end_select, pos_abs_select)

}


message("Writing segmentation data into file")

to_write_segments <- do.call("rbind", segmentation_table)
colnames(to_write_segments) <- c("Chr", "Pos", "logR", "logRsegment", "end", "abs")
## silly long name (idem)
## thresholds <- paste("PCF_kmin3_fastPCF_vs_NoREFM30hits", sep = "")
## output_file = paste(sample_name, "-LogR_GCcorrected_M30-", thresholds, "-", common_file_name, ".txt", sep = "")
output_file = paste(sample_name, "-logr_segmentation-", common_file_name, ".txt", sep = "")
write.table(to_write_segments, quote = F, sep = "\t", col.names = T, row.names = F, file = output_file)


message("All OK")

