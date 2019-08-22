#!/bin/bash
set -eEuo pipefail

src_dir=$1
work_dir=$2

# Configure
rm -rf "$work_dir"
mkdir -p "$work_dir"

# shellcheck disable=SC2191
make_args=(
	make
	-C "$src_dir"
	ARCH=um
	O="$work_dir"
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
) >> "$work_dir"/.config

"${make_args[@]}" olddefconfig

# Build
"${make_args[@]}" -j"$(nproc)"
