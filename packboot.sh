#!/bin/bash
dst=$1
TARGET_SHA_TYPE=sha256
PRODUCT_PRIVATE_KEY=(~/bin/qcom.key)
if [ -z "$dst" ];then
    dst=boot.img
fi

if [ ! -e $dst.orig ] && [ -e $dst ];then
    mv $dst $dst.orig
fi

abootimg-pack-initrd
[[ $? -eq 0 ]] || exit 0
stype=$(sed  -n -r -e 's/(type = )(.*)/\2/p' type.cfg)
if [[ "$stype" == "mtk" ]];then
    echo "type:$stype"
    mkimage initrd.img ROOTFS 0xFFFFFFFF > xxx.img
    mv xxx.img initrd.img

fi


size="0x100000"
sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" bootimg.cfg
if [ -e dt.img ];then
    ret=$(abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img --dt dt.img 2>&1 | sed -n -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/p')
else
    ret=$(abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img 2>&1 | sed -n -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/p')
fi

if [ ! -z "$ret" ];then
    size=$(printf 0x%x $ret)
    sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" bootimg.cfg
    if [ -e dt.img ];then
        abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img --dt dt.img
    else
        abootimg --create $dst -f bootimg.cfg -k zImage -r initrd.img 
    fi
fi

signed=$(sed  -n -r -e 's/(signed = )(.*)/\2/p' signed.cfg)
if [[ "$signed" == "true" ]];then
    echo signed $signed
    pagesize=$(($(sed  -n -r -e 's/(pagesize = )(0x.*)/\2/p' bootimg.cfg )))
    mv -f $dst $dst.nonsecure
    openssl dgst -$TARGET_SHA_TYPE -binary $dst.nonsecure > $dst.$TARGET_SHA_TYPE
    openssl rsautl -sign -in $dst.$TARGET_SHA_TYPE -inkey $PRODUCT_PRIVATE_KEY -out $dst.sig
    dd if=/dev/zero of=$dst.sig.padded bs=$pagesize count=1
    dd if=$dst.sig of=$dst.sig.padded conv=notrunc
    cat $dst.nonsecure $dst.sig.padded > $dst.secure
    rm -rf $dst.$TARGET_SHA_TYPE $dst.sig $dst.sig.padded
    mv -f $dst.secure $dst
fi

rm initrd.img
