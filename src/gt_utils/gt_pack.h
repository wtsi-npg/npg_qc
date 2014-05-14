/* Author:        Kevin Lewis
 * Maintainer:    $Author$
 * Created:       2012-04-16
 * Last Modified: $Date$
 * Id:            $Id$
 * $HeadURL$
 */

#ifndef __INC_GT_PACK__
#define __INC_GT_PACK__

/*
Version 2 header
	magic: "GT"
	ver: "02"
	hdr_size: sizeof(GT_HDR)
	callcount: number of SNPs per sample
	gt_bits: 2 for biallelic SNPs
	dp_bits: number of bits used to record read depth
	data_id: identifier for data set (e.g. "W30467_SNP")
	refresh_date: YYYYMMDDHHMISS indicating when latest data was added
*/

#define DATA_ID_LEN 64
#define REFRESH_DATE_LEN 16

struct _hdr_base {
        char magic[2];
        char ver[2];
        unsigned hdr_size;
        int callcount;
        unsigned char gt_bits;
        unsigned char dp_bits;
};

typedef struct _gt_hdr_v02 {
	struct _hdr_base hdr_base;
	char data_id[DATA_ID_LEN];
	char refresh_date[REFRESH_DATE_LEN];
} GT_HDR;

#endif

