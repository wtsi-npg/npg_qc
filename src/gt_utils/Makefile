# Author:        Kevin Lewis
# Created:       2012-04-16
#

CC = cc
CFLAGS = -g -Wall

builddir = .
installdir = /software/solexa/bin

.SUFFIXES:
.SUFFIXES: .c .o

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

.PHONY: clean

all: gt_pack find_gt_match

install: gt_pack find_gt_match
	-cp -uv $(builddir)/gt_pack $(installdir)/gt_pack
	-cp -uv $(builddir)/find_gt_match $(installdir)/find_gt_match

clean:
	rm -f gt_pack find_gt_match gt_pack.o fld_desc.o intvec.o find_gt_match.o

gt_pack: gt_pack.o fld_desc.o intvec.o
	$(CC) $(CFLAGS) $^ -o $@

find_gt_match: find_gt_match.o
	$(CC) $(CFLAGS) $^ -o $@

gt_pack.o: gt_pack.c gt_pack.h

fld_desc.o: fld_desc.c fld_desc.h

intvec.o: intvec.c intvec.h

