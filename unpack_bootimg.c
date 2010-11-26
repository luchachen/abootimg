#include <stdlib.h>
#include <stdio.h>
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

char *kernel_fname = "zImage";
char *ramdisk_fname = "initrd.img";
char *secondstage_fname = "stage2.img";

FILE *img_fh;
FILE *kernel_fh;
FILE *ramdisk_fh;


int main(int argc, char **argv)
{
   
  if (argc < 2) {
    printf("usage: %s <bootimg> [<kernel> [<ramdisk.img>]]\n", argv[0]);
    return -1;
  }

  if (argc >= 3)
    kernel_fname = argv[2];
  if (argc >= 4)
    ramdisk_fname = argv[3];

  img_fh = fopen(argv[1], "r");
  
  fread(&header, sizeof(boot_img_hdr), 1, img_fh);
  dump_header(&header);

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

  printf ("extracting ramdisk in %s\n", ramdisk_fname);

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

  fclose(img_fh);

  return 0;
}
