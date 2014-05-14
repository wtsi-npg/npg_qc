/*  File: fastqcheck.h
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

#ifndef __INC_FASTQCHECK__
#define __INC_FASTQCHECK__

#define MAX_LENGTH 10000

struct _fastqcheck {
	int nseq;
	unsigned long int total;
	unsigned long int sum[5], qsum[256];        /* 0 automatically */
	unsigned long int psum[MAX_LENGTH][5], pqsum[MAX_LENGTH][256], nlen[MAX_LENGTH];
	int lengthMax;
	int qMax;
	int status;
	char *outfilename;
	FILE *outfd;
};

struct _fastqcheck *new_fastqcheck(char *outfn);
int fqc_next_seq(struct _fastqcheck *fqc, char *id, int seqlen);
int fqc_add_seq_val(struct _fastqcheck *fqc, int call, int pos);
int fqc_add_qual_val(struct _fastqcheck *fqc, unsigned char qual, int pos);
int fqc_output(struct _fastqcheck *fqc);

#endif
