
CPPFLAGS=-DHAS_BLKID
CFLAGS=-O3 -Wall
LDLIBS=-lblkid
CC=gcc

ifneq ($(filter winall,$(MAKECMDGOALS)),)
CC=i586-mingw32msvc-gcc
CPPFLAGS=
LDLIBS=
endif

SRCS=abootimg.c libmincrypt/rsa.c libmincrypt/sha.c

ifneq ($(filter winall,$(MAKECMDGOALS)),)
SRCS+=getline.c
EXT=.exe
endif

OBJS=$(SRCS:.c=.o)

all: ABOOTIMG MKIMAGE

winall:ABOOTIMG MKIMAGE

ABOOTIMG: $(OBJS)
	$(CC) -o abootimg$(EXT) $(OBJS) $(LDLIBS)

MKIMAGE:mkimage.o
	$(CC) -o mkimage$(EXT) $<


version:
	if [ ! -f version.h ]; then \
	if [ -d .git ]; then \
	echo '#define VERSION_STR "$(shell git describe --tags --abbrev=0)"' > version.h; \
	else \
	echo '#define VERSION_STR ""' > version.h; \
	fi \
	fi

%.o: %.c version
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@ -I .

mkimage.o:mkimage.c

clean:
	rm -f abootimg mkimage abootimg.exe mkimage.exe *.o version.h  libmincrypt/*.o

.PHONY:	clean all version

