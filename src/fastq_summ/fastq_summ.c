/*******************************************************************************************************************************************
********************************************************************************************************************************************
fastq_summ:
A utility which, given a bam file, creates fastqcheck files and fastq files from sets of reads in a bam file. The fastqcheck files are
generated from all reads in a set; the fastq files contain a specified number of reads evenly spaced through the set.

Input: bam file with RG (read groups) values assigned. Tag indexes (if present) appear in the bam file as values for the RT or BC tags;
tag read qualities appear as values for the QT tag. In these bam files, plexed samples have been identified but not yet partitioned into
separate bam files. So the bam files to be processed can be partitioned into four classes, depending on whether the reads are single or
paired-end and whether they have index tags:

                         Unindexed          Indexed
 Single end               Case 1            Case 2
 Paired end               Case 3            Case 4

Only in cases 2 and 4 (indexed reads) are plex-level files generated, since these are the only cases where multiple samples may be
multiplexed in one lane. The reads for separate samples are distinguished by the value of the RG (read group) tag, although (since
the reads are tagged) they could also be separated by the the tag reads. The tag read for a sequence read is specified using the BC
tag by default (though an alternate tag can be specified using the -r flag).  Where these tag indexes are present, separate fastq and
fastqcheck files may be created at (de)plex(ed) level. The entries in the fastq selection files for the tag reads correspond to the
entries in the fastq selection files for the sequence reads.

Unless per-tag counts are specified using the -t flag, an initial pass thorough the input data is done to determine the number of reads
in each potential output stream. These counts, together with the requested number of selections, determine the intervals between reads in
the input stream where selected output will be done. Output queues are initially created for all potential output streams. In cases
1 and 3, no read group output queues are created in the counting pass. In cases 2 and 4, where only one read group is found, the single
read group output queue will be disregarded and there will be no plex-level output. If lane-level mode is specified (via the -l flag),
plex-level output will not be generated regardless of the number of read groups found.

Where the bam file contains paired-end reads, the output streams are split in two: one for first read, the other for the second read.

All output is written to an output directory which can be specified using the -d flag.

Output file names are based on 1) the base name of the input file, 2) the number of reads selected for the fastq output (where
appropriate) and 3) the number of the read in a pair. If the base name is not specified using the -o flag, a base name is generated.
In single-end read cases, only read number 1 files are created. The number of reads requested is specified with the -s flag (default 10000),
though <num_selects> equals the actual number of reads selected where not enough reads were available in the input to satisfy
the request.

Two sets of files can be produced: lane level (always produced) and plex level (optional). Note that tag read output is not produced
at plex level, since all tag reads for a deplexed set of reads should be the same.

Lane level files:
  <base_name>_1.fastq.<num_selects> : fastq selection for first reads Example: 6551_1_1.fastq.10000)
  <base_name>_1.fastqcheck : the fastqcheck report for all first reads
  <base_name>_2.fastq.<num_selects> : fastq selection for second reads (where present). Example: 6551_1_2.fastq.10000)
  <base_name>_2.fastqcheck : the fastqcheck report for all second reads
  <base_name>_t.fastq.<num_selects> : fastq selection for index tags (where present)
  <base_name>_t.fastqcheck : the fastqcheck report for all tag reads

Plex level files, one set for each tag number:
  <base_name>_1#<tag_no>.fastq.<num_selects> : fastq selection for first reads indexed with tag <tag_no>. Example: 6551_1_1#1.fastq.10000
  <base_name>_1#<tag_no>.fastqcheck : the fastqcheck report for all first reads indexed with tag <tag_no>. Example: 6551_1_1#1.fastqcheck
  <base_name>_2#<tag_no>.fastq.<num_selects> : fastq selection for second reads (where present) indexed with tag <tag_no>. Example: 6551_1_2#1.fastq.10000
  <base_name>_2#<tag_no>.fastqcheck : the fastqcheck report for all second reads indexed with tag <tag_no>. Example: 6551_1_2#1.fastqcheck
********************************************************************************************************************************************
*******************************************************************************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <search.h>
#include <ctype.h>
#include <time.h>


#include "sam.h"

#include "fastqcheck.h"

#define CMDSIZ 1024
#define BDSIZ 4096
#define FBSIZ 1024
#define RGNMMAXLEN 128
#define pretty_bool(v) (v? "YES": "NO")
#define FRAG_QUEUE_ENTRIES 10000

int global_open_file_count = 0;

struct _output_spec {
	char base_dir[BDSIZ];
	char lane_dir[FBSIZ];
	char outbase[FBSIZ];
	int do_fastqcheck;
};

/*
A _read_output_queue stores the total number of reads and keeps track of the numbers
for the output pass. A read pair is output for each 'select_interval'th pair up to
a maximum of 'num_selects' pairs.
There is one of these structs for each lane or read group to be output - if there
isn't one, data for that lane/read group will not be output.
*/
struct _read_output_queue {
	char *read_group;	/* NULL for lane level */
	uint64_t total_reads;
	uint64_t *num_selects;
	int select_interval;
	uint64_t reads_seen;
	int num_output;
	FILE *outs1fd;		/* selected single-end or read 1 of pair */
	FILE *outs2fd;		/* selected read 2 of pair */
	FILE *out_tag_fd;	/* tag corresponding to read(s) output via outs1fd (and  via outs2fd) */
	struct _fastqcheck *fqc1;	/* fastqcheck file for all single-end or read 1 of pair */
	struct _fastqcheck *fqc2;	/* fastqcheck file for all read 2 of pair */
	struct _fastqcheck *fqct;	/* fastqcheck file for all tag reads */
	struct _output_spec *output_spec;
	int is_paired;
};

struct _output_queues {
	struct _read_output_queue *lane_nonpairs_queue;	/* all non-paired reads pass through here */
	struct _read_output_queue *lane_pairs_queue;	/* all paired reads pass through here */
	void *read_group_queues;	/* root of a binary tree storing output queues for read groups */
};

struct _params {
	struct _output_spec output_spec;	/* specifies output location */
	char *rt_tag;
	char *qt_tag;
	uint64_t num_selects; /* number of sample reads (default: 10,000) */
	int num_reads;	/* used to determine interval for selection of num_select reads */
	int select_interval;
	int tags_seen;
	unsigned required_flag;		/* these bits in the FLAG value must be set */
	unsigned filtering_flag;	/* these bits in the FLAG value must not be set */
	int count_only;
	int lane_mode;
	int verbosity;
	struct _output_queues *output_queues;	/* if specified using -t flags, counting pass is not needed */
} params;

int stragglers = 0;	/* used to count unmatched members of read pairs */

/*
struct _frag_out contains the data selected from a read to be output to fastq
*/
struct _frag_out {
        int cached;
        char *frag_name;                /* fragment name (without appended frag no) */
        int frag_name_len;
        char frag_no;
        int l_qseq;                     /* length of sequence fragment */
        char *seq;                      /* sequence fragment data (compressed) */
        char *qual;                     /* sequence fragment qualities (add 33 for phred-encoded score) */
        int is_revcomp;                 /* reverse complement sequence fragment? */
        char *tag_seq;         /* tag sequence (got from bam_aux_get(b, "RT");) */
        char *tag_qual;        /* tag sequence qualities (got from bam_aux_get(b, "QT");) */
        char *rg;			/* read group */
};

struct _frag_store {
	void *store;
	int (*compare_func)(const void *, const void *);
};

/*
Static function prototypes
*/
static int usage(int full);

