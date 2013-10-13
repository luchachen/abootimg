
CPPFLAGS=-DHAS_BLKID
CFLAGS=-O3 -Wall
LDLIBS=-lblkid

abootimg.o: bootimg.h version.h

clean:
	rm -f abootimg *.o version.h

