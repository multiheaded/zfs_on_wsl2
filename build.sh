#!/bin/bash

# Fail on errors, undefined variables, or command piping errors
set -euo pipefail

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

function install_kernel {
	install_wslu

	echo ""
	echo "Installing kernel:"
	echo ""

	local "KERNEL_TARGET_DIR=${1:-/mnt/c/wsl2_zfs}"

	if contains "$KERNEL_TARGET_DIR" ":"; then
		KERNEL_TARGET_DIR=$(wslpath -u "$KERNEL_TARGET_DIR")
	fi

	local "SYSTEM_DRIVE=$(wslpath -u "$(wslvar -s SystemDrive)\\")"
	local "MOUNT_ROOT=${SYSTEM_DRIVE: 0 : -2 }"

	if ! starts_with "$KERNEL_TARGET_DIR" "$MOUNT_ROOT"; then
		KERNEL_TARGET_DIR=$SYSTEM_DRIVE$KERNEL_TARGET_DIR
	fi

	local "KERNEL_TARGET=$KERNEL_TARGET_DIR/$(kernel_filename {$2:-})"
	local "KERNEL_TARGET_WIN=$(wslpath -w "$KERNEL_TARGET")"
	local "WSL_CONFIG_WIN=$(wslvar USERPROFILE)\\.wslconfig"
	local "WSL_CONFIG=$(wslpath "$WSL_CONFIG_WIN")"

	echo "Kernel path (windows):     $KERNEL_TARGET_WIN"
	echo "Kernel path (linux):       $KERNEL_TARGET"
	echo "WSL config file (windows): $WSL_CONFIG_WIN"
	echo "WSL config file (linux):   $WSL_CONFIG"
	echo ""

	cd "$SCRIPT_DIR"
	mkdir -p "$KERNEL_TARGET_DIR"
	cp 3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage "$KERNEL_TARGET"

	local WSL_LINE=${KERNEL_TARGET_WIN//\\/\\\\\\\\}

	if [ ! -f "$WSL_CONFIG" ]; then
		cat > "$WSL_CONFIG" | <<<EOL
		[wsl2]
		kernel=$WSL_LINE
		localhostForwarding=true
		swap=0
		EOL

	else
		echo "Current WSL config:"
		echo "---------8<--------"
		cat "$WSL_CONFIG"
		echo "---------8<--------"
		echo ""

		if grep -qe "^kernel\s*=" "$WSL_CONFIG"; then
			# 1. replace current kernel path with new path
			# 2. remove pre-existing line with the same setting
			sed -i -e "s|^\s*kernel\s*=[^\n]*|;\0\nkernel=$WSL_LINE\r|i;s|^\s*;\s*kernel=\s*${WSL_LINE//\\\\\\\\/\\\\\\\\\\\?}\s*||g;/^$/d" "$WSL_CONFIG"
		else
			# simply add the kernel setting to the config file
			echo "kernel=$WSL_LINE\r" >> "$WSL_CONFIG"
		fi
	fi

	echo "New WSL config:"
	echo "---------8<--------"
	cat "$WSL_CONFIG"
	echo "---------8<--------"
	echo ""

	exit
}

function install_debs {
	echo ""
	echo "Installing command line tools:"
	echo ""

	cd "$SCRIPT_DIR"
	sudo apt install 3rdparty/zfs/zfs_*_amd64.deb 3rdparty/zfs/lib*.deb libzfs4linux
}

function install_wslu {
	echo ""
	echo "Installing latest WSL Utilities:"
	echo ""
	add-apt-repository -L | grep -q wslutilities/wslu
	if (( $? != 0 )); then
		sudo add-apt-repository -y ppa:wslutilities/wslu
		sudo apt update
	fi
	sudo apt upgrade wslu
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

function make_clean {
	echo ""
	echo "Cleaning source:"
	echo ""
	cd "$WSL_KERNEL_SOURCE_DIR"
	git reset --hard
	git clean -fdx
	make clean
	cd "$ZFS_SOURCE_DIR"
	git reset --hard
	git clean -fdx
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

function kernel_filename {
  local "KERNEL_VERSION=kernel-$(version_kernel)_zfs-$(version_zfs)"

  if [[ "${1:-}" ]]; then
	  echo "${KERNEL_VERSION}_${1}.bin"
  else
    echo "KERNEL_VERSION.bin"
  fi
}

function contains {
	case "$1" in
		*"$2"*) return 0;;
		*) return 1;;
	esac
}

function starts_with {
	case "$1" in
		"$2"*) return 0;;
		*) return 1;;
	esac
}

function print_help {
  cat << EOT

$(print_version)

SYNTAX:

    ./build.sh [ command [arguments] ]


COMMANDS:

    update          # Update source code

    clean           # Clean up source code

    build           # Build kernel from source

    install [ {KERNEL_TARGET_DIR} [ {KERNEL_SUFFIX} ] ]
                    #
                    # Install kernel to WSL2
                    #
                    # Optional arguments:
                    #
                    # - KERNEL_TARGET_DIR indicates the directory where the Kernel is stored on Windows
                    #
                    #       Default:  "C:\wsl2_zfs"
                    #       Note:     Can be given as a Windows path, or WSL path.
                    #
                    # - KERNEL_SUFFIX specifies a suffix to be added to the resulting kernel-name:
                    #       "$(kernel_filename SUFFIX)".
                    #
                    #       Default:  no suffix.
                    #       Note:     This parameter requires KERNEL_TARGET_DIR to be set.
                    #                 However, you can use "" if you still want to use the default value.

    debs            # Install zfs command-line binaries to current distro

    wslu            # Install/upgrade WSL Utilities command-line binaries to current distro

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

	clean)
	  print_info
		shift
		make_clean
		;;

	build|"")
		print_info
		shift
		make_all
		;;

	debs)
		print_info
		shift
		install_debs
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

	install)
		print_info
		shift
		install_kernel "$@"
		shift
		;;

	update)
		print_info
		shift
		git pull
		git submodule update --init --recursive --progress
		;;

	wslu)
		shift
		install_wslu
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

