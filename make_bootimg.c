#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "bootimg.h"


boot_img_hdr header;


void dump_header(boot_img_hdr *h)
{
  int i;

  if (memcmp(h->magic, BOOT_MAGIC, BOOT_MAGIC_SIZE)) {
    printf("no magic value found\n");
    exit -1;
  }

  printf("kernel size = %d\n", h->kernel_size);
  printf("kernel addr = %08x\n", h->kernel_addr);

  printf("ramdisk size = %d\n", h->ramdisk_size);
  printf("ramdisk addr = %08x\n", h->ramdisk_addr);

  printf("second size = %d\n", h->second_size);
  printf("second addr = %08x\n", h->second_addr);

  printf("tags addr = %08x\n", h->tags_addr);
  printf("page_size = %d\n", h->page_size);

  printf("name = %s\n", h->name);

  printf("cmdline = %s\n", h->cmdline);

  printf("id = ");
  for(i=0; i<8; i++)
    printf("%08x ", h->id[i]);
  printf("\n");
}

int  newboot = 0;
char *cmdline = "";
char *bootimg_fname = NULL;
char *kernel_fname = NULL;
char *ramdisk_fname = NULL;

FILE *img_fh;
FILE *kernel_fh;
FILE *ramdisk_fh;


int usage()
{
   printf("usage: make_bootimg [-n] [-c cmdline] <bootimg> [<kernel>] [<ramdisk.img>]\n");
}

int main(int argc, char **argv)
{
  int i;

  for(i=1; i<argc; i++) {
    if (!strcmp(argv[i], "-n")) {
      newboot=1;
    }
    else if (!strcmp(argv[i], "-c")) {
      i++;
      if (i<argc)
        cmdline=argv[i];
      else {
        usage();
        exit(1);
      }
    }
    else if (!bootimg_fname) {
      bootimg_fname = argv[i];
    }
    else if (!kernel_fname) {
      kernel_fname = argv[i];
    }
    else if (!ramdisk_fname) {
      ramdisk_fname = argv[i];
    }
  }

  if (!bootimg_fname) {
    usage();
    exit(1);
  }

 
  if (newboot) {
    printf("-n TODO\n");
    exit(1);
  }
  else {
    img_fh = fopen(argv[1], "r+");
    
    fread(&header, sizeof(boot_img_hdr), 1, img_fh);
    dump_header(&header);
  }

  unsigned page_size = header.page_size;

  if (kernel_fname) {
    kernel_fh = fopen(kernel_fname, "r");

    void *k = malloc(page_size);

    unsigned kernel_size = 0;
    unsigned k_size;

    fseek(img_fh, page_size, SEEK_SET);

    do {
      k_size = fread(k, 1, page_size, kernel_fh);
      fwrite(k, 1, k_size, img_fh);
      kernel_size += k_size;
    } while (k_size == page_size);

    printf("kernel size = %d\n", kernel_size);
    header.kernel_size = kernel_size;

    fclose(kernel_fh);
  }

  if (ramdisk_fname) {
    ramdisk_fh = fopen(ramdisk_fname, "r");

    void *k = malloc(page_size);

    unsigned ramdisk_size = 0;
    unsigned rd_size;

    unsigned rd_pos = ( 1 + (header.kernel_size+page_size-1)/page_size) * page_size;
    fseek(img_fh, rd_pos, SEEK_SET);

    do {
      rd_size = fread(k, 1, page_size, ramdisk_fh);
      fwrite(k, 1, rd_size, img_fh);
      ramdisk_size += rd_size;
    } while (rd_size == page_size);

    printf("ramdisk size = %d\n", ramdisk_size);
    header.ramdisk_size = ramdisk_size;

    fclose(ramdisk_fh);
  }

  if (cmdline) {
    strncpy(header.cmdline, cmdline, BOOT_ARGS_SIZE);
  }

  fseek(img_fh, 0, SEEK_SET);
  fwrite(&header, 1, sizeof(header), img_fh);

  /*
  unsigned page_size = header.page_size;
  unsigned i;
  void *k;

  printf ("extracting kernel in %s\n", kernel_fname);
  fseek(img_fh, page_size, SEEK_SET);
  
  k = malloc(header.kernel_size);
  fread(k, header.kernel_size, 1, img_fh);
  
  kernel_fh = fopen(kernel_fname, "w");
  fwrite(k, header.kernel_size, 1, kernel_fh);
  fclose(kernel_fh);
  free(k);

  printf ("extracting ramdisk in %s\n", kernel_fname);

  unsigned n = (header.kernel_size + page_size - 1) / page_size;
  unsigned ramdisk_pos = (1+n)*page_size;
  void *r;

  fseek(img_fh, ramdisk_pos, SEEK_SET);
  
  r = malloc(header.ramdisk_size);
  fread(r, header.ramdisk_size, 1, img_fh);
  
  ramdisk_fh = fopen(ramdisk_fname, "w");
  fwrite(r, header.ramdisk_size, 1, ramdisk_fh);
  fclose(ramdisk_fh);
  free(r);

  if (header.second_size) {
    printf("second stage present. but ignored for now...\n");
  }
*/

  fclose(img_fh);

  return 0;
}
