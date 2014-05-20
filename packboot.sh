#!/bin/bash
dst=$1
if [ -z "$dst" ];then
    dst=boot.img
fi

if [ ! -e $dst.orig ] && [ -e $dst ];then
    mv $dst $dst.orig
fi

abootimg-pack-initrd
type=`sed  -n -r -e 's/(type = )(.*)/\2/p' type.cfg `
if [[ "$type" == "mtk" ]];then
    echo "type:$type"
    mkimage initrd.img ROOTFS > xxx.img
    mv xxx.img initrd.img

fi

size="0x100000"
sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" bootimg.cfg
if [ -e dt.img ];then
    ret=`abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img --dt dt.img 2>&1 | sed -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/'| sed -r -e '/[0-9]+/!d'`
else
    ret=`abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img 2>&1 | sed -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/'| sed -r -e '/[0-9]+/!d'`
fi

if [ ! -z "$ret" ];then
    size=`printf 0x%x $ret`
    sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" bootimg.cfg
    if [ -e dt.img ];then
        abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img --dt dt.img
    else
        abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img 
    fi
fi

rm initrd.img
