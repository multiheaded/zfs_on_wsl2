#!/bin/bash

SCRIPT_VERSION=1.1.0
SCRIPT_PATH=$(readlink -f $0)
SCRIPT_DIR=$(dirname $SCRIPT_PATH)

SUBMODULE_PATH=${SCRIPT_DIR}/3rdparty

WSL_KERNEL_SOURCE_DIR=${SUBMODULE_PATH}/WSL2-Linux-Kernel
ZFS_SOURCE_DIR=${SUBMODULE_PATH}/zfs

PARALLEL_THREADS=$(/usr/bin/nproc --all)

# Helper variable to print the information form print_info() only once
declare -gi info_printed=0

function print_info {
	(( $info_printed == 0 )) || return 0

	info_printed=1

	echo ""
	print_version

	echo ""
	echo "Script location:"
	echo $SCRIPT_DIR

	echo ""
	echo "WSL2 Kernel source location:"
	echo $WSL_KERNEL_SOURCE_DIR

	echo ""
	echo "WSL2 Kernel version:"
	version_kernel

	echo ""
	echo "OpenZFS source location:"
	echo $ZFS_SOURCE_DIR
	echo ""

	echo "OpenZFS version:"
	version_zfs
	echo ""
}

function print_version {
	echo "zfs_on_linux/build.sh v$SCRIPT_VERSION"
}

function install_build_env {
	echo ""
	echo "Setting up build environment:"
	echo ""
	sudo apt install -yqq build-essential autoconf automake libtool gawk alien fakeroot dkms libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev python3 python3-dev python3-setuptools python3-cffi libffi-dev flex bison bc dwarves
}

function prepare_kernel {
	echo ""
	echo "Preparing kernel:"
	echo ""
	cd $WSL_KERNEL_SOURCE_DIR

	# some hardeing options in the Linux kernel are not yet preconfigured in the WSL kernel config, so we do it ourselves...
	git apply ../../config-wsl.patch
	cp Microsoft/config-wsl .config

	make -j${PARALLEL_THREADS} prepare scripts
	make -j${PARALLEL_THREADS} prepare
}

function prepare_zfs {
	echo ""
	echo "Configuring ZFS source:"
	echo ""
	cd $ZFS_SOURCE_DIR
	# https://github.com/openzfs/zfs/commit/b72efb751147ab57afd1588a15910f547cb22600
	# configure broken on Python version check if not cherry-picked. Probably not necessary in future release
	git cherry-pick b72efb751147ab57afd1588a15910f547cb22600
	sh autogen.sh
	./configure --prefix=/ --libdir=/lib --includedir=/usr/include --datarootdir=/usr/share --enable-linux-builtin=yes --with-linux=$WSL_KERNEL_SOURCE_DIR --with-linux-obj=$WSL_KERNEL_SOURCE_DIR --enable-systemd
}

function copy_zfs_builtin {
	echo ""
	echo "Copying ZFS module to kernel source:"
	echo ""
	cd $ZFS_SOURCE_DIR
	./copy-builtin $WSL_KERNEL_SOURCE_DIR
}

function build_zfs {
	echo ""
	echo "Building ZFS:"
	echo ""
	cd $ZFS_SOURCE_DIR
	make -j${PARALLEL_THREADS}
	make deb-utils
}

function enable_zfs_in_kernel {
	echo ""
	echo "Enabling ZFS in kernel config:"
	echo ""
	cd $WSL_KERNEL_SOURCE_DIR
	echo "CONFIG_ZFS=y" >> .config
}

function build_zfs_enabled_kernel {
	echo ""
	echo "Building new WSL2 kernel:"
	echo ""
	cd $WSL_KERNEL_SOURCE_DIR
	make -j${PARALLEL_THREADS}
}

function install_kernel_modules {
	echo ""
	echo "Install modules and metadata to /usr/lib:"
	echo ""
	cd $WSL_KERNEL_SOURCE_DIR
	sudo make modules_install
}

function make_all {
	install_build_env
	prepare_kernel
	prepare_zfs
	copy_zfs_builtin
	build_zfs
	enable_zfs_in_kernel
	build_zfs_enabled_kernel
	install_kernel_modules
}

function version_kernel {
	if [ -r 3rdparty/WSL2-Linux-Kernel/.config ]; then
		grep "Kernel Configuration" 3rdparty/WSL2-Linux-Kernel/.config | cut -d" " -f3
	elif [ -r 3rdparty/WSL2-Linux-Kernel/Microsoft/config-wsl ]; then
		grep "Kernel Configuration" 3rdparty/WSL2-Linux-Kernel/Microsoft/config-wsl | cut -d" " -f3
	else
		echo "N/A"
	fi
}

function version_zfs {
	if [ -r 3rdparty/zfs/zfs.release ]; then
		cat 3rdparty/zfs/zfs.release
	else
		echo "N/A"
	fi
}

function print_help {
  cat << EOT

$(print_version)

SYNTAX:

    ./build.sh [ command [arguments] ]


COMMANDS:

    build           # Build kernel from source

    env             # Install building environment

    help            # Show this help

    info            # Show information about directories and source versions

    version         # Show the script's version


INFO:
EOT
}


if (( $# == 0 )); then
	make_all
else
	while (( $# > 0 )); do
	case "$1" in

	build|"")
		print_info
		shift
		make_all
		;;

	env)
		print_info
		shift
		install_build_env
		;;

	info)
		shift
		print_info
		;;

	-h|--help|help)
		shift
		print_help
		print_info
		;;

	-V|--version|version)
		shift
		print_version
		;;

	*)
		echo "Unknown command '$1' ..."
		exit 1
		;;

	esac
	done
fi

