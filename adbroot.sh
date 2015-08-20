#!/bin/bash
echo "start root adb..."
function patch_adbd()
{
  cp ramdisk/sbin/adbd ./
  patch_setuid
  patch_prctl
}

function permissive_adbd()
{
  mv ramdisk/sepolicy ./
  sepolicy-inject -Z adbd -P sepolicy  -o  sepolicy.adbd
  sepolicy-inject -Z shell -P sepolicy.adbd  -o  ramdisk/sepolicy
  checkpolicy -M  -b  ramdisk/sepolicy
  if [[ $? -ne 0 ]];
  then
     echo "permissive adbd fail"
     exit 1
  fi
}

function patch_setuid()
{
   echo patch_setuid
   #start sed the adbd
   CROSS_COMPILE=${HOME}/work/android/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi
   SRC=$HOME/bin/ramdisk/setuid.S
   ${CROSS_COMPILE}-as -o setuid.o $SRC
   #readelf -x .text setuid.o 
   magic=$(readelf   -x .text setuid.o  | awk ' $1 ~ /0x[0-9a-zA-Z]+/ { i=1; while ( ++i < NF ) printf "%s\\n", $i}  END { print $0 } ' | sed -e '$s/\\n$//')
   
   
   echo magic:${magic}
   echo -e "${magic}"
   magic_count=$(echo -e $magic | wc -l)
   #for all match
   #match_line_num=$(hexdump -ve '4/1 "%02x" "\n"' ramdisk/sbin/adbd | sed -r -n -e '1{N;N;N;N;N;N};H;g' -e "/$magic/{s/\n//g;=;q}" -e 's/^\n[^\n]*//' -e 'h')
   echo $magic_count
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
   #end sed the adbd
}

function patch_prctl()
{
   #start sed the adbd
   echo patch_prctl
   CROSS_COMPILE=${HOME}/work/android/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.7/bin/arm-linux-androideabi
   SRC=$HOME/bin/ramdisk/prctl.S
   ${CROSS_COMPILE}-as -o prctl.o $SRC
   #readelf -x .text prctl.o 
   magic=$(readelf   -x .text prctl.o | awk ' $1 ~ /0x[0-9a-zA-Z]+/ { i=1; while ( ++i < NF ) printf "%s\\n", $i}  END { print $0 } ' | sed -e '$s/\\n$//')
   
   
   echo magic:${magic}
   echo -e "${magic}"
   magic_count=$(echo -e $magic | wc -l)
   #for all match
   match_line_num=$(hexdump -ve '4/1 "%02x" "\n"' ramdisk/sbin/adbd | \
                    sed -r -n -e "1{:k;1,+$(($magic_count -2)){N;b k}};H;g" -e "/$magic/{s/\n//g;=;q}" -e 's/^\n[^\n]*//' -e 'h')
   
   echo match_line:$match_line_num
   if [[ -n $match_line_num ]];then
     swi='000000ef'
     swi_line=$(echo -e $magic | sed -r -n -e "/$swi/=")
     magic_count=$(echo -e $magic | wc -l)
     echo swiline:$swi_line magic count $magic_count
     match_line_num=$(($match_line_num - $magic_count + $swi_line - 1))
     echo $match_line_num
     address=$((($match_line_num)*4))
     echo addr:$address
     #d570a0e3
     printf '\xd5\x70\xa0\xe3' | dd of=ramdisk/sbin/adbd bs=1 seek=$address count=4 conv=notrunc
   fi
   #end sed the adbd
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
}

function copy_adbd()
{
   #start copy the adbd
   adbs=(~/bin/ramdisk/sbin/adbd*)
   adbmagic=$(head -c 24 ramdisk/init)
   #echo ${adbs[@]}
   #echo $adbmagic
   for i in ${adbs[@]}
   do
     #echo "$i magic:$(head -c 24 $i)"
     if [[ "$(head -c 24 $i)" == "$adbmagic" ]];then
        #echo "copy $i success"
        cp $i ramdisk/sbin/adbd
        echo "root adb success"
        exit 0
        break
     fi
   done
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

patch_prop
#patch_cmdline
patch_adbd
permissive_adbd
#copy_adbd
echo "root adb success"
