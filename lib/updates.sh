#!/bin/bash

# Funcions : update_rootfs

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

	cat > "$DEST/update_post-install_systemctl" <<EOF
# Post-install update systemctl services
#systemctl disable networking.service
#systemctl disable NetworkManager-wait-online.service
systemctl disable zram-config.service
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
