#########
# Author:        Aylwyn Scally
# Maintainer:    $Author: mg8 $
# Created:       2008-11-26
# Last Modified: $Date: 2010-04-29 16:52:26 +0100 (Thu, 29 Apr 2010) $
# Id:            $Id: gc_bias_data.R 9175 2010-04-29 15:52:26Z mg8 $
# $HeadURL: svn+ssh://intcvs1.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/trunk/lib/R/gc_bias_data.R $
# Original code by: Aylwyn Scally 2008

library(Biostrings)

read.depth = function(datafile) { 

    # alt_factor is the sum of alternative matches for all reads mapping to
    # the window divided by the number of mapping reads. It is used to
    # determine the uniqueness of the window sequence.
    cnames   = c('seq_name', 'pos',     'depth',   'alt_factor',     
                 'gc_count', 'n_count', 'window_size')

    cclasses = c('factor',   'integer', 'integer', 'numeric',
                 'numeric',  'numeric', 'integer')

	gc_data = read.table(datafile, col.names = cnames, colClasses = cclasses)

    # Convert GC and N counts to proportions.
    gc_data$gc_count = gc_data$gc_count / gc_data$window_size
    gc_data$n_count  = gc_data$n_count  / gc_data$window_size


	return(list(data = gc_data, gc_max = 1.0))
}

gcdepth = function(gc_depth_data, path = '', plot_name = '', depmax = NULL,
                   plotdev = png, nbins = 30, quant = 0.1, qtrim = 0.01, 
                   binned = FALSE, make_plot = FALSE) {

    # Shorthand.
    GCDepth = gc_depth_data$data
    gc_max  = gc_depth_data$gc_max

    # Some windows (end of chromosomes/sequences) will be smaller than
    # expected.
    window_size = max(GCDepth$window_size)

    # Save the parameters, graph data and statistical summary to a file.
    sink(paste(path, plot_name, '-gcdepth.txt', sep = ''))

    # Get rid of rows with NAs. Then count what's left.
	GCDepth = na.omit(GCDepth)

	Nall        = nrow(GCDepth)                          # Total count.
	meantot.all = mean(GCDepth$depth)                    # Total mean depth.
	sstot.all   = sum((GCDepth$depth - meantot.all) ^ 2) # Total sum of sq.
	msstot.all  = Nall * meantot.all

    # Get unique sequences - windows where all mapped reads map there only.
    udata = GCDepth[GCDepth$alt_factor == 1,]
#udata = GCDepth

    # Remove bins with many N's, count the remaining rows.
	udata    = udata[udata$n_count <= 0.1,]
	N_unique = nrow(udata)

	meantot = mean(udata$depth)                # Mean depth for unique seqs
	sstot   = sum((udata$depth - meantot) ^ 2) # Sum of sq. for unique seqs
	msstot  = N_unique * meantot               # Total depth for unique seqs

    # Store various statistics for each bin.
	gfrac  = rep(0, nbins)  # Cumulative percentage of data-points (x-axis).
	avg_gc = rep(0, nbins)  # Mean GC relative to gc_max (for %GC scale)
	lquant = rep(0, nbins)  # Trim below this value
	uquant = rep(0, nbins)  # Trim above this value
	mu     = rep(0, nbins)  # Trimmed mean depth - (y-axis).
	var    = rep(0, nbins)  # Trimmed depth variance - not used in plot.
	ssres  = 0              # Residual sum of squares - summary statistics.
	mssres = 0              # 

    # Divide the GC range into bins. Calculate and print raw values for each.
	for (ib in 1:nbins){
		binlow  = gc_max * (ib - 1) / nbins
		binhigh = gc_max *  ib      / nbins

        # Get the data rows that fall into this bin.
		if (ib == 1){
			depths = udata$depth[udata$gc >= 0     & udata$gc <= binhigh]
		}else{
			depths = udata$depth[udata$gc > binlow & udata$gc <= binhigh]
		}

        # Calculate the cumulative fraction of GC values at this bin.
		N = length(depths)
		if (ib == 1)
			gfrac[ib] = 0.5           * 100 * N / N_unique    # ** Why 0.5? **
		if (ib > 1)
			gfrac[ib] = gfrac[ib - 1] + 100 * N / N_unique

        # Call the depth.nbfit function to calculate mean and variance from 
        # trimmed depth values. 
		fit = depth.nbfit(depths, qtrim = qtrim)

		mu[ib]  = fit$mu   # The mean of the trimmed depths.
		var[ib] = fit$var  # The variance of the trimmed depths.

		avg_gc[ib] = mean(c(binlow, binhigh)) / gc_max
		ssres      = ssres + sum((depths - mean(depths)) ^ 2)

		if (N > 0)
			mssres = mssres + N * mean(depths)

        # Trim away the smallest and biggest datapoints - why no exception
        # here for N < 4?
		lim    = round(quantile(depths, c(qtrim, 1 - qtrim)))
		depths = depths[depths >= lim[1] & depths <= lim[2]]

        # Calculate the upper and lower quantile of what remains.
		lquant[ib] = quantile(depths, quant)
		uquant[ib] = quantile(depths, 1 - quant)

	}

	pd = data.frame(gfrac, avg_gc, mu, var, lquant, uquant)
	pd = na.omit(pd)
	nb = nrow(pd)

    # Some more stats - temp added by me
#    cat( 'Variance: ',var(pd$mu),'\n')
#    cat( 'Mean: ',mean(pd$mu),'\n')

	if (is.null(depmax))
		depmax = 1.3 * max(pd$uquant)

    cat( 'DEPMAX: ', depmax, '\n' )

    cat( 'WINDOW_COUNT: ', N_unique, '\n' )

    cat( 'BIN_COUNT: ', length(pd$gfrac), '\n' )

    cat('POLYGON_X: ')
    cat( pd$gfrac, rev(pd$gfrac), sep=',' )

    cat('\nPOLYGON_Y: ')
    cat( pd$uquant, rev(pd$lquant), sep=',' )

	gclocs = approx(pd$avg_gc, pd$gfrac, seq(0, 1.0, 0.1))$y

    cat('\nGC_TICKMARK: ')
    cat( gclocs, sep=',' )

    cat('\nMAIN_PLOT_X: ')
    cat( pd$gfrac, sep=',' )

    cat('\nMAIN_PLOT_Y: ')
    cat( pd$mu, sep=',' )


    cat('\nLOWER_POISS: ')
    cat( qpois(quant, pd$mu), sep=',' )

    cat('\nUPPER_POISS: ')
    cat( qpois(1 - quant, pd$mu), sep=',' )
    cat('\n')

	sink()  

    if (make_plot) {
        plot.biasdata( plot_name,
                       paste(path, plot_name, '-gc_bias.png', sep=''),
                       depmax, N_unique, length(pd$gfrac), window_size,
                       gclocs, c(pd$gfrac, rev(pd$gfrac)),
                       c(pd$uquant, rev(pd$lquant)), pd$gfrac, pd$mu, 
                       qpois(quant, pd$mu), qpois(1 - quant, pd$mu) )
    }
}


