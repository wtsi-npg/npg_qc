
CC = cc
CFLAGS = -g -Wall

builddir = .
installdir = ../../t/bin

INCLUDES= -I.
LIBS= -lz -lm
LIBPATH=

ifdef FQS_BUILD_DIR
builddir = $(FQS_BUILD_DIR)
endif

ifdef FQS_INSTALL_DIR
installdir = $(FQS_INSTALL_DIR)
endif

.SUFFIXES: .c .o

.c.o:
	$(CC) -c $(CFLAGS) $(INCLUDES) $< -o $@

.PHONY: clean

all: norm_fit

install: norm_fit
	-cp -uv $(builddir)/norm_fit $(installdir)/norm_fit

clean:
	rm -f norm_fit norm_fit.o

norm_fit: norm_fit.o
	$(CC) $(CFLAGS) $^ -o $@ $(LIBPATH) $(LIBS)

norm_fit.o: norm_fit.c