static int fetch_params(int ac, char **av, struct _params *params);
static int convert_numarg(char flag, char *val);
static int validate_params(struct _params *params);
static struct _output_queues *add_tag_count(struct _output_queues *q, char *tc, struct _output_spec *output_spec, uint64_t *num_selects);

static struct _output_queues *init_output_queues(char *fn, struct _params *params);
static int initialise_lane_output_queues(struct _output_queues *output_queues, struct _params *params);

static int output_single_end_read(struct _frag_out *fo, struct _output_queues *output_queues);
static int output_read_pair_member(struct _frag_out *fo, struct _output_queues *output_queues, struct _frag_store *frag_store);

static struct _read_output_queue *new_roq(char *rg, uint64_t total_reads, uint64_t *num_selects, struct _output_spec *output_spec, int pair);
static struct _frag_out *make_cached_frag_out(struct _frag_out *fo);
static struct _frag_out *load_uncached_frag_out(bam1_t *b);
static struct _frag_out *_load_frag_out(bam1_t *b, struct _frag_out *ret);
static int output_frag(struct _frag_out *fo, FILE *seq_fd, struct _fastqcheck *fqc);
static int output_tag_read(struct _frag_out *fo, FILE *outfd, struct _fastqcheck *fqc);
static int compare_frags(const void *item1, const void *item2);
static int compare_oq(const void *item1, const void *item2);
static int free_frag_out(struct _frag_out *fo);
static int fwd_nle(int idx, int end);
static int rev_nle(int idx, int end);
static struct _read_output_queue *get_rg_params(void *rg_queues, char *rg);
static void activate_rgq_nodes(const void *nodep, const VISIT which, const int depth);
static void close_rgq_nodes(const void *nodep, const VISIT which, const int depth);
static void close_oq(struct _read_output_queue *queue);
static void visit_frag_nodes(const void *nodep, const VISIT which, const int depth);
static void report_rgq_nodes(const void *nodep, const VISIT which, const int depth);
static char *generate_out_file_name(void);

int main(int ac, char **av)
{
	char *bamfile_name = NULL;
	samfile_t *fp = NULL;
	bam1_t *b = NULL;
	int lc, rc, se, filtered, orphans;	/* line count, (unfiltered) read count, filtered count */
	int i;
	unsigned int is_multifrag, is_revcomp, nextfrag_revcomp, is_firstfrag, is_lastfrag;	/* bools */
	struct _frag_out *fo;
	struct _frag_store frag_store = { NULL, compare_frags };	/* cache used for matching read pairs for simultaneous output */
	struct _frag_store orphan_store = { NULL, compare_frags };	/* cache used for matching read pairs for simultaneous output */
	void *pp;
	struct _output_queues *output_queues = NULL;

	i=fetch_params(ac, av, &params);

	if(ac-i < 1) {
		fprintf(stderr, "Fatal error: No BAM file specified\n");
		usage(0);
		exit(0);
	}

	bamfile_name = av[i];

	if(params.output_queues == NULL) {	/* read counts not specified on command-line */
		if((output_queues = init_output_queues(bamfile_name, &params)) == NULL) {
			fprintf(stderr, "Failed to initialise output queues\n");
			exit(-99);
		}
		if(params.tags_seen < 2) {
			fprintf(stderr, "Only one tag seen, disregarding tag level\n");
			output_queues->read_group_queues = NULL;
		}

	}
	else {
		output_queues = params.output_queues;	/* params.output_queues is created by fetch_params when -t flags are used */
		if((params.lane_mode && output_queues->read_group_queues == NULL)) {
			fprintf(stderr, "Tag counts specified in lane_mode, disregarding\n");
			output_queues->read_group_queues = NULL;
		}
	}

	/* open lane level outputs as required */
	initialise_lane_output_queues(output_queues, &params);

	if(params.verbosity > 0) {
		printf("Output queues initialised\n");
		printf("Lane level total reads (paired): %lu\n", output_queues->lane_pairs_queue->total_reads);
		printf("Lane level total reads (unpaired): %lu\n", output_queues->lane_nonpairs_queue->total_reads);
	}

	/* now that we have read counts, walk the tree and calculate select_interval */
	twalk(output_queues->read_group_queues, activate_rgq_nodes);	/* finalises numbers used for output selection */

	if(params.count_only)
		exit(0);

/*
We now know the counts and select intervals for the various types of read (single-end, paired read, paired-read orphan (missing mate)),
either from command-line specification or the results of an initial counting pass through the alignment data. Now read through all the
alignments, disregarding any excluded by the required (-f) or filtering (-F) flags, and output to the appropriate streams when the
select interval occurs (and for paired reads, when the second read of the pair is seen).
*/
	if((fp = samopen(bamfile_name, "rb", 0)) == NULL) {
		fprintf(stderr, "Failed to open BAM file %s\n", bamfile_name);
		usage(0);
		exit(-1);
	}

	b = bam_init1();

	for(lc=filtered=rc=se=0; samread(fp, b) >= 0; lc++) {
		if(((b->core.flag & params.required_flag) != params.required_flag) || (b->core.flag & params.filtering_flag)) {
			filtered++;
			continue;
		}
		else {
			rc++;
		}

		if(params.verbosity > 2) {
			unsigned mapq = b->core.qual;

			printf("Chrom/pos/mapq: %s (%d)/%d/%d\n", fp->header->target_name[b->core.tid], b->core.tid, b->core.pos+1, mapq);
		}

		is_multifrag = b->core.flag & 0x1;
		is_revcomp = b->core.flag & 0x10;
		nextfrag_revcomp = b->core.flag & 0x20;
		is_firstfrag = b->core.flag & 0x40;
		is_lastfrag = b->core.flag & 0x80;

		if(params.verbosity > 2) {	/* output for each read should only be used at high verbose levels */
			printf("flags stuff: %d / %#0X , %d / %#0X\n", b->core.flag, b->core.flag, b->core.flag & 0x404, b->core.flag & 0x404);
			printf("multifrag: %s, is_revcomp: %s, nextfrag_revcomp: %s, is_firstfrag: %s, is_lastfrag: %s\n",
				pretty_bool(is_multifrag),
				pretty_bool(is_revcomp),
				pretty_bool(nextfrag_revcomp),
				pretty_bool(is_firstfrag),
				pretty_bool(is_lastfrag));
				printf("data: %.*s, seq len: %d, flag: %d / %#0X\n", b->data_len, b->data, b->core.l_qseq, b->core.flag, b->core.flag);
		}

		/* Load up the output data. If we have data for both reads in the pair, output data appropriately; otherwise store data for this read */
		fo=load_uncached_frag_out(b);

		if(!is_multifrag) {	/* not paired end */
			se++;
			output_single_end_read(fo, output_queues);
		}
		else if((pp=tfind(fo, &(orphan_store.store), orphan_store.compare_func)) != NULL) {	/* orphaned member of read pair */
			orphans++;
		}
		else {		/* should be a member of a read pair */
			output_read_pair_member(fo, output_queues, &frag_store);
		}
	}

	/* close output streams (files and pipes) */
	close_oq(output_queues->lane_nonpairs_queue);
	close_oq(output_queues->lane_pairs_queue);
	twalk(output_queues->read_group_queues, close_rgq_nodes);

	stragglers = 0;
	twalk(frag_store.store, visit_frag_nodes);	/* count orphaned frags */

	if(params.verbosity > 0) {
		printf("Unfiltered reads: %d\n", rc);
		printf("Filtered reads: %d\n", filtered);
		printf("Unfiltered single-end reads: %d\n", se);
		printf("Total reads: %d\n", lc);
		printf("Orphaned reads: %d\n", stragglers);
	}

	bam_destroy1(b);

	samclose(fp);

	return 0;
}

