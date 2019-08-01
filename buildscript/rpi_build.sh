#!/bin/bash
{
log () {
          echo -e "\e[32m["$(date +'%T' )"]  \e[1m $1 \e[0m " #| tee -a "${LOG_FILE}"
}



thisArch=RPi-ARMv6
imageSource="https://dietpi.com/downloads/images/"
zipName="DietPi_RPi-ARMv6-Buster.7z"
imageName="DietPi_v6.25_RPi-ARMv6-Buster.img"
dietPiRepo="https://github.com/MichaIng/DietPi"
dietPiBranch="dev"

DBOOTmirror="http://archive.raspbian.org/raspbian"
DBOOTinclude="net-tools,isc-dhcp-client,nano,openssh-server,rsync,wget"
DBOOTaptsources="deb http://archive.raspbian.org/raspbian stretch main contrib non-free\ndeb-src http://archive.raspbian.org/raspbian stretch main contrib non-free"



# Create caching folder hierarchy to work with this architecture
mkdir -p ./cache/$thisArch
mkdir -p ./work/$thisArch
mkdir -p ./work/$thisArch/rootfs
mkdir -p ./work/$thisArch/bootfs
mkdir -p ./release/$thisArch



# Check dependency Needed to shrink the image size at the end.
if [ ! -f ./cache/pishrink.sh ] ; then
        log "Downloading pishrink"
        cd ./cache
        wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
        chmod +x pishrink.sh
        cd ..
else
        log "Using pishrink from cache"

fi



# Check dietPi repo cache.
if [ ! -d ./cache/DietPi/.git ] ; then
        log "Downloading dietPi repository"
        cd ./cache
        git clone $dietPiRepo
        cd ./DietPi
        git checkout $dietPiBranch
        cd ../../

else
        log "Updating dietPi repository"
        cd ./cache/DietPi/
        git checkout $dietPiBranch
        git pull
        cd ../../

fi



# Download or copy the official image from cache
if [ ! -f ./cache/$thisArch/$imageName ]; then
        log "Downloading image from internet"
        wget -P ./cache/$thisArch/  $imageSource/$zipName
        7z e -o./cache/$thisArch/   ./cache/$thisArch/$zipName
        rm ./cache/$thisSbc/$zipName ./cache/$thisSbc/hash.txt ./cache/$thisSbc/README.txt

else
        log "Using image from cache"

fi



# expend dietpi image
if [ ! -f ./cache/$thisArch/$imageName-rdy2build ]; then
        log "Getting DietPi image ready to run in qemu and build "
        cp -fv ./cache/$thisArch/$imageName ./cache/$thisArch/$imageName-rdy2build
        truncate -s "5G" ./cache/$thisArch/$imageName-rdy2build
        partQty=$(sudo fdisk -l ./cache/$thisArch/$imageName-rdy2build | grep -e "^./cache/$thisArch/$imageName-rdy2build"|wc -l  )
        parted ./cache/$thisArch/$imageName-rdy2build --script "resizepart $partQty 100%" ;
        # cp -fv ./cache/$thisArch/$imageName-rdy2build ./work/$thisArch/$imageName

        # Mount the image and make the binds required to chroot.
        log "Mount Dietpi image"
        IFS=$'\n'
        kpartx -sa ./work/$thisArch/$imageName

        loop=$(losetup -j ./work/$thisArch/$imageName |  cut -d":" -f1 | sed "s/\/dev\/loop//g" )
        loop=$(echo "${loop[*]}" | sort -nr | head -n1)

        if [  -L "/dev/mapper/loop${loop}p2" ] ; then
                mount /dev/mapper/loop${loop}p2 ./work/$thisArch/rootfs/
                mount /dev/mapper/loop${loop}p1 ./work/$thisArch/rootfs/boot/

        else
                mount /dev/mapper/loop${loop}p1 ./work/$thisArch/rootfs/
        fi

        # Resize the root file system to fill the new drive size;
        log "Resize the root file system to fill the new drive size WITHOUT DEV PROC SYS"
        echo $partQty partitions detected.
        resize2fs /dev/mapper/loop${loop}p$partQty

        # Copy the lysmarine and dietpi config files in the mounted rootfs
        log "copying lysmarine and dietpi_configuration_script on the image"
        cp -r ../lysmarine ./work/$thisArch/rootfs/
        chmod 0775 ./work/$thisArch/rootfs/lysmarine/*.sh
        chmod 0775 ./work/$thisArch/rootfs/lysmarine/*/*.sh

        cp -rvf ./cache/DietPi/rootfs/*    ./work/$thisArch/rootfs/
        cp -rvf ./cache/DietPi/dietpi      ./work/$thisArch/rootfs/

        # Fix the no-dns problem due to the fact that services are not started.
        mv ./work/$thisArch/rootfs/etc/resolv.conf ./work/$thisArch/rootfs/etc/resolv.conf.lysmarinebak
        cp -vf /etc/resolv.conf ./work/$thisArch/rootfs/etc/resolv.conf

        #debootstrap
        log "Debootstraping."
        debootstrap --arch armhf --foreign --no-check-gpg --include $DBOOTinclude buster ./work/$thisArch/rootfs/ $DBOOTmirror
        cp -v /usr/bin/qemu-arm-static "./work/$thisArch/rootfs/usr/bin"

        #Unmount.
	log "Unmount Dietpi image"
        umount ./work/$thisArch/bootfs
        umount ./work/$thisArch/rootfs

else
        log "Using Ready to build image from cache"
fi



cp -fv ./cache/$thisArch/$imageName-rdy2build ./work/$thisArch/$imageName



# Mount the image and make the binds required to chroot.
log "Mount Dietpi image"
IFS=$'\n'
kpartx -sa ./work/$thisArch/$imageName

loop=$(losetup -j ./work/$thisArch/$imageName |  cut -d":" -f1 | sed "s/\/dev\/loop//g" )
loop=$(echo "${loop[*]}" | sort -nr | head -n1)

if [  -L "/dev/mapper/loop${loop}p2" ] ; then
        mount /dev/mapper/loop${loop}p2 ./work/$thisArch/rootfs/
        mount /dev/mapper/loop${loop}p1 ./work/$thisArch/rootfs/boot/

else
        mount /dev/mapper/loop${loop}p1 ./work/$thisArch/rootfs/
fi

mount --bind /dev  ./work/$thisArch/rootfs/dev/
#mount --bind /dev ./work/$thisArch/rootfs/dev/pts
mount --bind /sys  ./work/$thisArch/rootfs/sys/
mount --bind /proc ./work/$thisArch/rootfs/proc/

cp -vf /etc/resolv.conf ./work/$thisArch/rootfs/etc/resolv.conf
mv ./work/$thisArch/rootfs/etc/resolv.conf ./work/$thisArch/rootfs/etc/resolv.conf.lysmarinebak






# chroot into the mounted image.
log "chroot into the image"

echo "";echo "";echo "";echo "";echo "";
echo "========================================================================="
echo "You are now in the chroot environement.";
echo "Start the build script with by pasting the following line in the terminal:";
echo "";
echo "export ARCH=$thisArch ;cd /lysmarine; ./build.sh 00 10 50 51 55 98; exit"
echo "";
echo "========================================================================="
echo "";echo "";

cmds='/bin/bash -e ' # drop to shell prompt
sudo proot -r ./work/$thisArch/rootfs -q qemu-arm -S ./work/$thisArch/rootfs ;

sed -i 's/^#//g' ./work/$thisArch/rootfs/etc/ld.so.preload



# The file transfer is done now, unmouting
mv ./work/$thisArch/rootfs/etc/resolv.conf.lysmarinebak ./work/$thisArch/rootfs/etc/resolv.conf



# Unmount the image
umount ./work/$thisArch/rootfs/dev/
umount ./work/$thisArch/rootfs/sys/
umount ./work/$thisArch/rootfs/proc/
#  umount $ROOTFS/dev/pts
umount ./work/$thisArch/bootfs
umount ./work/$thisArch/rootfs
kpartx -d ./work/$thisArch/$imageName
log "Image UNmounted"



# Shrink the image size.
# ./cache/pishrink.sh ./work/$thisArch/$image



# Renaming the OS and moving it to the release folder.
cp -v ./work/$thisArch/$imageName  ./release/$thisArch/LysMarine_$thisArch-0.9.0.img
log "DONE."

# echo "cp -fv ./work/$thisArch/$imageName ./cache/$thisArch/$imageName-rdy2build" 

}; exit
