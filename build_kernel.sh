#!/bin/bash

TARGET=/efi/EFI/Arch
BOOTDIR=/boot
UCODE=$BOOTDIR/intel-ucode.img
EFISTUB=/usr/lib/systemd/boot/efi/linuxx64.efi.stub
SECURE_BOOT=1
SECURE_BOOT_KEY=/etc/efi-keys

echo "Updating EFI kernels..."

for k in $BOOTDIR/vmlinuz*; do
	NAME=$(basename $k|sed 's/vmlinuz-//')
	echo "  Building $NAME"
	INITRD="$BOOTDIR/initramfs-$NAME.img"

	if [ -f "$UCODE" ]; then
		cat "$UCODE" "$INITRD" > /tmp/initrd.bin
		INITRDFILE=/tmp/initrd.bin
	else
		# Do not fail on AMD systems
		echo "    Intel microcode not found. Skipping."
		INITRDFILE="$INITRD"
	fi

	# Check for custom command line for the kernel.
	CMDLINE="$BOOTDIR/cmdline-$NAME.txt"
	if [ -f "$CMDLINE" ]; then
		echo "    Using custom command line $CMDLINE"
	else
		CMDLINE="$BOOTDIR/cmdline.txt"
		if [ ! -f "$CMDLINE" ]; then
			echo "CMDLINE missing. Extracting from running kernel..."
			cat /proc/cmdline |sed 's/BOOT_IMAGE=[^ ]* \?//' > "$CMDLINE"
		fi
	fi

	objcopy \
	    --add-section .osrel="/usr/lib/os-release" --change-section-vma .osrel=0x20000 \
	    --add-section .cmdline="$CMDLINE" --change-section-vma .cmdline=0x30000 \
	    --add-section .linux="$k" --change-section-vma .linux=0x40000 \
	    --add-section .initrd="$INITRDFILE" --change-section-vma .initrd=0x3000000 \
	    "$EFISTUB" "$TARGET/$NAME.efi"

	if [ $SECURE_BOOT -ne 0 ]; then
		sbsign --key $SECURE_BOOT_KEY/DB.key --cert $SECURE_BOOT_KEY/DB.crt --output "$TARGET/$NAME.efi" "$TARGET/$NAME.efi"
	fi
done
