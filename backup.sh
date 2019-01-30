#!/bin/bash
# full system backup
if [ ! $UID = 0 ]; then echo "Root required"; exit 1; fi
my_path=$(readlink -f $0|rev|cut -d "/" -f 2- |rev);
my_workdir=$(pwd);

# Backup destination
echo "were do you want to put the backup?";
read backdest
if [[ -z backdest ]]; then
backdest=$(pwd)
fi


# Labels for backup name
#PC=${HOSTNAME}
echo "what do you want to label the backup?";
read pc
if [[ -z $pc ]]; then
pc=$(uname -a | awk '{print $2}')
fi
distro=$(uname -a | awk '{print $3}')
date=$(date "+%F_%H")

echo "please select the kind of backup do you want to do?";
echo "1. Full OS";
echo "2. OS Config";
echo "3. Home drives";
echo "4. Containers";
echo "5. Complete";
read type


case  $type  in
         "1")
type="OS"
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time
#Monitor window
if [[ -f $my_path/backup_monitor ]];then
xterm -bg black -fg cyan -geometry  60x10 -e "transset-df -a;$my_path/backup_monitor / $backupfile" &
fi
#
sudo tar --exclude=/var/log/* --exclude=seagate --exclude=backup* --exclude=/share --exclude=/containers/* --exclude=/mnt/* --exclude=/tmp/* --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/run/* \
--exclude=/media/* --exclude=/swap/* --exclude=/home/* --exclude="$backupfile" --xattrs -czpvf $backupfile /
;;

         "2")
type="Config"
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time

#build exclude list
#
for OUTPUT in $(ls -x1 / | grep -v var | grep -v etc )
do
	exclude_list=$exclude_list" --exclude=/$OUTPUT"
done
#
sudo tar $exclude_list --exclude=/var/cache --exclude="$backupfile" --xattrs -czpvf $backupfile /
;;


         "3")
type="Home"
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time
#Monitor window
if [[ -f $my_path/backup_monitor ]];then
xterm -bg black -fg cyan -geometry  60x10 -e "transset-df -a;$my_path/backup_monitor /home $backupfile" &
fi
#
sudo tar --exclude=backup* --exclude=seagate --exclude="$backupfile" --xattrs -czpvf $backupfile /home/
;;

         "4")
type="Containers"
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time

#build exclude list
#
for OUTPUT in $(ls -x1 / | grep -v containers)
do
	exclude_list=$exclude_list" --exclude=/$OUTPUT"
done
#Monitor window
if [[ -f $my_path/backup_monitor ]];then
xterm -bg black -fg cyan -geometry  60x10 -e "transset-df -a;$my_path/backup_monitor /containers $backupfile" &
fi
#
sudo tar $exclude_list --exclude="$backupfile" --xattrs -czpvf $backupfile /containers
;;

         "5")
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
type="Full"
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time
#Monitor window
if [[ -f $my_path/backup_monitor ]];then
xterm -bg black -fg cyan -geometry  60x10 -e "transset-df -a;$my_path/backup_monitor / $backupfile" &
fi
#
sudo tar --exclude=/var/log/* --exclude=seagate --exclude=backup* --exclude=/share --exclude=/mnt/* --exclude=/tmp/* --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* --exclude=/run/* \
--exclude=/media/* --exclude=/swap/* --exclude="$backupfile" --xattrs -czpvf $backupfile /
;;
esac

#backupfile="$backdest/$pc-$type-$date.tar.gz"
#start_time=$(date)
#echo -ne "backup started ";echo $start_time
#sudo tar --exclude-from=$exclude_file --xattrs -czpvf $backupfile /
echo -ne "Backup of $type saved to $backupfile"
echo -ne "backup started at ";echo $start_time
echo -ne "backup finished at ";echo $(date)
