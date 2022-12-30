# Script to build the MS WSL2-modified Linux kernel with ZFS support

Get the WSL2-modified Linux kernel and OpenZFS source code:
```bash
git submodule update --init --recursive
```
Should already be set to the correct tags. Verify and checkout fitting versions if necessary!

```bash
/bin/bash build.sh
```

Kernel will be `3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage`  
.deb files are created as `3rdparty/zfs/*.deb`

Install your newly built kernel by copying it to Windows:
```
# Create a directory on "Windows" path to store the kernel
mkdir -p /mnt/c/wsl2_zfs

# Copy the Kernel file
cp 3rdparty/WSL2-Linux-Kernel/arch/x86/boot/bzImage /mnt/c/wsl2_zfs/kernel
```

Also install the comand line utilites:
```
sudo dpkg -i 3rdparty/zfs/zfs_*_amd64.deb 3rdparty/zfs/lib*.deb
```

In your Windows 10 environment, create or edit %userprofile%/.wslconfig and have it point to your kernel file. Copy and rename if necessary.
```
[wsl2]
kernel=c:\\wsl2_zfs\\kernel
localhostForwarding=true
swap=0
```

Start a PowerShell with administrator privileges, stop your WSL instances and restart LxssManager
```
wsl --shutdown
Restart-Service LxssManager
```

In your WSL2 environment, you should now be able to run 
```bash
sudo zfs version
```
and get appropriate version information about ZFS.

To actually use it, check your drive paths from Powershell
```
wmic diskdrive list brief
```
and mount (bare) to your distribution (e.g. Ubuntu or whatever, but that's optional)
```
wsl --mount \\.\PHYSICALDRIVE1 --bare [-d Ubuntu-20.04]
```

You can see that drive in Linux
```bash
lsblk
```

### Resources:
- https://wsl.dev/wsl2-kernel-zfs/
- https://docs.microsoft.com/de-de/windows/wsl/wsl2-mount-disk

