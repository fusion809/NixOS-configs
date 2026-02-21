I've installed LFS on a virtual machine a few times in the past. Most of the time, I did it out of curiosity, and I typically deleted the VM soon after, as I didn't see myself going through the bother of maintaining it long-term.  

But on 9 February 2026, I started an LFS 12.4 installation on a QEMU/KVM virtual machine (VM). After installing it, I decided to upgrade it to the developmental version of LFS. I also upgraded my kernel to the latest version (6.19.0) and Vim to the latest release. Then, with the help of AI, I wrote some scripts to help automate maintenance of the LFS system.  

After this, I decided to install Flatpak on the VM to [answer this query](https://www.reddit.com/r/linuxquestions/comments/1r7j0y7/is_lfs_and_blfs_the_right_things_for_me_or_should/) by following the BLFS guide and using [these modified SlackBuilds](https://github.com/fusion809/flatpak_lfs). There were also some packages not provided by BLFS, LFS, or the SlackBuilds that I had to compile myself. This worked, but I couldn't properly test Flatpak without a full GUI, could I?  

So I decided to go through the process of installing GNOME 49.4 on this VM, including only the apps I actually use. In the process, I had to compile many large packages such as LLVM, Rustc, and WebKitGTK (which I compiled with both GTK+3 and GTK+4 support). I also installed spice-vdagent and its dependencies because I wanted a shared clipboard, automatic guest window resizing, and similar features. I achieved this using modified SlackBuilds as well, which you can find in [this repository](https://github.com/fusion809/spice_lfs).

I've since customized my LFS VM by installing my own Zsh setup and my preferred GNOME themes. I also installed Fastfetch and Hyfetch by compiling them from source. Since I already needed Rust to build GNOME, I figured I might as well use it to compile Hyfetch as well. I've also fixed some minor errors I was getting.

It was all worth it. I gradually grew to enjoy using LFS/BLFS, as installing software began to feel like unwrapping presents.

Below is a screenshot showcasing my LFS virtual machine. Wallpaper is courtesy of [Valentin Klopfenstein](https://unsplash.com/photos/paragliders-soar-near-a-snow-capped-mountain-peak-K5W6JHHmSm8).

![](https://fusion809.github.io/images/LFS/LFS_2026-02-21_11-12-07.png)