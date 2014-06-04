/* Author:        Kevin Lewis
 * Created:       2012-04-16
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "intvec.h"
#include "fld_desc.h"

#ifndef __INC_FLD_DESC__
/* These are just here for reference - see header for actual definitions */

struct _snp_info {
	char *name;
	char *alleles[16];
	int allele_count[16];
	int top_aidx;
};

struct _fld_type_si {
	char type;
	struct _snp_info *si;	/* NULL unless type is 'G' */
};

struct _assay_alleles {
	char call; /*?*/
	char alleles[2];
	int last_allele;
};

struct _fld_desc {
	int fldcnt;
	struct _fld_type_si *fld_types;
	int genotype_fld_count;
	struct _int_vec *sample_id_fields;
	struct _int_vec *sample_label_fields;
	struct _assay_alleles *assay_alleles;
};

struct _node {
	struct _node *prev;
	char *val;
};
#endif

#define BSIZ 128

struct _allele_item {
	char *snp_name;
	char *alleles;
};

static int preload_alleles(PAL *preload_alleles_source, struct _assay_alleles *alleles_arr, struct _fld_desc *fld_desc);
static struct _allele_item *get_allele_item(PAL *pal);

static struct _node *new_node(struct _node *tail_node, char *val);
static struct _node *del_node(struct _node *node);

/*
new_fld_desc:
parse inbuf and use parameter string to set up _fld_desc struct
*/
struct _fld_desc *new_fld_desc(char *inbuf, char *sample_id_fields, char *sample_label_fields, char *ignore_fields, PAL *preload_alleles_list)
{
	struct _fld_desc *ret = NULL;
	int fldcount = 1;
	char *p, *q;
	int i;
	struct _node *tail_node = NULL;

	/* count number of fields and copy column header name to linked list */
	for(p=q=inbuf; *q; q++) {
		if(*q == '\t') {
			*q = '\0';
			if((tail_node=new_node(tail_node, p)) == NULL) {
				fprintf(stderr, "Failed to create link in field list\n");
				exit(-99);
			}
			*q = '\t';	/* restore inbuf */
			p=q+1;
			
			fldcount++;
		}
	}
	/* add last field name to list */
	if((tail_node=new_node(tail_node, p)) == NULL) {
		fprintf(stderr, "Failed to create link in field list\n");
		exit(-99);
	}

	if((ret=malloc(sizeof(struct _fld_desc))) != NULL) {
		if((ret->fld_types=malloc(sizeof(struct _fld_type_si) * fldcount)) == NULL) {
			free(ret);
			return(NULL);
		}
		memset(ret->fld_types, 0, sizeof(struct _fld_type_si) * fldcount);
		ret->fldcnt = fldcount;
		for(p=ignore_fields; p && *p; ) {	/* flag any fields to ignore */
			int i;

			i=atoi(p);
			i--;
			if(i>=0 && i<ret->fldcnt) {
				ret->fld_types[i].type = 'I';
				ret->fld_types[i].si = NULL;	/* handled by the memset above, but...? */
			}
			for( ; *p && isdigit(*p); p++)
				;
			if(*p)
				p++;
		}
		ret->sample_id_fields = newIntVec(8);
		for(p=sample_id_fields; p && *p; ) {	/* flag the fields to be used to ID the sample */
			int i;

			i=atoi(p);
			i--;
			if(i>=0 && i<ret->fldcnt) {
				ret->fld_types[i].type = 'S';
				ret->fld_types[i].si = NULL;  /* handled by the memset above, but...? */
				intVecAppend(ret->sample_id_fields, i);
			}
			for( ; *p && isdigit(*p); p++)
				;
			if(*p)
				p++;
		}

		if(sample_label_fields != NULL) {
			ret->sample_label_fields = newIntVec(8);
			for(p=sample_label_fields; p && *p; ) {	/* flag the fields to be used to ID the sample */
				int i;

				i=atoi(p);
				i--;
				if(i>=0 && i<ret->fldcnt) {
					if(ret->fld_types[i].type != 'S') {
						ret->fld_types[i].type = 'L';
						ret->fld_types[i].si = NULL;  /* handled by the memset above, but...? */
					}
					intVecAppend(ret->sample_label_fields, i);
				}
				for( ; *p && isdigit(*p); p++)
					;
				if(*p)
					p++;
			}
		}
		else {
			ret->sample_label_fields = NULL;
		}

		ret->genotype_fld_count = 0;
		for(i=ret->fldcnt-1; i>= 0; i--) { /* work backwards because that's the direction of the linked list */
			if(ret->fld_types[i].type == '\0') {
				ret->fld_types[i].type = 'G';
				ret->genotype_fld_count++;
				if((ret->fld_types[i].si=calloc(1, sizeof(struct _snp_info))) == NULL) {
					/* malloc failure, crash and burn */
					fprintf(stderr, "Malloc fails while processing header\n");
					exit(-90);
				}

				ret->fld_types[i].si->name = tail_node->val;	/* keep SNP name for index file */
				tail_node->val = NULL;	/* avoid free in del_node() */
			}

			tail_node = del_node(tail_node);
		}
	}

