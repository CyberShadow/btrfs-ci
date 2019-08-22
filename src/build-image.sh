#!/bin/bash
set -eEuo pipefail

work_dir=$1
progs_dir=$2
image=$3
image_arch_date=$4

if [[ -d "$work_dir" ]]
then
	chmod -R u+w "$work_dir"
	rm -rf "$work_dir"
fi
mkdir -p "$work_dir"

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
		tar zx -C "$WORK_DIR"

	cat <<-'EOF' > "$WORK_DIR"/root.x86_64/etc/init
		#!/bin/sh
		mount none /mnt -t hostfs
		exec /mnt/init
	EOF
	chmod +x "$WORK_DIR"/root.x86_64/etc/init

	rm -f "$IMAGE".tmp
	dd if=/dev/zero of="$IMAGE".tmp bs=1G count=0 seek=1
	"$PROGS_DIR"/bin/mkfs.btrfs "$IMAGE".tmp -r "$WORK_DIR"/root.x86_64
	rm -rf "$WORK_DIR"
	mv "$IMAGE".tmp "$IMAGE"
IMAGEEOF
