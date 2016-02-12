
CC = cc
CFLAGS = -g -Wall

BUILDDIR = build
installdir = .

SAMTOOLS_LOC= /software/solexa/pkg/samtools/1.3
HTSLIB_LOC= /software/solexa/pkg/htslib/1.3
INCLUDES= -I. -I$(SAMTOOLS_LOC)/include -I$(HTSLIB_LOC)/include/htslib
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

all: $(BUILDDIR)/fastq_summ

install: $(BUILDDIR)/fastq_summ
	-cp -uv $(BUILDDIR)/fastq_summ $(installdir)/fastq_summ

clean:
	rm -f $(BUILDDIR)/fastq_summ $(BUILDDIR)/fastq_summ.o $(BUILDDIR)/fastqcheck.o

$(BUILDDIR)/fastq_summ: $(BUILDDIR)/fastq_summ.o $(BUILDDIR)/fastqcheck.o
	$(CC) $(CFLAGS) $^ -o $@ -pthread $(SAMTOOLSLIBPATH) $(SAMTOOLSLIB) $(LIBPATH) $(LIBS)

$(BUILDDIR)/fastq_summ.o: fastq_summ.c

$(BUILDDIR)/fastqcheck.o: fastqcheck.c fastqcheck.h

