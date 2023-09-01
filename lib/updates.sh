#!/bin/bash

# Funcions : update_rootfs, update_wifi

update_rootfs() {
	# Add qemu emulation.

       if [ $ARCH = "arm64" ]; then
               cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin"
       elif [ $ARCH = "arm" ]; then
               	cp /usr/bin/qemu-arm-static "$DEST/usr/bin"
       fi

 	# if [[ ! -f /proc/sys/fs/binfmt_misc/arm ]]; then
		# echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:CF' > /proc/sys/fs/binfmt_misc/register
	# fi
	chroot "$DEST" mount -t proc proc /proc || true
	chroot "$DEST" mount -t sysfs sys /sys || true
	mkdir "$DEST/updates"
        cp $UPDATES/*.deb "$DEST/updates"
	cd "$DEST/updates"
	for f in *.deb; do
  		echo "Update package -> /updates/$f";
                chroot "$DEST" dpkg --install "/updates/$f"
	done
	rm -r "$DEST/updates"
	cat > "$DEST/update_post-install_openssl" <<EOF
# Post-install for openssl 1.1.1v
echo "/usr/local/ssl/lib" > /etc/ld.so.conf.d/openssl-1.1.1v.conf
ldconfig -v
#mv /usr/bin/c_rehash /usr/bin/c_rehash.backup
#mv /usr/bin/openssl /usr/bin/openssl.backup
sed -e 's|PATH="\(.*\)"|PATH="/usr/local/ssl/bin:\1"|g' -i /etc/environment
EOF
	chmod +x "$DEST/update_post-install_openssl"
	chroot "$DEST" /update_post-install_openssl
	rm "$DEST/update_post-install_openssl"

	cp $UPDATES/init-zram-swapping-orangepi3g "$DEST/usr/bin"
	chmod +x "$DEST/usr/bin/init-zram-swapping-orangepi3g"
	cp $UPDATES/end-zram-swapping-orangepi3g "$DEST/usr/bin"
	chmod +x "$DEST/usr/bin/end-zram-swapping-orangepi3g"

	cat > "$DEST/update_post-install_systemctl" <<EOF
# Post-install update systemctl services
#systemctl disable networking.service
#systemctl disable NetworkManager-wait-online.service
systemctl disable zram-config.service
sed -i 's/init-zram-swapping/init-zram-swapping-orangepi3g/g' /lib/systemd/system/zram-config.service
sed -i 's/end-zram-swapping/end-zram-swapping-orangepi3g/g' /lib/systemd/system/zram-config.service
systemctl enable zram-config.service
EOF
        chmod +x "$DEST/update_post-install_systemctl"
        chroot "$DEST" /update_post-install_systemctl
        rm "$DEST/update_post-install_systemctl"

	chroot "$DEST" umount /sys
	chroot "$DEST" umount /proc

	# echo -1 > /proc/sys/fs/binfmt_misc/arm

	# Clean up
	rm -f "$DEST/usr/bin/qemu-arm-static"

}

update_wifi(){
IMAGE_UPDATE="${BUILD}/images"
cd ${IMAGE_UPDATE}
for f in */; do
    if [ -f ${IMAGE_UPDATE}/${f}rootfs.img ]; then
	# Get SSID and PASSWORD of Wifi conection.
	#read -p 'SSID: ' SSID
        SSID=$(whiptail --inputbox "Enter SSID" 10 30 3>&1 1>&2 2>&3)
        #read -sp 'Password: ' SSID_PASS
        SSID_PASS=$(whiptail --passwordbox "Enter password" 10 30 3>&1 1>&2 2>&3)

        if [ ! -d /media/tmp ]; then
           mkdir -p /media/tmp
        fi

	mount -t ext4 ${IMAGE_UPDATE}/${f}rootfs.img /media/tmp

        #Add Wifi info into Image
        sed -i "s/^wpa-ssid .*$/wpa-ssid $SSID/g" /media/tmp/etc/network/interfaces
        sed -i "s/^wpa-psk .*$/wpa-psk $SSID_PASS/g" /media/tmp/etc/network/interfaces
        umount /media/tmp

        #cd ${BUILD}/images
	IMAGE_FILE=$(echo $f | sed 's#/##g')
	if [ -f ${IMAGE_FILE}.tar.gz ]; then
		rm ${IMAGE_FILE}.tar.gz
	fi
        tar -cvzf ${IMAGE_FILE}.tar.gz ${IMAGE_FILE}
    else
	whiptail --title "OrangePi Build System" --msgbox "Error changing wifi info." \
                        10 40 0 --ok-button Continue
	exit -1
    fi
done
}
