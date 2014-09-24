
CPPFLAGS=-DHAS_BLKID
CFLAGS=-O3 -Wall
LDFLAGS= -L .
LDLIBS=-lblkid -lmincrypt

all: abootimg mkimage

libmincrypt.a:
	make -C libmincrypt

version.h:
	if [ ! -f version.h ]; then \
	if [ -d .git ]; then \
	echo '#define VERSION_STR "$(shell git describe --tags --abbrev=0)"' > version.h; \
	else \
	echo '#define VERSION_STR ""' > version.h; \
	fi \
	fi

abootimg.o: bootimg.h version.h libmincrypt.a

mkimage.o:mkimage.c

clean:
	make -C libmincrypt clean
	rm -f abootimg *.o version.h libmincrypt.a

.PHONY:	clean all

