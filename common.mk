CFLAGS=-O3 -Wall
PREFIX=/usr/local

all: abootimg

version.h:
	if [ ! -f version.h ]; then \
	if [ -d .git ]; then \
	echo '#define VERSION_STR "$(shell git describe --tags --abbrev=0)"' > version.h; \
	else \
	echo '#define VERSION_STR ""' > version.h; \
	fi \
	fi

install: abootimg
	install -m 0755 abootimg $(PREFIX)/bin
	install -m 0755 abootimg-pack-initrd $(PREFIX)/bin
	install -m 0755 abootimg-unpack-initrd $(PREFIX)/bin

clean:
	rm -f abootimg *.o version.h
	rm -f fmemopen/fmemopen.o

.PHONY:	clean all