	/* set up alleles array - lazy assumption that most input fields are genotype calls */
	if((ret->assay_alleles = calloc(ret->fldcnt, sizeof(struct _assay_alleles))) == NULL) {
		fprintf(stderr, "Failed to create alleles array\n");
		exit(-99);
	}

	/* pre-set allele order if specified by -a flag - otherwise it's determined by the genotype data */
	if(preload_alleles_list->type != PAL_EMPTY) {
		preload_alleles(preload_alleles_list, ret->assay_alleles, ret);
	}

	return(ret);
}

static struct _node *new_node(struct _node *tail_node, char *val)
{
	struct _node *ret = NULL;

	if((ret=calloc(1, sizeof(struct _node))) != NULL) {
		ret->prev = tail_node;

		if((ret->val=strdup(val)) == NULL) {
			free(ret);
			return(NULL);
		}
	}

	return(ret);
}

static struct _node *del_node(struct _node *node)
{
	struct _node *ret = NULL;

	if(node != NULL) {
		ret = node->prev;

		if(node->val != NULL) {
			free(node->val);
		}

		free(node);
	}

	return(ret);
}

static int preload_alleles(PAL *preload_alleles_source, struct _assay_alleles *alleles_arr, struct _fld_desc *fld_desc)
{
	struct _allele_item *allele_item;
	int fldno;

	for(allele_item = get_allele_item(preload_alleles_source); allele_item != NULL; allele_item = get_allele_item(preload_alleles_source)) {
		for(fldno=0; fldno<=fld_desc->fldcnt; fldno++) {
			if(fld_desc->fld_types[fldno].type != 'G') {	/* only check genotype fields */
				continue;
			}
			if(fld_desc->fld_types[fldno].si->name != NULL
				&& !strcmp(fld_desc->fld_types[fldno].si->name, allele_item->snp_name)) {
				memcpy(alleles_arr[fldno].alleles, allele_item->alleles, 2);
				alleles_arr[fldno].last_allele = 2;
			}
		}
	}

	return(0);
}

static struct _allele_item *get_allele_item(PAL *pal)
{
	static struct _allele_item ai;
	static char inbuf[BSIZ];
	char *p;

	if(pal->type & PAL_STRING_TYPE) {
		if(pal->next_elem == NULL || *(pal->next_elem) == '\0') {
			pal->type &= ~PAL_STRING_TYPE;	/* finished with string */
			return(NULL);
		}
		ai.snp_name = pal->next_elem;
		pal->next_elem=index(pal->next_elem, ',');
		if(pal->next_elem == NULL) {
			pal->next_elem = ai.snp_name + strlen(ai.snp_name);	/* this must be the last element in the string */
		}
		if(pal->sne != NULL)
			*(pal->sne) = ':';	/* restore allele source string */
		pal->sne=index(ai.snp_name, ':');

		if((pal->sne > pal->next_elem) || (pal->next_elem-pal->sne) != 3 || (*(pal->next_elem) && *(pal->next_elem) != ',')) { /* unless separators present and in the correct order, allele spec is two chars, and next_elem currently poits to end of string or element separator (,) */
			fprintf(stderr, "Badly formatted preload_alleles_list string: %.*s (in %s)\n", (int)(pal->next_elem-ai.snp_name), ai.snp_name, pal->source_string);
			return(NULL);
		}
		*(pal->sne) = '\0';	/* temporary termination of snp_name */
		if(*(pal->next_elem))
			++pal->next_elem;	
		ai.alleles =  pal->sne + 1;

		return(&ai);
	}
	else if(pal->type & PAL_FILE_TYPE) {
		if(fgets(inbuf, BSIZ, pal->fd) == NULL) {
			pal->type &= ~PAL_FILE_TYPE;    /* finished with file */
			return(NULL);
		}

		ai.snp_name = inbuf;

		p = ai.snp_name + strcspn(ai.snp_name, " ");
		if(p <= ai.snp_name) {
			fprintf(stderr, "Badly formatted preload_alleles_list item from file: %s\n", inbuf);
			return(NULL);
		}

		ai.alleles = p + strspn(p, " ");

		*p = '\0';	/* terminate snp_name */

		return(&ai);
		
	}
	else {
		fprintf(stderr, "Unrecognised preload_alleles_list type %d\n", pal->type);
		return(NULL);
	}
}

