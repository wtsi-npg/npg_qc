/*  File: fastqcheck.c
 *  Author: Richard Durbin (rd@sanger.ac.uk)
 *  Copyright (C) Genome Research Limited, 2006
 *-------------------------------------------------------------------
 * Description: check and return basic stats for a fastq file
 * Exported functions:
 * HISTORY:
 * Last edited: Tue Sep 22 14:40:02 BST 2009 (jo3)
 * Created: Tue May  9 01:05:21 2006 (rd)
 *-------------------------------------------------------------------
 * Altered by James Bonfield: max length increased, limit of 50 
 * cycles removed, add global error rate for the entire cycle.
 * Altered by David K Jackson (david.jackson@sanger.ac.uk): rounding
 * of thousandths of clusters with given Q at a given cycle changed,
 * -std=c99 now required for compile.
 * Fixes from Petr Danecek (pd3@sanger.ac.uk): avoid overflow on 
 * total by changing it to an unsigned long int, plus fixes to avoid
 * gcc -Wall gripes.
 * Change requested by Richard Durbin, Petr Danecek, to space long
 * numbers rather than rely on fixed width fields.
 * sum, qsum, psum and pqsum all changed to unsigned long int to fix
 * overflow error.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "sam.h"

#include "fastqcheck.h"

#define _A 0
#define _C 1
#define _G 2
#define _T 3
#define _N 4

#ifndef __INC_FASTQCHECK__

#define MAX_LENGTH 10000

struct _fastqcheck {
	uint64_t nseq;
	uint64_t total;
	uint64_t sum[5], qsum[256];        /* 0 automatically */
	uint64_t psum[MAX_LENGTH][5], pqsum[MAX_LENGTH][256], nlen[MAX_LENGTH];
	int lengthMax;
	int qMax;
	int status;
	char *outfilename;
	FILE *outfd;
};

#endif

struct _fastqcheck *new_fastqcheck(char *outfn) {
	struct _fastqcheck *ret;

	if((ret=(struct _fastqcheck *)calloc(1, sizeof(struct _fastqcheck))) != NULL) {
		/* should probably allow stdout to be specified as "-" */
		if((ret->outfilename=strdup(outfn)) == NULL) {
			free(ret);
			return(NULL);
		}
	}

	return(ret);
}

int fqc_next_seq(struct _fastqcheck *fqc, char *id, int seqlen) {
	++fqc->nseq;
	++fqc->nlen[seqlen];
	fqc->total += seqlen;

	if(seqlen > fqc->lengthMax)  {
		fqc->lengthMax = seqlen;
		if(seqlen > MAX_LENGTH) {
			fprintf(stderr, "read %s length = %d longer than MAX_LENGTH = %d; edit and recompile with larger MAX_LENGTH\n", (id!=NULL)? id: "NULL", seqlen, MAX_LENGTH);
			exit(EXIT_FAILURE);
		}
	}

	return(0);
}

/*
fqc_add_seq_val:
call: the call is encoded A|a => 0, C|c => 1, G|g => 2, N|n => 4, T|t => 3, other char => error
qual: quality string encoded fastqval-33 (i.e., the actual Phred quality score)
id: sequence identifier
length: length of sequence
*/
int fqc_add_seq_val(struct _fastqcheck *fqc, int call, int pos) {
	++fqc->sum[call];
	++fqc->psum[pos][call];

	return(0);
}

int fqc_add_qual_val(struct _fastqcheck *fqc, unsigned char qual, int pos) {
	++fqc->qsum[qual];
	++fqc->pqsum[pos][qual];
	if(qual > fqc->qMax)
		fqc->qMax = qual;

	return(0);
}

int fqc_output(struct _fastqcheck *fqc)
{
	uint64_t total;
	uint64_t *sum, *qsum;        /* 0 automatically */
	uint64_t *nlen;
	int qMax;
	uint64_t nseq;
	int lengthMax;
	double erate;
	int i, j;

	total = fqc->total;
	sum = fqc->sum;
	qsum = fqc->qsum;
	nlen = fqc->nlen;
	qMax = fqc->qMax;
	nseq = fqc->nseq;
	lengthMax = fqc->lengthMax;

	if((fqc->outfd=fopen(fqc->outfilename, "w")) == NULL) {
		return(-1);
	}

	fprintf(fqc->outfd, "%lu sequences, %lu total length", nseq, total) ;
	if(nseq)
		fprintf (fqc->outfd, ", %.2f average, %d max", total/(float)nseq, lengthMax) ;
	fprintf(fqc->outfd, "\n") ;

	if(total) {
		fprintf(fqc->outfd, "Standard deviations at 0.25:  total %5.2f %%, per base %5.2f %%\n", 
			100*(sqrt(0.25*(double)total)/total), 100*(sqrt(0.25*(double)nseq)/nseq));
		fprintf(fqc->outfd, "            A    C    G    T    N ");
		for(i = 0 ; i <= qMax ; ++i)
			fprintf(fqc->outfd, " %3d",i);
		fprintf(fqc->outfd, " AQ\nTotal  ");
		fprintf(fqc->outfd, "  %4.1f %4.1f %4.1f %4.1f %4.1f ", 
			100*((double)sum[_A]/total), 100*((double)sum[_C]/total),
			100*((double)sum[_G]/total), 100*((double)sum[_T]/total),
			100*((double)sum[_N]/total));

		for(erate = j = 0 ; j <= qMax ; ++j) {
			fprintf(fqc->outfd, " %3ld", lrint(1000*((double)qsum[j]/total)));
			erate += pow(10, j/-10.0) * qsum[j];
		}

		fprintf(fqc->outfd, " %4.1f", -10*log(erate/total)/log(10));
		for(i = 0 ; i < lengthMax ; ++i) {
			nseq -= nlen[i];
			fprintf(fqc->outfd, "\nbase %2d", i+1);
			fprintf(fqc->outfd, "  %4.1f %4.1f %4.1f %4.1f %4.1f ",
				100*((double)fqc->psum[i][_A]/nseq), 100*((double)fqc->psum[i][_C]/nseq),
				100*((double)fqc->psum[i][_G]/nseq), 100*((double)fqc->psum[i][_T]/nseq),
				100*((double)fqc->psum[i][_N]/nseq));

			for(erate = j = 0 ; j <= qMax ; ++j) {
				fprintf(fqc->outfd, " %3d",(int)lrint(1000*((double)fqc->pqsum[i][j]/nseq)));
				erate += pow(10, j/-10.0) * fqc->pqsum[i][j];
			}
			fprintf(fqc->outfd, " %4.1f", -10*log(erate/nseq)/log(10));

		}
		fprintf(fqc->outfd, "\n");
	}

	fclose(fqc->outfd);

	return(0);
}

