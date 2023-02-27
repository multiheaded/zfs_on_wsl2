# MS WSL2-modified Linux kernel with ZFS support

## Script to build the kernel from source


### Syntax

```bash
./build.sh [ command [ arguments ] ]
```


### Commands

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
                    #       e.g. "kernel-5.15.90.1_zfs-2.1.9-1_SUFFIX.bin".
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

## Step-by-step instructions to build the kernel

1.  For a fresh install, get the code:
    ```bash
    git clone https://github.com/multiheaded/zfs_on_wsl2.git && cd zfs_on_wsl2
    ```
    If you already have the repo, just run `git pull` to get any updates.\
    <br/>

2.  Get/update the WSL2-modified Linux kernel and OpenZFS source code:
    ```bash
    /bin/bash build.sh update
    ```
    **Note:** Should already set the `WSL2-Linux-Kernel` and `zfs` submodules under the `3rdparty` directory to the correct tags.
    Verify and checkout fitting versions if necessary! \
    <br/>

3.  In case you had built the kernel before, first clean the source tree:
    ```bash
    /bin/bash build.sh clean
    ```
    **WARNING:** this will reset any changes you made under the `3rdparty/WSL2-Linux-Kernel` and `3rdparty/zfs` directories! \
    <br/>

4.  Start the build:
    ```bash
    /bin/bash build.sh
    ```

### Result
- Kernel will be `3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage`
- `.deb` files are created as `3rdparty/zfs/*.deb`


## Install the kernel to WSL

### Option A: Automated install

1. Install the kernel and update `.wslconf`
    ```bash
    /bin/bash install
    ```
   **Note:** For more installation options, see the syntax of the `install` command above or in the `./build.sh help` command output. \
   <br/>

2.  Install the zfs command-line utilities
    ```bash
    /bin/bash debs
    ```
    **Warning:** The installation of these binaries might fail due to missing dependencies or unresolved conflicts. \
    **Note:** It is also possible to use the zfs binaries supplied by the package maintainers of your distribution.

### Option B: Manual install

1.  Install your newly built kernel by copying it to Windows:
    ```bash
    # Create a directory on "Windows" path to store the kernel
    mkdir -p /mnt/c/wsl2_zfs
    
    # Copy the Kernel file
    cp 3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage /mnt/c/wsl2_zfs/kernel
    ```

2.  Also install the command-line utilities:
    ```bash
    sudo dpkg -i 3rdparty/zfs/zfs_*_amd64.deb 3rdparty/zfs/lib*.deb
    ```

3.  In your Windows 10 environment, create or edit `%userprofile%/.wslconfig` and have it point to your kernel file. Copy and rename if necessary.
    ```ini
    [wsl2]
    kernel=c:\\wsl2_zfs\\kernel
    localhostForwarding=true
    swap=0
    ```

4.  Start a PowerShell with administrator privileges, stop your WSL instances and restart LxssManager
    ```batch
    wsl --shutdown
    Restart-Service LxssManager
    ```

5.  In your WSL2 environment, you should now be able to run
    ```bash
    sudo zfs version
    ```
    and get appropriate version information about ZFS.


## Attach your drive with the ZFS partition to your WSL2 VM

To actually use it, check your drive paths from Powershell
```batch
wmic diskdrive list brief
```
and mount (bare) to WSL
```
wsl --mount \\.\PHYSICALDRIVE1 --bare
```

You can see that drive in Linux
```bash
lsblk
```

and `zfs import {pool}` or create a new pool from scratch.

## Resources:
- https://wsl.dev/wsl2-kernel-zfs/
- https://docs.microsoft.com/de-de/windows/wsl/wsl2-mount-disk

