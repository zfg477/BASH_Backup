#!/bin/bash
#swap_status=$(free | grep 'Swap'|awk '{print $2}'); if [[ $swap_status = 0 ]]; then bash -c /scripts/Bash?crypt_swap.sh > /dev/null 2>&1 & fi

if [ ! $UID = 0 ]; then echo "Root required"; exit 1; fi

echo "this will deploy the current OS to a new device"
echo "*Note Is /boot mounted?"
echo "Press [Enter] to continue?"
read resp
#
#this is the drive that will recieve our OS
#alter this line to use a different disk
root_dev=$(mount | grep "on / type"|awk '{print $1}')
for devs in $(blkid -o device)
do
device_UUID=$(blkid -o export -d $devs | grep UUID |grep -v PARTUUID |grep -v PTUUID| grep -v UUID_SUB)
device_LABEL=$(blkid -o export -d $devs | grep "LABEL")
device_TYPE=$(blkid -o export -d $devs | grep "TYPE")
if [[ ! -z $device_UUID ]] && [[ ! "$devs" == "$root_dev" ]];then
echo $devs $device_UUID $device_LABEL $device_TYPE
fi
done

echo "What device would you like to deploy to?"
echo ""
read dest_
dest_=$(blkid | grep $dest_|cut -d ':' -f1)
if [[ -z $dest_ ]]; then echo "device not found, valid search options are";echo "device path,UUID,PARTUUID,LABEL"; return 0; fi
for dev in $dest_
do
device_UUID=$(blkid -o export -d $dev | grep UUID |grep -v PARTUUID |grep -v PTUUID| grep -v UUID_SUB)
device_PUUID=$(blkid -o export -d $dev | grep PARTUUID |grep -v PTUUID)
device_LABEL=$(blkid -o export -d $dev | grep "LABEL")
device_TYPE=$(blkid -o export -d $dev | grep "TYPE")
echo $dev 
echo $device_UUID;echo $device_PUUID;echo $device_LABEL;echo $device_TYPE
echo "is this device correct?"
read resp
if [[ $resp == "y" ]]; then
break;
else 
unset device_UUID
continue
fi
done
if [[ -z $device_UUID ]]; then echo "device not found, valid search options are";echo "device path,UUID,PARTUUID,LABEL"; return 0; fi



device_UUID=$(echo $device_UUID | cut -c 6- );
dest_drive="/dev/disk/by-uuid/"$device_UUID
#
mkdir /mnt/usb_root > /dev/null 2>&1
mount $dest_drive /mnt/usb_root;
chk_mnt=$(mount | grep /mnt/usb_root)
if [[ -z $chk_mnt ]]; then
echo 'Failed to mount our destination drive';
echo 'ethier the drive isnt attached or this script needs updateing';
#umount /mnt/usb_root && rm /mnt/usb_root
exit
fi

if [[ -f /mnt/usb_root/boot/grub/grub.cfg ]];then
echo "grub.cfg found on our destination drive,"
echo "do you wish to preserve this file? y/n"
read preserve_grub
if [[ $preserve_grub == "y" ]]; then
cp /mnt/usb_root/boot/grub/grub.cfg /tmp/grub.cfg
fi
fi
echo "Starting Sync of $root to $dest_drive"
rsync -avHAX --delete --info=progress2 --exclude "/images" --exclude "backup" --exclude "fstab" --exclude "grub.cfg" --exclude "/media/*" --exclude "/sys/*" --exclude "/proc/*" --exclude "/tmp/*" --exclude "/dev/*" --exclude "/run/*" --exclude "/mnt/*" --exclude "/home/*" --exclude "/containers/*" --exclude "/swap/*" --exclude "/var/log" / /mnt/usb_root;
#Sync some barebones user data
#
rsync -avHAX --delete --exclude "containers" --exclude "swap" --exclude "android-ndk" --exclude "android-sdk" --exclude "swap*" --exclude "Movies" --exclude "Games" --exclude "backup" --exclude "Downloads" --exclude "Pictures" --exclude ".cache" --exclude ".thumbnails" --exclude ".mozilla" --exclude "seagate"  /home/ /mnt/usb_root/home

echo "Would you like to install a bootloader? y/n"
read resp
if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
#Set-up bootloader
arch-chroot /mnt/usb_root/ genfstab -U / > /mnt/usb_root/etc/fstab
part=$(mount |grep /mnt/usb_root|awk '{print $1}')
disk=$(mount |grep /mnt/usb_root|awk '{print $1}'|rev|cut -b 2-|rev)
disk_pcheck=$(echo $disk|rev|cut -b -1)
if [[ $disk_pcheck == 'p' ]]; then
disk=$(echo $disk|rev|cut -b 2-|rev);
fi
arch-chroot /mnt/usb_root/ grub-mkconfig -o /mnt/usb_root/boot/grub/grub.cfg
grub-install --force --no-floppy --boot-directory=/mnt/usb_root/boot/grub/ $disk
fi
if [[ $preserve_grub == "y" ]]; then
mv /tmp/grub.cfg /mnt/usb_root/boot/grub/grub.cfg
fi



