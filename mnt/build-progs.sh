#!/bin/bash
set -eEuo pipefail

(
	cd /mnt/src/btrfs-progs
	./autogen.sh
	./configure
	make
	make install

	make test
)
