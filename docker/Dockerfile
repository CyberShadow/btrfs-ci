FROM scratch AS rootfs

ARG arch_tar
ADD ${arch_tar} /


FROM scratch AS arch

COPY --from=rootfs /root.x86_64/ /

RUN pacman-key --init && pacman-key --populate

ARG arch_date
RUN echo 'Server=https://archive.archlinux.org/repos/'"${arch_date}"'/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN awk '/HoldPkg/{next;}{print;}' /etc/pacman.conf > /etc/pacman.conf.new && mv /etc/pacman.conf.new /etc/pacman.conf

RUN \
	pacman --noconfirm -Syyuu
RUN \
	pacman --noconfirm -D --asdeps $(pacman -Qqe) && \
	pacman --noconfirm -D --asexplicit bash coreutils e2fsprogs findutils libarchive util-linux && \
	pacman --noconfirm -S --asexplicit acl asciidoc autoconf automake gcc grep lzo make pkgconf python python-setuptools sed xmlto zstd && \
	pacman --noconfirm -Rsunc $(pacman -Qtdq)

FROM arch

COPY --from=arch / /arch/

RUN printf '#!/bin/sh\n''mount none /mnt -t hostfs && exec /mnt/init\n' > /arch/etc/init && \
	chmod +x /arch/etc/init

# Docker can't commit sparse files (efficiently),
# so we need to tar it up immediately after creation.
RUN dd if=/dev/zero of=/image bs=2G count=0 seek=1 && \
	mkfs.ext4 /image -d /arch/ && \
	rm -rf /arch/ && \
	bsdtar cf /image.tar /image && \
	rm /image

ENTRYPOINT cat /image.tar
