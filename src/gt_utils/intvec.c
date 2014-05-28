/* Author:        Kevin Lewis
 * Created:       2012-04-16
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "intvec.h"

#ifndef __INC_INTVEC__
/* These are just here for reference - see header for actual definitions */

struct _int_vec {
	int status;
	int curElem;
	int curEnd;
	int maxIdx;
	int *vec;
};
#endif

/*
Some utility functions for integer vectors
*/
struct _int_vec *newIntVec(int init_size)
{
	struct _int_vec *ret = NULL;

	if(init_size <= 0)
		return(NULL);

	if((ret=malloc(sizeof(struct _int_vec))) != NULL) {
		if((ret->vec = malloc(init_size * sizeof(int))) == NULL) {
			free(ret);
			return(NULL);
		}
		memset(ret->vec, 0, init_size * sizeof(int));
		ret->curEnd = 0;
		ret->curElem = 0;
		ret->maxIdx = init_size-1;
		ret->status = VECSTAT_OK;
	}

	return(ret);
}

int intVecAppend(struct _int_vec *vec, int val)
{
	int newMaxIdx;
	int *new_vec;

	if(vec == NULL)
		return(-1);

	if(vec->curEnd > vec->maxIdx) {
		if(vec->maxIdx < 32768)		/* 32768 is an arbitrary doubling limit */
			newMaxIdx = vec->maxIdx * 2;
		else
			newMaxIdx = vec->maxIdx + 32768;

		if((new_vec = realloc(vec->vec, newMaxIdx)) == NULL) {
			return(-2);
		}
		else {
			vec->maxIdx = newMaxIdx;
		}
	}

	vec->vec[vec->curEnd++] = val;

	return(0);
}

int intVecElem(struct _int_vec *vec, int idx)
{
	if(idx > vec->curEnd) {
		vec->status = VECSTAT_BADFETCH;
		return(-1);
	}

	return(vec->vec[idx]);
}

int intVecFirstElem(struct _int_vec *vec)
{
	vec->curElem = 0;

	if(vec->curEnd <= 0) {
		vec->status = VECSTAT_BADFETCH;
		return(0);
	}
	else {
		vec->status = VECSTAT_OK;
		return(vec->vec[0]);
	}
}

int intVecNextElem(struct _int_vec *vec)
{
	if(vec->curElem >= vec->curEnd) {
		vec->status = VECSTAT_BADFETCH;
		return(0);
	}

	if(vec->curElem == vec->curEnd-1) {
		vec->status = VECSTAT_LASTELEM;
	}
	else {
		++vec->curElem;
		vec->status = VECSTAT_OK;
	}

	return(vec->vec[vec->curElem]);
}

int intVecCurElem(struct _int_vec *vec)
{
	return(vec->vec[vec->curElem]);
}

