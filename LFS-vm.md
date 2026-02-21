I've installed LFS to a virtual machine a few times in the past. Most of the time I did it just as a curiosity and I typically deleted the VM soon after, as I didn't see myself going through the bother of maintaining the thing long-term. 

But on 9 February 2026, I started a LFS 12.4 install to a QEMU/KVM virtual machine. After installing it, I decided to upgrade it to the developmental version of LFS. I also upgraded my kernel to the latest (6.19.0) and Vim to the latest version. I then, with the help of AI, wrote some scripts to help automate the maintenance of the LFS system. 

After this, I decided to install Flatpak on the VM, to [answer this query](https://www.reddit.com/r/linuxquestions/comments/1r7j0y7/is_lfs_and_blfs_the_right_things_for_me_or_should/) via following the BLFS guide and [these modified SlackBuilds](https://github.com/fusion809/flatpak_lfs). There were some packages not provided by BLFS, LFS and the SlackBuilds that I had to compile for myself, too. This worked, but I couldn't really properly test Flatpak out without having a full GUI, could I? 

So I decided to go through the process of installing GNOME 49.4 to this VM with just the apps I'd use. In the process, I had to compile a lot of big packages like LLVM, Rustc and WebKitGTK (which I had to compile with both GTK+3 and GTK+4 support). I also installed spice-vdagent and its dependencies as I wanted a shared clipboard, auto-resizing of the guest to host window, etc. This, too, I achieved using modified SlackBuilds, which you can find in [this repository](https://github.com/fusion809/spice_lfs). But it was worth it. And I kind of grew to enjoy using LFS/BLFS, as installing software started feeling like unwrapping presents. 

I've since customized my LFS VM, too, by installing my own Zsh set up, and installing my preferred GNOME themes. I also installed Fastfetch and Hyfetch by compiling them from source, too. Given I already needed Rust to build GNOME, I thought I might as well use Rust to compile Hyfetch, too. 

Below a screenshot showcasing my LFS virtual machine. 

![](https://fusion809.github.io/images/LFS/LFS_2026-02-21_11-12-07.png)