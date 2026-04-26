# My NixOS configuration files
![Hyprland on NixOS screenshot as of 11 April 2026](https://fusion809.github.io/images/Hyprland/Hyprland_NixOS_2026-04-11.png)
**Figure 1: Hyprland NixOS configuration as of 11 April 2026.**

These are my [NixOS 25.11](https://nixos.org) configuration files for my [MS-7B90](https://www.msi.com/Motherboard/B450M-BAZOOKA-PLUS/Specification) PC with dual 1080p monitor setup. [Hyprland](https://hypr.land/) is my graphical user interface (GUI). [Flakes](https://nixos.wiki/wiki/Flakes) are used to manage packages. 

# Table of Contents
<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Language breakdown](#language-breakdown)
- [Shell profile](#shell-profile)
  - [Package management commands](#package-management-commands)
- [nixpkgs](#nixpkgs)
  - [Antigravity package](#antigravity-package)
  - [Marvin package](#marvin-package)
  - [OpenRA package](#openra-package)
- [Hyprland](#hyprland)
  - [Autostart](#autostart)
  - [Default apps](#default-apps)
  - [Keyboard shortcuts](#keyboard-shortcuts)
  - [Wallpaper script](#wallpaper-script)
    - [Syntax](#syntax)
  - [Waybar](#waybar)
  - [Workspaces](#workspaces)
    - [Monitor 1](#monitor-1)
    - [Monitor 2](#monitor-2)
- [History](#history)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


# Language breakdown
<!-- STATS START -->
| Language | Lines | Lines % | Complexity | Complexity % |
| :--- | :--- | :--- | :--- | :--- |
| Shell | 9113 | 61.19% | 1395 | 86.59% |
| Nix | 2904 | 19.50% | 147 | 9.12% |
| CSS | 831 | 5.58% | 0 | 0.00% |
| JSONC | 436 | 2.93% | 0 | 0.00% |
| Markdown | 433 | 2.91% | 0 | 0.00% |
| Patch | 396 | 2.66% | 0 | 0.00% |
| JSON | 337 | 2.26% | 0 | 0.00% |
| Python | 310 | 2.08% | 65 | 4.03% |
| XML | 78 | 0.52% | 0 | 0.00% |
| JavaScript | 41 | 0.28% | 4 | 0.25% |
| TOML | 13 | 0.09% | 0 | 0.00% |
| **Total** | **14892** | **100.00%** | **1611** | **100.00%** |
<!-- STATS END -->

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

# Hyprland
I run the latest [Hyprland](https://github.com/hyprwm/Hyprland), even when [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs)' Hyprland is not the latest version. It is managed by my [nix/flake.nix](nix/flake.nix) file and the [shell/hyprland/updates](/shell/hyprland/updates) script &mdash; which is run by Waybar's custom/updates widget &mdash; updates it. I also utilize the [hy3](https://github.com/outfoxxed/hy3) plugin to provide the window tabbing I am used to from i3 and [hyprsession](https://github.com/joshurtree/hyprsession) to provide a backup of old sessions. 

[shell/hyprland](/shell/hyprland/) contains shell scripts that are part of my Hyprland setup, or used to launch apps under Hyprland. [dotfiles/](/dotfiles/) contains my Hyprland configuration files and desktop config files for the aforementioned apps. 

## Autostart
Applications and programs autostarted include the default browser, virtual machine manager, the Brave browser, Waybar, Discord, Blueman Manager, Kitty (with Hyfetch), WinBoat, GNOME Files, Alacritty, my Debian 13 virtual machine, and cliphist and wl-clip-persist for managing the clipboard. A command is also run to show the next wallpaper, another kills old processes for showing the wallpaper that are errantly running, and another logs network activity so it can be used for creating graphs if one clicks the network widgets in the Waybar.

## Default apps
* Application menu is [Rofi](https://github.com/davatorium/rofi).
* File manager is [GNOME Files](https://apps.gnome.org/en-GB/Nautilus/), as it has among the best Wayland support of any graphical file manager. 
* Terminal is [Alacritty](https://alacritty.org/), although [Kitty](https://sw.kovidgoyal.net/kitty/) is also installed and used for creating [Hyfetch](https://github.com/hykilpikonna/hyfetch) output-inclusive screenshots. 
* Text editor/IDE is [Antigravity](https://antigravity.google/). [Neovim](https://neovim.io/) and [Visual Studio Code](https://code.visualstudio.com/) are also installed. 
* Web browser is [Google Chrome](https://www.google.com/chrome/), although [Brave](https://brave.com/) and [Firefox](https://www.firefox.com/en-US/) are also installed. 

## Keyboard shortcuts
| Keyboard combination                                              | Action                |
|-------------------------------------------------------------------|-----------------------|
| <kbd>h</kbd>                                                      | Resize window (only in resize mode) to the left. | 
| <kbd>l</kbd>                                                      | Resize window (only in resize mode) to the right. | 
| <kbd>k</kbd>                                                      | Resize window (only in resize mode) down. | 
| <kbd>j</kbd>                                                      | Resize window (only in resize mode) up. | 
| <kbd>Left</kbd>                                                   | Resize window (only in resize mode) to the left. | 
| <kbd>Right</kbd>                                                  | Resize window (only in resize mode) to the right. | 
| <kbd>Down</kbd>                                                   | Resize window (only in resize mode) down. | 
| <kbd>Up</kbd>                                                     | Resize window (only in resize mode) up. | 
| <kbd>F1</kbd>                                                     | Open workspace #1     |
| <kbd>Win</kbd>+<kbd>2</kbd>                                       | Open workspace #2     |
| <kbd>F3</kbd>                                                     | Open workspace #3     |
| <kbd>F4</kbd>                                                     | Open workspace #4     |
| <kbd>F5</kbd>                                                     | Open workspace #5     |
| <kbd>F6</kbd>                                                     | Open workspace #6     |
| <kbd>F7</kbd>                                                     | Open workspace #7     |
| <kbd>F8</kbd>                                                     | Open workspace #8     |
| <kbd>F9</kbd>                                                     | Open workspace #9     |
| <kbd>F10</kbd>                                                    | Open workspace #10    |
| <kbd>F11</kbd>                                                    | Open workspace #11    |
| <kbd>F12</kbd>                                                    | Open workspace #12    |
| <kbd>Win</kbd>+<kbd>Print</kbd>                                   | Open workspace #13    |
| <kbd>Pause</kbd>                                                  | Open workspace #14    |
| <kbd>Insert</kbd>                                                 | Open worksapce #15    |
| <kbd>Home</kbd>                                                   | Open workspace #16    |
| <kbd>Page Up</kbd>                                                | Open worksapce #17    |
| <kbd>Win</kbd>+<kbd>Delete</kbd>                                  | Open workspace #18    |
| <kbd>End</kbd>                                                    | Open worksapce #19    |
| <kbd>Page Down</kbd>                                              | Open workspace #20    |
| <kbd>Print</kbd>                                                  | Take a screenshot and copy it to clipboard. | 
| <kbd>Win</kbd>+<kbd>F1</kbd>                                      | Open workspace #21    |
| <kbd>Win</kbd>+<kbd>F2</kbd>                                      | Open workspace #22    |
| <kbd>Win</kbd>+<kbd>F3</kbd>                                      | Open workspace #23    |
| <kbd>Win</kbd>+<kbd>F4</kbd>                                      | Open workspace #24    |
| <kbd>Win</kbd>+<kbd>F5</kbd>                                      | Open workspace #25    |
| <kbd>Win</kbd>+<kbd>F6</kbd>                                      | Open workspace #26    |
| <kbd>Win</kbd>+<kbd>F7</kbd>                                      | Open workspace #27    |
| <kbd>Win</kbd>+<kbd>F8</kbd>                                      | Open workspace #28    |
| <kbd>Win</kbd>+<kbd>F9</kbd>                                      | Open workspace #29    |
| <kbd>Win</kbd>+<kbd>F10</kbd>                                     | Open workspace #30    |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>1</kbd>                       | Move selected workspace to monitor 1 |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>2</kbd>                       | Move selected workspace to monitor 2 |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>1</kbd>                      | Move focused window (silently) to workspace #1     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>2</kbd>                      | Move focused window (silently) to workspace #2     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>3</kbd>                      | Move focused window (silently) to workspace #3     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>4</kbd>                      | Move focused window (silently) to workspace #4     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>5</kbd>                      | Move focused window (silently) to workspace #5     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>6</kbd>                      | Move focused window (silently) to workspace #6     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>7</kbd>                      | Move focused window (silently) to workspace #7     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>8</kbd>                      | Move focused window (silently) to workspace #8     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>9</kbd>                      | Move focused window (silently) to workspace #9     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>0</kbd>                      | Move focused window (silently) to workspace #10    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F1</kbd>                     | Move focused window (silently) to workspace #11    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F2</kbd>                     | Move focused window (silently) to workspace #12    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F3</kbd>                     | Move focused window (silently) to workspace #13    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F4</kbd>                     | Move focused window (silently) to workspace #14    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F5</kbd>                     | Move focused window (silently) to workspace #15    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F6</kbd>                     | Move focused window (silently) to workspace #16    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F7</kbd>                     | Move focused window (silently) to workspace #17    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F8</kbd>                     | Move focused window (silently) to workspace #18    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F9</kbd>                     | Move focused window (silently) to workspace #19    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F10</kbd>                    | Move focused window (silently) to workspace #20    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F11</kbd>                    | Move focused window (silently) to workspace #21    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F12</kbd>                    | Move focused window (silently) to workspace #22    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Print</kbd>                  | Move focused window (silently) to workspace #23    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Pause</kbd>                  | Move focused window (silently) to workspace #24    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Insert</kbd>                 | Move focused window (silently) to workspace #25    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Home</kbd>                   | Move focused window (silently) to workspace #26    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Page Up</kbd>                | Move focused window (silently) to workspace #27    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Delete</kbd>                 | Move focused window (silently) to workspace #28    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>End</kbd>                    | Move focused window (silently) to workspace #29    |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Page Down</kbd>              | Move focused window (silently) to workspace #30    |
| <kbd>Win</kbd>+<kbd>a</kbd>                                       | Expand out of tabbed mode |  
| <kbd>Win</kbd>+<kbd>b</kbd>                                       | Open Brave. |
| <kbd>Win</kbd>+<kbd>c</kbd>                                       | Open Google Chat Chrome app |
| <kbd>Win</kbd>+<kbd>d</kbd>                                       | Open rofi dmenu            |
| <kbd>Win</kbd>+<kbd>e</kbd>                                       | Delete currently shown wallpaper and show next one. |
| <kbd>Win</kbd>+<kbd>m</kbd>                                       | Open WhatsApp web |
| <kbd>Win</kbd>+<kbd>f</kbd>                                       | Set window to full screen. | 
| <kbd>Win</kbd>+<kbd>g</kbd>                                       | Launch gtop in Alacritty. |
| <kbd>Win</kbd>+<kbd>h</kbd>                                       | Launch hyfetch in kitty. |
| <kbd>Win</kbd>+<kbd>k</kbd>                                       | Open kitty terminal. |
| <kbd>Win</kbd>+<kbd>n</kbd>                                       | Specify the number of wallpaper shown. | 
| <kbd>Win</kbd>+<kbd>o</kbd>                                       | Open RuneScape. |
| <kbd>Win</kbd>+<kbd>p</kbd>                                       | Open file manager (Nautilus). |
| <kbd>Win</kbd>+<kbd>q</kbd>                                       | Close current window. |
| <kbd>Win</kbd>+<kbd>s</kbd>                                       | Change wallpaper to a randomly selected one. |
| <kbd>Win</kbd>+<kbd>t</kbd>                                       | Enter tabbed mode.         |
| <kbd>Win</kbd>+<kbd>v</kbd>                                       | Open VirtualBox. |
| <kbd>Win</kbd>+<kbd>w</kbd>                                       | Set wallpaper to the one after the current one specified in `$HOME/.cache/swaybg-wallstate` |
| <kbd>Win</kbd>+<kbd>z</kbd>                                       | Set wallpaper to the one before the current one specified in `$HOME/.cache/swaybg-wallstate` |
| <kbd>Win</kbd>+<kbd>Left</kbd>                                    | Move focus left. |
| <kbd>Win</kbd>+<kbd>Right</kbd>                                   | Move focus right. |
| <kbd>Win</kbd>+<kbd>Down</kbd>                                    | Move focus down. |
| <kbd>Win</kbd>+<kbd>Up</kbd>                                      | Move focus up. |
| <kbd>Win</kbd>+<kbd>Space</kbd>                                   | Change keyboard (between US and Brazilian Portuguese). |
| <kbd>Win</kbd>+<kbd>Tab</kbd>                                     | Open Alacritty terminal. |
| <kbd>Win</kbd>+<kbd>Return</kbd>                                  | Open Alacritty terminal. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>1</kbd>                        | Move focus to tab 1. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>2</kbd>                        | Move focus to tab 2. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>3</kbd>                        | Move focus to tab 3. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>4</kbd>                        | Move focus to tab 4. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>5</kbd>                        | Move focus to tab 5. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>6</kbd>                        | Move focus to tab 6. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>7</kbd>                        | Move focus to tab 7. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>8</kbd>                        | Move focus to tab 8. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>9</kbd>                        | Move focus to tab 9. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>0</kbd>                        | Move focus to tab 10. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F1</kbd>                       | Move focus to tab 11. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F2</kbd>                       | Move focus to tab 12. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd>                       | Move focus to tab 13. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F4</kbd>                       | Move focus to tab 14. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F5</kbd>                       | Move focus to tab 15. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F6</kbd>                       | Move focus to tab 16. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F7</kbd>                       | Move focus to tab 17. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F8</kbd>                       | Move focus to tab 18. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F9</kbd>                       | Move focus to tab 19. |
| <kbd>Win</kbd>+<kbd>Alt</kbd>+<kbd>F10</kbd>                      | Move focus to tab 20. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>f</kbd>                      | Open nerd fonts cheat sheet webpage in browser. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>o</kbd>                      | Open NixOS options search webpage in browser. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>p</kbd>                      | Open NixOS packages search webpage in browser. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>r</kbd>                      | Rebuild NixOS. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>s</kbd>                      | Repair the Nix store. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>u</kbd>                      | Update NixOS without repairing the Nix store. |
| <kbd>Win</kbd>+<kbd>Ctrl</kbd>+<kbd>w</kbd>                      | Open NixOS Wiki webpage in browser. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>b</kbd>                      | Open bluetooth manager |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>d</kbd>                      | Launch Duoingo app. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>e</kbd>                      | Exit Hyprland. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>f</kbd>                      | Open Facebook Chrome app. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>i</kbd>                      | Open Instagram Chrome app. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>j</kbd>                      | Move window left (not including tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>k</kbd>                      | Move window down (not including tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>l</kbd>                      | Move window up (not including tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>n</kbd>                      | Edit NixOS configuration files. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>p</kbd>                      | Move tab focus to the left. | 
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>q</kbd>                      | Open Quora Chrome app |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>r</kbd>                      | Enter window resizing mode. | 
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>s</kbd>                      | Shutdown OS. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>w</kbd>                      | Open windows list in rofi |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>;</kbd>                      | Move window right (not including tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Left</kbd>                   | Move window left (tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Down</kbd>                   | Move window down (tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Up</kbd>                     | Move window up (tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Right</kbd>                  | Move window right (tabbed windows). |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd>                 | Open workspace of Alacritty terminal. |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>                  | Toggle float of focused window. | 

## Wallpaper script
There is a script within this repository called `wallpaper` that will, using swaybg, set your background to a wallpaper in Arch's `/usr/share/wallpapers`, `/usr/share/backgrounds`, `/usr/share/antergos/wallpapers`, `~/.local/share/backgrounds`, `~/.local/share/wallpapers` or `~/Pictures/Wallpapers`. It is used by some Waybar widgets mentioned below. I originally used hyprpaper to set the wallpaper, I find hyprpaper more difficult to use and I also use the wallpaper script under Niri.

### Syntax

```bash
wallpaper <algorithm/no> [direction]
```

The algorithm/no argument is mandatory; the direction argument is optional. 

The algorithm argument decides which algorithm is used to decide the wallpaper set as your background. If you give it the argument `random` (first letter's case doesn't matter), you will get a randomly decided wallpaper out of those within those specified directories. If you give it the argument `systematic` (first letter's case also doesn't matter), wallpaper will systematically go through the wallpapers one by one. 

An alternative to the algorithm argument is the no argument which specifies the number of the wallpaper to be displayed. Keep in mind that list-wallpapers (which shows wallpapers with Vim line numbers) displays wallpapers with a number one higher than the number used by the wallpaper script (as wallpaper script numbers start at 0, whereas Vim starts at 1).  

The direction argument, which is only applicable if the first argument is algorithm, can be "previous" or something else. If it is previous and the first argument is "systematic", this will lead to the previous wallpaper being shown. Otherwise the next wallpaper will be shown. This is also the default behaviour if direction is omitted.

## Waybar
The waybar has the following components, going from left to right:

<ul>
<li>(<i>Only shown on monitor 1</i>) The NixOS menu () which gives you options for (all websites opened in Chrome and all directories opened in Antigravity):
<ul>
<li>Opening up the Nerd font cheat sheet websites.</li>
<li>Opening up NixOS-configs repo on GitHub.</li>
<li>Opening up the NixOS options search.</li>
<li>Opening up the NixOS packages search.</li>
<li>Opening up the NixOS Wiki.</li>
<li>Rebuilding one's system.</li>
<li>Repairing the Nix store.</li>
<li>Update one's system without repairing the store.</li>
<li>Opening NixOS-configs in the default code editor.</li>
<li>Suspend.</li>
<li>Hibernate.</li>
<li>Shutdown.</li>
<li>Logout.</li>
<li>Reboot.</li>
</ul>
</li>
<li>Workspaces (which are numbered). Workspaces are shown here only on the monitor in which they're active.</li>
<li>Weather conditions, obtained by wttr.in. Beware that wttr.in can be quite unreliable at times.
<br/><br/>
The background colour of this depends on the temperature. Temperatures of &lt;10&deg;C are <span style="color: #1565C0;">blue</span>, between 10 and <15&deg;C are <span style="color: #2196F3">lighter blue</span>, between 15 and <20&deg;C are <span style="color: #03DAC6">cyan</span>, between 20 and <25&deg;C are <span style="color: #4CAF50">green</span>, between 25 and <30&deg;C are <span style="color: #EF6C00">orange</span>, between 30 and <35&deg;C are <span style="color: #FF5722">light red</span>, between 35 and <40&deg;C are <span style="color: #D32F2F">medium red</span> and &geq;40&deg;C are <span style="color: #B71C1C">dark red</span>.</li>
<li>Keyboard layout (  followed by its two-letter initial). I have two colours set up for this widget: us=<span style="color: #018786">teal</span>, which is also the default, and br=<span style="color: #AD1457">purple</span>.</li>
<li>Pulseaudio showing the volume of your output audio device. Has a purple background and white text. You can decrease or increase volume by scrolling on it. Left clicking opens pavucontrol.</li>
<li>(<i>Only shown on monitor 1</i>) Wallpaper number widget (󰸉): it displays the number of the wallpaper most recently displayed on your desktop, then a forward slash, and then the total number of wallpapers you have installed on your system.</li>
<!-- <li>A bin icon (󰆴) that, when clicked, will delete your current wallpaper and load the next wallpaper.</li> -->
<li>(<i>Only shown on monitor 1</i>) A left arrow () that, when clicked, changes your wallpaper to the previous one in your collection (keeping in mind, this is when you're using the systematic algorithm for the wallpaper script).</li>
<li>(<i>Only shown on monitor 1</i>) A shuffling arrow () that, when clicked, changes your wallpaper to a randomly selected one.</li>
<li>(<i>Only shown on monitor 1</i>) A forward arrow () that, when clicked, changes your wallpaper to the next systematically selected one.</li> 
<li>(<i>Only shown on monitor 1</i>) A collection of numbers () that, when clicked, changes your wallpaper to a wallpaper whose number you specify in a pop-up window.</li> 
<li>The title of your currently focused window.</li>
<li>Motherboard temperature () according to sensors. 
<br/><br/>
It is colour coded with <40&deg;C being <span style="#42A5F5">sky blue</span>, 40 to <60&deg;C being <span style="color: #66BB6A">green</span>, 60 to <75&deg;C being <span style="color: #FFA726">orange</span>, 75 to <85&deg;C being <span style="color: #FF7043">light red</span> and &geq;85&deg;C being <span style="color: #EF5350">deep red</span>. 
<br/><br/>
Left clicking this opens a graph showing the history of the motherboard temperature.</li>
<li>Used space (/) on your root file system. 
<br/><br/>
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>.
<br/><br/>
Left clicking this opens gtop in Alacritty. Right clicking runs `nixcg` in Alacritty.</li>
<li>Used space (A) on your Arch file system. 
<br/><br/>
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to &lt;50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to &lt;75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to &lt;95%, it is <span style="color: #FF7043">orange</span>. If it is &geq;95%, it is <span style="color: #EF5350">red</span>. The reason for the higher boundaries is that my /data partition was already very full when this NixOS install was setup.</li>
<li>Used space (D) on your data file system. 
<br/><br/>
If the used disk space is less than 25%, it is <span style="color: #66BB6A">green</span> If it is between 25 to &lt;50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to &lt;75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to &lt;95%, it is <span style="color: #FF7043">orange</span>. If it is &geq;95%, it is <span style="color: #EF5350">red</span>. The reason for the higher boundaries is that my /data partition was already very full when this NixOS install was setup.</li>
<li>Internet download speed () on enp24s0 interface in bps.
<br/><br/>
If the download speed is &lt;10486 bits per second, it is <span style="color: #00796B">green</span>. If it is between 10486 and &lt;104858 bits per second, it is <span style="color: #4CAF50">light green</span>. If it is between 104858 and &lt;1048576 bits per second, it is <span style="color: #FF9800">orange</span>. If it is between 1048576 and &lt;5242880 bits per second, it is <span style="color: #D32F2F">light red</span>. If it is &geq;5242880 bits per second, it is <span style="color: #B71C1C">darker red</span>.
<br/><br/>
Left clicking this opens nethogs, which is a command-line app monitoring network activity, in Alacritty. Right clicking prompts the user for how long they want to monitor network usage for and then, after this period, it displays network usage and network usage by process. Middle clicking produces a pop up window with a graph of download speed (on enp24s0) history against time.</li> 
<li>Internet upload speed () on enp24s0 interface in bps.
<br/><br/>
If the download speed is &lt;5243 bits per second, it is <span style="color: #00796B">green</span>. If it is between 5243 and &lt;52429 bits per second, it is <span style="color: #4CAF50">light green</span>. If it is between 52429 and &lt;524288 bits per second, it is <span style="color: #FF9800">orange</span>. If it is between 524288 and &lt;5242880 bits per second, it is <span style="color: #D32F2F">light red</span>. If it is &geq;5242880 bits per second, it is <span style="color: #B71C1C">darker red</span>. 
<br/><br/>
Left clicking and right clicking does the same thing as per download speed. Middle clicking largely does the same as per download, except with upload speeds.</li> 
<li>CPU usage percentage (). 
<br/><br/>
If the CPU usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 
<br/><br/>
Left clicking this opens gtop, a command-line system monitor app, in Alacritty. Right clicking this opens a graph of the CPU usage over time.</li>
<li>RAM usage percentage (). 
<br/><br/>
If the CPU usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 
<br/><br/>
Left clicking this opens gtop in Alacritty. Right clicking this opens a graph of the RAM usage over time.</li>
<li>GPU memory usage percentage (). 
<br/><br/>
If the GPU memory usage is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>. 
<br/><br/>
Left clicking this opens up an Alacritty terminal with nvidia-smi output (showing GPU utilization and processes utilizing it). Right clicking this opens a graph of the GPU memory usage over time.</li>
<li>GPU utilization percentage (󱃏). 
<br/><br/>
If the GPU utilization is less than 25%, it is <span style="color: #66BB6A">green</span>. If it is between 25 to <50%, it is <span style="color: #9CCC65">lighter green</span>. If it is between 50 to <75%, it is <span style="color: #FFCA28">yellow</span>. If it is between 75 to <90%, it is <span style="color: #FF7043">orange</span>. If it is &geq;90%, it is <span style="color: #EF5350">red</span>.
<br/><br/>
Left clicking this opens up an Alacritty terminal with nvidia-smi output (showing GPU utilization and processes utilizing it). Right clicking this opens a graph of the GPU utilization over time.</li>
<li>Updates available.<sup>1</sup>
<ul>
<li>"h" indicates updates to home-manager are available.</li>
<li>"m" indicates updates to nixpkgs-master are available.</li>
<li>"s" indicates that updates to nixpkgs (stable branch) are available.</li> 
<li>"u" indicates updates to nixpkgs-unstable are available.</li>
<li>󱇛 indicates that hy3 updates are available. </li>
<li> indicates that Hyprland updates are available. </li>
    <!---  indicates that Vim updates are available.-->
<li>󱢇 indicates that OpenRA updates are available.</li>
<li>󰄻 indicates that Marvin updates are available.</li>
</li> 
</ul>
<li>Clock with AM/PM time with seconds, short day of the week name, day of the month/month of the year (short format).</li>
</ul>

Footnotes:
1. The script that manages this runs every ~20 minutes, and runs `nixfu` as part of checking for updates. If any are available, you merely need to run `nixfrb` to install them. Left clicking the widget, will open a terminal that runs `nixfrb`.

## Workspaces
### Monitor 1
Workspace 1: Chrome (<kbd>F1</kbd>).<br/>
Workspace 2: Kitty terminal that takes up just enough of the screen to show Hyfetch output, useful for taking screenshots(<kbd>Win</kbd>+<kbd>2</kbd>).<br/>
Workspace 5: Antigravity/VSCode (<kbd>F5</kbd>).<br/>
Workspace 7: Terminal and Chrome windows for dealing with HPC job submission (<kbd>F7</kbd>).<br/>
Workspace 15: Brave (<kbd>Insert</kbd>).<br/>
Workspace 16: Instagram (<kbd>Home</kbd>).<br/>
Workspace 18: Okular (<kbd>Win</kbd>+<kbd>Delete</kbd>).<br/>
Workspace 21: Steam (<kbd>Win</kbd>+<kbd>F1</kbd>).<br/>
Workspace 25: VLC media player (<kbd>Win</kbd>+<kbd>F5</kbd>).<br/>

### Monitor 2
Workspace 3: Bluetooth (<kbd>F3</kbd>).<br/>
Workspace 4: WinBoat (<kbd>F4</kbd>).<br/>
Workspace 6: WinBoat FreeRDP window for working in Word (<kbd>F6</kbd>).<br/>
Workspace 8: Gaming, especially RuneScape or OpenRA (<kbd>F8</kbd>).<br/>
Workspace 9: WhatsApp Web (<kbd>F9</kbd>).<br/>
Workspace 10: Google Chat (<kbd>F10</kbd>).<br/>
Workspace 11: Discord (<kbd>F11</kbd>).<br/>
Workspace 12: Boo (<kbd>F12</kbd>).<br/>
Workspace 13: Nautilus file manager (<kbd>Win</kbd>+<kbd>Print</kbd>).<br/>
Workspace 14: Chrome (<kbd>Pause</kbd>).<br/>
Workspace 19: Duolingo (<kbd>End</kbd>).<br/>
Workspace 20: Terminal (<kbd>Page Down</kbd>).<br/>
Workspace 22: Payday 2 (<kbd>Win</kbd>+<kbd>F2</kbd>).<br/>
Workspace 23: Google Earth (<kbd>Win</kbd>+<kbd>F3</kbd>).<br/>
Workspace 24: Boo (<kbd>Win</kbd>+<kbd>F4</kbd>).<br/>
Workspace 26: VLC media player (<kbd>Win</kbd>+<kbd>F6</kbd>).<br/>
Workspace 27: Brave private window (<kbd>Win</kbd>+<kbd>F7</kbd>).<br/>
Workspace 28: Virtual machine manager (<kbd>Win</kbd>+<kbd>F8</kbd>)
Workspaces 29-30: Virt Viewer (<kbd>Win</kbd>+<kbd>F9</kbd> to <kbd>F10</kbd>).

# History
[6e524bcfb7db7653ac4df86b378faab6e25a7bf3](https://github.com/fusion809/NixOS-configs/tree/6e524bcfb7db7653ac4df86b378faab6e25a7bf3) was the final commit with vim-ai with deepseek-coder model. Was removed as it wasn't useful for me. 