/*
initialise_lane_output_queues:
Opens the output files for the lane level output
*/
static int initialise_lane_output_queues(struct _output_queues *output_queues, struct _params *params)
{
	char oq_fn[FBSIZ];	/* output filename buffer */
	struct _read_output_queue *lane_pairs_queue = output_queues->lane_pairs_queue;
	struct _read_output_queue *lane_nonpairs_queue = output_queues->lane_nonpairs_queue;
	int lp_fn_suffix = (*lane_pairs_queue->num_selects < lane_pairs_queue->total_reads)? *lane_pairs_queue->num_selects: lane_pairs_queue->total_reads;
	int se_fn_suffix = (*lane_nonpairs_queue->num_selects < lane_nonpairs_queue->total_reads)? *lane_nonpairs_queue->num_selects: lane_nonpairs_queue->total_reads;

	if(params->output_spec.outbase[0] == '\0' || params->output_spec.outbase[0] == '-')
		return(-1);

	/* open output files */
	lane_pairs_queue->fqc1 = lane_pairs_queue->fqc2 = lane_pairs_queue->fqct = NULL;
	lane_nonpairs_queue->fqc1 = lane_nonpairs_queue->fqc2 =  lane_nonpairs_queue->fqct = NULL;
	if(lane_pairs_queue && lane_pairs_queue->total_reads > 0) {
		snprintf(oq_fn, FBSIZ, "%s/%s_1.fastq.%d", params->output_spec.lane_dir, params->output_spec.outbase, lp_fn_suffix);
		if((lane_pairs_queue->outs1fd=fopen(oq_fn, "w")) == NULL) {
			fprintf(stderr, "Failed to open %s for output s1 in initialise_lane_output_queues\n", oq_fn);
			usage(0);
			exit(-99);
		}
		else {
			global_open_file_count++;
		}
		snprintf(oq_fn, FBSIZ, "%s/%s_2.fastq.%d", params->output_spec.lane_dir, params->output_spec.outbase, lp_fn_suffix);
		if((lane_pairs_queue->outs2fd=fopen(oq_fn, "w")) == NULL) {
			fprintf(stderr, "Failed to open %s for output s2 in initialise_lane_output_queues\n", oq_fn);
			usage(0);
			exit(-99);
		}
		else {
			global_open_file_count++;
		}

		snprintf(oq_fn, FBSIZ, "%s/%s_t.fastq.%d", params->output_spec.lane_dir, params->output_spec.outbase, lp_fn_suffix);
		if(params->tags_seen > 1) {
			if((lane_pairs_queue->out_tag_fd=fopen(oq_fn, "w")) == NULL) {
				fprintf(stderr, "Failed to open %s for output t in initialise_lane_output_queues (pair)\n", oq_fn);
				usage(0);
				exit(-99);
			}
		}
		else {
			lane_pairs_queue->out_tag_fd = NULL;
		}

		if(params->output_spec.do_fastqcheck) {
			snprintf(oq_fn, FBSIZ, "%s/%s_1.fastqcheck", params->output_spec.lane_dir, params->output_spec.outbase);
			if((lane_pairs_queue->fqc1=new_fastqcheck(oq_fn)) == NULL) {
				fprintf(stderr, "Failed to open create output for fastqcheck 1: %s\n", oq_fn);
				usage(0);
				exit(-99);
			}
			snprintf(oq_fn, FBSIZ, "%s/%s_2.fastqcheck", params->output_spec.lane_dir, params->output_spec.outbase);
			if((lane_pairs_queue->fqc2=new_fastqcheck(oq_fn)) == NULL) {
				fprintf(stderr, "Failed to open create output for fastqcheck 2: %s\n", oq_fn);
				usage(0);
				exit(-99);
			}
			if(params->tags_seen > 1) {
				snprintf(oq_fn, FBSIZ, "%s/%s_t.fastqcheck", params->output_spec.lane_dir, params->output_spec.outbase);
				if((lane_pairs_queue->fqct=new_fastqcheck(oq_fn)) == NULL) {
					fprintf(stderr, "Failed to open create output for fastqcheck t: %s\n", oq_fn);
					usage(0);
					exit(-99);
				}
			}
		}

	}

	if(lane_nonpairs_queue && lane_nonpairs_queue->total_reads > 0) {
		snprintf(oq_fn, FBSIZ, "%s/%s_1.fastq.%d", params->output_spec.lane_dir, params->output_spec.outbase, se_fn_suffix);
		if((lane_nonpairs_queue->outs1fd=fopen(oq_fn, "w")) == NULL) {
			fprintf(stderr, "Failed to open %s for output se in initialise_lane_output_queues\n", oq_fn);
			usage(0);
			exit(-99);
		}
		else {
			global_open_file_count++;
		}

		snprintf(oq_fn, FBSIZ, "%s/%s_t.fastq.%d", params->output_spec.lane_dir, params->output_spec.outbase, se_fn_suffix);
		if(params->tags_seen > 1) {
			if((lane_nonpairs_queue->out_tag_fd=fopen(oq_fn, "w")) == NULL) {
				fprintf(stderr, "Failed to open %s for output t in initialise_lane_output_queues (nonpair)\n", oq_fn);
				usage(0);
				exit(-99);
			}
			else {
				global_open_file_count++;
			}
		}
		else {
			lane_nonpairs_queue->out_tag_fd = NULL;
		}

		if(params->output_spec.do_fastqcheck) {
			snprintf(oq_fn, FBSIZ, "%s/%s_1.fastqcheck", params->output_spec.lane_dir, params->output_spec.outbase);
			if((lane_nonpairs_queue->fqc1=new_fastqcheck(oq_fn)) == NULL) {
				fprintf(stderr, "Failed to open create output for fastqcheck 1: %s\n", oq_fn);
				usage(0);
				exit(-99);
			}
			if(params->tags_seen > 1) {
				snprintf(oq_fn, FBSIZ, "%s/%s_t.fastqcheck", params->output_spec.lane_dir, params->output_spec.outbase);
				if((lane_nonpairs_queue->fqct=new_fastqcheck(oq_fn)) == NULL) {
					fprintf(stderr, "Failed to open create output for fastqcheck t: %s\n", oq_fn);
					usage(0);
					exit(-99);
				}
			}
		}
		else {
			lane_nonpairs_queue->fqc1 = lane_nonpairs_queue->fqc2 = lane_nonpairs_queue->fqct = NULL;
		}
	}

	return(0);
}

