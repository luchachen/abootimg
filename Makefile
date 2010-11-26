
all: unpack_bootimg make_bootimg

unpack_bootimg: unpack_bootimg.c bootimg.h
	gcc -O2 -o unpack_bootimg unpack_bootimg.c

make_bootimg: make_bootimg.c bootimg.h
	gcc -O2 -o make_bootimg make_bootimg.c


clean:
	rm -f unpack_bootimg
	rm -f make_bootimg

archive: clean
	cd .. && tar cvzf bootimg.tar.gz bootimg

