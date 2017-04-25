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
Usage: $myprog [indir]
'$myprog' take the adb shell and console have root permissive, 
According to modify the selinux sepolicy and same of property and init.rc.

Examples:
  $myprog in_boot_dir            # Take root permissive to modify the some 
                                      of file in dir in_boot_dir.
  $myprog                        # Take root permissive to modify the some 
                                      of file in current dir.

Other options:
  -?, --help                 give this help list
  -v, --verbose              show command lines being executed.
      --version              print program version

Report bugs to <lucha.chen@gmail.com,chunhua.chen@tcl.com>.
EOF
}

function patch_adbd()
{
  cp ramdisk/sbin/adbd ./
  patch_setuid
  patch_prctl
}

function permissive_adbd()
{

  echo "permissiving adbd and sh... "
  mv ramdisk/sepolicy ./
  ${SCRIPTPATH}/sepolicy-inject$suffix -Z adbd -P sepolicy  -o  sepolicy.adbd
  ${SCRIPTPATH}/sepolicy-inject$suffix -Z shell -P sepolicy.adbd  -o  ramdisk/sepolicy
  ${SCRIPTPATH}/checkpolicy$suffix -M  -b  ramdisk/sepolicy
  if [[ $? -ne 0 ]];
  then
     echo "permissive adbd fail"
     exit 1
  fi
}

function patch_should_drop_privileges()
{
   echo patch_should_drop_privileges
   CROSS_COMPILE=${HOME}/work/android/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi
   SRC=$HOME/bin/ramdisk/adb.c
   ${CROSS_COMPILE}-gcc -c  -o adb.o $SRC
   magic=$(readelf   -x .text adb.o  | awk ' $1 ~ /0x[0-9a-zA-Z]+/ { i=1; while ( ++i < NF ) printf "%s\\n", $i}  END { print $0 } ' | sed -e '$s/\\n$//')
   patch_magic $magic
}

function patch_magic()
{
   magic=$1
   echo magic:${magic}
   #echo -e "${magic}"
   magic_count=$(echo -e $magic | wc -l)
   #for all match
   #echo $magic_count
   match_line_num=$(hexdump -ve '4/1 "%02x" "\n"' ramdisk/sbin/adbd | \
                    sed -r -n -e "1{:k;1,+$(($magic_count -2)){N;b k}};H;g" -e "/$magic/{s/\n//g;=;q}" -e 's/^\n[^\n]*//' -e 'h')
   
   echo match_line:$match_line_num
   if [[ -n $match_line_num ]];then
     swi='000000ef'
     swi_line=$(echo -e $magic | sed -r -n -e "/$swi/=")
     echo swiline:$swi_line magic count $magic_count
     match_line_num=$(($match_line_num - $magic_count + $swi_line - 1))
     echo $match_line_num
     #address=$((($match_line_num-5)*4))
     address=$((($match_line_num)*4))
     echo addr:$address
     #d570a0e3
     printf '\xd5\x70\xa0\xe3' | dd of=ramdisk/sbin/adbd bs=1 seek=$address count=4 conv=notrunc
   fi
}

function patch_setuid()
{
   echo patch_setuid
   #start sed the adbd
   #CROSS_COMPILE=${HOME}/work/android/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi
   #SRC=$HOME/bin/ramdisk/setuid.S
   #${CROSS_COMPILE}-as -o setuid.o $SRC
   #magic=$(readelf   -x .text setuid.o  | awk ' $1 ~ /0x[0-9a-zA-Z]+/ { i=1; while ( ++i < NF ) printf "%s\\n", $i}  END { print $0 } ' | sed -e '$s/\\n$//')
   magic='07c0a0e1\nd570a0e3\n000000ef\n0c70a0e1\n010a70e3\n1eff2f91\n000060e2'
   
   patch_magic $magic
   #end sed the adbd
}

function patch_prctl()
{
   #start sed the adbd
   echo patch_prctl
   #CROSS_COMPILE=${HOME}/work/android/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi
   #SRC=$HOME/bin/ramdisk/prctl.S
   #${CROSS_COMPILE}-as -o prctl.o $SRC
   #magic=$(readelf   -x .text prctl.o | awk ' $1 ~ /0x[0-9a-zA-Z]+/ { i=1; while ( ++i < NF ) printf "%s\\n", $i}  END { print $0 } ' | sed -e '$s/\\n$//')
   magic='0dc0a0e1\nf0002de9\n70009ce8\nac70a0e3\n000000ef\nf000bde8\n010a70e3\n1eff2f91\n000060e2'
   
   
   patch_magic $magic
}