static int output_single_end_read(struct _frag_out *fo, struct _output_queues *output_queues)
{
	struct _read_output_queue *lane_nonpairs_queue = output_queues->lane_nonpairs_queue;
	void *read_group_queues = output_queues->read_group_queues;
	struct _read_output_queue *rg_queue = NULL;
	FILE *sel_fd = NULL;
	FILE *sel_tfd = NULL;

	if(lane_nonpairs_queue != NULL) {
		if((lane_nonpairs_queue->reads_seen % lane_nonpairs_queue->select_interval == 0) 
				&& (lane_nonpairs_queue->num_output < *(lane_nonpairs_queue->num_selects))) {	/* select_interval always > 0 */
			sel_fd = lane_nonpairs_queue->outs1fd;	/* so output_frag writes to select_interval output */
			sel_tfd = lane_nonpairs_queue->out_tag_fd;
			++lane_nonpairs_queue->num_output;
		}
		output_frag(fo, sel_fd, lane_nonpairs_queue->fqc1);	/* output read */
		if(fo->tag_seq != NULL)
			output_tag_read(fo, sel_tfd, lane_nonpairs_queue->fqct);	/* output actual tag sequence */
		++lane_nonpairs_queue->reads_seen;
	}

	/* read pairs, plex-based */
	sel_fd = NULL;
	if((rg_queue = get_rg_params(read_group_queues, fo->rg)) != NULL) {
		if(((rg_queue->reads_seen % rg_queue->select_interval) == 0)
			&& (rg_queue->num_output < *rg_queue->num_selects)) {	/* select_interval always > 0 */
			sel_fd = rg_queue->outs1fd;
			++rg_queue->num_output;
		}
		output_frag(fo, sel_fd, rg_queue->fqc1);	/* output read */
		++rg_queue->reads_seen;
	}

	return(0);
}

static int output_read_pair_member(struct _frag_out *fo, struct _output_queues *output_queues, struct _frag_store *frag_store)
{
	void **pp;
	struct _frag_out *cfo;	/* cached member of pair */
	struct _frag_out *tag_fo;	/* member of pair with tag */
	struct _read_output_queue *rg_queue = NULL;
	struct _read_output_queue *lane_pairs_queue = output_queues->lane_pairs_queue;
	void *read_group_queues = output_queues->read_group_queues;
	struct _fastqcheck *fqc_fo = NULL;
	FILE *fo_fd = NULL;	/* set to non-NULL to trigger output */
	FILE *cfo_fd = NULL;	/* set to non-NULL to trigger output */
	FILE *sel_tfd = NULL;	/* set to non-NULL to trigger output */
	struct _fastqcheck *fqc_cfo = NULL;

	if((pp=tfind(fo, &(frag_store->store), frag_store->compare_func)) == NULL) {	/* first frag of pair; store until partner seen */

		cfo=make_cached_frag_out(fo);	/* can't use the uncached one for storage */
		if(tsearch(cfo, &(frag_store->store), frag_store->compare_func) == NULL) {
			fprintf(stderr, "Failed to add QNAME %s to frag_store as first seen read\n", fo->frag_name);
			exit(-99);
		}
	}
	else {	/* second frag of pair, so do output */

		cfo = *(struct _frag_out **)pp;

		/* read pairs, lane-based */
		if(lane_pairs_queue != NULL) {
			if((lane_pairs_queue->reads_seen % lane_pairs_queue->select_interval == 0) 
					&& (lane_pairs_queue->num_output < *(lane_pairs_queue->num_selects))) {	/* select_interval always > 0 */
				fo_fd = (fo->frag_no == '1')? lane_pairs_queue->outs1fd: lane_pairs_queue->outs2fd;
				cfo_fd = (cfo->frag_no == '1')? lane_pairs_queue->outs1fd: lane_pairs_queue->outs2fd;

				/* allow output to tag "10000" file */
				sel_tfd = lane_pairs_queue->out_tag_fd;
				++lane_pairs_queue->num_output;
			}

			fqc_fo = (fo->frag_no == '1')? lane_pairs_queue->fqc1: lane_pairs_queue->fqc2;
			fqc_cfo = (cfo->frag_no == '1')? lane_pairs_queue->fqc1: lane_pairs_queue->fqc2;

			output_frag(fo, fo_fd, fqc_fo);
			output_frag(cfo, cfo_fd, fqc_cfo);
			/* At most one of the pair should have the tag */
			tag_fo = (fo->tag_seq != NULL)? fo: cfo;
			if(tag_fo->tag_seq != NULL)
				output_tag_read(tag_fo, sel_tfd, lane_pairs_queue->fqct);	/* handles both "10000" tag output and tag fastqcheck output */

			++lane_pairs_queue->reads_seen;
		}

		/* read pairs, plex-based */
		fo_fd = cfo_fd = NULL;
		if((rg_queue = get_rg_params(read_group_queues, fo->rg)) != NULL) {
			if(((rg_queue->reads_seen % rg_queue->select_interval) == 0)
				&& (rg_queue->num_output < *rg_queue->num_selects)) {	/* select_interval always > 0 */

				fo_fd = (fo->frag_no == '1')? rg_queue->outs1fd: rg_queue->outs2fd;
				cfo_fd = (cfo->frag_no == '1')? rg_queue->outs1fd: rg_queue->outs2fd;

				++rg_queue->num_output;
			}

			fqc_fo = (fo->frag_no == '1')? rg_queue->fqc1: rg_queue->fqc2;
			fqc_cfo = (cfo->frag_no == '1')? rg_queue->fqc1: rg_queue->fqc2;
			output_frag(fo, fo_fd, fqc_fo);
			output_frag(cfo, cfo_fd, fqc_cfo);

			++rg_queue->reads_seen;	/* strictly speaking, "read_pairs_seen" */
		}

		/* finished with this pair, so remove from frag_store */
		if(tdelete(cfo, &(frag_store->store), frag_store->compare_func) == NULL) {
			fprintf(stderr, "Failed to delete QNAME %s from (not found?) when processing highpos read\n", cfo->frag_name);
			exit(-99);
		}
		free_frag_out(cfo);
	}

	return(0);
}

static struct _read_output_queue *get_rg_params(void *rg_queues, char *rg)
{
	void **pp;
	static struct _read_output_queue loc_oq;

	loc_oq.read_group = rg;

	if((pp=tfind(&loc_oq, &rg_queues, compare_oq)) == NULL)
		return(NULL);
	else
		return(*(struct _read_output_queue **)pp);
}

/*
Take the uncached struct _frag_out and make a cacheable version of it
*/
static struct _frag_out *make_cached_frag_out(struct _frag_out *fo)
{
	struct _frag_out *ret;
	int compressed_seqlen;

	if((ret=malloc(sizeof(struct _frag_out))) == NULL) {
		fprintf(stderr, "Failed to malloc _frag_out struct in makd_cached_frag_out()\n");
		exit(-99);
	}

	ret->cached = 1;	/* flag that this is cached */
	ret->frag_no = fo->frag_no;
	ret->frag_name_len = fo->frag_name_len;
	ret->l_qseq = fo->l_qseq;
	ret->is_revcomp = fo->is_revcomp;

	ret->frag_name = strdup(fo->frag_name);

	compressed_seqlen = (fo->l_qseq+1) / 2;
	if((ret->seq = malloc(compressed_seqlen)) == NULL) {
		fprintf(stderr, "malloc seq area fails in _load_frag_out\n");
		return(NULL);
	}
	memcpy(ret->seq, fo->seq, compressed_seqlen);

	if((ret->qual = malloc(fo->l_qseq)) == NULL) {
		fprintf(stderr, "malloc qual area fails in _load_frag_out\n");
		return(NULL);
	}
	memcpy(ret->qual, fo->qual, ret->l_qseq);

	if(fo->tag_seq != NULL)   /* default: RT */
		ret->tag_seq = strdup(fo->tag_seq);             /* tag sequence (+1 to skip type indicator) */
	else
		ret->tag_seq = NULL;

	if(fo->tag_qual != NULL)   /* default: QT */
		ret->tag_qual = strdup(fo->tag_qual);            /* tag sequence qualities (+1 to skip type indicator) */
	else
		ret->tag_qual = NULL;