pacman -Ql | awk '{print $1}' > /tmp/packages.list.tmp && cat /tmp/packages.list.tmp|sort -u > /tmp/packages.list && mv /tmp/packages.list /packages.list && rm /tmp/packages.list.tmp


echo "Would you like to alter the configuration the new install? y/n"
read resp
if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then

  echo "Would you like to disable autologin? y/n"
    read resp
  if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
    rm /mnt/usb_root/etc/systemd/system/getty@tty1.service.d/override.conf
  fi
  echo ""
  echo ""
  echo ""
  echo "Would you like to change the hostname? y/n"
    read resp
  if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
    echo "Enter new hostname?"
    read hostname
    if [[ -z $hostname ]];then hostname="Arch-2019"; fi
    #Hostname update
    sudo echo $hostname > /mnt/usb_root/etc/hostname
    rm /tmp/hosts_update >/dev/null 2>&1
    while IFS='' read -r line || [[ -n "$line" ]]; do
    hostname=$(echo $line|awk '{print $2}')
    address=$(echo $line|awk '{print $1}')
    if [[ "$hostname" == "laptop01" ]];then
    echo $address" "$hostname >> /tmp/hosts_update
    else
    echo $line >> /tmp/hosts_update
    fi
    done < "/mnt/usb_root/etc/hosts"
    rm /mnt/usb_root/etc/hosts && mv /tmp/hosts_update /mnt/usb_root/etc/hosts
  fi
  echo ""
  echo ""
  echo ""
  echo "Would you like to alter user accounts? y/n"
    read resp
  if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then

    for user in $(cat /etc/passwd|grep -v "/bin/false\|/sbin/nologin"|grep "/usr/bin/sh\|/bin/bash\|/usr/bin/zsh"|awk '{print $1}')
    do
    user=$(echo $user|cut -d ':' -f1)

    echo ""
    echo ""
    echo "User Account: $user"
    echo "[Options]"
    echo  "l(Lock account)"
    echo  "b(Remove password)"
    echo  "r(Reset password now)"
    echo  "us(Reset password on first boot)"
    read options
    case  $options  in
             "b")
    arch-chroot /mnt/usb_root/ passwd -d $user >/dev/null 2>&1
        [[ "$?" == "1" ]] && echo "Something went wrong with the last command" || echo "Removed Password for $user"
    ;;
             "l")
    arch-chroot /mnt/usb_root/ usermod -L $user >/dev/null 2>&1
        [[ "$?" == "1" ]] && echo "Something went wrong with the last command" || echo "Locked $user account"
    ;;
             "r")
    arch-chroot /mnt/usb_root/ passwd $user >/dev/null 2>&1
    [[ "$?" == "1" ]] && echo "Something went wrong with the last command" || echo "Reset password for $user"
    ;;
             "us")
    arch-chroot /mnt/usb_root/ passwd -d $user >/dev/null 2>&1
    echo "echo 'Please set password for root.'" >> /mnt/usb_root/pre-config
    echo "passwd root" >> /mnt/usb_root/pre-config
    [[ "$?" == "1" ]] && echo "Something went wrong with the last command" || echo "First login will be asked to set the password for $user"
    ;;
              "")
              echo "$user account left unchanged"
;;
    esac
    done
  fi


echo "Would you like to enable/disable services? y/n"
  read resp
  if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then

    echo "Would you like to enable firewalld.service? y/n/enter"
    echo "y(enables service)  n(disables Service)  no_input(leaves it as is)"
    echo "note that by doing so you will have to configure the rules for the following remote services."
      read resp
    if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
      arch-chroot /mnt/usb_root/ systemctl enable firewalld.service
    elif [[ $resp == "n" ]]; then
      arch-chroot /mnt/usb_root/ systemctl disable firewalld.service
    fi
echo "Would you like to enable sshd.service? y/n/enter"
echo "y(enables service)  n(disables Service)  no_input(leaves it as is)"
  read resp
if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
  arch-chroot /mnt/usb_root/ systemctl enable sshd.service
elif [[ $resp == "n" ]]; then
  arch-chroot /mnt/usb_root/ systemctl disable sshd.service
fi
echo "Would you like to enable x11vnc.service? y/n/enter"
echo "y(enables service)  n(disables Service)  no_input(leaves it as is)"
  read resp
if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
  arch-chroot /mnt/usb_root/ systemctl enable x11vnc.service
elif [[ $resp == "n" ]]; then
  arch-chroot /mnt/usb_root/ systemctl disable x11vnc.service
fi

echo "Would you like to enable lighttpd.service? y/n/enter"
echo "y(enables service)  n(disables Service)  no_input(leaves it as is)"
  read resp
if [[ $resp == "y" ]] || [[ $resp == "Y" ]] ; then
  arch-chroot /mnt/usb_root/ systemctl enable lighttpd.service
