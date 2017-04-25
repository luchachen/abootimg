#!/bin/bash
#  author:LuchaChen
#  email:chenhua.chen@tcl.com
#  private:lucha.chen@gmail.com
# 

ABOOTMAGIC='414e44524f494421'
AMTKSIGNEDBOOTMAGIC='42464246' #BFBF
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
Usage: $myprog [infile [outdir]]
'$myprog' extract Android Boot Image of infile to outdir 

Examples:
  $myprog  myboot.img  myoutdir      # Extract myboot.img to dir the myoutdir. 
  $myprog  myboot.img                # Extract myboot.img to random tempdir. 
  $myprog                            # Extract default boot.img in current dir to random tempdir.

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

infile=${1:-boot.img}
inbn=$(basename $infile)
infile=$(absolutepath $infile)/${inbn}
fmagic='NONE'
#echo infile:$infile

if [[ $(pwd -P) == ${SCRIPTPATH} ]];then
$myprog: You must not work in the $SCRIPTPATH of script path.
Try '$myprog --help' or '$myprog -?' for more information.
  exit 1
elif [[ ! -f ${infile} ]] || \
    fmagic="$(xxd -b -ps -l 8 ${infile})"; [[ $fmagic != $ABOOTMAGIC ]] && [[ ${fmagic:0:8} != $AMTKSIGNEDBOOTMAGIC ]];then
    echo magic${fmagic}
cat<<EOF
$myprog: You must specify one of the file which is Android Boot Image.
Or current dir which had boot.img of Android Boot Image.
Try '$myprog --help' or '$myprog -?' for more information.
EOF
  exit 1
elif outdir=${2:-$(mktemp -d --suffix=-$(date +%Y%m%d-%H%M%S)  ${inbn%.*}-XXXX)}; \
    outdir=$(absolutepath $outdir)/$(basename $outdir); \
    [[ -d ${outdir}/ramdisk  ||  -f ${outdir}/var/zImage ]];then
cat<<EOF
$myprog: You must specify one of the dir which is not extract from Android Boot Image.
Or current dir which is not extract from Android Boot Image.
Try '$myprog --help' or '$myprog -?' for more information.
EOF
  exit 1
fi 

mkdir -p ${outdir}/var;cd ${outdir}/var
if [[ ${fmagic:0:8} == $AMTKSIGNEDBOOTMAGIC ]];then
    dd if=${infile} skip=1 bs=$((0x4040)) of=${outdir}/var/boot.img
    infile=${outdir}/var/boot.img
fi
${SCRIPTPATH}/abootimg -x "$infile" || exit 0

size=$(($(stat -c '%s' "$infile")))
cfgsize=$(($(sed  -n -r -e 's/(bootsize = )(0x.*)/\2/p' bootimg.cfg )))
pagesize=$(($(sed  -n -r -e 's/(pagesize = )(0x.*)/\2/p' bootimg.cfg )))
echo "signed = false" > signed.cfg
if [[ $(($size-$cfgsize)) -eq $pagesize ]];then
  echo "signed = true" > signed.cfg
fi 

stype=$(file initrd.img)
echo "type =" > type.cfg
if [[ $stype != *"gzip compressed data"* ]]
then
    echo "type: mtk"
    dd if=initrd.img skip=1 of=xx.img
    mv initrd.img initrd.img.orig
    mv xx.img initrd.img
    echo "type = mtk" > type.cfg
fi
${SCRIPTPATH}/abootimg-unpack-initrd initrd.img ${outdir}/ramdisk
FDT_MAGIC=0xd00dfeed
#dtb -O dts mpc8548.dtb -o mpc8548.dts
#rm initrd.img
echo Output Directory is: ${outdir}
#END
cd ${OLDPWD}

