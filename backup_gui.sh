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
elif [[ -z $(echo $backdest|rev|cut -d "/" -f1|rev) ]]; then
backdest=$(echo $backdest|rev|cut -d "/" -f2-|rev)
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

if [[ ! -z $DISPLAY ]]; then
title=$(echo $0 | rev|cut -d "/" -f1|rev)

zenity --progress --pulsate --title="$title" --text="Prepareing to backup" --auto-kill & zenity_PID=$!
sleep 1 && wmctrl -p "$title" -b add,above &
fi


case  $type  in
         "1")
type="OS"

backupfile="$backdest/$pc-$type-$date.tar.gz"

start_time=$(date)
echo -ne "backup started ";echo $start_time


backup_dir="/"

exclude_dirs="/var/log/* seagate backups* /share /containers/* /mnt/* /tmp/* /dev/* /proc/* /sys/* /run/* /media/* /swap/* /home/* "$backupfile" \
/tmp/temp.txt"
exclude_size=0
for OUTPUT in $(echo $exclude_dirs|tr " " "\n")
do
  if [[ "$(echo $OUTPUT|rev|cut -d "/" -f1 |rev)" == "*" ]];then
  output_T=$(echo $OUTPUT|rev|cut -d "/" -f2-|rev)
  exclude_size_tmp=$(du -d 0 -m  $output_T 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
else
  exclude_size_tmp=$(du -d 0 -m  $OUTPUT 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
fi

  exclude_list=$exclude_list" --exclude=$OUTPUT"
done

if [[ ! -z $DISPLAY ]]; then
  output_log="/tmp/tar"$RANDOM".log"
  title=$(echo $0 | rev|cut -d "/" -f1|rev)
  function finish { kill -9 $tar_pid; kill -9 $pkg_infopid; zenity --no-wrap --error --title=$title --text="Backup Cancelled before it completed, Cleaning up.";rm -f $backupfile;rm $output_log;}
  trap finish EXIT
  cd / && "$my_path/pkg_info" -b  & pkg_infopid=$! ; cd $my_workdir;
  tar $exclude_list --xattrs -czpvf $backupfile $backup_dir >$output_log & tar_pid=$!
  kill $zenity_PID
  sleep 1 && wmctrl -p "Progress Status" -b add,above &
  (

  while [[ ! -z $(ps -aopid|grep $tar_pid) ]];do
  curr_file=$(cat $output_log|tail -1)
  p_output=$((100 * $(du -m $backupfile|tail -1|awk '{print $1}') ));
  backup_dirS=$(($(du -m $backup_dir |tail -1|awk '{print $1}') - $exclude_size))
  p_output=$(( $p_output / $backup_dirS ))
#  if [[ ! -z $(ps -aopid|grep $pkg_infopid 2>/dev/null) ]];then
#    echo "#[*Generating package list] \n"$curr_file;sleep 2
  #  echo "10"
  #else
  echo "#"$curr_file;sleep 2
  echo $(($p_output + 10))
  #fi
  done
  echo "#Backup Complete";sleep 2
  echo "100"
  ) | zenity --progress --title=$title --text="Starting Backup" --percentage=0 --auto-kill --auto-close
    (( $? !=0 )) && zenity --error --title=$title --text="Error in zenity command"
  function finish { zenity --info --title=$title --text="backup complete" --no-wrap;rm $output_log;}

else
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;


sudo tar $exclude_list --xattrs -czpvf $backupfile $backup_dir
fi
;;

         "2")
type="Config"
backupfile="$backdest/$pc-$type-$date.tar.gz"
backup_dir="/"
start_time=$(date)
echo -ne "backup started ";echo $start_time
#build exclude list
#
exclude_size=0
for OUTPUT in $(ls -x1 / | grep -v var | grep -v etc )
do
  exclude_size_tmp=$(du -d 0 -m  $backup_dir$OUTPUT 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
	exclude_list=$exclude_list" --exclude=/$OUTPUT"
done
#

if [[ ! -z $DISPLAY ]]; then
  output_log="/tmp/tar"$RANDOM".log"
  title=$(echo $0 | rev|cut -d "/" -f1|rev)
  function finish { kill -9 $tar_pid; kill -9 $pkg_infopid;zenity --no-wrap --error --title=$title --text="Backup Cancelled before it completed, Deleting incomplete backup.";rm -f $backupfile;rm $output_log;}
  trap finish EXIT
  cd / && "$my_path/pkg_info" -b  & pkg_infopid=$! ; cd $my_workdir;
  tar $exclude_list --exclude=/var/cache --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir >$output_log & tar_pid=$!
  kill $zenity_PID
  sleep 1 && wmctrl -p "$title" -b add,above &
  (

  while [[ ! -z $(ps -aopid|grep $tar_pid) ]];do
    curr_file=$(cat $output_log|tail -1)
    p_output=$((100 * $(du -m $backupfile|tail -1|awk '{print $1}') ));
    backup_dirS=$(($(du -m $backup_dir |tail -1|awk '{print $1}') - $exclude_size))
    p_output=$(( $p_output / $backup_dirS ))
    if [[ ! -z $(ps -aopid|grep $pkg_infopid 2>/dev/null) ]];then
        echo "#[*Generating package list] \n"$curr_file;sleep 2
        echo "10"
      else
      echo "#"$curr_file;sleep 2
      echo $(($p_output + 10))
    fi
  done
  echo "#Backup Complete";sleep 2
  echo "100"
  ) | zenity --progress --title=$title --text="Starting Backup" --percentage=0 --auto-kill #--auto-close
  (( $? !=0 )) && zenity --error --title=$title --text="Error in zenity command"
  function finish { zenity --info --title=$title --text="backup complete" --no-wrap;rm $output_log;}

else
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
tar $exclude_list --exclude=/var/cache --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir
fi

;;


         "3")
type="Home"
backupfile="$backdest/$pc-$type-$date.tar.gz"
backup_dir="/home"
start_time=$(date)
echo -ne "backup started ";echo $start_time

if [[ ! -z $DISPLAY ]]; then
  output_log="/tmp/tar"$RANDOM".log"
  title=$(echo $0 | rev|cut -d "/" -f1|rev)
  function finish { kill -9 $tar_pid; kill -9 $pkg_infopid;zenity --no-wrap --error --title=$title --text="Backup Cancelled before it completed, Deleting incomplete backup.";rm -f $backupfile;rm $output_log;}
  trap finish EXIT
  tar --exclude=backup* --exclude=seagate --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir>$output_log & tar_pid=$!
  kill $zenity_PID
  sleep 1 && wmctrl -p "$title" -b add,above &
  (

  while [[ ! -z $(ps -aopid|grep $tar_pid) ]];do
    curr_file=$(cat $output_log|tail -1)
    p_output=$((100 * $(du -m $backupfile|tail -1|awk '{print $1}') ));
    backup_dirS=$(($(du -m $backup_dir |tail -1|awk '{print $1}') - $exclude_size))
    p_output=$(( $p_output / $backup_dirS ))
    if [[ ! -z $(ps -aopid|grep $pkg_infopid 2>/dev/null) ]];then
        echo "#[*Generating package list] \n"$curr_file;sleep 2
        echo "10"
      else
      echo "#"$curr_file;sleep 2
      echo $(($p_output + 10))
    fi
  done
  echo "#Backup Complete";sleep 2
  echo "100"
  ) | zenity --progress --title=$title --text="Starting Backup" --percentage=0 --auto-kill --auto-close
  (( $? !=0 )) && zenity --error --title=$title --text="Error in zenity command"
  function finish { zenity --info --title=$title --text="backup complete" --no-wrap;rm $output_log;}

else

cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
tar --exclude=backup* --exclude=seagate --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir
fi


;;

         "4")
