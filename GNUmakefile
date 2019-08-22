### Configuration

top = $(shell pwd)
work_dir = $(top)/work
cache_dir = $(top)/cache
self_sha1 = $(shell sha1sum $(lastword $(MAKEFILE_LIST)) | cut -c 1-40)

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
$(kernel_binary) : $(kernel_src_dir)
	src/build-kernel.sh $(kernel_src_dir) $(work_dir)/linux
	cp $(work_dir)/linux/vmlinux $@

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

image_build_id = $(image_arch_date)-$(self_sha1)
image_file = $(cache_dir)/image-$(image_build_id)
image : $(image_file)
$(image_file) : $(progs_dir)
	src/build-image.sh $(work_dir)/root $(progs_dir) $(image_file) $(image_arch_date)

# VM

run_vm : $(kernel_binary) $(image_file)
	$(kernel_binary) ubd0=$(image_file) hostfs=$(top)/mnt

.PHONY : all kernel_src kernel progs_src progs image run_vm