	if(fo->rg != NULL)    /* default: QT */
		ret->rg = strdup(fo->rg);          /* tag sequence qualities (+1 to skip type indicator) */
	else
		ret->rg = NULL;

	return(ret);
}

/*
This data should be flushed to file directly, so copies of the output data
do not need to be made
*/
static struct _frag_out *load_uncached_frag_out(bam1_t *b)
{
	static struct _frag_out uncached_frag_fo;

	uncached_frag_fo.cached = 0;	/* flag that this is uncached */
	return(_load_frag_out(b, &uncached_frag_fo));
}

static struct _frag_out *_load_frag_out(bam1_t *b, struct _frag_out *ret)
{
	char *p;
	int is_firstfrag = b->core.flag & 0x40;
	int compressed_seqlen;

	ret->frag_no = (!is_firstfrag? '2': '1');	/* funny reversed logic makes single-end default to '1' */
	ret->frag_name_len = b->data_len;
	ret->l_qseq = b->core.l_qseq;
	ret->is_revcomp = b->core.flag & 0x10;

	if(!ret->cached) {
		ret->frag_name = (char *)b->data;
		ret->seq = (char *)(bam1_seq(b));
		ret->qual = (char *)(bam1_qual(b));
		if((ret->tag_seq = (char *)bam_aux_get(b, params.rt_tag)) != NULL)	/* default: RT */
			++ret->tag_seq;						/* tag sequence (+1 to skip type indicator) */
		if((ret->tag_qual = (char *)bam_aux_get(b, params.qt_tag)) != NULL)	/* default: QT */
			++ret->tag_qual;					/* tag sequence qualities (+1 to skip type indicator) */
		if((ret->rg = (char *)(bam_aux_get(b, "RG"))) != NULL) {
			++ret->rg;						/* read group (+1 to skip type indicator) */
			if((p=strchr(ret->rg, '#')) != NULL)
				ret->rg = p;
		}
	}
	else {	/* this will be cached, so take local copies */
		ret->frag_name = strdup((char *)b->data);

		compressed_seqlen = (ret->l_qseq+1) / 2;
		if((ret->seq = malloc(compressed_seqlen)) == NULL) {
			fprintf(stderr, "malloc seq area fails in _load_frag_out\n");
			return(NULL);
		}
		memcpy(ret->seq, bam1_seq(b), compressed_seqlen);

		if((ret->qual = malloc(ret->l_qseq)) == NULL) {
			fprintf(stderr, "malloc qual area fails in _load_frag_out\n");
			return(NULL);
		}
		memcpy(ret->qual, bam1_qual(b), ret->l_qseq);

		if((p=(char *)bam_aux_get(b, params.rt_tag)) != NULL)	/* default: RT */
			ret->tag_seq = strdup(p+1);		/* tag sequence (+1 to skip type indicator) */
		else
			ret->tag_seq = NULL;
		
		if((p=(char *)bam_aux_get(b, params.qt_tag)) != NULL)	/* default: QT */
			ret->tag_qual = strdup(p+1);		/* tag sequence qualities (+1 to skip type indicator) */
		else
			ret->tag_qual = NULL;

		if((p=(char *)bam_aux_get(b, "RG")) != NULL) {	/* default: QT */
			ret->rg = strdup(p+1);		/* tag sequence qualities (+1 to skip type indicator) */
			if((p=strchr(ret->rg, '#')) != NULL)
				ret->rg = p;
		}
		else {
			ret->rg = NULL;
		}
	}

	return(ret);
}

static int free_frag_out(struct _frag_out *fo)
{
	if(fo == NULL || !fo->cached) {
		return(0);
	}
	free(fo->frag_name);
	free(fo->seq);
	free(fo->qual);
	if(fo->tag_seq != NULL)
		free(fo->tag_seq);
	if(fo->tag_qual != NULL)
		free(fo->tag_qual);
	if(fo->rg != NULL)
		free(fo->rg);

	free(fo);

	return(0);
}

/*
output_frag:
Output reads sequences and qualities
If seq_fd given
	output sequence and qualities in FASTQ format
If fqc given
	output to fastqcheck handler
*/
static int output_frag(struct _frag_out *fo, FILE *seq_fd, struct _fastqcheck *fqc)
{
        char *seq = fo->seq;
        int i, j;
	int pos;
        int incr = 1;
        int (*not_loop_end)(int idx, int end);
        unsigned char mask;
        char base;
        static char bases[] = { 'A', 'C', 'G', 'T' };
        static char rev_bases[] = { 'T', 'G', 'C', 'A' };
        int beg, end;
        char *basemap = NULL;
        unsigned char call;
	static int count = 0;

	++count;

        /* output fragment name */
	if(seq_fd != NULL)
		fprintf(seq_fd, "@%.*s/%c\n", fo->frag_name_len, (fo->frag_name!=NULL?fo->frag_name:"NULL"), fo->frag_no);    /* fragment name (with appended frag no) */

        /* determine loop control and base decoding parameters */
        if(fo->is_revcomp) {
                incr = -1; basemap = rev_bases; beg=fo->l_qseq-1; end=0; not_loop_end=rev_nle;
        }
        else {
                incr = 1; basemap = bases; beg=0; end=fo->l_qseq-1; not_loop_end=fwd_nle;
        }

	if(fqc) {
		fqc_next_seq(fqc, fo->frag_name, fo->l_qseq);
	}
	/* Iterate over the sequence string */
        for(pos=0, i=beg; (*not_loop_end)(i, end); pos++, i += incr) {
                call = (unsigned char)bam1_seqi(seq, i);
                base = 'U';
                if(call == 0xf) {
                        base='N';
                }
                else {
                        for(mask=1, j=0; j<4; mask <<= 1, j++) {
                                if(call & mask) {
                                        base = basemap[j];
                                        break;
                                }
                        }
                }
		if(seq_fd != NULL)
			fprintf(seq_fd, "%c", base);

		/* Transform base call into format used by fastqcheck */
		if(fqc) {
			int coded_call;
			switch(base) {
				case 'A': coded_call = 0; break;
				case 'C': coded_call = 1; break;
				case 'G': coded_call = 2; break;
				case 'T': coded_call = 3; break;
				case 'N':
				default: coded_call = 4; break;
			}

			fqc_add_seq_val(fqc, coded_call, pos);
		}
			
        }

	if(seq_fd != NULL)
		fprintf(seq_fd, "\n+\n");
        char *qual = fo->qual;

	/* Iterate over the quality string */
        for(pos=0, j=beg; (*not_loop_end)(j, end); pos++, j += incr) {
		if(seq_fd != NULL)
			fprintf(seq_fd, "%c", qual[j]+33);

		if(fqc) {
			fqc_add_qual_val(fqc, qual[j], pos);	/* fastqcheck wants unencoded quality value (so no need for +33) */
		}
        }
	if(seq_fd != NULL)
		fprintf(seq_fd, "\n");

        return(0);
}

