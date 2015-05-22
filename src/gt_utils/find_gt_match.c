/* Author:        Kevin Lewis
 * Created:       2012-04-16
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "gt_pack.h"

#define BITS_PER_CALL 2
#define NAMESIZE 128
#define FTMC_BUFLEN 48

struct _base_gt {
	char *base_gt;
	char *depths;
	char *never_match;
};

/* global section */
struct _global_env {
	int min_full_call_depth;
	char *sample_name;	/* Override value in input files/stream */
} global_env = { 5, NULL };

/*
Static function prototypes
*/
static int read_hdr(FILE *infd, GT_HDR *gt_hdr);
static FILE *open_file(char *basename, char *extname);
static char *readSampleName(FILE *sfd, int sidx, char *buf, int bsiz);
static int find_sample_index(FILE *sfd, char *s1);
static int checkCallRate(char *rec, int callcount, int min_sample_callrate);
static int print_params(int output_format, char *data_id, char *refresh_date, int callcount, int min_common, int min_sample_callrate, int high_concord_level, int posdup_level, int print_only_posdups, int only_check_same_names, int only_check_diff_names, char *lh1, char *l1, char *l2, char *base_gt);
static int print_start(int output_format);
static int print_end(int output_format, int status, char *status_ms);
static int print_comp_result_start(int output_format);
static int print_comp_result_end(int output_format);
static int print_comp_result(int output_format, char *desc, char *l1, char *l2, int commoncalls, int match, int mismatch, char *match_score_string, int callcount, char *matched_gt);
static char *remove_tabs(char *s);
static int usage(void);
static int valid_gt_hdr(GT_HDR *hdr);
static struct _base_gt *get_base_gt(FILE *fd, int callcount, int dp_bits);
static char match_score(char basecall, char floatcall, unsigned mask);
static char *reformat_gt(char *gt, int callcount);

