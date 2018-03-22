/*  File: fastqcheck.c
 *  Author: Richard Durbin (rd@sanger.ac.uk)
 *  Copyright (C) Genome Research Limited, 2006
 *-------------------------------------------------------------------
 * Description: check and return basic stats for a fastq file
 * Exported functions:
 * HISTORY:
 * Last edited: Mon Jul 27 17:54:52 BST 2009 (dj3)
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
 *
 * Get the latest version from
 *      http://svn.internal.sanger.ac.uk/cgi-bin/viewvc.cgi/tools/trunk/fastqtools/fastqcheck.c?root=new-pipeline-dev&view=log
 *
 * Dependencies:
 *      readseq.c readseq.h fastqcheck.c
 *
 * Compile by running:
 *      gcc -std=c99 readseq.c fastqcheck.c -o fastqcheck -lm
 */

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include "readseq.h"
#define _A 0
#define _C 1
#define _G 2
#define _T 3
#define _N 4

#define MAX_LENGTH 1000000

int main (int argc, char **argv)
{
  int i, j, length, lengthMax = 0, qMax = 0, status ;
  unsigned long int nseq = 0;
  unsigned long int total = 0 ;
  char *seq, *id ;
  unsigned char *qval ;
  FILE *fil ;
  static unsigned long int sum[5], qsum[256] ;		/* 0 automatically */
  static unsigned long int psum[MAX_LENGTH][5], pqsum[MAX_LENGTH][256], nlen[MAX_LENGTH] ;
  double erate;

  if (argc == 1)
    fil = stdin ;
  else if (!(fil = fopen (argv[1], "r")))
    { fprintf (stderr, "Failed to open fastq file %s\n", argv[1]) ;
      exit (EXIT_FAILURE) ;
    }

  while ( (status=readFastq (fil, dna2indexConv, &seq, &qval, &id, &length))>0 )
    { ++nseq ; ++nlen[length] ;
      total += length ;
      if (length > lengthMax) 
	{ lengthMax = length ;
	  if (length > MAX_LENGTH)
	    { fprintf (stderr, "read %s length = %d longer than MAX_LENGTH = %d; edit and recompile with larger MAX_LENGTH\n", id, length, MAX_LENGTH) ;
	      exit (EXIT_FAILURE) ;
	    }
	}
      for (i = 0 ; i < length ; ++i)
	{ ++sum[(int)seq[i]] ; ++psum[i][(int)seq[i]] ;
	  ++qsum[qval[i]] ; ++pqsum[i][qval[i]] ;
	  if (qval[i] > qMax) qMax = qval[i] ;
	}
      free (seq) ; free (qval) ; free (id) ;
    }

    if ( status<0 )
    {
        exit (EXIT_FAILURE);
    }

  printf ("%lu sequences, %lu total length", nseq, total) ;
  if (nseq)
    printf (", %.2f average, %d max", total/(float)nseq, lengthMax) ;
  printf ("\n") ;

  if (total)
    { printf ("Standard deviations at 0.25:  total %5.2f %%, per base %5.2f %%\n", 
	      100*(sqrt(0.25*(double)total)/total), 100*(sqrt(0.25*(double)nseq)/nseq)) ;
      printf ("            A    C    G    T    N ") ;
      for (i = 0 ; i <= qMax ; ++i) printf (" %3d",i) ;
      printf (" AQ\nTotal  ") ;
      printf ("  %4.1f %4.1f %4.1f %4.1f %4.1f ", 
	      100*((double)sum[_A]/total), 100*((double)sum[_C]/total),
	      100*((double)sum[_G]/total), 100*((double)sum[_T]/total),
	      100*((double)sum[_N]/total)) ;
      for (erate = j = 0 ; j <= qMax ; ++j) {
	printf (" %3d",(int)lrint(1000*((double)qsum[j]/total))) ;
	erate += pow(10, j/-10.0) * qsum[j];
      }
      printf(" %4.1f", -10*log(erate/total)/log(10));
      for (i = 0 ; i < lengthMax ; ++i)
	{ nseq -= nlen[i] ;
	  printf ("\nbase %2d", i+1) ;
	  printf ("  %4.1f %4.1f %4.1f %4.1f %4.1f ",
		  100*((double)psum[i][_A]/nseq), 100*((double)psum[i][_C]/nseq),
		  100*((double)psum[i][_G]/nseq), 100*((double)psum[i][_T]/nseq),
		  100*((double)psum[i][_N]/nseq)) ;
	  for (erate = j = 0 ; j <= qMax ; ++j) {
	      printf (" %3d",(int)lrint(1000*((double)pqsum[i][j]/nseq))) ;
	      erate += pow(10, j/-10.0) * pqsum[i][j];
	  }
	  printf(" %4.1f", -10*log(erate/nseq)/log(10));
	}
      printf ("\n") ;
    }
  exit(EXIT_SUCCESS);

}