static int output_tag_read(struct _frag_out *fo, FILE *outfd, struct _fastqcheck *fqc)
{
	int i;

        /* output fragment name */
	if(outfd != NULL) {
		fprintf(outfd, "@%.*s/%c\n%s\n+\n%s\n",
			fo->frag_name_len,fo->frag_name,
			fo->frag_no,
			fo->tag_seq,
			fo->tag_qual);
	}

	/* Transform base calls into format used by fastqcheck */
	if(fqc) {
		fqc_next_seq(fqc, fo->frag_name, strlen(fo->tag_seq));

		for(i=0; fo->tag_seq[i] ; i++) {
			int coded_call;
			switch(fo->tag_seq[i]) {
				case 'A': coded_call = 0; break;
				case 'C': coded_call = 1; break;
				case 'G': coded_call = 2; break;
				case 'T': coded_call = 3; break;
				case 'N':
				default: coded_call = 4; break;
			}

			fqc_add_seq_val(fqc, coded_call, i);
			fqc_add_qual_val(fqc, fo->tag_qual[i]-33, i);	/* fastqcheck wants unencoded quality value (so -33 here) */
		}
	}

	return(0);
}

static int compare_frags(const void *item1, const void *item2)
{
	const struct _frag_out *fo1 = item1;
	const struct _frag_out *fo2 = item2;

	return(strcmp(fo1->frag_name, fo2->frag_name));
}

static int fwd_nle(int idx, int end)
{
	return(idx<=end);
}

static int rev_nle(int idx, int end)
{
	return(idx>=end);
}

static int fetch_params(int ac, char **av, struct _params *params)
{
	int c;
	int need_help = 0;

	/* defaults */
	params->rt_tag = "BC";
	params->qt_tag = "QT";
	params->num_selects = 10000; /* number of sample reads (default: 10,000) */
	params->num_reads = 0;	/* used to determine interval for selection of num_select reads */
	params->select_interval = 1;	/* implied by num_selects and num_reads, so no flag */
	params->required_flag = 0;
	params->filtering_flag = 0;
	params->count_only = 0;
	params->lane_mode = 0;
	params->verbosity = 0;
	strcpy(params->output_spec.base_dir, "");
	strcpy(params->output_spec.lane_dir, ".npg_cache_10000");
	strcpy(params->output_spec.outbase, generate_out_file_name());
	params->output_spec.do_fastqcheck = 0;

	/*** process flags ***/
	while((c = getopt(ac, av, "hv:r:q:o:n:s:f:F:b:d:klt:c")) >= 0) {
		switch(c) {
			case 'h': need_help = 1; break;
			case 'c': params->count_only = 1; break;
			case 'v': params->verbosity = convert_numarg(c, optarg); break;
			case 'r': params->rt_tag = optarg; break;
			case 'q': params->qt_tag = optarg; break;
			case 'o': strncpy(params->output_spec.outbase, optarg, FBSIZ - 16); break;
			case 'n': params->num_reads = convert_numarg(c, optarg); break;
			case 's': params->num_selects = convert_numarg(c, optarg); break;
			case 'f': params->required_flag = convert_numarg(c, optarg); break;
			case 'F': params->filtering_flag = convert_numarg(c, optarg); break;
			case 'b': strncpy(params->output_spec.base_dir, optarg, BDSIZ - 16); break;
			case 'd': strncpy(params->output_spec.lane_dir, optarg, FBSIZ - 16); break;
			case 'k': params->output_spec.do_fastqcheck = 1; break;
			case 'l': params->lane_mode = 1; break;
			case 't': params->output_queues = add_tag_count(params->output_queues, optarg, &(params->output_spec), &(params->num_selects)); break;
			default: usage(0); exit(-99);
		}
	}

	if(need_help) {
		usage(1);
		exit(0);
	}

	if(validate_params(params)) {
		fprintf(stderr, "Fatal error setting params\n");
		usage(0);
		exit(-99);
	}

	return(optind);
}

static int convert_numarg(char flag, char *val)
{
	int ret = 0;
	char *p;

	errno=0;
	ret = strtol(val, &p, 0);
	if(errno != 0) {
		if(errno == ERANGE)
			fprintf(stderr, "Value \"%s\" out of range for -%c flag\n", val, flag);
		else
			fprintf(stderr, "Error converting value \"%s\" for -%c flag\n", val, flag);
			
		usage(0);
		exit(-99);
	}
	if(*p) {
		fprintf(stderr, "Invalid character %c in conversion of value \"%s\" for -%c flag\n", *p, val, flag);
		usage(0);
		exit(-99);
	}

	return(ret);
}

static int validate_params(struct _params *params)
{
	struct stat statbuf;

	if(*params->output_spec.lane_dir) {
		if(stat(params->output_spec.lane_dir, &statbuf)) {
			if(errno == ENOENT) {	/* create directory of appropriate */
				if(mkdir(params->output_spec.lane_dir, 0777)) {	/* create directory of appropriate */
					fprintf(stderr, "In lane mode and directory %s does not exist and cannot be created\n", params->output_spec.lane_dir);
					exit(-99);
				}
			}
			else {
				perror("stat lane_dir");
				exit(-99);
			}
		}
		else if(!S_ISDIR(statbuf.st_mode)) {	/* file exists - is it  a directory? */
			fprintf(stderr, "In lane mode and %s exists and is not a directory\n", params->output_spec.lane_dir);
			exit(-99);
		}
	}

	return(0);
}

static int usage(int full)
{
	fprintf(stderr, "Usage: fastq_summ [-v <verbose_level>] [-r <rt_tag>] [-q <qt_tag>] [-o <filebase>] [-n <num_reads>] [-s <num_selects>] [-f <required_flag>] [-F <filtering_flag>] <bamfile>\n");

	if(full) {
		printf("\nParameters:\n");
		printf("\tBase dir: %s\n", params.output_spec.base_dir);
		printf("\tLane dir: %s\n", params.output_spec.lane_dir);
		printf("\tOutbase: %s\n", params.output_spec.outbase);
		printf("\tRT tag: %s\n", params.rt_tag);
		printf("\tQT tag: %s\n", params.qt_tag);
		printf("\tNo. of selects: %lu\n", params.num_selects);
		printf("\tNo. of reads: %d\n", params.num_reads);
		printf("\tSelect interval: %d\n", params.select_interval);
		printf("\tRequired flag: %d (%#0X)\n", params.required_flag, params.required_flag);
		printf("\tFiltering flag: %d (%#0X)\n", params.filtering_flag, params.filtering_flag);
		if(params.output_queues != NULL) {
			printf("Lane non-pairs queue: [TBD]\n");
			printf("Lane pairs queue: [TBD]\n");
			printf("Read group queues:\n");
			twalk(params.output_queues->read_group_queues, report_rgq_nodes);
		}
		printf("\tVerbosity level: %d\n", params.verbosity);

		printf("\nfastq_summ version 1.1 (25/10/12)\n");
	}

	return(0);
}

/*
add_tag_count:
Add a read output queue node for the specified read group.
1. If output queues struct doesn't exist, create it
2. If the read group output queue cache does not exist, create it
3. parse read group count spec
4. a) If a RGOQ node already exists for the read group, output warning
   b) otherwise create new RGOQ node, initialise it and add it to the read group output queue cache
5. return output queues struct ptr
*/
static struct _output_queues *add_tag_count(struct _output_queues *q, char *tc, struct _output_spec *output_spec, uint64_t *num_selects)
{
	struct _output_queues *ret = q;
	char read_group_name[RGNMMAXLEN];
	int len;
	int rgnmlen;
	char *p;
	uint64_t total_reads;
	struct _read_output_queue *roq;

	if(ret == NULL) {
		if((ret = malloc(sizeof(struct _output_queues))) == NULL) {
			fprintf(stderr, "Failed to malloc _output_queues struct\n");
			exit(-99);
		}

		ret->lane_nonpairs_queue = ret->lane_pairs_queue = ret->read_group_queues = NULL;
	}

