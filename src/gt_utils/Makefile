# Author:        Kevin Lewis
# Created:       2012-04-16
#

CC = cc
CFLAGS = -g -Wall

BUILDDIR=build

$(BUILDDIR)/%.o: %.c
	$(CC) -c -o $@ $< $(CFLAGS)

.PHONY: clean

all: $(BUILDDIR)/gt_pack $(BUILDDIR)/find_gt_match

install: gt_pack find_gt_match
	-cp -uv $(builddir)/gt_pack $(installdir)/gt_pack
	-cp -uv $(builddir)/find_gt_match $(installdir)/find_gt_match

clean:
	rm -f $(BUILDDIR)/gt_pack $(BUILDDIR)/find_gt_match $(BUILDDIR)/gt_pack.o $(BUILDDIR)/fld_desc.o $(BUILDDIR)/intvec.o $(BUILDDIR)/find_gt_match.o

$(BUILDDIR)/gt_pack: $(BUILDDIR)/gt_pack.o $(BUILDDIR)/fld_desc.o $(BUILDDIR)/intvec.o
	$(CC) $(CFLAGS) $^ -o $@

$(BUILDDIR)/find_gt_match: $(BUILDDIR)/find_gt_match.o
	$(CC) $(CFLAGS) $^ -o $@

$(BUILDDIR)/gt_pack.o: gt_pack.c gt_pack.h

$(BUILDDIR)/fld_desc.o: fld_desc.c fld_desc.h

$(BUILDDIR)/intvec.o: intvec.c intvec.h

