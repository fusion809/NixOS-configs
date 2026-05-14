local hl = require("hyprland")

------------------
---- PLUGINS -----
------------------

-- hl.plugin(os.getenv("HOME") .. "/.local/share/hyprland/plugins/hy3.so")

-------------------
---- VARIABLES ----
-------------------

local browser     = "google-chrome-stable"
local editor      = "antigravity"
local fileManager = "dolphin"
local menu        = "rofi -show window"
local terminal    = "alacritty"
local nixcfg      = os.getenv("HOME") .. "/GitHub/mine/config/NixOS-configs"
local mainMod     = "SUPER"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd(nixcfg .. "/shell/hyprland/waybar-multi-start")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/workspace-router")
    hl.exec_cmd('bash -c "' .. nixcfg .. '/shell/hyprland/wallpaper systematic"')
    hl.exec_cmd("virt-manager")
    hl.exec_cmd("brave")
    hl.exec_cmd("discord")
    hl.exec_cmd("blueman-manager")
    hl.exec_cmd("google-chrome-stable")
    hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=mdpkiolbdkhdjpekfbkbmhigcaggjagi")
    hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=jneocipojkkahfcibhjaiilegofacenn")
    hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm")
    hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=akpamiohjfcnimfljfndmaldlcfphjmp")
    hl.exec_cmd("kitty -e --hold " .. nixcfg .. "/shell/hyprland/hyfetch-run")
    hl.exec_cmd("winboat")
    hl.exec_cmd("kdeconnect-app")
    hl.exec_cmd(fileManager .. " " .. os.getenv("HOME") .. "/.files")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/debian13")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/ssh-debian-alacritty")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/killOldSwayBg")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/network-daemon")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/gpu-daemon")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/system-daemon")
    hl.exec_cmd("/run/current-system/sw/bin/kdeconnectd")
end)

---------------------------
---- ENVIRONMENT VARS ----
---------------------------

hl.env("HYPRCURSOR_THEME", "Future-Cyan-Hyprcursor_Theme")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        layout = "hy3",
    },
    
    input = {
        kb_layout = "us,br",
        follow_mouse = 1,
        force_no_accel = true,
        
        touchpad = {
            natural_scroll = false,
        },
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    
    ecosystem = {
        no_update_news = true,
    },
})

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "DVI-D-1",  mode = "preferred", position = "1920x0", scale = 1 })

--------------------
---- WORKSPACES ----
--------------------

local monitors = {
    HDMI = "HDMI-A-1",
    DVI  = "DVI-D-1"
}

hl.workspace_rule({ workspace = 1,  monitor = monitors.HDMI, default = true })
hl.workspace_rule({ workspace = 2,  monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 3,  monitor = monitors.DVI })
hl.workspace_rule({ workspace = 4,  monitor = monitors.DVI })
hl.workspace_rule({ workspace = 5,  monitor = monitors.DVI })
hl.workspace_rule({ workspace = 6,  monitor = monitors.DVI })
hl.workspace_rule({ workspace = 7,  monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 8,  monitor = monitors.DVI,  default = true })
hl.workspace_rule({ workspace = 9,  monitor = monitors.DVI })
hl.workspace_rule({ workspace = 10, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 11, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 12, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 13, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 14, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 15, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 16, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 17, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 18, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 19, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 20, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 21, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 22, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 23, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 24, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 25, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 26, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 27, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 28, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 29, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 30, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 31, monitor = monitors.DVI })
hl.workspace_rule({ workspace = 32, monitor = monitors.HDMI })
hl.workspace_rule({ workspace = 33, monitor = monitors.HDMI })

----------------------
---- KEYBINDINGS ----
----------------------

-- Resize submap
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.submap("resize"))