elif [[ $resp == "n" ]]; then
  arch-chroot /mnt/usb_root/ systemctl disable lighttpd.service
fi


fi #finished asking about services


if [[ -f /mnt/usb_root/pre-config ]]; then
  echo '#if [[ ! -z $(ps -aux|grep /pre-config) ]];then exit;fi'>/mnt/usb_root/pre-config.new;
  echo "echo '---------------------------------------------------------------------'">> /mnt/usb_root/pre-config.new;
  echo "echo 'Running initial boot configurations tasks.';">> /mnt/usb_root/pre-config.new;
  echo "echo '---------------------------------------------------------------------'">> /mnt/usb_root/pre-config.new;
  echo "neofetch;sleep 5">> /mnt/usb_root/pre-config.new;
  cat /mnt/usb_root/pre-config >> /mnt/usb_root/pre-config.new && mv /mnt/usb_root/pre-config.new /mnt/usb_root/pre-config;
  echo "echo 'enter a user account to enable autologin or press enter to disable'" >> /mnt/usb_root/pre-config;
  echo "read useracc "  >> /mnt/usb_root/pre-config;
  echo 'sys_user=$(cat /etc/passwd | grep $useracc);'  >> /mnt/usb_root/pre-config;
  echo 'if [[ -z "$sys_user" ]];then echo $useracc" Account not found, disableing autologin.";sudo rm /etc/systemd/system/getty@tty1.service.d/override.conf'  >> /mnt/usb_root/pre-config;
  echo 'else '  >> /mnt/usb_root/pre-config;
  echo 'echo "[Service]" > /tmp/override.conf'>> /mnt/usb_root/pre-config;
  echo 'echo "ExecStart=" >> /tmp/override.conf'>> /mnt/usb_root/pre-config;
  echo 'echo "ExecStart=-/usr/bin/agetty --autologin $useracc --noclear %I $TERM" >> /tmp/override.conf'>> /mnt/usb_root/pre-config;
  echo 'sudo rm /etc/systemd/system/getty@tty1.service.d/override.conf'>> /mnt/usb_root/pre-config;
  echo 'sudo mv /tmp/override.conf /etc/systemd/system/getty@tty1.service.d/override.conf && echo "Autologin Updated"'>> /mnt/usb_root/pre-config;
  echo 'fi'  >> /mnt/usb_root/pre-config;
  echo 'systemctl enable ospreconfig_tidy.service' >> /mnt/usb_root/pre-config;
  echo "echo 'Rebooting Now!' "  >> /mnt/usb_root/pre-config;
  echo 'sleep 4'>> /mnt/usb_root/pre-config;
  echo 'rm /pre_config;'>> /mnt/usb_root/pre-config;
  echo "reboot"  >> /mnt/usb_root/pre-config;
  chmod +x /mnt/usb_root/pre-config;
  arch-chroot /mnt/usb_root/ useradd -m ospreconfig
  #mkdir /mnt/usb_root/home/ospreconfig >/dev/null 2>&1
  echo "sudo /pre-config" >> /mnt/usb_root/home/ospreconfig/.bashrc
  chmod +x /mnt/usb_root/home/ospreconfig/.bashrc;
  echo '[Service]' > /mnt/usb_root/etc/systemd/system/getty@tty1.service.d/override.conf
  echo 'ExecStart=' >> /mnt/usb_root/etc/systemd/system/getty@tty1.service.d/override.conf
  echo 'ExecStart=-/usr/bin/agetty --autologin ospreconfig --noclear %I $TERM' >> /mnt/usb_root/etc/systemd/system/getty@tty1.service.d/override.conf


  echo 'systemctl disable ospreconfig_tidy.service' > /mnt/usb_root/pre_config_tidy;
  echo 'userdel -f -r ospreconfig' >> /mnt/usb_root/pre_config_tidy;
  echo 'rm /pre_config_tidy' >> /mnt/usb_root/pre_config_tidy;
  echo 'rm /pre-config' >> /mnt/usb_root/pre_config_tidy;
  echo 'rm /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service'>> /mnt/usb_root/pre_config_tidy;
  chmod +x /mnt/usb_root/pre_config_tidy;
  echo '[Unit]' > /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'Description=Removes pre config user account and this supposvdly this service' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'After=network.target' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'StartLimitIntervalSec=0' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo '[Service]' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'Type=simple' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'Restart=never' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'User=root' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'ExecStart=/pre_config_tidy' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo '[Install]' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service
  echo 'WantedBy=multi-user.target' >> /mnt/usb_root/lib/systemd/system/ospreconfig_tidy.service

fi

fi #finished altering config



#umount /boot
umount /mnt/usb_root;
return=$(mount|grep '/mnt/usb_root')
if [[ -z /mnt/usb_root ]]; then
rm -rf /mnt/usb_root;
fi

echo "Tranfer complete at $(date)"
