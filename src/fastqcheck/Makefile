
CC = cc
CFLAGS = -g -Wall

BUILDDIR = build
installdir = .

SAMTOOLS_LOC= /software/solexa/pkg/samtools/samtools-1.2
HTSLIB_LOC= /software/solexa/pkg/htslib/htslib-1.2.1
INCLUDES= -I. -I$(SAMTOOLS_LOC)/include -I$(HTSLIB_LOC)/include
LIBS= -lz -lm -Wl,-rpath=$(HTSLIB_LOC)/lib
LIBPATH=
SAMTOOLSLIB= -lbam -lhts
SAMTOOLSLIBPATH= -L $(SAMTOOLS_LOC)/lib -L $(HTSLIB_LOC)/lib

ifdef FQS_BUILD_DIR
BUILDDIR = $(FQS_BUILD_DIR)
endif

ifdef FQS_INSTALL_DIR
installdir = $(FQS_INSTALL_DIR)
endif

.SUFFIXES: .c .o

$(BUILDDIR)/%.o: %.c
	$(CC) -c $(CFLAGS) $(INCLUDES) $< -o $@

.PHONY: clean

all: $(BUILDDIR)/fastqcheck

install: $(BUILDDIR)/fastqcheck
	-cp -uv $(BUILDDIR)/fastqcheck $(installdir)/fastqcheck

clean:
	rm -f $(BUILDDIR)/fastqcheck $(BUILDDIR)/fastqcheck.o $(BUILDDIR)/readseq.o

$(BUILDDIR)/fastqcheck: $(BUILDDIR)/fastqcheck.o $(BUILDDIR)/readseq.o
	$(CC) $(CFLAGS) $^ -o $@ -pthread $(SAMTOOLSLIBPATH) $(SAMTOOLSLIB) $(LIBPATH) $(LIBS)

$(BUILDDIR)/fastqcheck.o: fastqcheck.c

$(BUILDDIR)/readseq.o: readseq.c readseq.h