int main(int ac, char **av)
{
	FILE *infd;
	int min_common = 8, high_concord_level = 70, posdup_level = 95, print_only_posdups = 0, min_sample_callrate = 0, output_format = 0;
	int use_aux_files = 1;
	int only_check_same_names = 0, only_check_diff_names = 0;
	char *comp_gt_basename = NULL, *basename = NULL;
	GT_HDR gt_hdr;
	GT_HDR hdr;
	int hdr_size;
	long endpos;
	int i, j;
	int gti;
	int cc;
	unsigned mask = 0;
	FILE *sfd = NULL, *lfd = NULL;
	char lh1[NAMESIZE], s1[NAMESIZE], s2[NAMESIZE], l1[NAMESIZE], l2[NAMESIZE];
	int sample_index = -1;	/* index of sample name entry (if there is one) */
	int callcount;
	int lastrec, calldatasize, gt_size;	/* calldatasize is the size of the entire compressed block of genotype data, gt_size is a sample's worth */
	char *floatrec = NULL;
	char *match_score_string = NULL;
	struct _base_gt *base_gt;
	int commoncalls, match, mismatch;
	int relaxed_commoncalls, relaxed_match, relaxed_mismatch;
	int matchrate, relaxed_matchrate;
	char basecall, floatcall;
	int err;

	if(ac < 2 || !strcmp(av[1], "-h")) {
		usage();
		exit(0);
	}

	/*** process flags ***/
	i=1;
	while(i < ac) {
		if(!strcmp(av[i], "-m")) {
			if((ac-i) > 0) {
				min_common = atoi(av[i+1]);
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -m specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-c")) {
			if((ac-i) > 0) {
				high_concord_level = atoi(av[i+1]);
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -c specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-d")) {
			if((ac-i) > 0) {
				posdup_level = atoi(av[i+1]);
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -d specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-s")) {
			if((ac-i) > 0) {
				min_sample_callrate = atoi(av[i+1]);
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -s specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-t")) {
			if((ac-i) > 0) {
				int match_type;

				match_type = atoi(av[i+1]);
				i += 2;
				if(match_type == 1) {
					only_check_same_names = 1;
					only_check_diff_names = 0;
				}
				else if(match_type == 2) {
					only_check_same_names = 0;
					only_check_diff_names = 1;
				}
				else {
					only_check_same_names = 0;
					only_check_diff_names = 0;
				}
			}
			else {
				fprintf(stderr, "Flag -t specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-r")) {
			if((ac-i) > 0) {
				global_env.min_full_call_depth = atoi(av[i+1]);
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -r specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-n")) {
			if((ac-i) > 0) {
				global_env.sample_name = av[i+1];
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -n specified without argument\n");
				usage();
				exit(-1);
			}
		}
		else if(!strcmp(av[i], "-p")) {
			print_only_posdups = 1;
			i++;
		}
		else if(!strcmp(av[i], "-x")) {
			use_aux_files = 0;
			i++;
		}
		else if(!strcmp(av[i], "-j")) {
			output_format = 1;
			i++;
		}
		else if(!strcmp(av[i], "-h")) {
				usage();
			exit(0);
		}
		else {
			break;  /* any unrecognised arguments are not treated as flags */
		}
	}

	if(ac-i != 2) {
		usage();
		exit(0);
	}

	comp_gt_basename = av[i++];
	basename = av[i];

/**********************************************************
allocate buffer and read compressed genotype record into it
fetch sample name and label
**********************************************************/
	if(!strcmp(comp_gt_basename, "-")) {
		infd = stdin;
		use_aux_files = 0;
	}
	else if((infd=open_file(comp_gt_basename, "bin")) == NULL) {
		fprintf(stderr, "Failed to open %s.bin for input\n", comp_gt_basename);
		exit(-1);
	}

	if((err=read_hdr(infd, &gt_hdr)) != 0) {
		fprintf(stderr, "Fatal error %d reading gt header\n", err);
		exit(-99);
	}

	base_gt = get_base_gt(infd, gt_hdr.hdr_base.callcount, gt_hdr.hdr_base.dp_bits);

	fclose(infd);

	/* read the first line from the sample label files for the report header */
	*l1 = '\0';
	if(strcmp(comp_gt_basename, "-") && use_aux_files) {
		if((sfd = open_file(comp_gt_basename, "six")) == NULL) {
			fprintf(stderr, "Failed to open %s.six for input\n", comp_gt_basename);
			exit(-1);
		}
	}
	readSampleName(sfd, 0, s1, NAMESIZE);	/* Sample id columns header(s) */

	if(strcmp(comp_gt_basename, "-") && use_aux_files && (lfd = open_file(comp_gt_basename, "slx")) != NULL) {
		readSampleName(lfd, 0, lh1, NAMESIZE);	/* sample label column header */
		readSampleName(lfd, 1, l1, NAMESIZE);	/* sample 1 label */
		fclose(lfd);
	}
	else {
		memcpy(lh1, s1, NAMESIZE);
	}
	if(global_env.sample_name != NULL) {
		snprintf(s1, NAMESIZE, "%s", global_env.sample_name);
	}
	else {
		readSampleName(sfd, 1, s1, NAMESIZE);	/* the actual sample id (buffer reuse OK) */
	}
	if(!*l1) {
		memcpy(l1, s1, NAMESIZE);
	}
	if(sfd != NULL)
		fclose(sfd);
	if(lfd != NULL && lfd != sfd)
		fclose(lfd);

	/*** All the descriptive information for sample 1 should now be read into memory (lh1, s1 and l1 are fixed). Any further file accesses for sample id/label data (via sfd and lfd) will be for sample 2 ***/

	if((sfd = open_file(basename, "six")) == NULL) {
		fprintf(stderr, "Failed to open %s.six for input\n", basename);
		exit(-1);
	}
	sample_index = find_sample_index(sfd, s1);	/* try to ensure there is always a report on matching sample names */

	if((lfd = open_file(basename, "slx")) == NULL) {
		lfd = sfd;	/* sample labels not required */
	}

/* Column headers */
	readSampleName(lfd, 0, l2, NAMESIZE);

/******************************************************
open file of compressed genotype records for comparison
******************************************************/
	if((infd=open_file(basename, "bin")) == NULL) {
		fprintf(stderr, "Failed to open %s.%s for input\n", basename, "bin");
		exit(-1);
	}

	if((err=read_hdr(infd, &hdr)) != 0) {
		fprintf(stderr, "Fatal error %d reading gt header\n", err);
		exit(-99);
	}

	callcount = hdr.hdr_base.callcount;
	if(callcount != gt_hdr.hdr_base.callcount) {
		fprintf(stderr, "Call count mismatch: genotype call count: %d, comparison genotype call counts %d\n", gt_hdr.hdr_base.callcount, callcount);
		exit(-99);
	}

	if(fseek(infd, 0L, SEEK_END)) {
		perror("fseek fails");
		exit(-3);
	}

	if((endpos=ftell(infd)) < 0) {
		perror("ftell fails");
		exit(-4);
	}

	gt_size = (callcount+3)/4;
	hdr_size = (!strncmp(hdr.hdr_base.ver, "01", 2)? sizeof(hdr.hdr_base): sizeof(hdr));
	calldatasize = endpos - hdr_size;
	if(calldatasize % gt_size) {
		fprintf(stderr, "Call data section size %d not an integral number of rows of %d\n", calldatasize, callcount);
		exit(-5);
	}
	lastrec = calldatasize/gt_size;

	if((floatrec = malloc(gt_size)) == NULL) {
		fprintf(stderr, "Failed to malloc floatrec buffer of size %d\n", gt_size);
		exit(-6);
	}

        if((match_score_string=malloc(callcount)) == NULL) {
                fprintf(stderr, "Failed to malloc mismatch string buffer of size %d\n", callcount);
                exit(-6);
        }

/* Print header information */
	/* Print parameters */
	print_start(output_format);
	print_params(output_format, hdr.data_id, gt_hdr.refresh_date, hdr.hdr_base.callcount, min_common, min_sample_callrate, high_concord_level, posdup_level, print_only_posdups, only_check_same_names, only_check_diff_names, lh1, l1, l2, base_gt->base_gt);
	print_comp_result_start(output_format);

	/* return to first record position */
	if(fseek(infd, hdr_size, SEEK_SET)) {
		perror("seeking to genotype data start");
		exit(-7);
	}
	for(j=0; j<lastrec; j++) {
		memset(match_score_string, 0, callcount);

		/* fetch floatrec into floatrec buffer */
		if(fread(floatrec, 1, gt_size, infd) != gt_size) {
			fprintf(stderr, "Failed to read floatrec, record %d\n", j);
			exit(-6);
		}

		if(!checkCallRate(floatrec, callcount, min_sample_callrate) && (j != sample_index)) {
			continue;
		}

		match = mismatch = commoncalls = 0;
		relaxed_match = relaxed_mismatch = relaxed_commoncalls = 0;
		mask = 0xC0;
		gti=0;
		for(cc=0; cc<callcount; cc++) {
			/*
			2 bit encoded calls (these SNPs should always be biallelic,
			so 2 bits is enough)
				00 - NN
				01 - Homozygous allele_1
				10 - Homozyogous allele_2
				11 - Heterozygous
			*/

			if(base_gt->never_match != NULL && base_gt->never_match[cc]) {

				floatcall = floatrec[gti] & mask;
				if(floatcall) {	/* not NN */
					mismatch++;
					relaxed_mismatch++;
					commoncalls++;
					relaxed_commoncalls++;
					match_score_string[cc] = -1;	/* mismatch even if float result is NN */
				}
			}
			else {

				basecall = base_gt->base_gt[gti] & mask;
				floatcall = floatrec[gti] & mask;

				if(basecall && floatcall) {	/* if neither call is NN */
					commoncalls++;

					/* strict match check */
					if(basecall ^ floatcall) {	/* some bits don't match */
						mismatch++;
					}
					else {			/* all bits the same */
						match++;
					}

					if((base_gt->depths == NULL) || (base_gt->depths[cc] >= global_env.min_full_call_depth)) {
						/* strict match check when sufficient depth */
						if(basecall ^ floatcall) {	/* some bits don't match */
							relaxed_mismatch++;
						}
						else {			/* all bits the same */
							relaxed_match++;
						}
					}
					else {
						/* relaxed match check (e.g. if basecall == AA and floatcall == AG, match) */
						if((basecall & floatcall) == basecall) {	/* mismatch not proven */
							relaxed_match++;
						}
						else {			/* all bits the same */
							relaxed_mismatch++;
						}
					}

					match_score_string[cc] = match_score(basecall, floatcall, mask);
				}
			}

			mask >>=2;
			if(mask == 0) {
				mask = 0xC0;
				gti++;
			}
		}

		/* Always report on sample name match if there is one */
		if(j == sample_index) {
			readSampleName(sfd, j+1, s2, NAMESIZE);
			readSampleName(lfd, j+1, l2, NAMESIZE);
			print_comp_result(output_format, "SampleNameMatch", l1, l2, commoncalls, match, mismatch, match_score_string, callcount, floatrec);
			if(gt_hdr.hdr_base.dp_bits > 0) {
				print_comp_result(output_format, "RM_SampleNameMatch", l1, l2, commoncalls, relaxed_match, relaxed_mismatch, NULL, 0, NULL);
			}
		}

		matchrate = (commoncalls!=0)? (match*100)/commoncalls: 0;
		if(matchrate >= high_concord_level) {
			readSampleName(sfd, j+1, s2, NAMESIZE);
			readSampleName(lfd, j+1, l2, NAMESIZE);

			if(only_check_same_names && strcmp(s1, s2)) {
				continue;
			}

			if(only_check_diff_names && !strcmp(s1, s2)) {
				continue;
			}

			if(matchrate >= posdup_level) {
				if(commoncalls >= min_common) {	
					print_comp_result(output_format, "HIGHconcordantPosDupDnaDiff", l1, l2, commoncalls, match, mismatch, match_score_string, callcount, floatrec);
				}
				else if(!print_only_posdups) {
					print_comp_result(output_format, "HIGHconcordantButFewerThanMinCommonSNPs", l1, l2, commoncalls, match, mismatch, match_score_string, callcount, floatrec);
				}
			}
			else if(!print_only_posdups) {
				print_comp_result(output_format, "HIGHconcordant", l1, l2, commoncalls, match, mismatch, match_score_string, callcount, floatrec);

			}
		}

		relaxed_matchrate = (commoncalls!=0)? (relaxed_match*100)/commoncalls: 0;
		if(relaxed_matchrate >= high_concord_level) {
			readSampleName(sfd, j+1, s2, NAMESIZE);
			readSampleName(lfd, j+1, l2, NAMESIZE);

			if(only_check_same_names && strcmp(s1, s2)) {
				continue;
			}

			if(only_check_diff_names && !strcmp(s1, s2)) {
				continue;
			}


			if(gt_hdr.hdr_base.dp_bits > 0) {
				if(relaxed_matchrate >= posdup_level) {
					if(commoncalls >= min_common) {	
						print_comp_result(output_format, "RM_HIGHconcordantPosDupDnaDiff", l1, l2, commoncalls, relaxed_match, relaxed_mismatch, NULL, 0, NULL);
					}
					else if(!print_only_posdups) {
						print_comp_result(output_format, "RM_HIGHconcordantButFewerThanMinCommonSNPs", l1, l2, commoncalls, relaxed_match, relaxed_mismatch, NULL, 0, NULL);
					}
				}
				else if(!print_only_posdups) {
					print_comp_result(output_format, "RM_HIGHconcordant", l1, l2, commoncalls, relaxed_match, relaxed_mismatch, NULL, 0, NULL);

				}
			}
		}
	}

	fclose(infd);

	print_comp_result_end(output_format);
	print_end(output_format, 0, "SUCCESS");

	return(0);
}

/*
basecall and floatcall are 2 bit encoded calls (these SNPs should always be biallelic,
so 2 bits is enough)
	00 - NN
	01 - Homozygous allele_1
	10 - Homozyogous allele_2
	11 - Heterozygous
*/
static char match_score(char basecall, char floatcall, unsigned mask)
{
	if(floatcall == basecall) {
		return(1);
	}
	else if((floatcall & mask) == mask) {   /* db (Sequenom) call is het */
		return(0);
	}
	else if(basecall & mask) {      /* hom mismatch */
		return(-1);
	}
	else if(mask & (mask-1) & floatcall) {  /* basecall is het, floatcall is hom2 */
		return(-3);
	}
	else {                                  /* basecall is het, floatcall is hom1 */
		return(-2);
	}
}

/*
read_hdr:
	First read header base, then remainder if there is any
*/
static int read_hdr(FILE *infd, GT_HDR *gt_hdr)
{
	if(fread(gt_hdr, sizeof(GT_HDR), 1, infd) != 1) {
		fprintf(stderr, "Failed to read base gt header\n");
		return(-1);
	}

	if(!strncmp(gt_hdr->hdr_base.ver, "01", 2)) {
		snprintf(gt_hdr->data_id, DATA_ID_LEN, "%-*s", DATA_ID_LEN, "GTHDRVER01");
		snprintf(gt_hdr->refresh_date, REFRESH_DATE_LEN, "%-*s", REFRESH_DATE_LEN, "00000000");
	}

	if(!valid_gt_hdr(gt_hdr)) {
		fprintf(stderr, "Invalid gt header (must be ver 02)\n");
		return(-2);
	}

	return(0);
}

static FILE *open_file(char *basename, char *extname)
{
	char *fn = NULL;
	char *sep = ".";
	int bsiz = 0;
	FILE *fd = NULL;

	bsiz = strlen(basename) + 1;
	if(extname != NULL) {
		bsiz += strlen(extname) + strlen(sep);
	}
	else {
		extname = "";
		sep = "";
	}
	if((fn=malloc(bsiz)) != NULL) {
		snprintf(fn, bsiz, "%s%s%s", basename, sep, extname);
		fd = fopen(fn, "r");
		free(fn);
	}

	return(fd);
}

static char *readSampleName(FILE *sfd, int sidx, char *buf, int bsiz )
{
	int i;

	if(sfd == NULL) {
		snprintf(buf, bsiz, "%s", "UNKNOWN");
		return(buf);
	}

	if((fseek(sfd, (sidx*bsiz), SEEK_SET)) || (fread(buf, bsiz, 1, sfd) != 1)) {
		snprintf(buf, bsiz, "SAMPLENAMEFETCHFAIL");
	}
	else {
		/* remove  newline and trailing spaces from sample names */
		for(i=bsiz-2; i>=0; i--) {
			if(!isspace(buf[i])) {
				buf[i+1] = '\0';
				break;
			}
		}
	}

	return(buf);
}

/*
hard-wired to allow two bits per call
*/
#define HMASK 0xF0
#define LMASK 0x0F
static int checkCallRate(char *rec, int callcount, int min_sample_callrate)
{
	int i;
	int called_count = 0;
	unsigned mask;
	int cc;

	mask = 0xC0;
	i=0;
	for(cc=0, called_count = 0; cc<callcount; cc++) {
		
		if(rec[i] & mask)
			called_count++;

		mask >>=2;
		if(mask == 0) {
			mask = 0xC0;
			i++;
		}
	}

	if(((called_count*100)/callcount) >= min_sample_callrate)
		return(1);
	else
		return(0);
}

static int print_start(int output_format)
{
	if(output_format == 1) {
		printf("{");
	}

	return(0);
}

static int print_comp_result_start(int output_format)
{
	if(output_format == 1) {
		printf(" \"comp_results\" : [ ");
	}

	return(0);
}

static int print_comp_result_end(int output_format)
{
	if(output_format == 1) {
		printf("  ]");
	}

	return(0);
}

static int print_end(int output_format, int status, char *status_ms)
{
	if(output_format == 1) {
		printf(", \"status\" : %d, \"status_ms\" : \"%s\" ", status, (status_ms!=NULL)? status_ms: "NO_MS");
		printf("}\n");
	}

	return(0);
}

static int print_params(int output_format, char *data_id, char *refresh_date, int callcount, int min_common, int min_sample_callrate, int high_concord_level, int posdup_level, int print_only_posdups, int only_check_same_names, int only_check_diff_names, char *lh1, char *l1, char *l2, char *base_gt)
{
	if(output_format == 0) {
		printf("Genotype data set: %s/%s\n", data_id, refresh_date);
		printf("Calls per sample: %d\n", callcount);
		printf("Min.Common SNPs: %d\n", min_common);
		printf("Min.Sample Callrate: %d\n", min_sample_callrate);
		printf("High Concordance Threshold: %d %%\n", high_concord_level);
		printf("Poss. Dup. Level: %d %%\n", posdup_level);
		printf("Only Print Poss. Dups: %c\n", print_only_posdups? 'Y': 'N');
		printf("Comparison sets: %s\n", (only_check_same_names? "Same names": (only_check_diff_names? "Different names": "All")));
		printf("Base gt: %s\n", reformat_gt(base_gt, callcount));
		printf("\n");

		printf("BaseSample\tMatchSample\tCommonCalls\tMatch\tMismatch\tConcordance\tRemark\n");	/* header line */
	}
	else if(output_format == 1) {
		printf(" \"genotype_data_set\" : \"%s/%s\",", data_id, refresh_date);
		printf(" \"sample_name\" : \"%s\",", l1);
		printf(" \"params\" : { ");
		printf("\"calls_per_sample\" : %d, ", callcount);
		printf("\"min_common_snps\" : %d, ", min_common);
		printf("\"min_sample_callrate\" : %d, ", min_sample_callrate);
		printf("\"high_concordance_threshold\" : %d, ", high_concord_level);
		printf("\"poss_dup_level\" : %d, ", posdup_level);
		printf("\"report_only_poss_dups\" : \"%c\", ", print_only_posdups? 'Y': 'N');
		printf("\"comparison_sets\" : \"%s\", ", (only_check_same_names? "Same names": (only_check_diff_names? "Different names": "All")));
		printf("\"base_gt\" : \"%s\"", reformat_gt(base_gt, callcount));
		printf(" },");
	}
	else {
		fprintf(stderr, "Unrecognised out_format: %d\n", output_format);
		exit(-99);
	}

	return(0);
}

static int print_comp_result(int output_format, char *desc, char *l1, char *l2, int commoncalls, int match, int mismatch, char *match_score_string, int callcount, char *matched_gt)
{
	static int seen_a_result = 0;
	int i;

	if(output_format == 0) {
		printf("%s\t%s\t%d\t%d\t%d\t%.3f\t", l1, l2, commoncalls, match, mismatch, (commoncalls > 0)? (float)match/(float)commoncalls : 0);
		printf("%s\n", desc);
	}
	else if(output_format == 1) {
		remove_tabs(desc);
		remove_tabs(l1);
		remove_tabs(l2);

		if(seen_a_result) {
			printf(",");
		}
		else {
			seen_a_result = 1;
		}
		printf("   { \"match_type\" : \"%s\", \"matched_sample_name\" : \"%s\", \"common_snp_count\" : %d, \"match_count\" : %d, \"mismatch_count\" : %d, \"match_pct\" : %01.3f", desc, l2, commoncalls, match, mismatch, (commoncalls > 0)? (float)match/(float)commoncalls : 0);
		if(match_score_string != NULL) {
			printf(", \"match_score\" : \"");
			for(i=0; i < callcount; i++) {
				if(i != 0)
					printf(";");
				printf("%d", (int)match_score_string[i]);
			}
			printf("\"");
		}

		if(matched_gt != NULL) {
			printf(", \"matched_gt\" : \"%s\"", reformat_gt(matched_gt, callcount));
		}

		printf(" }");
	}
	else {
		fprintf(stderr, "Unrecognised out_format: %d", output_format);
		exit(-99);
	}

	return(0);
}

static char *remove_tabs(char *s)
{
	char *p;

	for(p=s; *p; p++)
		if(*p == '\t')
			*p = ' ';

	return(s);
}

static int usage(void)
{
	fprintf(stderr, "Usage: find_gt_match [-m <min_common_SNPs>] [-c <high_concordance_level>] [-d <pos_dup_level> ] [-t <comparison_type>] [-s <min_sample_callrate>] [-r <reliable_read_depth>] [-n <sample_name>] [-p] [-j] [-x] <single_compressed_genotype_base> <compressed_genotypes_base>\n");

	return(0);
}

/*find_sample_index: try to ensure there is always a report on matching sample names */
static int find_sample_index(FILE *sfd, char *s1)
{
	int idx = -1;
	int len = 0;
	long pos = 0L;
	char buf[NAMESIZE+16];

	if(sfd != NULL && s1 != NULL && *s1) {
		len = strlen(s1);
		pos = ftell(sfd);
		fseek(sfd, 0L, SEEK_SET);
		for(idx=0, fgets(buf, NAMESIZE+16, sfd); !ferror(sfd) && !feof(sfd); idx++, fgets(buf, NAMESIZE+16, sfd)) {
			if(!strncmp(buf, s1, len) && isspace(buf[len]) ) {
				break;
			}
		}

		if(ferror(sfd) || feof(sfd) ) {
			idx = -1;
		}

		fseek(sfd, pos, SEEK_SET);
	}

	return(idx-1);	/* -1 to allow for the header row in the sample index file */
}

static int valid_gt_hdr(GT_HDR *hdr)
{
	if(!strncmp(hdr->hdr_base.magic, "GT", 2) && (hdr->hdr_base.ver[0] == '0')
		&& (
		((hdr->hdr_base.ver[1] == '1') && hdr->hdr_base.hdr_size == sizeof(struct _hdr_base))
			||
		((hdr->hdr_base.ver[1] == '2') && hdr->hdr_base.hdr_size == sizeof(*hdr))
		)) {
		return(1);	/* OK */
	}
	else {
		return(0);	/* Invalid */
	}
}

static struct _base_gt *get_base_gt(FILE *fd, int callcount, int dp_bits)
{
	struct _base_gt *ret;
	int gt_size;
	int n;

	if((ret=malloc(sizeof(struct _base_gt))) != NULL) {
		/* assumes 2 bits per call, 8 bits per char */
		gt_size = (callcount + 3)/4;

		if((ret->base_gt = calloc(gt_size, sizeof(char))) == NULL) {	/* buffer for compressed results */
			fprintf(stderr, "Failed to malloc baserec buffer of size %d\n", gt_size);
			exit(-6);
		}

		if(dp_bits == 0) {	/* no depth info for the calls */
			if((n=fread(ret->base_gt, 1, gt_size, fd)) != gt_size) {
				fprintf(stderr, "Failed to read gt rec (tried %d, got %d)\n", gt_size, n);
				exit(-99);
			}
			ret->depths = ret->never_match = NULL;
		}
		else {	/* extract depth information and pack genotype data */
			unsigned char *tmpbuf = NULL;
			int i, j;
			char callCode;
			int offset;

			if((ret->depths=calloc(callcount, sizeof(char))) == NULL) {
				free(ret);
				return(NULL);
			}
			if((ret->never_match=calloc(callcount, sizeof(char))) == NULL) {
				free(ret->depths);
				free(ret);
				return(NULL);
			}
			if((tmpbuf=calloc(callcount, sizeof(unsigned char))) == NULL) {
				free(ret->never_match);
				free(ret->depths);
				free(ret);
				return(NULL);
			}
			if((n=fread(tmpbuf, 1, callcount, fd)) != callcount) {
				fprintf(stderr, "Failed to read gt rec (tried %d, got %d)\n", callcount, n);
				exit(-99);
			}

			offset = 0;
			j=0;	/* index for ret->base_gt */
			for(i=0; i<callcount; i++) {
				ret->depths[i] = (tmpbuf[i] >> 2);
				ret->never_match[i] = (ret->depths[i] == 0x3f)? 1 : 0;	/* depth of 0x3f (63) is a reserved value indicating "never match" */
				callCode = (tmpbuf[i] & 3);
				ret->base_gt[j] |= (callCode << (6-offset));
				if(offset == 6) { /* char full */
					j++;
				}
				offset = (offset + 2) % 8;      /* 0, 2, 4, 6 */
			}

			free(tmpbuf);
		}
			
	}

	return(ret);
}

/*
reformat_gt:

Return a null-terminated string containing the ASCII equivalent for the call codes in
the packed genotype string pointed to by gt.

              byte1    byte2        string
For example: 10011100 11000011 => "21303003"

The contents of the buffer allocated by this function will not survive between calls,
and the returned pointer should not be freed by the caller.
*/
static char *reformat_gt(char *gt, int callcount)
{
	int gti;
	int cc;
	unsigned shift;
	static char *retbuf = NULL;
	static int retbuf_size = 0;

	if(callcount > retbuf_size-1) {

		retbuf_size = callcount+1;

		if(retbuf != NULL) {
			free(retbuf);
		}

		if((retbuf=realloc(retbuf, retbuf_size)) == NULL) {
			retbuf_size = 0;
			return(NULL);
		}

		memset(retbuf, 0, retbuf_size);
	}

	shift = 8;
	gti=0;
	for(cc=0; cc<callcount; cc++) {
		/* expand 2 bit encoded calls */

		shift -= 2;
		retbuf[cc] = (char)((gt[gti] >> shift) & 3) + '0';

		if(shift == 0) {
			shift = 8;
			gti++;
		}
	}

	return(retbuf);
}

