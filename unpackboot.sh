#!/bin/bash
src=$1
if [ -z "$src" ];then
    src=boot.img
fi

abootimg -x $src
type=`file initrd.img`
echo "type =" > type.cfg
if [[ $type != "initrd.img: gzip compressed data"* ]]
then
    echo "type: mtk"
    dd if=initrd.img skip=1 of=xx.img
    mv xx.img initrd.img
    echo "type = mtk" > type.cfg
fi
echo output directory is: ramdisk
abootimg-unpack-initrd
rm initrd.img
