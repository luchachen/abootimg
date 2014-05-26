#!/bin/bash
src=$1
if [ -z "$src" ];then
    src=boot.img
fi

abootimg -x "$src"

size=$((`stat -c '%s' "$src"`))
cfgsize=$((`sed  -n -r -e 's/(bootsize = )(0x.*)/\2/p' bootimg.cfg `))
pagesize=$((`sed  -n -r -e 's/(pagesize = )(0x.*)/\2/p' bootimg.cfg `))
echo "signed = false" > signed.cfg
if [[ $(($size-$cfgsize)) -eq $pagesize ]];then
  echo "signed = true" > signed.cfg
fi 

stype=`file initrd.img`
echo "type =" > type.cfg
if [[ $stype != "initrd.img: gzip compressed data"* ]]
then
    echo "type: mtk"
    dd if=initrd.img skip=1 of=xx.img
    mv xx.img initrd.img
    echo "type = mtk" > type.cfg
fi
echo output directory is: ramdisk
abootimg-unpack-initrd
rm initrd.img