hl.submap("resize", {
    { "", "h", hl.dsp.window.resize({ size = "-10 0" }) },
    { "", "l", hl.dsp.window.resize({ size = "10 0" }) },
    { "", "k", hl.dsp.window.resize({ size = "0 -10" }) },
    { "", "j", hl.dsp.window.resize({ size = "0 10" }) },
    { "", "left",  hl.dsp.window.resize({ size = "-10 0" }) },
    { "", "right", hl.dsp.window.resize({ size = "10 0" }) },
    { "", "up",    hl.dsp.window.resize({ size = "0 -10" }) },
    { "", "down",  hl.dsp.window.resize({ size = "0 10" }) },
    { "", "escape", hl.dsp.submap("reset") },
})

-- Common binds
hl.bind("", "Print", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/screenshot"))
hl.bind(mainMod .. " + d", hl.dsp.exec_cmd('rofi -show drun -show-icons -icon-theme "WhiteSur-dark"'))
hl.bind(mainMod .. " + CTRL + f", hl.dsp.exec_cmd(browser .. " https://www.nerdfonts.com/cheat-sheet"))
hl.bind(mainMod .. " + o", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/runescape"))
hl.bind(mainMod .. " + SHIFT + p", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + CTRL + n", hl.dsp.exec_cmd(browser .. " https://search.nixos.org/packages"))
hl.bind(mainMod .. " + CTRL + o", hl.dsp.exec_cmd(browser .. " https://search.nixos.org/options"))
hl.bind(mainMod .. " + CTRL + r", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/repair"))
hl.bind(mainMod .. " + CTRL + u", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/update"))
hl.bind(mainMod .. " + CTRL + w", hl.dsp.exec_cmd(browser .. " https://wiki.nixos.org/"))
hl.bind(mainMod .. " + SHIFT + n", hl.dsp.exec_cmd(editor .. " " .. nixcfg))
hl.bind(mainMod .. " + g", hl.dsp.exec_cmd("alacritty -e gtop"))
hl.bind(mainMod .. " + h", hl.dsp.exec_cmd("kitty -e --hold " .. nixcfg .. "/shell/hyprland/hyfetch-run"))
hl.bind(mainMod .. " + v", hl.dsp.exec_cmd("virt-manager"))
hl.bind(mainMod .. " + w", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/wallpaper systematic"))
hl.bind(mainMod .. " + z", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/wallpaper systematic previous"))
hl.bind(mainMod .. " + s", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/wallpaper random"))
hl.bind(mainMod .. " + n", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/wallpaper-no-specify"))
hl.bind(mainMod .. " + b", hl.dsp.exec_cmd("brave"))
hl.bind(mainMod .. " + SHIFT + b", hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mainMod .. " + m", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm"))
hl.bind(mainMod .. " + c", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=mdpkiolbdkhdjpekfbkbmhigcaggjagi"))
hl.bind(mainMod .. " + e", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/wallpaper-rm"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=jneocipojkkahfcibhjaiilegofacenn"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=kippjfofjhjlffjecoapiogbkgbpmgej"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=akpamiohjfcnimfljfndmaldlcfphjmp"))
hl.bind(mainMod .. " + SHIFT + q", hl.dsp.exec_cmd("/opt/google/chrome/google-chrome --profile-directory=Default --app-id=cechoboadpfjgoaooidphlandgelehhi"))
hl.bind(mainMod .. " + SHIFT + w", hl.dsp.exec_cmd(menu))

-- Navigation
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move windows (using hyprland built-in dispatchers as fallback or hy3 if available via hyprctl)
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + semicolon", hl.dsp.window.move({ direction = "right" }))

-- hy3 specifics
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.exec_cmd("hyprctl dispatch hy3:movewindow l"))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.exec_cmd("hyprctl dispatch hy3:movewindow d"))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.exec_cmd("hyprctl dispatch hy3:movewindow u"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch hy3:movewindow r"))

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("hyprctl dispatch hy3:killactive"))

hl.bind(mainMod .. " + SHIFT + s", hl.dsp.exec_cmd("sudo poweroff"))
hl.bind("", "XF86HomePage", hl.dsp.exec_cmd("dolphin"))
hl.bind("", "XF86Calculator", hl.dsp.exec_cmd("octave"))
hl.bind(mainMod .. " + r", hl.dsp.exec_cmd("hyprctl reload; " .. nixcfg .. "/shell/hyprland/waybar-multi-start"))

-- Monitor workspace move
hl.bind(mainMod .. " + CTRL + 2", hl.dsp.exec_cmd("hyprctl dispatch moveworkspacetomonitor $(hyprctl activeworkspace -j | jq .id) 0"))
hl.bind(mainMod .. " + CTRL + 1", hl.dsp.exec_cmd("hyprctl dispatch moveworkspacetomonitor $(hyprctl activeworkspace -j | jq .id) 1"))
hl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd(nixcfg .. "/shell/user/move-window-to-other-monitor.sh"))

-- Workspace switching
hl.bind("", "F1", hl.dsp.workspace.focus(1))
hl.bind(mainMod .. " + 2", hl.dsp.workspace.focus(2))
hl.bind("", "F3", hl.dsp.workspace.focus(3))
hl.bind("", "F4", hl.dsp.workspace.focus(4))
hl.bind("", "F5", hl.dsp.workspace.focus(5))
hl.bind("", "F6", hl.dsp.workspace.focus(6))
hl.bind("", "F7", hl.dsp.workspace.focus(7))
hl.bind("", "F8", hl.dsp.workspace.focus(8))
hl.bind("", "F9", hl.dsp.workspace.focus(9))
hl.bind("", "F10", hl.dsp.workspace.focus(10))
hl.bind("", "F11", hl.dsp.workspace.focus(11))
hl.bind("", "F12", hl.dsp.workspace.focus(12))
hl.bind(mainMod .. " + Print", hl.dsp.workspace.focus(13))
hl.bind("", "Pause", hl.dsp.workspace.focus(14))
hl.bind(mainMod .. " + Insert", hl.dsp.workspace.focus(15))
hl.bind("", "Home", hl.dsp.workspace.focus(16))
hl.bind("", "Page_Up", hl.dsp.workspace.focus(17))
hl.bind(mainMod .. " + Delete", hl.dsp.workspace.focus(18))
hl.bind("", "End", hl.dsp.workspace.focus(19))
hl.bind("", "Page_Down", hl.dsp.workspace.focus(20))
hl.bind(mainMod .. " + F1", hl.dsp.workspace.focus(21))
hl.bind(mainMod .. " + F2", hl.dsp.workspace.focus(22))
hl.bind(mainMod .. " + F3", hl.dsp.workspace.focus(23))
hl.bind(mainMod .. " + F4", hl.dsp.workspace.focus(24))
hl.bind(mainMod .. " + F5", hl.dsp.workspace.focus(25))
hl.bind(mainMod .. " + F6", hl.dsp.workspace.focus(26))
hl.bind(mainMod .. " + F7", hl.dsp.workspace.focus(27))
hl.bind(mainMod .. " + F8", hl.dsp.workspace.focus(28))
hl.bind(mainMod .. " + F9", hl.dsp.workspace.focus(29))
hl.bind(mainMod .. " + F10", hl.dsp.workspace.focus(30))
hl.bind(mainMod .. " + F11", hl.dsp.workspace.focus(31))
hl.bind(mainMod .. " + F12", hl.dsp.workspace.focus(32))
hl.bind(mainMod .. " + Pause", hl.dsp.workspace.focus(33))

-- Move window to workspace
for i = 1, 10 do
    hl.bind(mainMod .. " + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i, silent = true }))
end

hl.bind(mainMod .. " + SHIFT + F1", hl.dsp.window.move({ workspace = 11, silent = true }))
hl.bind(mainMod .. " + SHIFT + F2", hl.dsp.window.move({ workspace = 12, silent = true }))
hl.bind(mainMod .. " + SHIFT + F3", hl.dsp.window.move({ workspace = 13, silent = true }))
hl.bind(mainMod .. " + SHIFT + F4", hl.dsp.window.move({ workspace = 14, silent = true }))
hl.bind(mainMod .. " + SHIFT + F5", hl.dsp.window.move({ workspace = 15, silent = true }))
hl.bind(mainMod .. " + SHIFT + F6", hl.dsp.window.move({ workspace = 16, silent = true }))
hl.bind(mainMod .. " + SHIFT + F7", hl.dsp.window.move({ workspace = 17, silent = true }))
hl.bind(mainMod .. " + SHIFT + F8", hl.dsp.window.move({ workspace = 18, silent = true }))
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.window.move({ workspace = 19, silent = true }))
hl.bind(mainMod .. " + SHIFT + F10", hl.dsp.window.move({ workspace = 20, silent = true }))
hl.bind(mainMod .. " + SHIFT + F11", hl.dsp.window.move({ workspace = 21, silent = true }))
hl.bind(mainMod .. " + SHIFT + F12", hl.dsp.window.move({ workspace = 22, silent = true }))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.window.move({ workspace = 23, silent = true }))
hl.bind(mainMod .. " + SHIFT + Pause", hl.dsp.window.move({ workspace = 24, silent = true }))
hl.bind(mainMod .. " + SHIFT + Insert", hl.dsp.window.move({ workspace = 25, silent = true }))
hl.bind(mainMod .. " + SHIFT + Home", hl.dsp.window.move({ workspace = 26, silent = true }))
hl.bind(mainMod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = 27, silent = true }))
hl.bind(mainMod .. " + SHIFT + Delete", hl.dsp.window.move({ workspace = 28, silent = true }))
hl.bind(mainMod .. " + SHIFT + End", hl.dsp.window.move({ workspace = 29, silent = true }))
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = 30, silent = true }))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = 31, silent = true }))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = 32, silent = true }))
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.move({ workspace = 33, silent = true }))

