#!/bin/bash
set -eEuo pipefail

function build_kernel() {
	local kernel_build_id="$kernel_commit"-"$self_sha1"
	kernel_binary="$cache_dir"/linux-"$kernel_build_id"
	if [[ ! -e "$kernel_binary" ]]
	then
		# Download source code
		local kernel_src_dir=$work_dir/src/linux-$kernel_commit
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

function build_progs() {
	local progs_build_id="$btrfs_progs_commit"-"$self_sha1"
	progs_dir="$cache_dir"/progs-"$progs_build_id"

	if [[ ! -d "$progs_dir" ]]
	then
		# Download source code
		local progs_src_dir=$work_dir/src/progs-$btrfs_progs_commit
		if [[ ! -d "$progs_src_dir" ]]
		then
			mkdir -p "$progs_src_dir".tmp
			curl -fL https://github.com/kdave/btrfs-progs/archive/"$btrfs_progs_commit".tar.gz |
				tar zx -C "$progs_src_dir".tmp --strip-components 1
			mv "$progs_src_dir".tmp "$progs_src_dir"
		fi

		# Build
		(
			cd "$progs_src_dir"
			./autogen.sh
			./configure --prefix=
		)
		make -C "$progs_src_dir" -j"$(nproc)"

		# Install
		rm -rf "$progs_dir".tmp
		mkdir -p "$progs_dir".tmp
		make -C "$progs_src_dir" install DESTDIR="$progs_dir".tmp
		mv "$progs_dir".tmp "$progs_dir"
	fi
}

function build_image() {
	local image_build_id="$image_arch_date"-"$self_sha1"
	image="$cache_dir"/image-"$image_build_id"
	if [[ ! -f "$image" ]]
	then
		if [[ -d "$work_dir"/root ]]
		then
			chmod -R u+w "$work_dir"/root
			rm -rf "$work_dir"/root
		fi
		mkdir -p "$work_dir"/root

		# debootstrap has a hard requirement on root, so we can't use Debian.
		# Instead use Arch Linux, for which fakeroot and fakechroot suffice.
		env \
			WORK_DIR="$work_dir" \
			PROGS_DIR="$progs_dir" \
			ARCH_DATE="$image_arch_date" \
			IMAGE="$image" \
			fakeroot bash -s <<-'IMAGEEOF'
			set -xeEuo pipefail
			curl "https://archive.archlinux.org/iso/$ARCH_DATE/archlinux-bootstrap-$ARCH_DATE-x86_64.tar.gz" |
				tar zx -C "$WORK_DIR"/root

			cat <<-'EOF' > "$WORK_DIR"/root/root.x86_64/etc/init
				#!/bin/sh
				mount none /mnt -t hostfs
				exec /mnt/init
			EOF
			chmod +x "$WORK_DIR"/root/root.x86_64/etc/init

			rm -f "$IMAGE".tmp
			dd if=/dev/zero of="$IMAGE".tmp bs=1G count=0 seek=1
			"$PROGS_DIR"/bin/mkfs.btrfs "$IMAGE".tmp -r "$WORK_DIR"/root/root.x86_64
			rm -rf "$WORK_DIR"/root
			mv "$IMAGE".tmp "$IMAGE"
		IMAGEEOF
	fi
}

function run_vm() {
	"$kernel_binary" ubd0="$image" hostfs="$top"/mnt
}

### Configuration

top=$PWD
work_dir=$top/work
cache_dir=$top/cache
self_sha1=$(sha1sum "$0" | cut -c 1-40)
source ./config.sh
# You can put local configuration (e.g. location of scratch or cache dirs) here
if [[ -f ./config-local.sh ]] ; then source ./config-local.sh ; fi
# Allow specifying var=value on command line
for arg in "$@" ; do eval "$arg" ; done

### Setup

mkdir -p "$cache_dir"

### Main

build_kernel
build_progs
build_image
run_vm
