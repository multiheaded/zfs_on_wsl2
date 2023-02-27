# MS WSL2-modified Linux kernel with ZFS support

## Script to build the kernel from source


### Syntax

```bash
./build.sh [ command ]
```


### Commands

    build           # Build kernel from source

    env             # Install building environment

    info            # Show information about directories and source versions

    version         # Show the script's version

## Step-by-step instructions to build the kernel

1.  For a fresh install, get the code:
    ```bash
    git clone https://github.com/multiheaded/zfs_on_wsl2.git && cd zfs_on_wsl2
    ```
    If you already have the repo, just run `git pull` to get any updates.\
    <br/>

2.  Get the WSL2-modified Linux kernel and OpenZFS source code:
    ```bash
    git submodule update --init --recursive --progress
    ```
    Should already be set to the correct tags. Verify and checkout fitting versions if necessary! \
    <br/>

3.  Start the build:
    ```bash
    /bin/bash build.sh
    ```

### Result
- Kernel will be `3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage`
- `.deb` files are created as `3rdparty/zfs/*.deb`


## Install the kernel to WSL

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