-- Terminal
hl.bind(mainMod .. " + tab", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + k", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + SHIFT + tab", hl.dsp.exec_cmd("focus-terminal"))

-- System controls
hl.bind("", "XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"))
hl.bind("", "XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"))
hl.bind("", "XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))
hl.bind("", "XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("", "XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("", "XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({ match = { initialClass = "org.kde.ksecretd" }, workspace = 1 })
hl.window_rule({ match = { initialClass = "SpaceCadetPinball" }, float = true })
hl.window_rule({ match = { initialClass = "eog" }, float = true, size = "1000 700", center = true })
hl.window_rule({ match = { initialClass = "org.gnome.eog" }, float = true, size = "1000 700", center = true })
hl.window_rule({ match = { initialClass = "steam_app_1343400" }, tile = true, suppress_event = "activate activatefocus" })
hl.window_rule({ match = { title = "Gmail" }, float = true })
hl.window_rule({ match = { initialTitle = "Gmail" }, float = true })
hl.window_rule({ match = { title = "Google Chrome" }, float = true })
hl.window_rule({ match = { initialTitle = "Google Chrome" }, float = true })
hl.window_rule({ match = { class = "Alacritty" }, opacity = "0.8 0.8" })
hl.window_rule({ match = { class = "kitty" }, opacity = "0.6 0.6", workspace = 2, float = true, size = "815 400", move = "1104 679" })
hl.window_rule({ match = { initialClass = ".blueman-manager-wrapped" }, workspace = 3 })
hl.window_rule({ match = { initialClass = "winboat" }, workspace = 4 })
hl.window_rule({ match = { initialClass = "Code" }, workspace = 5 })
hl.window_rule({ match = { initialClass = "antigravity" }, workspace = 5 })
hl.window_rule({ match = { initialClass = "xfreerdp" }, workspace = 6 })
hl.window_rule({ match = { title = "ved" }, workspace = 7 })
hl.window_rule({ match = { initialTitle = "ged" }, workspace = 7 })
hl.window_rule({ match = { initialClass = "ffxivlauncher64.exe" }, workspace = 8 })
hl.window_rule({ match = { initialClass = "ffxiv_dx11.exe" }, workspace = 8 })
hl.window_rule({ match = { initialClass = "chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Default" }, workspace = 9 })
hl.window_rule({ match = { initialClass = "chrome-mdpkiolbdkhdjpekfbkbmhigcaggjagi-Default" }, workspace = 10 })
hl.window_rule({ match = { title = "Google Chat - Chat" }, workspace = 10 })
hl.window_rule({ match = { initialClass = "discord" }, workspace = 11 })
hl.window_rule({ match = { title = "WhatsApp Web" }, workspace = 12 })
hl.window_rule({ match = { initialClass = "org.kde.dolphin" }, workspace = 13 })
hl.window_rule({ match = { initialClass = "org.kde.kdeconnect.app" }, workspace = 14 })
hl.window_rule({ match = { initialClass = "chrome-akpamiohjfcnimfljfndmaldlcfphjmp-Default" }, workspace = 16 })
hl.window_rule({ match = { initialClass = "net.lutris.Lutris" }, workspace = 17 })
hl.window_rule({ match = { initialClass = "chrome-jneocipojkkahfcibhjaiilegofacenn-Default" }, workspace = 19 })
hl.window_rule({ match = { initialClass = "steam" }, workspace = 21 })
hl.window_rule({ match = { initialClass = "steam_app_218620" }, workspace = 22 })
hl.window_rule({ match = { initialClass = "texstudio" }, workspace = 24 })
hl.window_rule({ match = { title = "Virtual Machine Manager" }, workspace = 28 })
hl.window_rule({ match = { initialClass = "DiscoveryStudio2025-bin" }, workspace = 32 })
hl.window_rule({ match = { initialClass = "org.openchemistry.Avogadro2" }, workspace = 32 })
hl.window_rule({ match = { initialClass = "PyMOL" }, workspace = 32 })
hl.window_rule({ match = { initialClass = "org-openscience-jmol-app-jmolpanel-JmolPanel" }, workspace = 32 })
hl.window_rule({ match = { initialClass = "install4j-chemaxon-marvin-Sketch_msketch" }, workspace = 32 })
hl.window_rule({ match = { title = "2019 Skype.png - 853x909 - 100% - Gwenview" }, workspace = 33 })
hl.window_rule({ match = { title = "DP 2018.png - 427x550 - 100% - Gwenview" }, workspace = 33 })

---------------------
---- PLUGIN SETS ----
---------------------

hl.config({
    plugin = {
        hy3 = {
            tabs = {
                border_width = 0,
                col = {
                    active = "rgba(ff55ffff)",
                    ["active.text"] = "rgba(00000000)",
                    inactive = "rgba(333333ff)",
                    ["inactive.text"] = "rgba(ffffffff)",
                    urgent = "rgba(ff0000ff)",
                    ["urgent.text"] = "rgba(000000ff)",
                }
            },
            autotile = {
                enable = true,
                trigger_width = 800,
                trigger_height = 500,
            }
        }
    }
})

hl.bind(mainMod .. " + t", hl.dsp.exec_cmd("hyprctl dispatch hy3:makegroup tab"))
hl.bind(mainMod .. " + a", hl.dsp.exec_cmd("hyprctl dispatch hy3:expand expand"))
hl.bind(mainMod .. " + SHIFT + p", hl.dsp.exec_cmd("hyprctl dispatch hy3:focustab l"))
hl.bind(mainMod .. " + x", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/waybar-toggle-monitor"))
hl.bind(mainMod .. " + SHIFT + x", hl.dsp.exec_cmd(nixcfg .. "/shell/hyprland/focustab-no"))

for i = 1, 9 do
    hl.bind(mainMod .. " + ALT + " .. i, hl.dsp.exec_cmd("hyprctl dispatch hy3:focustab index " .. i))
end
hl.bind(mainMod .. " + ALT + 0", hl.dsp.exec_cmd("hyprctl dispatch hy3:focustab index 10"))

for i = 1, 10 do
    hl.bind(mainMod .. " + ALT + F" .. i, hl.dsp.exec_cmd("hyprctl dispatch hy3:focustab index " .. (10 + i)))
end

--------------------
---- DEVICES ----
--------------------

hl.device({
    name = "telink-wireless-receiver",
    kb_layout = "us,br",
})

hl.bind(mainMod, "space", hl.dsp.exec_cmd("hyprctl switchxkblayout current next"))