	/* parse RG count spec */
	len = strlen(tc);
	if(len > 0) len--;
	for(p=tc+len; p>tc; p--) { /* format: <RG_val>:<count> */
		if(!isdigit(*p)) {
			if(*p == ':') {
				break;
			}
			if(*(p-1) != '0' || *p != 'x') {
				fprintf(stderr, "Invalid format %s for tag count spec\n", tc);
				return(ret);	/* if only invalid tag counts given, there will be no output */
			}
		}
	}
	if(*p != ':' || (rgnmlen = p-tc) <= 0) {
		fprintf(stderr, "Invalid format %s for tag count spec\n", tc);
		return(ret);	/* if only invalid tag counts given, there will be no output */
	}
	if(rgnmlen >= RGNMMAXLEN) {
		fprintf(stderr, "RG name too long in tag count spec: %s\n", tc);
		return(ret);	/* if only invalid tag counts given, there will be no output */
	}
	memcpy(read_group_name, tc, rgnmlen);
	read_group_name[rgnmlen] = '\0';
	total_reads = convert_numarg('t', p+1);

	if(ret->read_group_queues == NULL || get_rg_params(ret->read_group_queues, read_group_name) == NULL) {
		roq = new_roq(read_group_name, total_reads, num_selects, output_spec, 1);	/* can't currently specify single-end tagged here */
		if(tsearch(roq, &(ret->read_group_queues), compare_oq) == NULL) {
			fprintf(stderr, "Failed to add read group %s to read_group_queues\n", roq->read_group);
			exit(-99);
		}
	}
	else {
		fprintf(stderr, "Output queue for RG %s already exists in add_tag_count()\n", read_group_name);
	}

	return(ret);
}

/*
init_output_queues:
If the counts for the reads have not been specified using -t flags, make an initial pass through the
data to count the reads, both per-lane and per-readgroup. Calculate the select_interval for each
output from the results.
opening and closing then reopening the bam file seems wasteful, but I can't see a rewind function
in the samtools C API. Fix this if it's too slow
*/
static struct _output_queues *init_output_queues(char *fn, struct _params *params)
{
	struct _output_queues *ret;
	static struct _read_output_queue *selected_queue;
	int is_paired = 1;
	static struct _read_output_queue loc_oq;
	static struct _read_output_queue *rg_oq;
	char *rg, *p;
	int lc, filtered, rc, se;
	samfile_t *fp = NULL;
	bam1_t *b = NULL;
	void **pp;

	if((ret = malloc(sizeof(struct _output_queues))) != NULL) {

		/* First, the output queue for all paired reads */
		if((rg_oq=malloc(sizeof(struct _read_output_queue))) == NULL) {
			fprintf(stderr, "Failed to malloc output queue for lane pairs queue\n");
			exit(-99);
		}
		rg_oq->read_group = NULL;
		rg_oq->total_reads = rg_oq->reads_seen = rg_oq->num_output = 0;
		rg_oq->num_selects = &(params->num_selects);
		rg_oq->select_interval = 1;
		ret->lane_pairs_queue = rg_oq;

		/* Second, the output queue for all non-paired reads */
		if((rg_oq=malloc(sizeof(struct _read_output_queue))) == NULL) {
			fprintf(stderr, "Failed to malloc output queue for lane pairs queue\n");
			exit(-99);
		}
		rg_oq->read_group = NULL;
		rg_oq->total_reads = ret->lane_pairs_queue->reads_seen = ret->lane_pairs_queue->num_output = 0;
		rg_oq->num_selects = &(params->num_selects);
		rg_oq->select_interval = 1;
		ret->lane_nonpairs_queue = rg_oq;

		/* Now set up the tree storing the queues for the individual read groups (tags) */
		ret->read_group_queues = NULL;

		if((fp = samopen(fn, "rb", 0)) == NULL) {
			fprintf(stderr, "Failed to open BAM file %s\n", fn);
			usage(0);
			exit(-1);
		}

		b = bam_init1();

		params->tags_seen = 0;	/* the one case of general environment checking at this stage */
		/*********************
		Do some counting
		*********************/
		for(lc=filtered=rc=se=0; samread(fp, b) >= 0; lc++) {
			if(((b->core.flag & params->required_flag) != params->required_flag) || (b->core.flag & params->filtering_flag)) {
				filtered++;
				continue;
			}
			else {
				rc++;
			}

			if((b->core.flag & 0x1) == 0) {	/* not a member of a pair */
				selected_queue = ret->lane_nonpairs_queue;
				is_paired = 0;
			}
			else {
				selected_queue = ret->lane_pairs_queue;
				is_paired = 1;
			}

			if((b->core.flag & 0x41) == 0x41)
				continue;	/* only count one read of a pair */

			/* create output queue for the read group (if necessary), record the sighting for the read
				group and the lane total for single-end|paired-end reads */
			if(!params->lane_mode && (rg = (char *)(bam_aux_get(b, "RG"))) != NULL) {
				++rg;	/* skip type indicator char */
				if((p=strchr(rg, '#')) != NULL)
					rg = p;
				loc_oq.read_group = rg;
				if((pp=tfind(&loc_oq, &(ret->read_group_queues), compare_oq)) == NULL) {	/* check to see if output_queue needs to be created */
					if((rg_oq = new_roq(rg, 0, &(params->num_selects), &(params->output_spec), is_paired)) == NULL) {
						fprintf(stderr, "Failed to create new output queue node for read group %s\n", rg);
						exit(-99);
					}
					if(tsearch(rg_oq, &(ret->read_group_queues), compare_oq) == NULL) {
						fprintf(stderr, "Failed to add read group %s to read_group_queues\n", rg_oq->read_group);
						exit(-99);
					}
					params->tags_seen++;	/* the one case of general environment checking at this stage */
				}
				else {
					rg_oq = *(struct _read_output_queue **)pp;
				}

				++rg_oq->total_reads;
			}
			++selected_queue->total_reads;
		}

		bam_destroy1(b);

		samclose(fp);

		/* if total_reads and num_selects are known, calculate select_intervals for lane level */
		if(ret->lane_pairs_queue->total_reads != 0 && *ret->lane_pairs_queue->num_selects > 1 && ret->lane_pairs_queue->total_reads > *ret->lane_pairs_queue->num_selects)
			ret->lane_pairs_queue->select_interval = (ret->lane_pairs_queue->total_reads - 1) / (*ret->lane_pairs_queue->num_selects - 1);
		if(ret->lane_nonpairs_queue->total_reads != 0 && *ret->lane_nonpairs_queue->num_selects > 1 && ret->lane_nonpairs_queue->total_reads > *ret->lane_nonpairs_queue->num_selects)
			ret->lane_nonpairs_queue->select_interval = (ret->lane_nonpairs_queue->total_reads - 1) / (*ret->lane_nonpairs_queue->num_selects - 1);

		/* specification of num_selects == 0 is a special case meaning "output all reads" */
		if(*ret->lane_pairs_queue->num_selects == 0) {
			ret->lane_pairs_queue->num_selects = &(ret->lane_pairs_queue->total_reads);
		}
		if(*ret->lane_pairs_queue->num_selects == 0) {
			ret->lane_nonpairs_queue->num_selects = &(ret->lane_nonpairs_queue->total_reads);
		}

		if(params->verbosity > 0) {
			printf("calculated select interval for lane (paired reads): %d\n", ret->lane_pairs_queue->select_interval);
			printf("calculated select interval for lane (non-paired reads): %d\n", ret->lane_nonpairs_queue->select_interval);
		}
	}

