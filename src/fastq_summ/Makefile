
CC = cc
CFLAGS = -g -Wall

builddir = .
installdir = ../../t/bin

INCLUDES= -I.
SAMTOOLS_LOC= /software/solexa/bin/aligners/samtools/samtools-0.1.17
LIBS= -lz -lm
LIBPATH=
SAMTOOLSLIB= -lbam
SAMTOOLSLIBPATH= -L $(SAMTOOLS_LOC)

ifdef FQS_BUILD_DIR
builddir = $(FQS_BUILD_DIR)
endif

ifdef FQS_INSTALL_DIR
installdir = $(FQS_INSTALL_DIR)
endif

ifdef SAMTOOLS_LOC
INCLUDES += -I $(SAMTOOLS_LOC)
endif

.SUFFIXES: .c .o

.c.o:
	$(CC) -c $(CFLAGS) $(INCLUDES) $< -o $@

.PHONY: clean

all: fastq_summ

install: fastq_summ
	-cp -uv $(builddir)/fastq_summ $(installdir)/fastq_summ

clean:
	rm -f fastq_summ fastq_summ.o fastqcheck.o

fastq_summ: fastq_summ.o fastqcheck.o
	$(CC) $(CFLAGS) $^ -o $@ $(SAMTOOLSLIBPATH) $(SAMTOOLSLIB) $(LIBPATH) $(LIBS)

fastq_summ.o: fastq_summ.c

fastqcheck.o: fastqcheck.c fastqcheck.h

