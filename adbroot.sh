#!/bin/bash
echo "start root adb..."
sed -i -r -e 's/(ro\..*secure)=(.)/\1=0/'  ramdisk/default.prop  || exit 0
sed -i -r -e 's/(ro\..*debuggable)=(.)/\1=1/'  ramdisk/default.prop  || exit 0
sed -i -r -e '/setprop persist.sys.usb.config/d' -e '/on boot/a \    setprop persist.sys.usb.config mtp,adb' ramdisk/init.rc 
#sed -i  -r -e '/on property:persist.sys.usb.config=\*/,/on property:/{s/\s*#?\s*(setprop sys.usb.config ).*/    \1 mtp,adb/;/(setprop|on property:)/!d}' ramdisk/init.usb.rc

sed -i  -r -e '/service adbd\s.*/,/seclabel/{/\s*user .*\s*/d;/\s*seclabel .*\s*/i\    user root' -e '}' ramdisk/init.rc

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

echo "root adb fail"
#cp ~/bin/5.0/sbin/adbd ramdisk/sbin/
#cp ~/bin/4.4/sbin/adbd ramdisk/sbin/
#cp ~/bin/sepolicy/sepolicy ramdisk/

exit 0
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
