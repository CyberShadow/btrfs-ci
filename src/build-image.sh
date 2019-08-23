#!/bin/bash
set -xeEuo pipefail

work_dir=$1
progs_dir=$2
image=$3

if [[ -d "$work_dir" ]]
then
	chmod -R u+w "$work_dir"
	rm -rf "$work_dir"
fi
mkdir -p "$work_dir"

tar x -C "$work_dir"

cat <<-'EOF' > "$work_dir"/arch/etc/init
	#!/bin/sh
	mount none /mnt -t hostfs
	exec /mnt/init
EOF
chmod +x "$work_dir"/arch/etc/init

rm -f "$image".tmp
dd if=/dev/zero of="$image".tmp bs=1G count=0 seek=1
"$progs_dir"/bin/mkfs.btrfs "$image".tmp -r "$work_dir"/arch
rm -rf "$work_dir"
mv "$image".tmp "$image"