type="Containers"
backupfile="$backdest/$pc-$type-$date.tar.gz"
backup_dir="/containers"
start_time=$(date)
echo -ne "backup started ";echo $start_time

#build exclude list
#
for OUTPUT in $(ls -x1 / | grep -v containers)
do
	exclude_list=$exclude_list" --exclude=/$OUTPUT"
  exclude_size_tmp=$(du -d 0 -m  $backup_dir$OUTPUT 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
done

if [[ ! -z $DISPLAY ]]; then
  output_log="/tmp/tar"$RANDOM".log"
  title=$(echo $0 | rev|cut -d "/" -f1|rev)
  function finish { kill -9 $tar_pid; kill -9 $pkg_infopid;zenity --no-wrap --error --title=$title --text="Backup Cancelled before it completed, Deleting incomplete backup.";rm -f $backupfile;rm $output_log;}
  trap finish EXIT
  tar $exclude_list --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir>$output_log& tar_pid=$!
  kill $zenity_PID
  sleep 1 && wmctrl -p "$title" -b add,above &
  (
  while [[ ! -z $(ps -aopid|grep $tar_pid) ]];do
    curr_file=$(cat $output_log|tail -1)
    p_output=$((100 * $(du -m $backupfile|tail -1|awk '{print $1}') ));
    backup_dirS=$(($(du -m $backup_dir |tail -1|awk '{print $1}') - $exclude_size))
    p_output=$(( $p_output / $backup_dirS ))
    if [[ ! -z $(ps -aopid|grep $pkg_infopid 2>/dev/null) ]];then
        echo "#[*Generating package list] \n"$curr_file;sleep 2
        echo "10"
      else
      echo "#"$curr_file;sleep 2
      echo $(($p_output + 10))
    fi
  done
  echo "#Backup Complete";sleep 2
  echo "100"
  ) | zenity --progress --title=$title --text="Starting Backup" --percentage=0 --auto-kill --auto-close
  (( $? !=0 )) && zenity --error --title=$title --text="Error in zenity command"
  function finish { zenity --info --title=$title --text="backup complete" --no-wrap;rm $output_log;}
else
cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
tar $exclude_list --exclude="$backupfile" --xattrs -czpvf $backupfile $backup_dir
fi
;;

         "5")
