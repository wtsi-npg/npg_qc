library(optparse, quietly=TRUE, verbose=FALSE)

rm(list=ls(all=TRUE))

option_list <- list(
    make_option("--logr_segmentation_file", type="character", help="sample logR segmentation data file []"),
    make_option("--output_dir", type="character", help="Directory to write results []"),
    make_option("--chromosomes", type="character", help="list of chromosomes[]"),
    make_option("--threshold", type="double", help="threshold[]"),
    make_option("--sample_name", type="character", help="sample name[]"),
    make_option("--bin_size", type="character", help="read_length[]"),
    make_option("--read_length", type="integer", help="bin size[]")
)

opt  <- parse_args(OptionParser(option_list = option_list))

sample_logr_file <- opt$logr_segmentation_file
output_dir <- opt$output_dir
chr_list <- opt$chromosomes
threshold <- opt$threshold
sample_name <- opt$sample_name
bin_size <-opt$bin_size
read_length <- opt$read_length

setwd(output_dir)
wd <- getwd()
common_file_name <- paste(bin_size, "_", read_length, "bases_", threshold, "threshold", sep = "")


message("Reading chromosomes list file")

chrom <- read.table(chr_list, header = F)
chrom <- as.vector(chrom[[1]])
num_chr <- length(chrom)


message("Reading sample logR segmentation file")

data <- read.table(sample_logr_file, header = T, sep = "\t", quote = "", comment.char = "", check.names = FALSE)


# MAPD calculation
message("Calculating MAPD")

logR <- vector("list", num_chr)
logR1 <- vector("list", num_chr)
logR2 <- vector("list", num_chr)
mapd <- vector("list", num_chr)
mapd_calc_table <- vector("list", num_chr)

for (chr in seq(1, num_chr)) {
    logR[[chr]] <- data$logR[as.character(data$Chr) == chrom[chr]]
    logR1[[chr]] <- logR[[chr]][1:(length(logR[[chr]]) - 1)]
    logR2[[chr]] <- logR[[chr]][2:length(logR[[chr]])]
    mapd[[chr]] <- abs(logR1[[chr]] - logR2[[chr]])
    mapd_calc_table[[chr]] <- cbind(rep(chrom[chr], length(logR[[chr]])-1), logR[[chr]], logR1[[chr]], logR2[[chr]], mapd[[chr]])
}

mapd_sample <- median(unlist(mapd))


message("Writing MAPD data into files")

mapd_calc_data <- do.call("rbind", mapd_calc_table)
colnames(mapd_calc_data) <- c("Chr", "LogR", "LogR1", "LogR2", "MAPD")
mapd_data_filename <- paste(sample_name, "-mapd_precalc_logr_data-", common_file_name, ".txt", sep = "")
write.table(mapd_calc_data, quote = F, col.names = T, row.names = F, sep = "\t", file = mapd_data_filename)

mapd_res_data  <- cbind(Sample = sample_name, MAPD = mapd_sample, Threshold = threshold)
mapd_res_filename  <- paste(sample_name, "-mapd_results-", common_file_name, ".txt", sep = "")
write.table(mapd_res_data, quote = F, col.names = T, row.names = F, sep = "\t", file = mapd_res_filename)


message("All OK")

