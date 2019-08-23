### Configuration

top = $(shell pwd)
work_dir = $(top)/work
cache_dir = $(top)/cache
self_sha1 = $(shell cat $(lastword $(MAKEFILE_LIST)) docker/Dockerfile | sha1sum | cut -c 1-40)

docker = docker

include config.mk
-include config-local.mk

all : run_vm

# Kernel

kernel_src_dir = $(work_dir)/src/linux-$(kernel_commit)

kernel_src : $(kernel_src_dir)
$(kernel_src_dir) :
	rm -rf $@.tmp
	mkdir -p $@.tmp
	curl -fL https://github.com/kdave/btrfs-devel/archive/$(kernel_commit).tar.gz | \
		tar zx -C $@.tmp --strip-components 1
	mv $@.tmp $@

kernel_build_id = $(kernel_commit)-$(self_sha1)
kernel_binary = $(cache_dir)/linux-$(kernel_build_id)

kernel : $(kernel_binary)
$(kernel_binary) : | $(kernel_src_dir)
	src/build-kernel.sh $(kernel_src_dir) $(work_dir)/linux
	cp $(work_dir)/linux/vmlinux $@

# Base rootfs

arch_tar_fn=archlinux-bootstrap-$(arch_date)-x86_64.tar.gz
arch_tar_url=https://archive.archlinux.org/iso/$(arch_date)/$(arch_tar_fn)
arch_tar_dir=$(work_dir)/arch
arch_tar=$(arch_tar_dir)/$(arch_tar_fn)

$(arch_tar_dir) :
	mkdir -p $@

$(arch_tar) : | $(arch_tar_dir)
	curl --fail --output $@.tmp $(arch_tar_url)
	printf "%s %s\n" $(arch_tar_sha1) $@.tmp | sha1sum -c
	mv $@.tmp $@

# btrfs-progs

progs_src_dir = $(work_dir)/src/progs-$(btrfs_progs_commit)

progs_src : $(progs_src_dir)
$(progs_src_dir) :
	rm -rf $@.tmp
	mkdir -p $@.tmp
	curl -fL https://github.com/kdave/btrfs-progs/archive/$(btrfs_progs_commit).tar.gz | \
		tar zx -C $@.tmp --strip-components 1
	mv $@.tmp $@

progs_build_id = $(btrfs_progs_commit)-$(self_sha1)
progs_dir = $(cache_dir)/progs-$(progs_build_id)

progs : $(progs_dir)
$(progs_dir) : $(progs_src_dir)
	cd $(progs_src_dir) && ./autogen.sh
	cd $(progs_src_dir) && ./configure --prefix=
	make -C $(progs_src_dir) -j$(shell nproc)

	# Install
	rm -rf $@.tmp
	mkdir -p $@.tmp
	make -C $(progs_src_dir) install DESTDIR=$@.tmp
	mv $@.tmp $@

# Image

image_build_id = $(arch_date)-$(self_sha1)
image_dir = $(cache_dir)/image-$(image_build_id)
image_file = $(cache_dir)/image-$(image_build_id)/image
image : $(image_file)
$(image_file) : $(arch_tar) docker/Dockerfile
	$(docker) build \
		-t btrfs-ci \
		-f - \
		--build-arg arch_tar="$(arch_tar_fn)" \
		--build-arg arch_date=$(subst .,/,$(arch_date)) \
		"$(arch_tar_dir)" \
		< docker/Dockerfile
	mkdir -p $(image_dir)
	$(docker) run --rm btrfs-ci | tar x -C $(image_dir)

# VM

run_vm : $(kernel_binary) $(image_file)
	$(kernel_binary) ubd0=$(image_file) hostfs=$(top)/mnt

.PHONY : all kernel_src kernel progs_src progs image run_vm
