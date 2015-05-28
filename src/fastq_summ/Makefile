
CC = cc
CFLAGS = -g -Wall

BUILDDIR = build
installdir = .

SAMTOOLS_LOC= /software/solexa/pkg/samtools/samtools-1.2
HTSLIB_LOC= /software/solexa/pkg/htslib/htslib-1.2.1
INCLUDES= -I. -I$(SAMTOOLS_LOC)/include -I$(HTSLIB_LOC)/include
LIBS= -lz -lm -Wl,-rpath=$(HTSLIB_LOC)
LIBPATH=
SAMTOOLSLIB= -lbam -lhts
SAMTOOLSLIBPATH= -L $(SAMTOOLS_LOC)/lib -L $(HTSLIB_LOC)/lib

ifdef FQS_BUILD_DIR
BUILDDIR = $(FQS_BUILD_DIR)
endif

ifdef FQS_INSTALL_DIR
installdir = $(FQS_INSTALL_DIR)
endif

ifdef SAMTOOLS_LOC
INCLUDES += -I $(SAMTOOLS_LOC)
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

