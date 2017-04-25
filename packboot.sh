#!/bin/bash
#  author:LuchaChen
#  email:chenhua.chen@tcl.com
#  private:lucha.chen@gmail.com
# 

# Absolute path to this script, e.g. /home/user/bin/foo.sh
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in, thus /home/user/bin
SCRIPTPATH=$(dirname "$SCRIPT")

myprog=$(basename $0)

function absolutepath()
{
  echo -n "$(cd -P -- "$(dirname -- "$1")" && pwd -P)"
}

function version()
{
cat<<EOF
$myprog (GNU $myprog) 1.7.0
Copyright (C) 2013 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Lucha Chen/Chunhua Chen.
EOF
}

function usage()
{
cat<<EOF
Usage: $myprog [indir [outfile]]
'$myprog' create a Android Boot Image from scratch.

Examples:
  $myprog in_boot_dir boot.img   # Create boot.img from dir in_boot_dir.
  $myprog                        # Create boot.img from current dir.

Other options:
  -?, --help                 give this help list
  -v, --verbose              show command lines being executed.
      --version              print program version

Report bugs to <lucha.chen@gmail.com,chunhua.chen@tcl.com>.
EOF
}

if ! options=$(getopt -n $0 -o v? -l verbose,help,version -- "$@")
then
    # something went wrong, getopt will put out an error message for us
    usage
    exit 1
fi

eval set -- "$options"

VERBOSE=""

while [[ $# -gt 0 ]]
do
    case $1 in
     -v|--verbose) VERBOSE="-v"; shift;;
     -\?|--help) usage; exit 0;;
     --version) version; exit 0;;
     --) shift;break;;
     -*) echo "$myprog: error - unrecognized option $1" 1>&2; exit 1;;
     *) break;;
    esac
done

indir=${1:-$(pwd -P)}
if [[ $(pwd -P) == $SCRIPTPATH ]];then
cat<<EOF
$myprog: You must not work in the $SCRIPTPATH of script path.
Try '$myprog --help' or '$myprog -?' for more information.
EOF
  exit 1
elif [[ ! -d ${indir}/ramdisk ]] || [[ ! -f ${indir}/var/zImage ]];then
cat<<EOF
$myprog: You must specify one of the dir which is extract from Android Boot Image.
Or current dir which is extract from Android Boot Image.
Try '$myprog --help' or '$myprog -?' for more information.
EOF
  exit 1
fi

dst=${2:-${indir}/boot.img}
dst=$(absolutepath $dst)/$(basename $dst)

if [[ ! -e $dst.orig ]] && [[ -e $dst ]];then
    mv $dst $dst.orig
fi

cd ${indir}

${SCRIPTPATH}/abootimg-pack-initrd initrd.img ramdisk
[[ $? -eq 0 ]] || exit 0
stype=$(sed  -n -r -e 's/(type = )(.*)/\2/p' var/type.cfg)
if [[ "$stype" == "mtk" ]];then
    echo "type:$stype"
    ${SCRIPTPATH}/mkimage initrd.img ROOTFS > xxx.img
    mv xxx.img initrd.img

fi


size="0x100000"
sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" var/bootimg.cfg
if [[ -e var/dt.img ]];then
    ret=$(${SCRIPTPATH}/abootimg --create $dst -f var/bootimg.cfg -k var/zImage -r initrd.img --dt var/dt.img 2>&1 | sed -n -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/p')
else
    ret=$(${SCRIPTPATH}/abootimg --create $dst -f var/bootimg.cfg -k var/zImage -r initrd.img 2>&1 | sed -n -r -e 's/.*\(([0-9]+) vs [0-9]+ bytes\)/\1/p')
fi

if [[ -n "$ret" ]];then
    size=$(printf 0x%x $ret)
    sed -i -r -e "s/(bootsize = )(0x.*)/\1$size/" var/bootimg.cfg
    if [[ -e var/dt.img ]];then
        ${SCRIPTPATH}/abootimg --create $dst -f var/bootimg.cfg -k var/zImage -r initrd.img --dt var/dt.img
    else
        ${SCRIPTPATH}/abootimg --create $dst -f var/bootimg.cfg -k var/zImage -r initrd.img
    fi
else
cat<<EOF
  Get boot.img size fail.
EOF
  exit 1
fi

cp -f $dst $dst.nonverity
#ee
#${SCRIPTPATH}/ee/boot_signer /boot $dst  ${SCRIPTPATH}/ee/security_releasekey/verity.pk8  ${SCRIPTPATH}/ee/security_releasekey/verity.x509.pem $dst
#tmo
${SCRIPTPATH}/boot_signer /boot $dst  ${SCRIPTPATH}/security_releasekey/verity.pk8  ${SCRIPTPATH}/security_releasekey/verity.x509.pem $dst
#pixi564g
#${SCRIPTPATH}/boot_signer /boot $dst  ${SCRIPTPATH}/pixi564g/security/verity.pk8  ${SCRIPTPATH}/pixi564g/security/verity.x509.pem $dst
rm initrd.img

#END
cd ${OLDPWD}
