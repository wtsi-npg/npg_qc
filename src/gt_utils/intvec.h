/* Author:        Kevin Lewis
 * Maintainer:    $Author$
 * Created:       2012-04-16
 * Last Modified: $Date$
 * Id:            $Id$
 * $HeadURL$
 */

#ifndef __INC_INTVEC__
#define __INC_INTVEC__

#define VECSTAT_OK 0
#define VECSTAT_LASTELEM 1
#define VECSTAT_BADFETCH 2

struct _int_vec {
        int status;
        int curElem;
        int curEnd;
        int maxIdx;
        int *vec;
};

struct _int_vec *newIntVec(int init_size);
int intVecAppend(struct _int_vec *vec, int val);
int intVecFirstElem(struct _int_vec *vec);
int intVecNextElem(struct _int_vec *vec);
int intVecElem(struct _int_vec *vec, int idx);
int intVecCurElem(struct _int_vec *vec);

#endif