	return(ret);
}

/*
new_roq:
create a new node for the read group output queue cache. Any caching issues (checks for duplicates,
addition to cache) should be handled by the caller
*/
static struct _read_output_queue *new_roq(char *rg, uint64_t total_reads, uint64_t *num_selects, struct _output_spec *output_spec, int is_paired)
{
	static struct _read_output_queue *ret;

	if((ret=malloc(sizeof(struct _read_output_queue))) == NULL) {
		fprintf(stderr, "Failed to malloc output queue for read group %s\n", rg);
		exit(-99);
	}

	ret->reads_seen = ret->num_output = 0;
	ret->total_reads = total_reads;
	ret->num_selects = num_selects;
	ret->outs1fd = ret->outs2fd = ret->out_tag_fd =  NULL;
	ret->fqc1 = ret->fqc2 = ret->fqct = NULL;
	ret->is_paired = is_paired;

	if(rg!=NULL) {
		ret->read_group = strdup(rg);
		ret->output_spec = output_spec;	/* points directly to params setting */
	}
	else {
		ret->read_group = NULL;
	}

	return(ret);
}

/*
compare_oq:
Comparison function used for output queue tree
*/
static int compare_oq(const void *item1, const void *item2)
{
	const struct _read_output_queue *oq1 = item1;
	const struct _read_output_queue *oq2 = item2;

	return(strcmp(oq1->read_group, oq2->read_group));
}

/*
visit_frag_nodes:
Counts reads which are still in the read pair cache. Used after all input has been processed
to count number of reads which are flagged as one of a pair but whose mate doesn't appear
in the input.
*/
static void visit_frag_nodes(const void *nodep, const VISIT which, const int depth)
{
	if(which == postorder || which == leaf) {
		stragglers++;
	}

	return;
}

/*
A set of functions to act on all the nodes of the "read group queue" tree:
	report_rgq_nodes
	activate_rgq_nodes
	close_rgq_nodes
*/
/*
report_rgq_nodes:
Print information about a read group queue node
*/
static void report_rgq_nodes(const void *nodep, const VISIT which, const int depth)
{
	struct _read_output_queue *oq = *(struct _read_output_queue **)nodep;

	if(which == postorder || which == leaf) {
		printf("\t%s node: read_group_name: %s, count: %lu, outbase: %s\n", (which==leaf? "Leaf": "Internal"), (oq->read_group != NULL? oq->read_group: "NULL"), oq->total_reads, oq->output_spec->outbase);
	}

	return;
}

/*
activate_rgq_nodes:
Open output streams and calculate the select_interval for the read stream. Done late since we may not have the necessary information
(total_read counts, base_dir for output) until the tree is already constructed.
*/
static void activate_rgq_nodes(const void *nodep, const VISIT which, const int depth)
{
	struct _read_output_queue *node = *(struct _read_output_queue **)nodep;
	char rg_oq_fn[FBSIZ];	/* output filename for a read group */

	if(which == postorder || which == leaf) {
		if(params.verbosity > 0)
			printf("%s node: tag_name: %s; read_count: %lu\n", (which==leaf? "Leaf": "Internal"), node->read_group, node->total_reads);

		if(node->total_reads > 0) {
			/* calculate select interval for the read group output */
			if(*node->num_selects > 1 && node->total_reads > *node->num_selects)
				node->select_interval = (node->total_reads - 1) / (*node->num_selects - 1);
			else
				node->select_interval = 1;
		
			if(params.verbosity > 0)
				printf("calculated select interval for read group %s: %d\n", node->read_group, node->select_interval);

			/* open the output files */
			snprintf(rg_oq_fn, FBSIZ, "%s/%s_1%s.fastq.%lu", node->output_spec->lane_dir, node->output_spec->outbase, node->read_group, (*node->num_selects < node->total_reads? *node->num_selects: node->total_reads));
			if((node->outs1fd=fopen(rg_oq_fn, "w")) == NULL) {
				fprintf(stderr, "Failed to open %s for output\n", rg_oq_fn);
				exit(-99);
			}
			else {
				global_open_file_count++;
			}
			if(node->is_paired) {
				snprintf(rg_oq_fn, FBSIZ, "%s/%s_2%s.fastq.%lu", node->output_spec->lane_dir, node->output_spec->outbase, node->read_group, (*node->num_selects < node->total_reads? *node->num_selects: node->total_reads));
				if((node->outs2fd=fopen(rg_oq_fn, "w")) == NULL) {
					fprintf(stderr, "Failed to open %s for output\n", rg_oq_fn);
					exit(-99);
				}
				else {
					global_open_file_count++;
				}
			}
			if(node->output_spec->do_fastqcheck) {
				snprintf(rg_oq_fn, FBSIZ, "%s/%s_1%s.fastqcheck", node->output_spec->lane_dir, node->output_spec->outbase, node->read_group);
				if((node->fqc1=new_fastqcheck(rg_oq_fn)) == NULL) {
					fprintf(stderr, "Failed to open create output for fastqcheck 1: %s\n", rg_oq_fn);
					usage(0);
					exit(-99);
				}
				if(node->is_paired) {
					snprintf(rg_oq_fn, FBSIZ, "%s/%s_2%s.fastqcheck", node->output_spec->lane_dir, node->output_spec->outbase, node->read_group);
					if((node->fqc2=new_fastqcheck(rg_oq_fn)) == NULL) {
						fprintf(stderr, "Failed to open create output for fastqcheck 2: %s\n", rg_oq_fn);
						usage(0);
						exit(-99);
					}
				}
			}
			else {
				node->fqc1 = node->fqc2 = node->fqct = NULL;
			}

			if(*node->num_selects == 0) {
				node->num_selects = &(node->total_reads);
			}

		}
	}

	return;
}

/*
close_rgq_nodes:
used to walk through the read_group_queues tree and close any output streams
*/
static void close_rgq_nodes(const void *nodep, const VISIT which, const int depth)
{
	struct _read_output_queue *node = *(struct _read_output_queue **)nodep;

	if(which == postorder || which == leaf) {
		if(params.verbosity > 0)
			printf("closing %s node: tag_name: %s; read_count: %lu\n", (which==leaf? "Leaf": "Internal"), node->read_group, node->total_reads);

		close_oq(node);
	}

	return;
}

static void close_oq(struct _read_output_queue *queue)
{
	if(queue->outs1fd != NULL) fclose(queue->outs1fd);
	if(queue->outs2fd != NULL) fclose(queue->outs2fd);
	if(queue->fqc1 != NULL) fqc_output(queue->fqc1);
	if(queue->fqc2 != NULL) fqc_output(queue->fqc2);
	if(queue->fqct != NULL) fqc_output(queue->fqct);
	return;
}

/*
generate_out_file_name:
Generates a file name based on the time. Used when no output_base is specified.
*/
static char *generate_out_file_name(void)
{
	time_t t;
	struct tm *tm;
	static char file_name[FBSIZ];

	t = time(NULL);
	tm = localtime(&t);

	snprintf(file_name, FBSIZ, "genoutfn_%02d%02d%02d_%02d%02d%02d", tm->tm_mday, tm->tm_mon+1, tm->tm_year%100, tm->tm_hour, tm->tm_min, tm->tm_sec);

	return(file_name);
}


