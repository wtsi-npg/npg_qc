/* Author:        Kevin Lewis
 * Created:       2012-04-16
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <time.h>

#include "gt_pack.h"
#include "intvec.h"
#include "fld_desc.h"

#define BSIZ 1024
#define NAMESIZE 128
#define SNPNAMESIZE 33
#define VECSTAT_OK 0
#define VECSTAT_LASTELEM 1
#define VECSTAT_BADFETCH 2
#define STRICT_FORMAT 0
#define MAX_ALLELE_NUM 2
#define GT_CALLS_ONLY 0 
#define GT_CALLS_INCLUDE_READ_DEPTH 1 

struct _fld_arr {
	int fldcnt;
	char **flds;
};

static FILE *open_outfile(char *basename, char *ext, char *write_mode);
static GT_HDR *init_hdr(GT_HDR *hdr, int genotype_fld_count, int bits_per_call, int read_depth_bits, char *data_id);
static int cmp_hdr(GT_HDR *new_hdr, GT_HDR *check_hdr);
static struct _fld_desc *read_header(char *inbuf, int bsiz, FILE *infd, char *sample_id_fields, char *sample_label_fields, char *ignore_fields, PAL *preload_alleles_list);
static struct _fld_arr *new_fld_arr(struct _fld_desc *fld_desc);
static struct _fld_arr *parse_rec(char *inbuf, struct _fld_arr *fld_arr);
static char *retail(char *buf);
static unsigned char encodeCall(char *call, int fldno, struct _assay_alleles *alleles_arr, int call_format, unsigned high_read_depth_threshold);
static int find_allele(char call, int fldno, struct _assay_alleles *alleles_arr);
static char *fetchSampleName(struct _fld_arr *fld_arr, struct _int_vec *sample_id_fields, char *buf, int bsiz);
static int usage(int full);

/* global section */
struct _global_env {
	int verbosity;
	unsigned high_read_depth_threshold;
	unsigned read_depth_bits;	/* ?? */
	int call_format;
} global_env = { 0, 10, 6, GT_CALLS_ONLY };

