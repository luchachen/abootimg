#ifdef _MSC_VER  
typedef __int32 int32_t; 
typedef unsigned __int32 uint32_t; 
typedef __int64 int64_t; 
typedef unsigned __int64 uint64_t;  
#else 
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#endif 


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

#define PART_MAGIC        0x58881688
#define BLK_SIZE          512

typedef union
{
    struct
    {
        unsigned int magic;     /* partition magic */
        unsigned int dsize;     /* partition data size */
        char name[32];          /* partition name */
        unsigned int maddr;     /* partition memory address */
    } info;
    unsigned char data[512];
} part_hdr_t;

unsigned int filesize(char *name)
{
    struct stat statbuf;


    if(stat(name, &statbuf) != 0) {
        fprintf(stderr, "Cannot open file %s\n", name);
        exit(0);
    }
    return statbuf.st_size; 
}

char *readfile(char *name, unsigned int size)
{
    FILE *f;
    char *buf;

    f = fopen(name, "rb");
	


    if(f == NULL) {
        fprintf(stderr, "Cannot open file %s\n", name);
        exit(0);
    }
	
    buf = (char *)malloc(size);
    if (!buf) {
        fprintf(stderr, "error while malloc(%d)\n", size);
        fclose(f);
        exit(1);
    }
	
    if(fread(buf, 1, size, f) != size) { 

        fprintf(stderr, "Error while reading file %s\n", name);
        fclose(f);
        exit(0);
    }
    fclose(f);
    return buf;
}

char xtod(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return 0;
}

int hex2dec(char *hex, int l)
{
    if (*hex == 0)
        return l;
    return hex2dec(hex + 1, l * 16 + xtod(*hex));
}

int xstr2int(char *hex)
{
    return hex2dec(hex, 0);
}

int main(int argc, char *argv[])
{
    part_hdr_t part_hdr;
    char *img;
    uint32_t imgsize;
		int ret=0;
	
#ifdef _MSC_VER 

    if(argc != 5) {
        fprintf(stderr, "\nUsage: mkimage.exe <image_file_path> <image_name> <image_addr> <dest_image_file_path>\n\n");
		fprintf(stderr, "  e.g. <image_file_path>: Image, rootfs.gz \n");
        fprintf(stderr, "  e.g. <image_name>: KERNEL, ROOTFS\n");
        fprintf(stderr, "  e.g. <image_addr>: 0xA000\n");
		fprintf(stderr, "  e.g. <dest_image_file_path> patched_Image\n\n" );
        return 0;
    }
#else
	 if(argc != 5 && argc!=4) {			
        fprintf(stderr, "\nUsage1: ./mkimage <image_file_path> <image_name> <image_addr> > out_image\n");
        fprintf(stderr, "\nUsage2: ./mkimage <image_file_path> <image_name> <image_addr> <dest_image_file_path>\n\n");
        fprintf(stderr, "  e.g. <image_file_path>: Image, rootfs.gz\n");
        fprintf(stderr, "  e.g. <image_name>: KERNEL, ROOTFS\n");
        fprintf(stderr, "  e.g. <image_addr>: 0xA000\n");      
		fprintf(stderr, "  e.g. [optional]<dest_image_file_path>: patched_Image\n\n" );
        return 0;
    }
#endif
    
    memset(&part_hdr, 0xff, sizeof(part_hdr_t));

    part_hdr.info.magic = PART_MAGIC;
    part_hdr.info.dsize = filesize(argv[1]);
    strncpy(part_hdr.info.name, argv[2], sizeof(part_hdr.info.name));
    part_hdr.info.maddr = xstr2int(argv[3]);


    img = readfile(argv[1], part_hdr.info.dsize);
	
	 if(argc == 5) {
		FILE *pfile = fopen(argv[4],"wb");

		if ( pfile  == NULL) {

			ret=errno;
			if(ret==2){
				fprintf(stderr, "No such directory, please create by yourself\n\n");
			}
			else{
				fprintf(stderr, "create dest image error\n\n");
			}
 
			exit(1);
		}
		fwrite(&part_hdr,1,sizeof(part_hdr_t),pfile);
		fwrite(img,1,part_hdr.info.dsize,pfile);
		fclose(pfile);
	}
#ifndef _MSC_VER
	else if(argc == 4) {
		write(STDOUT_FILENO, &part_hdr, sizeof(part_hdr_t));
		write(STDOUT_FILENO, img, part_hdr.info.dsize);
	}

#endif


    return 0;
}
