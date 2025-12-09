# My NixOS configuration files
![Hyprland on NixOS screenshot as of 7 December 2025](https://fusion809.github.io/images/Hyprland/Hyprland_NixOS_2025-12-07.png)
**Figure 1: Hyprland NixOS configuration as of 7 December 2025.**

These are my NixOS 25.11 configuration files for my MS-7B90 PC. Hyprland is my graphical user interface (GUI). Flakes are used to manage packages. 

# Shell profile
Within shell/root is my root shell profile files, and within shell/user is my user shell profile files. I have many functions designed to make my time in the terminal more pleasant.

## Package management commands
* `nixcg` is used to remove old generations and sources with `sudo nix-collect-garbage -d`.
* `nixdg` is used to delete specified generations. 
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
I run the latest [Hyprland](https://github.com/hyprwm/Hyprland), even when [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs)' Hyprland is not the latest version. It is managed by my [nix/flake.nix](nix/flake.nix) file and the [shell/hyprland/updates](/shell/hyprland/updates) script &mdash; which is run by Waybar's custom/updates widget &mdash; updates it. I also utilize the [hy3](https://github.com/outfoxxed/hy3) plugin to provide the window tabbing I am used to from i3. 

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
| <kbd>F11</kbd>                                                    | Open workspace of Google Chrome.  |
| <kbd>F12</kbd>                                                    | Open workspace of Nautilus        
| <kbd>Print</kbd>                                                  | Take a screenshot and copy it to clipboard. | 
| <kbd>Win</kbd>+<kbd>F1</kbd>                                      | Open workspace #11    |
| <kbd>Win</kbd>+<kbd>F2</kbd>                                      | Open workspace #12    |
| <kbd>Win</kbd>+<kbd>F3</kbd>                                      | Open workspace #13    |
| <kbd>Win</kbd>+<kbd>F4</kbd>                                      | Open workspace #14    |
| <kbd>Win</kbd>+<kbd>F5</kbd>                                      | Open workspace #15    |
| <kbd>Win</kbd>+<kbd>F6</kbd>                                      | Open workspace #16    |
| <kbd>Win</kbd>+<kbd>F7</kbd>                                      | Open workspace #17    |
| <kbd>Win</kbd>+<kbd>F8</kbd>                                      | Open workspace #18    |
| <kbd>Win</kbd>+<kbd>F9</kbd>                                      | Open workspace #19    |
| <kbd>Win</kbd>+<kbd>F10</kbd>                                     | Open workspace #20    |
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
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F1</kbd>                     | Move focused window (silently) to workspace #11     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F2</kbd>                     | Move focused window (silently) to workspace #12     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F3</kbd>                     | Move focused window (silently) to workspace #13     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F4</kbd>                     | Move focused window (silently) to workspace #14     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F5</kbd>                     | Move focused window (silently) to workspace #15     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F6</kbd>                     | Move focused window (silently) to workspace #16     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F7</kbd>                     | Move focused window (silently) to workspace #17     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F8</kbd>                     | Move focused window (silently) to workspace #18     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F9</kbd>                     | Move focused window (silently) to workspace #19     |
| <kbd>Win</kbd>+<kbd>Shift</kbd>+<kbd>F10</kbd>                    | Move focused window (silently) to workspace #20    |
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

## Waybar
The waybar has the following components:
* The NixOS menu () which gives you options for (all websites opened in Chrome and all directories opened in Antigravity):
  - Opening up the Nerd font cheat sheet websites.
  - Opening up NixOS-configs repo on GitHub.
  - Opening up the NixOS options search.
  - Opening up the NixOS packages search.
  - Opening up the NixOS Wiki.
  - Rebuilding one's system.
  - Repairing the Nix store.
  - Update one's system without repairing the store. 
  - Opening NixOS-configs in the default code editor.
  - Suspend.
  - Hibernate.
  - Shutdown.
  - Logout.
  - Reboot.
* Workspaces.
* Weather conditions, obtained by wttr.in. Beware that wttr.in can be quite unreliable at times.
* Keyboard layout ( followed by its two-letter initial though). 
* Pulseaudio showing the volume of your output audio device. Has a purple background and white text.
* Wallpaper number widget (󰸉): it displays the number of the wallpaper most recently displayed on your desktop, then a forward slash, and then the total number of wallpapers you have installed on your system.
* A bin icon (󰆴) that, when clicked, will delete your current wallpaper and load the next wallpaper.
* A left arrow () that, when clicked, changes your wallpaper to the previous one in your collection (keeping in mind, this is when you're using the systematic algorithm for the wallpaper script).
* A shuffling arrow () that, when clicked, changes your wallpaper to a randomly selected one.
* A forward arrow () that, when clicked, changes your wallpaper to the next systematically selected one. 
* A collection of numbers () that, when clicked, changes your wallpaper to a wallpaper whose number you specify in a pop-up window. 
* The title of your currently focused window.
* Motherboard temperature () according to sensors. Left clicking this opens a graph showing the history of the motherboard temperature.
* Used space () on your root file system. Left clicking this opens gtop in Alacritty.
* Internet download speed () on enp24s0 interface. Left clicking this opens nethogs in Alacritty. Right clicking prompts the user for how long they want to monitor network usage for and then, after this period, it displays network usage and network usage by process. Middle clicking produces a pop up window with a graph of download speed (on enp24s0) history against time. 
* Internet upload speed () on enp24s0 interface. Left clicking and right clicking does the same thing as per download speed. Middle clicking largely does the same as per download, except with upload speeds. 
* CPU usage percentage (). Left clicking this opens gtop in Alacritty.
* RAM usage percentage (). Left clicking this opens gtop in Alacritty.
* Updates available.<sup>1</sup>
    - "h" indicates updates to home-manager are available. 
    - "m" indicates updates to nixpkgs-master are available.
    - "s" indicates that updates to nixpkgs (stable branch) are available. 
    - "u" indicates updates to nixpkgs-unstable are available. 
    - 󱇛 indicates that hy3 updates are available. 
    -  indicates that Hyprland updates are available. 
    <!---  indicates that Vim updates are available.-->
    - 󱢇 indicates that OpenRA updates are available.
    - 󰄻 indicates that Marvin updates are available. 
* Clock with AM/PM time with seconds, short day of the week name, day of the month/month of the year/year (short format).

Footnotes:
1. The script that manages this runs every ~20 minutes, and runs `nixfu` as part of checking for updates. If any are available, you merely need to run `nixfrb` to install them. Left clicking the widget, will open a terminal that runs `nixfrb`. Right clicking the widget will instead update the widget to show the contents of the final line of `$HOME/.cache/update` (which is the file that the update script writes update notifications to). This can be useful if it's made a mistake and you've corrected that in `$HOME/.cache/update`.

## Wallpaper script
There is a script within this repository called `wallpaper` that will, using swaybg, set your background to a wallpaper in Arch's `/usr/share/wallpapers`, `/usr/share/backgrounds`, `/usr/share/antergos/wallpapers`, `~/.local/share/backgrounds`, `~/.local/share/wallpapers` or `~/Pictures/Wallpapers`. I originally used hyprpaper to set the wallpaper, I find hyprpaper more difficult to use and I also use the wallpaper script under Niri. 

### Syntax

```bash
wallpaper <algorithm/no> [direction]
```

The algorithm/no argument is mandatory; the direction argument is optional. 

The algorithm argument decides which algorithm is used to decide the wallpaper set as your background. If you give it the argument `random` (first letter's case doesn't matter), you will get a randomly decided wallpaper out of those within those specified directories. If you give it the argument `systematic` (first letter's case also doesn't matter), wallpaper will systematically go through the wallpapers one by one. 

An alternative to the algorithm argument is the no argument which specifies the number of the wallpaper to be displayed. Keep in mind that list-wallpapers (which shows wallpapers with Vim line numbers) displays wallpapers with a number one higher than the number used by the wallpaper script (as wallpaper script numbers start at 0, whereas Vim starts at 1).  

The direction argument, which is only applicable if the first argument is algorithm, can be "previous" or something else. If it is previous and the first argument is "systematic", this will lead to the previous wallpaper being shown. Otherwise the next wallpaper will be shown. This is also the default behaviour if direction is omitted.