depth.nbfit = function(depth.seq, qtrim = 0, ...) {

    # Check for empty bins.
	if (length(depth.seq) == 0){
	    fit = list(mu = NA, size = NA, var = NA)
		return(fit)
	}

    # Is this redundant?
	depth.seq = na.omit(depth.seq)

	N = length(depth.seq)

	if (N < 4) # Don't trim quantiles
		qtrim = 0

    # Trim smallest and biggest values from the data.
	lim       = round(quantile(depth.seq, c(qtrim, 1 - qtrim)))
	depth.seq = depth.seq[depth.seq >= lim[1] & depth.seq <= lim[2]]

	mu   = mean(depth.seq)
	dvar = var(depth.seq)

	fit = list(mu = mu, var = dvar)

	return(fit)
}


plot.biasdata = function( plot_name, png_name, depmax, N_unique, bin_count,
                          window_size, gc_lines, 
                          polygon_x, polygon_y,
                          main_x, main_y,
                          lower_poiss, upper_poiss ) {

    xlabel = 'Percentile of Unique Sequence Ordered by GC Content'

    png(file = png_name, width = 600, height = 600)
	par(mfrow = c(1, 1), xpd = FALSE, mar = c(4, 4, 4, 3) + 0.5, mex = 0.7, 
        font.main = 1)

    plot(c(0, 100), c(0, depmax), type = 'n', lty = 2, xlab = xlabel, 
         ylab = paste('Mapped Depth (window size', window_size, 'bp)'),
         main = '' )

    datapoints = paste('Windows: ', N_unique, ' Bins: ', bin_count)
    mtext(datapoints, side = 3, line = 3, adj = 1)

	polygon(polygon_x, polygon_y, col = 'grey', border = NA) 

	abline(v = gc_lines, col = 'black', lty = 3)

    axis(3, at = gc_lines, labels = 100 * seq(0, 1.0, 0.1))
    mtext('GC content (%)', side = 3, line = 3)

	mtext(plot_name, side = 3, line = 3, adj = 0)

	lines(main_x, lower_poiss, lty = 2)
	lines(main_x, upper_poiss, lty = 2)

    dev.off()
}

