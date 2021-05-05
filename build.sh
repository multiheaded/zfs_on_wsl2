#!/bin/bash

SCRIPT_PATH=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_PATH)

SUBMODULE_PATH=${SCRIPT_DIR}/3rdparty

WSL_KERNEL_SOURCE_DIR=${SUBMODULE_PATH}/WSL2-Linux-Kernel
ZFS_SOURCE_DIR=${SUBMODULE_PATH}/zfs

PARALLEL_THREADS=$(/usr/bin/nproc --all)

echo "Script location: "
echo $SCRIPT_DIR

echo "WSL2 Kernel source location:"
echo $WSL_KERNEL_SOURCE_DIR

echo "OpenZFS source location:"
echo $ZFS_SOURCE_DIR



function install_build_env {
	echo "Setting up build environment"
	sudo apt install -yqq build-essential autoconf automake libtool gawk alien fakeroot dkms libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev python3 python3-dev python3-setuptools python3-cffi libffi-dev flex bison bc
}

function prepare_kernel {
	echo "Preparing kernel"
	cd $WSL_KERNEL_SOURCE_DIR

	cp Microsoft/config-wsl .config

	make -j4 prepare scripts
	make -j4 prepare
}

function prepare_zfs {
	echo "Configuring ZFS source"
	cd $ZFS_SOURCE_DIR
	sh autogen.sh
	./configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=$WSL_KERNEL_SOURCE_DIR --with-linux-obj=$WSL_KERNEL_SOURCE_DIR --enable-systemd
}

function copy_zfs_builtin {
	echo "Copying ZFS module to kernel source"
	cd $ZFS_SOURCE_DIR
	./copy-builtin $WSL_KERNEL_SOURCE_DIR
}

function build_zfs {
	echo "Building ZFS"
	cd $ZFS_SOURCE_DIR
	make -j8
	make -j1 deb-utils
}

function enable_zfs_in_kernel {
	echo "Enabling ZFS in kernel config"
	cd $WSL_KERNEL_SOURCE_DIR
	echo "CONFIG_ZFS=y" >> .config
}

function build_zfs_enabled_kernel {
	echo "Building new WSL2 kernel"
	cd $WSL_KERNEL_SOURCE_DIR
	make -j8
}

function install_kernel_modules {
	echo "Install modules and metadata to /usr/lib"
	cd $WSL_KERNEL_SOURCE_DIR
	sudo make modules_install
}

install_build_env
prepare_kernel
prepare_zfs
copy_zfs_builtin
build_zfs
enable_zfs_in_kernel
build_zfs_enabled_kernel
install_kernel_modules


