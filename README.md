# My NixOS configuration files
![Hyprland on NixOS screenshot as of 10 May 2026](https://fusion809.github.io/images/Hyprland/Hyprland_NixOS_2026-05-10.png)
**Figure 1: Hyprland NixOS configuration as of 10 May 2026.**

These are my [NixOS 25.11](https://nixos.org) configuration files for my [MS-7B90](https://www.msi.com/Motherboard/B450M-BAZOOKA-PLUS/Specification) PC with dual 1080p monitor setup. [Hyprland](https://hypr.land/) is my graphical user interface (GUI). [Flakes](https://nixos.wiki/wiki/Flakes) are used to manage packages. 

# Table of Contents
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Language breakdown](#language-breakdown)
- [Autostart](#autostart)
- [Default apps](#default-apps)
- [History](#history)
- [Hyprland](#hyprland)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [nixpkgs](#nixpkgs)
  - [Antigravity package](#antigravity-package)
  - [Marvin package](#marvin-package)
  - [OpenRA package](#openra-package)
- [Shell profile](#shell-profile)
  - [Package management commands](#package-management-commands)
- [Wallpaper script](#wallpaper-script)
  - [Syntax](#syntax)
- [Waybar](#waybar)
  - [NixOS menu (): only shown on monitor 1](#nixos-menu-%EE%A1%83-only-shown-on-monitor-1)
  - [Workspaces (which are numbered): shown on both monitors](#workspaces-which-are-numbered-shown-on-both-monitors)
  - [Weather conditions: shown on monitor 1](#weather-conditions-shown-on-monitor-1)
  - [Pulseaudio: shown on monitor 1](#pulseaudio-shown-on-monitor-1)
  - [Uptime (󰔚): shown on monitor 1](#uptime-%F3%B0%94%9A-shown-on-monitor-1)
  - [Wallpaper number widget (󰸉): shown on monitor 1](#wallpaper-number-widget-%F3%B0%B8%89-shown-on-monitor-1)
  - [Previous wallpaper button (): shown on monitor 1](#previous-wallpaper-button-%EF%81%A0-shown-on-monitor-1)
  - [Random wallpaper button (): shown on monitor 1](#random-wallpaper-button-%EF%81%B4-shown-on-monitor-1)
  - [Forward wallpaper button (): shown on monitor 1](#forward-wallpaper-button-%EF%81%A1-shown-on-monitor-1)
  - [Wallpaper specification button (): shown on monitor 1](#wallpaper-specification-button-%EF%93%B7-shown-on-monitor-1)
  - [The title of your currently focused window: shown on both monitors](#the-title-of-your-currently-focused-window-shown-on-both-monitors)
  - [Keyboard layout (): shown on monitor 2](#keyboard-layout-%EF%84%9C-shown-on-monitor-2)
  - [Motherboard temperature (): shown on both monitors](#motherboard-temperature-%EF%8B%87-shown-on-both-monitors)
  - [Root file system usage (/): shown on monitor 1](#root-file-system-usage--shown-on-monitor-1)
  - [Arch file system usage (A): shown on monitor 1](#arch-file-system-usage-a-shown-on-monitor-1)
  - [Data file system usage (D): shown on monitor 1](#data-file-system-usage-d-shown-on-monitor-1)
  - [Internet download speed () on enp24s0 interface in bps: shown on monitor 2](#internet-download-speed-%EE%AA%9A-on-enp24s0-interface-in-bps-shown-on-monitor-2)
  - [Internet upload speed () on enp24s0 interface in bps: shown on monitor 2](#internet-upload-speed-%EE%AA%A1-on-enp24s0-interface-in-bps-shown-on-monitor-2)
  - [CPU usage percentage (): shown on monitor 1](#cpu-usage-percentage-%EF%8B%9B-shown-on-monitor-1)
  - [RAM usage percentage (): shown on monitor 1](#ram-usage-percentage-%EF%83%89-shown-on-monitor-1)
  - [zRAM utilization (󰾆): shown on monitor 1](#zram-utilization-%F3%B0%BE%86-shown-on-monitor-1)
  - [Swap utilization (󰓡): shown on monitor 1](#swap-utilization-%F3%B0%93%A1-shown-on-monitor-1)
  - [GPU memory usage percentage (): shown on monitor 2](#gpu-memory-usage-percentage-%EE%BF%85-shown-on-monitor-2)
  - [GPU utilization percentage (󱃏): shown on monitor 2](#gpu-utilization-percentage-%F3%B1%83%8F-shown-on-monitor-2)
  - [Updates<sup>1</sup> available: shown on both monitors](#updatessup1sup-available-shown-on-both-monitors)
  - [Phone battery status and notifications: shown on both monitors](#phone-battery-status-and-notifications-shown-on-both-monitors)
  - [Clock: on both monitors](#clock-on-both-monitors)
  - [Footnotes](#footnotes)
- [Workspaces](#workspaces)
  - [Monitor 1](#monitor-1)
  - [Monitor 2](#monitor-2)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


# Language breakdown
<!-- STATS START -->
| Language | Lines | Lines % | Complexity | Complexity % |
| :--- | :--- | :--- | :--- | :--- |
| Shell | 9594 | 56.15% | 1619 | 79.17% |
| Nix | 3141 | 18.38% | 146 | 7.14% |
| CSS | 1012 | 5.92% | 1 | 0.05% |
| Python | 818 | 4.79% | 197 | 9.63% |
| Markdown | 515 | 3.01% | 0 | 0.00% |
| Lua | 452 | 2.65% | 43 | 2.10% |
| JSONC | 433 | 2.53% | 0 | 0.00% |
| Patch | 396 | 2.32% | 0 | 0.00% |
| JSON | 391 | 2.29% | 0 | 0.00% |
| AWK | 203 | 1.19% | 35 | 1.71% |
| XML | 78 | 0.46% | 0 | 0.00% |
| JavaScript | 41 | 0.24% | 4 | 0.20% |
| TOML | 13 | 0.08% | 0 | 0.00% |
| **Total** | **17087** | **100.00%** | **2045** | **100.00%** |
<!-- STATS END -->

# Autostart
Applications and programs autostarted include the default browser, virtual machine manager, the Brave browser, Waybar, Discord, Blueman Manager, KDE Connect, Kitty (with Hyfetch), WinBoat, GNOME Files, Alacritty, my Debian 13 virtual machine, and cliphist and wl-clip-persist for managing the clipboard. A command is also run to show the next wallpaper, another kills old processes for showing the wallpaper that are errantly running, and another logs network activity so it can be used for creating graphs if one clicks the network widgets in the Waybar.

# Default apps
* Application menu is [Rofi](https://github.com/davatorium/rofi).
* File manager is [Dolphin](https://apps.kde.org/dolphin/).
* [KDE Connect](https://apps.kde.org/kdeconnect/).
* Terminal is [Alacritty](https://alacritty.org/), although [Kitty](https://sw.kovidgoyal.net/kitty/) is also installed and used for creating [Hyfetch](https://github.com/hykilpikonna/hyfetch) output-inclusive screenshots. 
* Text editor/IDE is [Antigravity](https://antigravity.google/). [Neovim](https://neovim.io/) and [Visual Studio Code](https://code.visualstudio.com/) are also installed. 
* Web browser is [Google Chrome](https://www.google.com/chrome/), although [Brave](https://brave.com/) and [Firefox](https://www.firefox.com/en-US/) are also installed. 

# History
[6e524bcfb7db7653ac4df86b378faab6e25a7bf3](https://github.com/fusion809/NixOS-configs/tree/6e524bcfb7db7653ac4df86b378faab6e25a7bf3) was the final commit with vim-ai with deepseek-coder model. Was removed as it wasn't useful for me. 

# Hyprland
Hyprland and hy3 is built from the master branch of nixpkgs.

[shell/hyprland](/shell/hyprland/) contains shell scripts that are part of my Hyprland setup, or used to launch apps under Hyprland. [dotfiles/](/dotfiles/) contains my Hyprland configuration files and desktop config files for the aforementioned apps. I used to compile the latest version of Hyprland from source, but recompiling every time I ran `nixfrb` (i.e., rebuild the system) eventually deterred me. 

# Keyboard shortcuts
| Keyboard combination                                              | Action                                            |
|-------------------------------------------------------------------|---------------------------------------------------|
| <kbd>h</kbd>                                                      | Resize window (only in resize mode) to the left.  | 
| <kbd>l</kbd>                                                      | Resize window (only in resize mode) to the right. | 
| <kbd>k</kbd>                                                      | Resize window (only in resize mode) down.         | 
| <kbd>j</kbd>                                                      | Resize window (only in resize mode) up.           | 
| <kbd>Left</kbd>                                                   | Resize window (only in resize mode) to the left.  | 
| <kbd>Right</kbd>                                                  | Resize window (only in resize mode) to the right. | 
| <kbd>Down</kbd>                                                   | Resize window (only in resize mode) down.         | 
| <kbd>Up</kbd>                                                     | Resize window (only in resize mode) up.           | 
| <kbd>F1</kbd>                                                     | Open workspace #1                                 |
| <kbd>Win</kbd>+<kbd>2</kbd>                                       | Open workspace #2                                 |
| <kbd>F3</kbd>                                                     | Open workspace #3                                 |
| <kbd>F4</kbd>                                                     | Open workspace #4                                 |
| <kbd>F5</kbd>                                                     | Open workspace #5                                 |
| <kbd>F6</kbd>                                                     | Open workspace #6                                 |
| <kbd>F7</kbd>                                                     | Open workspace #7                                 |
| <kbd>F8</kbd>                                                     | Open workspace #8                                 |
| <kbd>F9</kbd>                                                     | Open workspace #9                                 |
| <kbd>F10</kbd>                                                    | Open workspace #10                                |
| <kbd>F11</kbd>                                                    | Open workspace #11                                |
| <kbd>F12</kbd>                                                    | Open workspace #12                                |
| <kbd>Win</kbd>+<kbd>Print</kbd>                                   | Open workspace #13                                |
| <kbd>Pause</kbd>                                                  | Open workspace #14                                |
| <kbd>Insert</kbd>                                                 | Open worksapce #15                                |
| <kbd>Home</kbd>                                                   | Open workspace #16                                |
| <kbd>Page Up</kbd>                                                | Open worksapce #17                                |
| <kbd>Win</kbd>+<kbd>Delete</kbd>                                  | Open workspace #18                                |
| <kbd>End</kbd>                                                    | Open worksapce #19                                |
| <kbd>Page Down</kbd>                                              | Open workspace #20                                |
| <kbd>Print</kbd>                                                  | Take a screenshot and copy it to clipboard.       |
| <kbd>Win</kbd>+<kbd>F1</kbd>                                      | Open workspace #21                                |
| <kbd>Win</kbd>+<kbd>F2</kbd>                                      | Open workspace #22                                |
| <kbd>Win</kbd>+<kbd>F3</kbd>                                      | Open workspace #23                                |
| <kbd>Win</kbd>+<kbd>F4</kbd>                                      | Open workspace #24                                |
| <kbd>Win</kbd>+<kbd>F5</kbd>                                      | Open workspace #25                                |
| <kbd>Win</kbd>+<kbd>F6</kbd>                                      | Open workspace #26                                |
| <kbd>Win</kbd>+<kbd>F7</kbd>                                      | Open workspace #27                                |
| <kbd>Win</kbd>+<kbd>F8</kbd>                                      | Open workspace #28                                |
| <kbd>Win</kbd>+<kbd>F9</kbd>                                      | Open workspace #29                                |
| <kbd>Win</kbd>+<kbd>F10</kbd>                                     | Open workspace #30                                |
| <kbd>Win</kbd>+<kbd>F11</kbd>                                     | Open workspace #31                                |
| <kbd>Win</kbd>+<kbd>F12</kbd>                                     | Open workspace #32                                |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>1</kbd>                       | Move selected workspace to monitor 1              |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>2</kbd>                       | Move selected workspace to monitor 2              |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd>                      | Move focused window (silently) to workspace #1    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>2</kbd>                      | Move focused window (silently) to workspace #2    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>3</kbd>                      | Move focused window (silently) to workspace #3    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>4</kbd>                      | Move focused window (silently) to workspace #4    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>5</kbd>                      | Move focused window (silently) to workspace #5    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>6</kbd>                      | Move focused window (silently) to workspace #6    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>7</kbd>                      | Move focused window (silently) to workspace #7    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>8</kbd>                      | Move focused window (silently) to workspace #8    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>9</kbd>                      | Move focused window (silently) to workspace #9    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>0</kbd>                      | Move focused window (silently) to workspace #10   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F1</kbd>                     | Move focused window (silently) to workspace #11   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F2</kbd>                     | Move focused window (silently) to workspace #12   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F3</kbd>                     | Move focused window (silently) to workspace #13   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F4</kbd>                     | Move focused window (silently) to workspace #14   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F5</kbd>                     | Move focused window (silently) to workspace #15   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F6</kbd>                     | Move focused window (silently) to workspace #16   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F7</kbd>                     | Move focused window (silently) to workspace #17   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F8</kbd>                     | Move focused window (silently) to workspace #18   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F9</kbd>                     | Move focused window (silently) to workspace #19   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F10</kbd>                    | Move focused window (silently) to workspace #20   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F11</kbd>                    | Move focused window (silently) to workspace #21   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F12</kbd>                    | Move focused window (silently) to workspace #22   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Print</kbd>                  | Move focused window (silently) to workspace #23   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Pause</kbd>                  | Move focused window (silently) to workspace #24   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Insert</kbd>                 | Move focused window (silently) to workspace #25   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Home</kbd>                   | Move focused window (silently) to workspace #26   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Page Up</kbd>                | Move focused window (silently) to workspace #27   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Delete</kbd>                 | Move focused window (silently) to workspace #28   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>End</kbd>                    | Move focused window (silently) to workspace #29   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Page Down</kbd>              | Move focused window (silently) to workspace #30   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>`</kbd> (Grave)              | Move focused window (silently) to workspace #31   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>-</kbd> (Minus)              | Move focused window (silently) to workspace #32   |
| <kbd>Win</kbd>+<kbd>a</kbd>                                       | Expand out of tabbed mode                         |  
| <kbd>Win</kbd>+<kbd>b</kbd>                                       | Open Brave.                                       | 
| <kbd>Win</kbd>+<kbd>c</kbd>                                       | Open Google Chat Chrome app                       | 
| <kbd>Win</kbd>+<kbd>d</kbd>                                       | Open rofi dmenu                                   | 
| <kbd>Win</kbd>+<kbd>e</kbd>                                       | Delete current wallpaper and show next one.       | 
| <kbd>Win</kbd>+<kbd>m</kbd>                                       | Open WhatsApp web                                 |
| <kbd>Win</kbd>+<kbd>f</kbd>                                       | Set window to full screen.                        | 
| <kbd>Win</kbd>+<kbd>g</kbd>                                       | Launch gtop in Alacritty.                         |
| <kbd>Win</kbd>+<kbd>h</kbd>                                       | Launch hyfetch in kitty.                          |
| <kbd>Win</kbd>+<kbd>k</kbd>                                       | Open kitty terminal.                              |
| <kbd>Win</kbd>+<kbd>n</kbd>                                       | Specify the number of wallpaper shown.            | 
| <kbd>Win</kbd>+<kbd>o</kbd>                                       | Open RuneScape.                                   |
| <kbd>Win</kbd>+<kbd>p</kbd>                                       | Open file manager (Nautilus).                     |
| <kbd>Win</kbd>+<kbd>q</kbd>                                       | Close current window.                             |
| <kbd>Win</kbd>+<kbd>s</kbd>                                       | Change wallpaper to a randomly selected one.      |
| <kbd>Win</kbd>+<kbd>t</kbd>                                       | Enter tabbed mode.                                |
| <kbd>Win</kbd>+<kbd>v</kbd>                                       | Open VirtualBox.                                  |
| <kbd>Win</kbd>+<kbd>w</kbd>                                       | Change wallpaper to next one in list.             |
| <kbd>Win</kbd>+<kbd>z</kbd>                                       | Change wallpaper to previous one in list.         |
| <kbd>Win</kbd>+<kbd>Left</kbd>                                    | Move focus left.                                  |
| <kbd>Win</kbd>+<kbd>Right</kbd>                                   | Move focus right.                                 |
| <kbd>Win</kbd>+<kbd>Down</kbd>                                    | Move focus down.                                  |
| <kbd>Win</kbd>+<kbd>Up</kbd>                                      | Move focus up.                                    |
| <kbd>Win</kbd>+<kbd>Space</kbd>                                   | Change keyboard (between US and Brazilian Portuguese). |
| <kbd>Win</kbd>+<kbd>Tab</kbd>                                     | Open Alacritty terminal.                          |
| <kbd>Win</kbd>+<kbd>Return</kbd>                                  | Open Alacritty terminal.                          |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>1</kbd>                        | Move focus to tab 1.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>2</kbd>                        | Move focus to tab 2.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>3</kbd>                        | Move focus to tab 3.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>4</kbd>                        | Move focus to tab 4.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>5</kbd>                        | Move focus to tab 5.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>6</kbd>                        | Move focus to tab 6.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>7</kbd>                        | Move focus to tab 7.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>8</kbd>                        | Move focus to tab 8.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>9</kbd>                        | Move focus to tab 9.                              |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>0</kbd>                        | Move focus to tab 10.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F1</kbd>                       | Move focus to tab 11.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F2</kbd>                       | Move focus to tab 12.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd>                       | Move focus to tab 13.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F4</kbd>                       | Move focus to tab 14.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F5</kbd>                       | Move focus to tab 15.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F6</kbd>                       | Move focus to tab 16.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F7</kbd>                       | Move focus to tab 17.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F8</kbd>                       | Move focus to tab 18.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F9</kbd>                       | Move focus to tab 19.                             |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F10</kbd>                      | Move focus to tab 20.                             |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>f</kbd>                       | Open nerd fonts cheat sheet webpage in browser.   |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>m</kbd>                       | Move selected window to other monitor.            |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>o</kbd>                       | Open NixOS options search webpage in browser.     |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>p</kbd>                       | Open NixOS packages search webpage in browser.    |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>r</kbd>                       | Rebuild NixOS.                                    |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>s</kbd>                       | Repair the Nix store.                             |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>u</kbd>                       | Update NixOS without repairing the Nix store.     |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>w</kbd>                       | Open NixOS Wiki webpage in browser.               |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>b</kbd>                      | Open bluetooth manager                            |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>d</kbd>                      | Launch Duoingo app.                               |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>e</kbd>                      | Exit Hyprland.                                    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>f</kbd>                      | Open Facebook Chrome app.                         |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>i</kbd>                      | Open Instagram Chrome app.                        |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>j</kbd>                      | Move window left (not including tabbed windows).  |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>k</kbd>                      | Move window down (not including tabbed windows).  |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>l</kbd>                      | Move window up (not including tabbed windows).    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>n</kbd>                      | Edit NixOS configuration files.                   |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>p</kbd>                      | Move tab focus to the left.                       |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>q</kbd>                      | Open Quora Chrome app                             |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>r</kbd>                      | Enter window resizing mode.                       |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>s</kbd>                      | Shutdown OS.                                      |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>w</kbd>                      | Open windows list in rofi.                        |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>;</kbd>                      | Move window right (not including tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Left</kbd>                   | Move window left (tabbed windows).                |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Down</kbd>                   | Move window down (tabbed windows).                |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Up</kbd>                     | Move window up (tabbed windows).                  |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Right</kbd>                  | Move window right (tabbed windows).               |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd>                 | Open workspace of Alacritty terminal.             |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>                  | Toggle float of focused window.                   | 

# nixpkgs
## Antigravity package
Essentially just a copy of the `antigravity` package in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) with shell/hyprland/updates auto-updating it. 

## Marvin package
[The Marvin package](/nixpkgs/marvin/) is essentially just a copy of the `marvin` package in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs); I keep it as an overlay just so that I can more easily update it to the latest version when a new release comes out. I do update it in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs), too, but it can take a month for my PRs to be merged. 

## OpenRA package
[The OpenRA package](/nixpkgs/openra/) utilizes `$HOME/GitHub/others/OpenRA` as the source directory for [its git repository](https://github.com/OpenRA/OpenRA). It will install the latest git commit and version it as `<commit number>.git.<commit 7-character hash>`. It is a modified version of the OpenRA package in [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs) as of ~October 2025. I use this one as it is more up-to-date, builds from a local copy of the git repo and has a version string I prefer. 

To update the [deps.json](/nixpkgs/openra/engines.git/deps.json) file for OpenRA git package, run:

```bash
nix-build --arg pkgs '(import <nixpkgs> {})' -A engines.git
```

in [nixpkgs/openra](/nixpkgs/openra/). Or simply run `openraup`. The package assumes you have a local copy of the OpenRA git repo at `${homeDir}/GitHub/others/OpenRA` (where `${homeDir}` is from `nix/lib.nix`).

# Shell profile
Within shell/root is my root shell profile files, and within shell/user is my user shell profile files. I have many functions designed to make my time in the terminal more pleasant.

## Package management commands
* `nixcg` is used to remove old generations and sources with `sudo nix-collect-garbage -d`.
* `nixdg` is used to delete specified generations. 
* `nixdiff` will show the differences between the two most recent generations of your system.
* `nixfrb` is used to build the flake-based system configuration.
* `nixfu` will update your flake.lock file. 
* `nixlg` will list generations.
* `nixrb` (alias `rebuild`) will rebuild your system without using your flake setup.
* `nixrsu` will run `nixfu` and `nixfrb`, if nixfu updated flake.lock. 
* `nixs` will search for a package in a specified repository. First argument is repo name and second argument is the package name.
* `nixspc` will count the number of packages in a specified repository. 
* `nixstrep` will try to repair the Nix store, if necessary.
* `nixver` will show the version of your NixOS system based on your installed channels.
* `update` will run `nixrsu`, `nixstrep` and `nixcg`. 
* `upgrade` will upgrade your system to the latest stable NixOS release. Shell profile is set up to automatically check for upgrades within 35 days of the end of life of your installed version of NixOS. 
* `rollback` will roll back your system to the previous generation.

# Wallpaper script
There is a script within this repository called `wallpaper` that will, using swaybg, set your background to a wallpaper in Arch's `/usr/share/wallpapers`, `/usr/share/backgrounds`, `/usr/share/antergos/wallpapers`, `~/.local/share/backgrounds`, `~/.local/share/wallpapers` or `~/Pictures/Wallpapers`. It is used by some Waybar widgets mentioned below. I originally used hyprpaper to set the wallpaper, I find hyprpaper more difficult to use and I also use the wallpaper script under Niri.

## Syntax

```bash
wallpaper <algorithm/no> [direction]
```

The algorithm/no argument is mandatory; the direction argument is optional. 

The algorithm argument decides which algorithm is used to decide the wallpaper set as your background. If you give it the argument `random` (first letter's case doesn't matter), you will get a randomly decided wallpaper out of those within those specified directories. If you give it the argument `systematic` (first letter's case also doesn't matter), wallpaper will systematically go through the wallpapers one by one. 

An alternative to the algorithm argument is the no argument which specifies the number of the wallpaper to be displayed. Keep in mind that list-wallpapers (which shows wallpapers with Vim line numbers) displays wallpapers with a number one higher than the number used by the wallpaper script (as wallpaper script numbers start at 0, whereas Vim starts at 1).  

The direction argument, which is only applicable if the first argument is algorithm, can be "previous" or something else. If it is previous and the first argument is "systematic", this will lead to the previous wallpaper being shown. Otherwise the next wallpaper will be shown. This is also the default behaviour if direction is omitted.

# Waybar
The waybar has the below components. The order below formerly referred to their order left to right, but that's not the case anymore.

## NixOS menu (): only shown on monitor 1
which gives you options for (all websites opened in Chrome and all directories opened in Antigravity):
* Opening up the Nerd font cheat sheet websites.
* Opening up NixOS-configs repo on GitHub.
* Opening up the NixOS options search.
* Opening up the NixOS packages search.
* Opening up the NixOS Wiki.
* Rebuilding one's system.
* Repairing the Nix store.
* Update one's system without repairing the store.
* Opening NixOS-configs in the default code editor.
* Suspend.
* Hibernate.
* Shutdown.
* Logout.
* Reboot.

## Workspaces (which are numbered): shown on both monitors
Workspaces are shown here only on the monitor in which they're active.

## Weather conditions: shown on monitor 1
Obtained by wttr.in. Beware that wttr.in can be quite unreliable at times.

The background colour of this depends on the temperature. Temperatures of &lt;10&deg;C are <span style="color: #1565C0;">blue</span>, between 10 and <15&deg;C are <span style="color: #2196F3">lighter blue</span>, between 15 and <20&deg;C are <span style="color: #03DAC6">cyan</span>, between 20 and <25&deg;C are <span style="color: #4CAF50">green</span>, between 25 and <30&deg;C are <span style="color: #EF6C00">orange</span>, between 30 and <35&deg;C are <span style="color: #FF5722">light red</span>, between 35 and <40&deg;C are <span style="color: #D32F2F">medium red</span> and &geq;40&deg;C are <span style="color: #B71C1C">dark red</span>.

## Pulseaudio: shown on monitor 1
Shows the battery status and volume of your output audio device (as percentages). Has a purple background and white text. You can decrease or increase volume by scrolling on it. Left clicking opens pavucontrol. 

If using headphones, the   symbol will be shown; if using bluetooth, the  symbol will be shown. These will be to the immediate left of the audio volume percentage. If these are wireless, you will also see a battery symbol (the specifics of this symbol will depend on the charge in a way explained in the ["Phone battery status and notifications"](#phone-battery-status-and-notifications-shown-on-both-monitors) section) and the battery charge to its right.

## Uptime (󰔚): shown on monitor 1
Shows the uptime in the format: hour(s):minute(s):second(s).

## Wallpaper number widget (󰸉): shown on monitor 1
It displays the number of the wallpaper most recently displayed on your desktop, then a forward slash, and then the total number of wallpapers you have installed on your system.

## Previous wallpaper button (): shown on monitor 1
When clicked, this changes your wallpaper to the previous one in your collection (keeping in mind, this is when you're using the systematic algorithm for the wallpaper script).

## Random wallpaper button (): shown on monitor 1
When clicked, this changes your wallpaper to a randomly selected one.

## Forward wallpaper button (): shown on monitor 1
When clicked, this changes your wallpaper to the next systematically selected one.

## Wallpaper specification button (): shown on monitor 1 
When clicked, this changes your wallpaper to a wallpaper whose number you specify in a pop-up window.

## The title of your currently focused window: shown on both monitors

## Keyboard layout (): shown on monitor 2
Is followed by its two-letter initial. I have two colours set up for this widget: us=<span style="color: #018786">teal</span>, which is also the default, and br=<span style="color: #AD1457">purple</span>.

## Motherboard temperature (): shown on both monitors
It is colour coded with <40&deg;C being <span style="#42A5F5">sky blue</span>, 40 to <60&deg;C being <span style="color: #66BB6A">green</span>, 60 to <75&deg;C being <span style="color: #FFA726">orange</span>, 75 to <85&deg;C being <span style="color: #FF7043">light red</span> and &geq;85&deg;C being <span style="color: #EF5350">deep red</span>. 

Left clicking this opens a graph showing the history of the motherboard temperature.

## Root file system usage (/): shown on monitor 1 
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>.

Left clicking this opens gtop in Alacritty. Right clicking runs `nixcg` in Alacritty.

## Arch file system usage (A): shown on monitor 1
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to &lt;50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to &lt;75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to &lt;95%, it is <span style="color: #FF7043">orange</span>. If it is &geq;95%, it is <span style="color: #EF5350">red</span>. The reason for the higher boundaries is that my /data partition was already very full when this NixOS install was setup.

## Data file system usage (D): shown on monitor 1
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to &lt;50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to &lt;75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to &lt;95%, it is <span style="color: #FF7043">orange</span>. If it is &geq;95%, it is <span style="color: #EF5350">red</span>. The reason for the higher boundaries is that my /data partition was already very full when this NixOS install was setup.

## Internet download speed () on enp24s0 interface in bps: shown on monitor 2
If the download speed is &lt;10486 bits per second, it is <span style="color: #00796B">green</span>. If it is between 10486 and &lt;104858 bits per second, it is <span style="color: #4CAF50">light green</span>. If it is between 104858 and &lt;1048576 bits per second, it is <span style="color: #FF9800">orange</span>. If it is between 1048576 and &lt;5242880 bits per second, it is <span style="color: #D32F2F">light red</span>. If it is &geq;5242880 bits per second, it is <span style="color: #B71C1C">darker red</span>.

Left clicking this opens nethogs, which is a command-line app monitoring network activity, in Alacritty. Right clicking prompts the user for how long they want to monitor network usage for and then, after this period, it displays network usage and network usage by process. Middle clicking produces a pop up window with a graph of download speed (on enp24s0) history against time.

## Internet upload speed () on enp24s0 interface in bps: shown on monitor 2
If the download speed is &lt;5243 bits per second, it is <span style="color: #00796B">green</span>. If it is between 5243 and &lt;52429 bits per second, it is <span style="color: #4CAF50">light green</span>. If it is between 52429 and &lt;524288 bits per second, it is <span style="color: #FF9800">orange</span>. If it is between 524288 and &lt;5242880 bits per second, it is <span style="color: #D32F2F">light red</span>. If it is &geq;5242880 bits per second, it is <span style="color: #B71C1C">darker red</span>. 

Left clicking and right clicking does the same thing as per download speed. Middle clicking largely does the same as per download, except with upload speeds. 

## CPU usage percentage (): shown on monitor 1
If the CPU usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 

Left clicking this opens gtop, a command-line system monitor app, in Alacritty. Right clicking this opens a graph of the CPU usage over time.

## RAM usage percentage (): shown on monitor 1
If the CPU usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 

Left clicking this opens gtop in Alacritty. Right clicking this opens a graph of the RAM usage over time.

## zRAM utilization (󰾆): shown on monitor 1
zRAM is only used if RAM is used up.

## Swap utilization (󰓡): shown on monitor 1
Swap is only used if zRAM and RAM are used up. 

## GPU memory usage percentage (): shown on monitor 2
If the GPU memory usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 

Left clicking this opens up an Alacritty terminal with nvidia-smi output (showing GPU utilization and processes utilizing it). Right clicking this opens a graph of the GPU memory usage over time.

## GPU utilization percentage (󱃏): shown on monitor 2
If the GPU utilization is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>.

Left clicking this opens up an Alacritty terminal with nvidia-smi output (showing GPU utilization and processes utilizing it). Right clicking this opens a graph of the GPU utilization over time.

## Updates<sup>1</sup> available: shown on both monitors
* "h" indicates updates to home-manager are available.
* "m" indicates updates to nixpkgs-master are available.
* "s" indicates that updates to nixpkgs (stable branch) are available.
* "u" indicates updates to nixpkgs-unstable are available.
* 󱇛 indicates that hy3 updates are available.
*  indicates that Hyprland updates are available.
* 󱢇 indicates that OpenRA updates are available.
* 󰄻 indicates that Marvin updates are available.

## Phone battery status and notifications: shown on both monitors
Battery status is symbolized with:
* 󰂅 if the battery is charging and has 90% to 100% charge.
* 󰂄 if the battery is charging and has 70% to <90% charge.
* 󰂃 if the battery is charging and has 50% to <70% charge.
* 󰂂 if the battery is charging and has 30% to <50% charge.
* 󰢜 if the battery is charging and has <30% charge.
* 󰁹 if the battery is not charging and has &geq;90% charge.
* 󰂀 if the battery is not charging and has 70% to <90% charge.
* 󰁾 if the battery is not charging and has 50% to <70% charge.
* 󰁼 if the battery is not charging and has 30% to <50% charge.
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #FF7700; color: #000000;">󰁺</span> if the battery is 15% to &lt;30%.
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #FF1744; color: #ffffff;">󰁻</span> if the battery is &lt;15% charge.

Notifications are symbolized with: 
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #FF1744; color: #ffffff;">󰄷</span> if disconnected.
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #aa4400; color: #ffffff;">󱅫</span> if there is a notification.
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #ac22ca; color: #ffffff;">󰂚</span> if there are no notifications.
* <span style="margin: 6px 1px; padding: 5px 8px; border-radius: 4px; background-color: #678900; color: #ffffff;">󰂛</span> if in do not disturb mode.

## Clock: on both monitors
With AM/PM time with seconds, short day of the week name, day of the month/month of the year (short format).

## Footnotes
1. The script that manages this runs every ~20 minutes, and runs `nixfu` as part of checking for updates. If any are available, you merely need to run `nixfrb` to install them. Left clicking the widget, will open a terminal that runs `nixfrb`.

# Workspaces
## Monitor 1
Workspace 1: Chrome (<kbd>F1</kbd>).<br/>
Workspace 2: Kitty terminal that takes up just enough of the screen to show Hyfetch output, useful for taking screenshots(<kbd>Win</kbd>+<kbd>2</kbd>).<br/>
Workspace 5: Antigravity/VSCode (<kbd>F5</kbd>).<br/>
Workspace 7: Terminal and Chrome windows for dealing with HPC job submission (<kbd>F7</kbd>).<br/>
Workspace 15: Brave (<kbd>Insert</kbd>).<br/>
Workspace 16: Instagram (<kbd>Home</kbd>).<br/>
Workspace 18: Okular (<kbd>Win</kbd>+<kbd>Delete</kbd>).<br/>
Workspace 21: Steam (<kbd>Win</kbd>+<kbd>F1</kbd>).<br/>
Workspace 25: VLC media player (<kbd>Win</kbd>+<kbd>F5</kbd>).<br/>

## Monitor 2
Workspace 3: Bluetooth (<kbd>F3</kbd>).<br/>
Workspace 4: WinBoat (<kbd>F4</kbd>).<br/>
Workspace 6: WinBoat FreeRDP window for working in Word (<kbd>F6</kbd>).<br/>
Workspace 8: Gaming, especially RuneScape or OpenRA (<kbd>F8</kbd>).<br/>
Workspace 9: WhatsApp Web (<kbd>F9</kbd>).<br/>
Workspace 10: Google Chat (<kbd>F10</kbd>).<br/>
Workspace 11: Discord (<kbd>F11</kbd>).<br/>
Workspace 12: Boo (<kbd>F12</kbd>).<br/>
Workspace 13: Nautilus file manager (<kbd>Win</kbd>+<kbd>Print</kbd>).<br/>
Workspace 14: KDE Connect (<kbd>Pause</kbd>).<br/>
Workspace 17: Lutris (<kbd>Page Up</kbd>).<br/>
Workspace 19: Duolingo (<kbd>End</kbd>).<br/>
Workspace 20: Terminal (<kbd>Page Down</kbd>).<br/>
Workspace 22: Payday 2 (<kbd>Win</kbd>+<kbd>F2</kbd>).<br/>
Workspace 23: Google Earth (<kbd>Win</kbd>+<kbd>F3</kbd>).<br/>
Workspace 24: Boo (<kbd>Win</kbd>+<kbd>F4</kbd>).<br/>
Workspace 26: VLC media player (<kbd>Win</kbd>+<kbd>F6</kbd>).<br/>
Workspace 27: Brave private window (<kbd>Win</kbd>+<kbd>F7</kbd>).<br/>
Workspace 28: Virtual machine manager (<kbd>Win</kbd>+<kbd>F8</kbd>).<br/>
Workspaces 29-31: Virt Viewer (<kbd>Win</kbd>+<kbd>F9</kbd> to <kbd>F11</kbd>).<br/>
Workspace 32: Chemistry apps (<kbd>Win</kbd>+<kbd>F12</kbd>).<br/>