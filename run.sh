#!/bin/bash
set -eEuo pipefail

function build_kernel() {
	local kernel_build_id="$kernel_commit"-"$self_sha1"
	kernel_binary="$cache_dir"/linux-"$kernel_build_id"
	if [[ ! -e "$kernel_binary" ]]
	then
		# Download source code
		local kernel_src_dir=$top/src/linux-$kernel_commit
		if [[ ! -d "$kernel_src_dir" ]]
		then
			mkdir -p "$kernel_src_dir".tmp
			curl -fL https://github.com/kdave/btrfs-devel/archive/"$kernel_commit".tar.gz |
				tar zx -C "$kernel_src_dir".tmp --strip-components 1
			mv "$kernel_src_dir".tmp "$kernel_src_dir"
		fi

		# Configure
		rm -rf "$work_dir"/linux
		mkdir -p "$work_dir"/linux

		# shellcheck disable=SC2191
		local make_args=(
			make
			-C "$kernel_src_dir"
			ARCH=um
			O="$work_dir"/linux
		)
		"${make_args[@]}" x86_64_defconfig

		(
			echo 'CONFIG_BTRFS_FS=y'
			echo 'CONFIG_BTRFS_FS_POSIX_ACL=y'
			echo 'CONFIG_RAID6_PQ_BENCHMARK=y'
			echo 'CONFIG_LIBCRC32C=y'

			echo 'CONFIG_BTRFS_FS_CHECK_INTEGRITY=y'
			echo 'CONFIG_BTRFS_DEBUG=y'
			echo 'CONFIG_BTRFS_ASSERT=y'
			echo 'CONFIG_BTRFS_FS_REF_VERIFY=y'

			echo 'CONFIG_DEBUG_INFO=y'
		#	echo 'CONFIG_GDB_SCRIPTS=y'
		) >> "$work_dir"/linux/.config

		"${make_args[@]}" olddefconfig

		# Build
		"${make_args[@]}" -j"$(nproc)"

		cp "$work_dir"/linux/vmlinux "$kernel_binary"
	fi
}

function build_image() {
	rm -rf "$work_dir"/root
	mkdir -p "$work_dir"/root

	local image_build_id="$image_arch_date"-"$self_sha1"
	image="$cache_dir"/image-"$image_build_id"
	if [[ ! -f "$image" ]]
	then
		# debootstrap has a hard requirement on root, so we can't use Debian.
		# Instead use Arch Linux, for which fakeroot and fakechroot suffice.
		WORK_DIR="$work_dir" ARCH_DATE="$image_arch_date" IMAGE="$image" FAKECHROOT_EXCLUDE_PATH=/dev:/proc:/sys fakeroot bash -s <<-'IMAGEEOF'
			set -xeEuo pipefail
			curl "https://archive.archlinux.org/iso/$ARCH_DATE/archlinux-bootstrap-$ARCH_DATE-x86_64.tar.gz" |
				tar zxv -C "$WORK_DIR"/root

			fakechroot --elfloader "$WORK_DIR"/root/root.x86_64/usr/lib/ld-linux-x86-64.so.2 chroot "$WORK_DIR"/root/root.x86_64 bash -s <<-'ARCHEOF'
				set -xeEuo pipefail
				pacman-key --init
				pacman-key --populate archlinux
				echo "Server=https://archive.archlinux.org/repos/${ARCH_DATE//.//}/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
				pacman -Sy
				pacman -S --noconfirm btrfs-progs
			ARCHEOF

			dd if=/dev/zero of="$IMAGE".tmp bs=1G count=0 seek=1
			mkfs.ext4 "$IMAGE".tmp -d "$WORK_DIR"/root/root.x86_64
			rm -rf "$WORK_DIR"/root
			mv "$IMAGE".tmp "$IMAGE"
		IMAGEEOF
	fi
}

### Configuration

top=$PWD
work_dir=$top/work
cache_dir=$top/cache
source ./config.sh
# You can put local configuration (e.g. location of scratch or cache dirs) here
if [[ -f ./config-local.sh ]] ; then source ./config-local.sh ; fi
# Allow specifying var=value on command line
for arg in "$@" ; do eval "$arg" ; done

### Setup

self_sha1=$(sha1sum "$0" | cut -c 1-40)
mkdir -p "$cache_dir"

### Main

build_kernel
build_image