type="Full"
backup_dir="/"
backupfile="$backdest/$pc-$type-$date.tar.gz"
start_time=$(date)
echo -ne "backup started ";echo $start_time


exclude_dirs="/var/log/* seagate backup* /share /containers/* /mnt/* /tmp/* /dev/* /proc/* /sys/* /run/* /media/* /swap/* "$backupfile" \
/tmp/temp.txt"

exclude_size=0
for OUTPUT in $(echo $exclude_dirs|tr " " "\n")
do
  if [[ "$(echo $OUTPUT|rev|cut -d "/" -f1 |rev)" == "*" ]];then
  output_T=$(echo $OUTPUT|rev|cut -d "/" -f2-|rev)
  exclude_size_tmp=$(du -d 0 -m  $output_T 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
else
  exclude_size_tmp=$(du -d 0 -m  $OUTPUT 2>/dev/null|tail -1|awk '{print $1}')
  [[ -z $exclude_size_tmp ]] && exclude_size_tmp=0
  exclude_size=$(($exclude_size + $exclude_size_tmp))
fi

  exclude_list=$exclude_list" --exclude=$OUTPUT"
done


if [[ ! -z $DISPLAY ]]; then
  output_log="/tmp/tar"$RANDOM".log"
  title=$(echo $0 | rev|cut -d "/" -f1|rev)
  function finish { kill -9 $tar_pid; kill -9 $pkg_infopid;zenity --no-wrap --error --title=$title --text="Backup Cancelled before it completed, Deleting incomplete backup.";rm -f $backupfile;rm $output_log;}
  trap finish EXIT
  cd / && "$my_path/pkg_info" -b  & pkg_infopid=$! ; cd $my_workdir;
  tar $exclude_list --xattrs -czpvf $backupfile $backup_dir>$output_log& tar_pid=$!
  sleep 1 && wmctrl -p "$title" -b add,above &
  (
  while [[ ! -z $(ps -aopid|grep $tar_pid) ]];do
    curr_file=$(cat $output_log|tail -1)
    p_output=$((100 * $(du -m $backupfile|tail -1|awk '{print $1}') ));
    backup_dirS=$(($(du -m $backup_dir |tail -1|awk '{print $1}') - $exclude_size))
    p_output=$(( $p_output / $backup_dirS ))
    if [[ ! -z $(ps -aopid|grep $pkg_infopid 2>/dev/null) ]];then
        echo "#[*Generating package list] \n"$curr_file;sleep 2
        echo "10"
      else
      echo "#"$curr_file;sleep 2
      echo $(($p_output + 10))
    fi
  done
  echo "#Backup Complete";sleep 2
  echo "100"
  ) | zenity --progress --title=$title --text="Starting Backup" --percentage=0 --auto-kill --auto-close
  (( $? !=0 )) && zenity --error --title=$title --text="Error in zenity command"
  function finish { zenity --info --title=$title --text="backup complete" --no-wrap;rm $output_log;}

else

cd / && "$my_path/pkg_info" -b ; cd $my_workdir;
tar $exclude_list--xattrs -czpvf $backupfile $backup_dir
fi
;;
esac

#backupfile="$backdest/$pc-$type-$date.tar.gz"
#start_time=$(date)
#echo -ne "backup started ";echo $start_time
#sudo tar --exclude-from=$exclude_file --xattrs -czpvf $backupfile /
echo -ne "Backup of $type saved to $backupfile"
echo -ne "backup started at ";echo $start_time
echo -ne "backup finished at ";echo $(date)