int main(int ac, char **av)
{
	FILE *infd=NULL, *outfd=NULL, *idxfd=NULL, *lidxfd=NULL, *snpidxfd=NULL;
	char inbuf[BSIZ];
	char sample_id_buf[NAMESIZE];
	char *outbase = NULL;
	char *call;
	unsigned char callCode, outCh;
	int line = 0;
	int i;
	char *write_mode = "w";
	int produce_aux_files = 1;
	GT_HDR hdr;
	struct _fld_desc *fld_desc = NULL;
	struct _fld_arr *fld_arr = NULL;
	char *sample_id_field_list = "1";
	char *sample_label_field_list = NULL;
	char *ignore_field_list = NULL;
	static char *data_id = "SQNMGTDATA";

	PAL preload_alleles_list = { PAL_EMPTY, NULL, NULL, NULL, NULL };
	int offset;

	/*** process flags ***/
	i=1;
	while(i < ac) {
		if(!strcmp(av[i], "-o")) {
			if((ac-i) > 0) {
				outbase = av[i+1];
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -o specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-s")) {	/* sample ID field(s) */
			if((ac-i) > 0) {
				sample_id_field_list = av[i+1];
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -s specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-l")) {	/* sample label field(s) */
			if((ac-i) > 0) {
				sample_label_field_list = av[i+1];
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -l specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-i")) {	/* ignore field(s) */
			if((ac-i) > 0) {
				ignore_field_list = av[i+1];
				i += 2;
			}
			else {
				fprintf(stderr, "Flag -i specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-p")) {	/* preload alleles for assays from string */
			if((ac-i) > 0) {
				preload_alleles_list.type |= PAL_STRING_TYPE;
				preload_alleles_list.source_string = preload_alleles_list.next_elem = av[i+1];
				preload_alleles_list.sne = NULL;

				i += 2;
			}
			else {
				fprintf(stderr, "Flag -p specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-P")) {	/* preload alleles for assays from file */
			if((ac-i) > 0) {
				preload_alleles_list.type |= PAL_FILE_TYPE;
				if((preload_alleles_list.fd=fopen(av[i+1], "r")) == NULL) {
					fprintf(stderr, "Failed to open snp alleles file (-P) %s for input\n", av[i+1]);
					exit(-99);
				}

				i += 2;
			}
			else {
				fprintf(stderr, "Flag -a specified without argument\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strncmp(av[i], "-v", 2)) {	/* verbosity level */
			char *p;

			if(*(av[i]+2)) {
				p = av[i]+2;
				i++;
			}
			else {
				if((ac-i) <= 0) {
					fprintf(stderr, "Flag -v specified without argument\n");
					usage(0);
					exit(-99);
				}

				p = av[i+1];
				i+=2;
			}
			global_env.verbosity = atoi(p);
			if(global_env.verbosity < 0)
				global_env.verbosity = 0;
		}
		else if(!strcmp(av[i], "-h")) {
			usage(1);
			exit(0);
		}
		else if(!strcmp(av[i], "-a")) {
			write_mode = "a+";	/* append/read mode - read for initial compatibility check */
			i++;
		}
		else if(!strcmp(av[i], "-n")) {
			produce_aux_files = 0;	/* */
			i++;
		}
		else if(!strncmp(av[i], "-d", 2)) {
                        char *p;

                        if(*(av[i]+2)) {
                                p = av[i]+2;
                                i++;
                        }
                        else {
                                if((ac-i) <= 0) {
                                        fprintf(stderr, "Flag -d specified without argument\n");
                                        usage(0);
                                        exit(-99);
                                }

                                p = av[i+1];
                                i+=2;
                        }
                        global_env.high_read_depth_threshold = atoi(p);
			if(global_env.high_read_depth_threshold != 0) {
				if(global_env.high_read_depth_threshold < 0) {
					global_env.high_read_depth_threshold = 0;
				}
				else if(global_env.high_read_depth_threshold > 62) {
					/* 63 is currently a reserved value indicating "never match". This was
						chosen since it's the highest value you can store in 6 bits,
						the current maximum width allocated for read depth. */
					global_env.high_read_depth_threshold = 62;
				}

#if NEW_DEPTH_THRESHOLD_CALC	/* correct calculation, not yet used */
				unsigned mask;
				for(mask = 32, global_env.read_depth_bits=6; mask; mask>>=1, global_env.read_depth_bits--) {
					if(global_env.high_read_depth_threshold & mask)
						break;
				} 
#else
				global_env.read_depth_bits=6;	/* for the moment either 0 or 6 bits */
#endif
			} 
		}
		else if(!strncmp(av[i], "-f", 2)) {
                        char *p;

                        if(*(av[i]+2)) {
                                p = av[i]+2;
                                i++;
                        }
                        else {
                                if((ac-i) <= 0) {
                                        fprintf(stderr, "Flag -f specified without argument\n");
                                        usage(0);
                                        exit(-99);
                                }

                                p = av[i+1];
                                i+=2;
                        }
                        global_env.call_format = atoi(p);
                        if(global_env.call_format < 0 || global_env.call_format > 1) {
				fprintf(stderr, "Flag -f  error: format must be 0 or 1\n");
				usage(0);
				exit(-99);
			}
		}
		else if(!strcmp(av[i], "-H")) {	/* specify data set label for header */
                        char *p;

			if(*(av[i]+2)) {
				p = av[i]+2;
				i++;
			}
			else {
				if((ac-i) <= 0) {
					fprintf(stderr, "Flag -H specified without argument\n");
					usage(0);
					exit(-99);
				}

				p = av[i+1];
				i+=2;
			}

			data_id = p;
		}
		else {
			break;
		}
	}

	if(global_env.call_format == GT_CALLS_ONLY) {	/* no depth data, so zero bits */
		global_env.read_depth_bits=0;
	}

	if(outbase == NULL) {
		fprintf(stderr, "Output file base must be specified\n");
		usage(0);
		exit(-98);
	}
	else if(!strcmp(outbase, "-")) {
		produce_aux_files = 0;
	}

	/*** open input file ***/
	if(i < ac) {
		if(!strcmp(av[i], "-")) {
			infd = stdin;
		}
		else if((infd=fopen(av[i], "r")) == NULL) {
			fprintf(stderr, "Failed to open %s for input\n", av[i]);
			exit(-2);
		}
	}
	else {
		infd = stdin;
	}

	/*** open output files ***/
	if(produce_aux_files && (idxfd = open_outfile(outbase, "six", write_mode)) == NULL) {
		fprintf(stderr, "Failed to open sample index file %s.%s for output\n", outbase, "six");
		exit(-97);
	}
	lidxfd = NULL;
	if(sample_label_field_list != NULL) {
		if(produce_aux_files && (lidxfd = open_outfile(outbase, "slx", write_mode)) == NULL) {
			fprintf(stderr, "Failed to open sample index file %s.%s for output\n", outbase, "slx");
			exit(-97);
		}
	}
	if(produce_aux_files && (snpidxfd = open_outfile(outbase, "aix", write_mode)) == NULL) {	/* aix for "assay index" */
		fprintf(stderr, "Failed to open snp/assay index file %s.%s for output\n", outbase, "aix");
		exit(-97);
	}
	if((outfd = open_outfile(outbase, "bin", write_mode)) == NULL) {
		fprintf(stderr, "Failed to open binary output file %s.%s for output\n", outbase, "bin");
		exit(-96);
	}

	/*** process input ***/

	/* derive parameters from flag values and header line */
	if(((fld_desc=read_header(inbuf, BSIZ, infd, sample_id_field_list, sample_label_field_list, ignore_field_list, &preload_alleles_list)) == NULL) || (fld_desc->fldcnt < 0)) {
		fprintf(stderr, "Error reading header line\n");
		exit(-95);
	}
	init_hdr(&hdr, fld_desc->genotype_fld_count, 2,  global_env.read_depth_bits, data_id);
	if(!strcmp(write_mode, "w")) {	/* default - create new output files from scratch */
		if(fwrite(&hdr, sizeof(hdr), 1, outfd) != 1) {
			fprintf(stderr, "Failed to write header\n");
			exit(-94);
		}
	}
	else {
		/* check compatibility of new data with existing header */
		/* This should use the new fields in GT_HDR */
		GT_HDR check_hdr;
		fseek(outfd, SEEK_SET, 0L);
		if(fread(&check_hdr, sizeof(check_hdr), 1, outfd) != 1) {
			fprintf(stderr, "Failed to read header for compatibility check\n");
			exit(-94);
		}
		if(cmp_hdr(&hdr, &check_hdr)) {
			fprintf(stderr, "Header incompatible (call count mismatch?)\n");
			exit(-99);
		}
		fseek(outfd, SEEK_END, 0L);
	}

	/* create structure used when parsing tab-delimited input row with parse_rec() */
	if((fld_arr=new_fld_arr(fld_desc)) == NULL) {
		fprintf(stderr, "Failed to allocate memory for fld_arr\n");
		exit(-88);
	}

	/* Write out header lines for sample index and sample label files */
	fld_arr = parse_rec(inbuf, fld_arr);
	if(produce_aux_files) {
		if(fld_desc->sample_label_fields != NULL) {
			fetchSampleName(fld_arr, fld_desc->sample_label_fields, sample_id_buf, NAMESIZE);
			fprintf(lidxfd, "%-*.*s\n", (NAMESIZE-1), (NAMESIZE-1), sample_id_buf);
		}
		fetchSampleName(fld_arr, fld_desc->sample_id_fields, sample_id_buf, NAMESIZE);
		fprintf(idxfd, "%-*.*s\n", (NAMESIZE-1), (NAMESIZE-1), sample_id_buf);
	}

	/* write sample index file and pack genotype data */
	for(line=2, fgets(inbuf, BSIZ, infd); !ferror(infd) && !feof(infd); line++, fgets(inbuf, BSIZ, infd)) {
		if(retail(inbuf) == NULL)  {
			fprintf(stderr, "Failed to amend inbuf terminator\n");
			exit(-99);
		}

		fld_arr = parse_rec(inbuf, fld_arr);

		if(fld_desc->sample_label_fields != NULL) {
			fetchSampleName(fld_arr, fld_desc->sample_label_fields, sample_id_buf, NAMESIZE);
			if(!strncasecmp(sample_id_buf, "EMPTY\t", 6))
				continue;
			if(produce_aux_files)
				fprintf(lidxfd, "%-*.*s\n", (NAMESIZE-1), (NAMESIZE-1), sample_id_buf);
		}
		fetchSampleName(fld_arr, fld_desc->sample_id_fields, sample_id_buf, NAMESIZE);
		if(fld_desc->sample_label_fields == NULL && !strncasecmp(sample_id_buf, "EMPTY\t", 6))
			continue;
		if(produce_aux_files)
			fprintf(idxfd, "%-*.*s\n", (NAMESIZE-1), (NAMESIZE-1), sample_id_buf);

		outCh = 0;
		offset = 0;
		for(i=0; fld_desc->fld_types[i].type && i<=fld_desc->fldcnt; i++) {
			switch(fld_desc->fld_types[i].type) {
				case 'G':	/* genotype call field */
					if((call = fld_arr->flds[i]) != NULL)
						callCode = encodeCall(call, i, fld_desc->assay_alleles, global_env.call_format, global_env.high_read_depth_threshold);
					else
						callCode = '\0';	/* NN */

					if(global_env.call_format == GT_CALLS_INCLUDE_READ_DEPTH) {	/* already packed into byte-sized pieces */
						if(fwrite(&callCode, sizeof(callCode), 1, outfd) != 1) {
							fprintf(stderr, "Write fails on call write\n");
							exit(-91);
						}
					}
					else {	/* pack */
						outCh |= (callCode << (6-offset));
						if(offset == 6) { /* char full */
							if(fwrite(&outCh, sizeof(outCh), 1, outfd) != 1) {
								fprintf(stderr, "Write fails on call write\n");
								exit(-91);
							}
							outCh = 0;
						}
						offset = (offset + 2) % 8;	/* 0, 2, 4, 6 */
					}
					break;

				case 'S':	/* sample ID field */
				case 'L':	/* sample label field */
				case 'I':	/* ignore field */
					break;

				default:
					fprintf(stderr, "Unrecognised fld_type %c for field %d\n", fld_desc->fld_types[i].type, i);
					exit(-89);
			}
		}

		if((global_env.read_depth_bits == 0) && (offset != 0)) { /* flush any remaining data */
			if(fwrite(&outCh, sizeof(outCh), 1, outfd) != 1) {
				fprintf(stderr, "Write fails on call write\n");
				exit(-91);
			}
		}
	}

	/* Write out assay/snp name index file */
	if(produce_aux_files) {
		for(i=0; i<fld_desc->fldcnt; i++) {
			if(fld_desc->fld_types[i].type == 'G') {
				fprintf(snpidxfd, "%-*.*s%c%c\n", (SNPNAMESIZE-3), (SNPNAMESIZE-3), fld_desc->fld_types[i].si->name, fld_desc->assay_alleles[i].alleles[0], (fld_desc->assay_alleles[i].alleles[1])? fld_desc->assay_alleles[i].alleles[1]: fld_desc->assay_alleles[i].alleles[0] );
			}
		}
		fclose(snpidxfd);

		fclose(idxfd);
	}


	fclose(infd);
	fclose(outfd);

	return(0);
}

static char *fetchSampleName(struct _fld_arr *fld_arr, struct _int_vec *sample_id_fields, char *buf, int bsiz)
{
	int fldidx = 0, bufidx = 0;
	char *p;

	for(fldidx=intVecFirstElem(sample_id_fields); sample_id_fields->status == VECSTAT_OK; fldidx=intVecNextElem(sample_id_fields)) {
		if(bufidx > 0 && bufidx < bsiz)
			buf[bufidx++] = '\t';
		for(p=fld_arr->flds[fldidx]; p && *p && *p != '\t'; p++)
			if(bufidx < bsiz)
				buf[bufidx++] = *p;
	}
	buf[bufidx] = '\0';

	return(buf);
}

static FILE *open_outfile(char *basename, char *ext, char *write_mode)
{
	char *fn = NULL;
	int blen = 0;
	FILE *retfd = NULL;

	if(!strcmp(basename, "-")) {
		return(stdout);
	}

	blen = strlen(basename)+5;
	if((fn=malloc(blen)) == NULL) {
		return(NULL);
	}

	snprintf(fn, blen, "%s.%s", basename, ext);
	if((retfd=fopen(fn, write_mode)) == NULL) {
		free(fn);
		return(NULL);
	}

	free(fn);

	return(retfd);
}

/*
read_header:
Aside from removing a trailing newline, inbuf should not be modified
*/
static struct _fld_desc *read_header(char *inbuf, int bsiz, FILE *infd, char *sample_id_fields, char *sample_label_fields, char *ignore_fields, PAL *preload_alleles_list)
{
	if(fgets(inbuf, bsiz, infd) == NULL) {
		perror("Reading header");
		exit(-89);
	}

	if(retail(inbuf) == NULL)
		return(NULL);

	return(new_fld_desc(inbuf, sample_id_fields, sample_label_fields, ignore_fields, preload_alleles_list));

}

static struct _fld_arr *new_fld_arr(struct _fld_desc *fld_desc)
{
	struct _fld_arr *ret = NULL;

	if((ret=malloc(sizeof(struct _fld_arr))) != NULL) {
		if((ret->flds = malloc(sizeof(unsigned char *) * fld_desc->fldcnt)) == NULL) {
			free(ret);
			return(NULL);
		}

		ret->fldcnt = fld_desc->fldcnt;
		memset(ret->flds, 0, sizeof(char *) * fld_desc->fldcnt);
	}

	return(ret);
}

/*
parse_rec:
modifies inbuf (tabs converted to '\0')
*/
static struct _fld_arr *parse_rec(char *inbuf, struct _fld_arr *fld_arr)
{
	int i = 0;
	char *p, *v;

	if(fld_arr != NULL && inbuf != NULL) {
		for(p=v=inbuf; *p && i<fld_arr->fldcnt; p++) {
			if(*p=='\t') {
				*p = '\0';
				fld_arr->flds[i++] = v;
				v=p+1;
			}
		}
		if(i<fld_arr->fldcnt)
			fld_arr->flds[i++] = v;
	}

	return(fld_arr);
}

static char *retail(char *buf)
{
	int len;

	if(((len=strlen(buf)) != 0) && (buf[len-1] == '\n')) {
		buf[len-1] = '\0';
		return(buf);
	}
	else {
		return(NULL);
	}
}

/*
encodeCall:
	Return 8 bit value, where top 6 bits are read depth (if specified), and
	lower 2 bits are the encoded call.  These SNPs should always be biallelic,
	so 2 bits is enough.
		00 - NN
		01 - Homozyogous allele_1
		10 - Homozyogous allele_2
		11 - Heterozygous

	A special case of "don't match anything" can be indicated when the call_format
	is GT_CALLS_INCLUDE_READ_DEPTH. The read depth is set to 0x3F (63), and the call
	data should be ignored. This can be used when an unacceptable allele is given
	for a SNP. ?? It can also be indicated in the input data by explicitly setting read
	depth for a call to 63.
*/
static unsigned char encodeCall(char *call, int fldno, struct _assay_alleles *alleles_arr, int call_format, unsigned high_read_depth_threshold)
{
	unsigned char retCode = '\0'; 
	unsigned char callCode = '\0'; 
	int match;
	int read_depth = 0;
	char *p;

	if(call == NULL || *call == 'D' || *call == 'N') {
		return(0);
	}

	if(call_format == GT_CALLS_INCLUDE_READ_DEPTH) {
		p=strchr(call, ':');
		if(p == NULL) {
			fprintf(stderr, "Fatal error: call format %d should include read depth, but no \':\' delimiter found\n", call_format);
			exit(-99);
		}

		read_depth=atoi(++p);
		if(read_depth < 0) {
			read_depth = 0;
		}
		else if(read_depth > high_read_depth_threshold) {
			read_depth = high_read_depth_threshold;
		}

	}

	retCode = (unsigned char)(read_depth << 2);	/* top 6 bits used for read depth */
	/* attempt to use read-depth to flag call information */
	if((match = find_allele(call[0], fldno, alleles_arr)) < 0) {
		if(call_format == GT_CALLS_INCLUDE_READ_DEPTH) {
			return(0x3f << 2);	/* unacceptable allele for SNP seen - return with a read depth of 0x3F (63) */
		}
		else {
			fprintf(stderr, "Found allele %c for assay %d (%s), already have alleles %c/%c\n", call[0], fldno, "ASSAYNAME", alleles_arr[fldno].alleles[0], alleles_arr[fldno].alleles[1]);
			exit(-99);
		}
	}

	callCode |= match;

	if(strlen(call) > 1) {
		/* attempt to use read-depth to flag call information */
		if((match = find_allele(call[1], fldno, alleles_arr)) < 0) {
			if(call_format == GT_CALLS_INCLUDE_READ_DEPTH) {
				return(0x3f << 2);	/* unacceptable allele for SNP seen - return with a read depth of 0x3F (63) */
			}
			else {
				fprintf(stderr, "Found allele %c for assay %d (%s), already have alleles %c/%c\n", call[1], fldno, "ASSAYNAME", alleles_arr[fldno].alleles[0], alleles_arr[fldno].alleles[1]);
				exit(-99);
			}
		}
	}

	callCode |= (match << 1);

	switch(callCode) {
		/* HomA */
		case 0:
			callCode = 1;	/* 01 */
			break;
		/* Het */
		case 1:
		case 2:
			callCode = 3;	/* 11 */
			break;
		/* HomB */
		case 3:
			/* no change */
			callCode = 2;	/* 10 */
			break;
		default:
			fprintf(stderr, "Unrecognised call %s in encodeCall()\n", call);
			break;
	}

	retCode |= callCode;

	return(retCode);
}

/*
find_allele:
Looks in alleles cache for this SNP. If found, return index for that allele. Otherwise, if the alleles
cache isn't already full (how many alleles are allowed is determined by MAX_ALLELE_NUM), add it and
return the new index. If the alleles cache is full, return -1. A full cache occurs when, for example,
a third allele is seen for a biallelic SNP.
*/
static int find_allele(char call, int fldno, struct _assay_alleles *alleles_arr)
{
	int match, allele_num;

	match = -1;
	for(allele_num=0; allele_num<alleles_arr[fldno].last_allele; allele_num++) {
		if(call == alleles_arr[fldno].alleles[allele_num]) {
			match = allele_num;
			break;
		}
	}

	if(match < 0) {	/* allele not previously seen */
		if(alleles_arr[fldno].last_allele < MAX_ALLELE_NUM) { /* OK to add, we haven't yet seen two alleles */
			match = alleles_arr[fldno].last_allele++;
			alleles_arr[fldno].alleles[match] = call;
		}
	}

	return(match);
}

static GT_HDR *init_hdr(GT_HDR *hdr, int genotype_fld_count, int bits_per_call, int read_depth_bits, char *data_id)
{
	time_t t;
	struct tm *tm;

	memcpy(hdr->hdr_base.magic, "GT", 2);
	memcpy(hdr->hdr_base.ver, "02", 2);
	hdr->hdr_base.hdr_size = sizeof(*hdr);
	hdr->hdr_base.callcount = genotype_fld_count;
        hdr->hdr_base.gt_bits = bits_per_call;
        hdr->hdr_base.dp_bits = read_depth_bits;
	if(hdr->hdr_base.dp_bits != 0) {
		hdr->hdr_base.dp_bits = 6;	/* temporarily fixed at 6 */
	}

	snprintf(hdr->data_id, DATA_ID_LEN, "%s", data_id);

	t=time(NULL);
	tm=localtime(&t);
	snprintf(hdr->refresh_date, REFRESH_DATE_LEN, "%04d%02d%02d%02d%02d%02d",
					tm->tm_year+1900,
					tm->tm_mon+1,
					tm->tm_mday,
					tm->tm_hour,
					tm->tm_min,
					tm->tm_sec);

	return(hdr);
}

static int cmp_hdr(GT_HDR *new_hdr, GT_HDR *check_hdr)
{
	if(strncmp(check_hdr->hdr_base.magic, "GT", 2)
		|| strncmp(check_hdr->hdr_base.ver, "01", 2)
		|| (new_hdr->hdr_base.callcount != check_hdr->hdr_base.callcount)
		|| (new_hdr->hdr_base.gt_bits != check_hdr->hdr_base.gt_bits)
		|| (new_hdr->hdr_base.dp_bits != check_hdr->hdr_base.dp_bits))  {
		return(1);
	}

	return(0);
}

static int usage(int full) {
	if(full) {
		fprintf(stderr, "gt_pack: pack a tab-delimited text file containing genotype data into a binary format\n\n");
	}
	fprintf(stderr, "Usage: gt_pack -o <outfile_base> [-s <sample_id_fields>] [-l <sample_label_fields>] [-i <ignore_fields>] [-p <preload_assays_spec>] [-P <preload_assays_file>] [-d <high_read_depth_threshold>] [-w <call_width>][-f <format>] [-a] [-n] [-H <data_set_label>] [-h] [<input_file>]\n");
	if(full) {
		fprintf(stderr, "\toutfile_base: base for file name(s) to which relevant extension is added. If this is '-', stdout is used for the compressed calls (.bin) file and no auxiliary files are produced\n");
		fprintf(stderr, "\tsample_id_fields: fields which provide a unique ID for the sample\n");
		fprintf(stderr, "\tsample_label_fields: fields which provide the sample name used in output (default: sample_id_fields)\n");
		fprintf(stderr, "\tignore_fields: fields whose contents should be ignored\n");
		fprintf(stderr, "\tpreload_assays_spec: specifies order of alleles (alleleA,alleleB) for a SNP. If unspecified, will be derived from input data. Overrides any conflicts with <preload_assays_file> specifications\n");
		fprintf(stderr, "\tpreload_assays_file: file containing specification of order of alleles (alleleA,alleleB) for a SNP.\n");
		fprintf(stderr, "\thigh_read_depth_threshold: Ceiling for read depths - used to calculate bits to use for encoding read depth data (default: 0)\n");
		fprintf(stderr, "\tcall_width: Number of bits used to encode calls (minimum and default: 2)\n");
		fprintf(stderr, "\tformat: format of genotype calls - 0: biallelic call only (e.g. AG), 1: read depth also specified (e.g. AG:7); (default: 0)\n");
		fprintf(stderr, "\t-a: append data to existing file (default: create new file(s)\n");
		fprintf(stderr, "\t-n: no auxiliary files; only create the compressed calls (.bin) file\n");
		fprintf(stderr, "\t-H: specify data set label for header\n");
		fprintf(stderr, "\t-h: this message\n");
	}

	return(0);
}

