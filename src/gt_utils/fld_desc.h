/* Author:        Kevin Lewis
 * Created:       2012-04-16
 */

#ifndef __INC_FLD_DESC__
#define __INC_FLD_DESC__

struct _snp_info {
        char *name;
        char *alleles[16];
        int allele_count[16];
        int top_aidx;
};

struct _fld_type_si {
        char type;
        struct _snp_info *si;   /* NULL unless type is 'G' */
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

#define PAL_EMPTY 0
#define PAL_STRING_TYPE 1
#define PAL_FILE_TYPE 2

typedef struct _parse_allele_source {
	/* string and/or from file */
	int type;       

	/* type string */
	char *source_string;
	char *sne;      /* to restore string */
	char *next_elem;

	/* type file */
	FILE *fd;
} PAL;

struct _fld_desc *new_fld_desc(char *inbuf, char *sample_id_fields, char *sample_label_fields, char *ignore_fields, PAL *preload_alleles_list);

#endif