function patch_prop()
{
   #disable secure and debuggable
   sed -i -r -e 's/(ro\..*secure)=(.)/\1=0/' -e '/ro.secure=.*/a ro.adb.secure=0' -e 's/(ro\..*debuggable)=(.)/\1=1/' ramdisk/default.prop  || exit 0
   sed -i -r -e '/setprop persist.sys.usb.config/d' -e '/on boot/a \    setprop persist.sys.usb.config mtp,adb' ramdisk/init.rc || exit 0
   #sed -i  -r -e '/on property:persist.sys.usb.config=\*/,/on property:/{s/\s*#?\s*(setprop sys.usb.config ).*/    \1 mtp,adb/;/(setprop|on property:)/!d}' ramdisk/init.usb.rc
   
   sed -i -r -e 's/(service adbd\s.*)(--root_seclabel=.*)(\s*.*)/\1\3/' \
             -e '/service adbd\s.*/,/seclabel/{/\s*user .*\s*/d;/\s*seclabel .*\s*/i\    user root' -e '}' \
             -e '/service console\s.*/,/seclabel/{/\s*user .*\s*/d;/\s*seclabel .*\s*/i\    user root' -e '}' ramdisk/init.rc || exit 0

   sed -i -r -e 's/(service adbd\s.*)(--root_seclabel=.*)(\s*.*)/\1\3/' \
             -e '/service adbd\s.*/,/seclabel/{/\s*user .*\s*/d;/\s*seclabel .*\s*/i\    user root' -e '}' \
             -e '/service console\s.*/,/seclabel/{/\s*user .*\s*/d;/\s*seclabel .*\s*/i\    user root' -e '}' ramdisk/init.usb.rc || exit 0
}

function copy_adbd()
{
   #start copy the adbd
   adbs=(${SCRIPTPATH}/ramdisk/sbin/adbd*$suffix)
   adbmagic=$(head -c 24 ramdisk/init)
   #echo ${adbs[@]}
   #echo $adbmagic
   for i in ${adbs[@]}
   do
     #echo "$i magic:$(head -c 24 $i)"
     if [[ "$(head -c 24 $i)" == "$adbmagic" ]];then
        echo "copying $i to ramdisk/sbin/adbd... "
        cp $i ramdisk/sbin/adbd
        echo "root adb success"
        exit 0
        break
     fi
   done

cat<<EOF
   Fail copying $i ramdisk/sbin/adbd. 
   Please copy adbd of eng in the project to the directory of ramdisk/sbin/adbd.
EOF
   exit 1
   #end copy the adbd
}

function patch_cmdline()
{
   #start modify cmdline
   cmdline=$(sed  -n -r -e 's/(cmdline = )(.*)/\2/p' bootimg.cfg)
   if [[ $cmdline != *"androidboot.selinux="* ]];then
   #    cmdline+=" androidboot.selinux=disabled"
       cmdline+=" androidboot.selinux=permissive"
   fi
   #permissive
   #disabled
   shopt -s extglob
   #shopt
   #cmdline=${cmdline/androidboot.selinux=*([[:alpha:]])/androidboot.selinux=disabled}
   cmdline=${cmdline/androidboot.selinux=*([[:alpha:]])/androidboot.selinux=permissive}
   echo "cmdline:"$cmdline
   sed -i -r -e "s/(cmdline = )(.*)/\1$cmdline/" bootimg.cfg
   #end modify cmdline
}

#TCL/5095K/pop464g:6.0/MRA58K/v4F12-0:user/release-keys
function get_android_version()
{
  if [[ -f ramdisk/selinux_version ]];then
    androidversion=$(sed -n -r -e 's:.*/.*/.*\:([0-9]+)\..*:\1:p' ramdisk/selinux_version)
  else
    androidversion=4
  fi
  echo "The $1 is Android ${androidversion}.0"

  if [[ $androidversion -le 6 ]];then
      suffix='-6'
  elif [[ $androidversion -eq 7 ]];then
      suffix='-7'
  fi
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

echo "Start root adb..."

#switch to directory of the top ramdisk
cd ${indir}
get_android_version
patch_prop
#patch_cmdline
#patch_adbd
#patch_should_drop_privileges
if [[ $androidversion -ge 5 ]];then
  permissive_adbd
fi
copy_adbd

#END switch back
cd ${OLDPWD}
echo "root adb success"
