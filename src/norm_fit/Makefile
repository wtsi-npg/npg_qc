
CC = cc
CFLAGS = -g -Wall

BUILDDIR=build

INCLUDES= -I.
LIBS= -lz -lm
LIBPATH=

$(BUILDDIR)/%.o: %.c 
	$(CC) -c -o $@ $< $(CFLAGS) $(INCLUDES)

.PHONY: clean

all: $(BUILDDIR)/norm_fit

clean:
	rm -f $(BUILDDIR)/norm_fit $(BUILDDIR)/norm_fit.o

$(BUILDDIR)/norm_fit: $(BUILDDIR)/norm_fit.o
	$(CC) $(CFLAGS) $^ -o $@ $(LIBPATH) $(LIBS)

