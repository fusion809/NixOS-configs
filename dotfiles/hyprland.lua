-- Load hy3 plugin first
hl.exec_cmd("hyprctl plugin load " .. os.getenv("HOME") .. "/.local/share/hyprland/plugins/hy3_patched.so")

-- Visual confirmation that the config is loading
hl.exec_cmd("hyprctl notify 5 5000 \"rgba(00ff00ff)\" \"Hyprland Lua Config Loaded\"")
hl.exec_cmd("hyprctl configerrors > /home/fusion809/GitHub/mine/config/NixOS-configs/dotfiles/config_errors.log 2>&1")


-- Verified hy3 dispatcher signatures:
-- make_group(string), move_focus(string), move_window(string), expand(string)
-- focus_tab({ direction = string }) or focus_tab({ index = number })
local hy3 = hl.plugin.hy3

-- Global bridge for Waybar
_G.workspace = function(id)
    hl.dispatch(hl.dsp.focus({ workspace = id }))
end

-------------------
---- VARIABLES ----
-------------------

local browser     = "google-chrome-stable"
local editor      = "antigravity"
local fileManager = "dolphin"
local mainMod     = "SUPER"
local menu        = "rofi -show window"
local nixcfg      = os.getenv("HOME") .. "/GitHub/mine/config/NixOS-configs"
local terminal    = "alacritty"

-- Helper for keybindings
local function bind(keys, name, arg)
    local ws = tonumber(arg) or arg
    local d

    -- hy3 plugin dispatchers (verified signatures)
    if name == "hy3:makegroup" then
        d = hy3.make_group(arg)
    elseif name == "hy3:movefocus" then
        d = hy3.move_focus(arg)
    elseif name == "hy3:movewindow" then
        d = hy3.move_window(arg)
    elseif name == "hy3:expand" then
        d = hy3.expand(arg)
    elseif name == "hy3:focustab" then
        if arg and arg:match("^index") then
            d = hy3.focus_tab({ index = tonumber(arg:match("%d+")) })
        elseif arg == "no" or arg == "nowrap" then
            -- 'no' was used as a nowrap modifier, skip — not supported in native API
            d = nil
        else
            d = hy3.focus_tab({ direction = arg })
        end
    elseif name == "hy3:killactive" then
        d = hy3.kill_active()
    -- Native system dispatchers
    elseif name == "submap" then d = hl.dsp.submap(arg)
    elseif name == "exec" then d = (hl.dsp.exec_cmd or hl.dsp.exec)(arg)
    elseif name == "workspace" then d = hl.dsp.focus({ workspace = ws })
    elseif name == "movetoworkspace" then d = hl.dsp.window.move({ workspace = ws })
    elseif name == "moveworkspacetomonitor" then d = hl.dsp.workspace.move({ monitor = ws })
    elseif name == "fullscreen" then d = hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })
    elseif name == "togglefloating" then d = hl.dsp.window.float({ action = "toggle" })
    elseif name == "killactive" then
        local f = hl.dsp.window.close or hl.dsp.window.kill or hl.dsp.window.close_active
        if f then d = f() end
    end

    if d then
        hl.bind(keys, d)
    end
end

-------------------
---- AUTOSTART ----
-------------------

hl.exec_cmd('bash -c "' .. nixcfg .. '/shell/hyprland/waybar-multi-start &"')
hl.exec_cmd('bash -c "' .. nixcfg .. '/shell/hyprland/workspace-router &"')

hl.on("hyprland.start", function()
    hl.exec_cmd('bash -c "' .. nixcfg .. '/shell/hyprland/wallpaper systematic"')
    --hl.exec_cmd("virt-manager")
    --hl.exec_cmd("brave")
    --hl.exec_cmd("discord")
    --hl.exec_cmd("blueman-manager")
    --hl.exec_cmd("google-chrome-stable")
    --hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=mdpkiolbdkhdjpekfbkbmhigcaggjagi")
    --hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=jneocipojkkahfcibhjaiilegofacenn")
    --hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm")
    --hl.exec_cmd("google-chrome-stable --profile-directory=Default --app-id=akpamiohjfcnimfljfndmaldlcfphjmp")
    --hl.exec_cmd("kitty -e --hold " .. nixcfg .. "/shell/hyprland/hyfetch-run")
    --hl.exec_cmd("winboat")
    --hl.exec_cmd("kdeconnect-app")
    --hl.exec_cmd(fileManager .. " " .. os.getenv("HOME") .. "/.files")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/debian13")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/ssh-debian-alacritty")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd(nixcfg .. "/shell/hyprland/killOldSwayBg")
    --hl.exec_cmd(nixcfg .. "/shell/hyprland/network-daemon")
    --hl.exec_cmd(nixcfg .. "/shell/hyprland/gpu-daemon")
    --hl.exec_cmd(nixcfg .. "/shell/hyprland/system-daemon")
    hl.exec_cmd("/run/current-system/sw/bin/kdeconnectd")
    hl.exec_cmd("antigravity")
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
    plugin = {
        os.getenv("HOME") .. "/.local/share/hyprland/plugins/hy3_patched.so",
        hy3 = {
            tabs = {
                border_width = 0,
                colors = {
                    active = 0xffff0000,
                    active_text = 0xffffffff,
                    active_border = 0xffff0000,
                    focused = 0xffff0000,
                    focused_text = 0xff000000,
                    focused_border = 0xffff0000,
                    inactive = 0xff333333,
                    inactive_text = 0xffffffff,
                    inactive_border = 0xff333333,
                    urgent = 0xffff0000,
                    urgent_text = 0xff000000,
                    urgent_border = 0xffff0000,
                }
            },
            autotile = {
                enable = true,
                trigger_width = 800,
                trigger_height = 500,
            }
        }
    },
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
hl.workspace_rule({ workspace = 16, monitor = monitors.DVI })
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
bind(mainMod .. " + SHIFT + R", "submap", "resize")

hl.define_submap("resize", function()
    bind("h", "resizeactive", "-10 0")
    bind("l", "resizeactive", "10 0")
    bind("k", "resizeactive", "0 -10")
    bind("j", "resizeactive", "0 10")
    bind("left",  "resizeactive", "-10 0")
    bind("right", "resizeactive", "10 0")
    bind("up",    "resizeactive", "0 -10")
    bind("down",  "resizeactive", "0 10")
    bind("escape", "submap", "reset")
end)

-- Common binds
bind("Print", "exec", nixcfg .. "/shell/hyprland/screenshot")
bind(mainMod .. " + d", "exec", "rofi -show drun -show-icons -icon-theme 'WhiteSur-dark'")
bind(mainMod .. " + CTRL + f", "exec", browser .. " https://www.nerdfonts.com/cheat-sheet")
bind(mainMod .. " + o", "exec", nixcfg .. "/shell/hyprland/runescape")
bind(mainMod .. " + SHIFT + p", "exec", fileManager)
bind(mainMod .. " + CTRL + n", "exec", browser .. " https://search.nixos.org/packages")
bind(mainMod .. " + CTRL + o", "exec", browser .. " https://search.nixos.org/options")
bind(mainMod .. " + CTRL + r", "exec", nixcfg .. "/shell/hyprland/repair")
bind(mainMod .. " + CTRL + u", "exec", nixcfg .. "/shell/hyprland/update")
bind(mainMod .. " + CTRL + w", "exec", browser .. " https://wiki.nixos.org/")
bind(mainMod .. " + SHIFT + n", "exec", editor .. " " .. nixcfg)
bind(mainMod .. " + g", "exec", "alacritty -e gtop")
bind(mainMod .. " + h", "exec", "kitty -e --hold " .. nixcfg .. "/shell/hyprland/hyfetch-run")
bind(mainMod .. " + v", "exec", "virt-manager")
bind(mainMod .. " + w", "exec", nixcfg .. "/shell/hyprland/wallpaper systematic")
bind(mainMod .. " + z", "exec", nixcfg .. "/shell/hyprland/wallpaper systematic previous")
bind(mainMod .. " + s", "exec", nixcfg .. "/shell/hyprland/wallpaper random")
bind(mainMod .. " + n", "exec", nixcfg .. "/shell/hyprland/wallpaper-no-specify")
bind(mainMod .. " + b", "exec", "brave")
bind(mainMod .. " + SHIFT + b", "exec", "blueman-manager")
bind(mainMod .. " + m", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm")
bind(mainMod .. " + c", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=mdpkiolbdkhdjpekfbkbmhigcaggjagi")
bind(mainMod .. " + e", "exec", nixcfg .. "/shell/hyprland/wallpaper-rm")
bind(mainMod .. " + SHIFT + D", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=jneocipojkkahfcibhjaiilegofacenn")
bind(mainMod .. " + SHIFT + F", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=kippjfofjhjlffjecoapiogbkgbpmgej")
bind(mainMod .. " + SHIFT + I", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=akpamiohjfcnimfljfndmaldlcfphjmp")
bind(mainMod .. " + SHIFT + q", "exec", "/opt/google/chrome/google-chrome --profile-directory=Default --app-id=cechoboadpfjgoaooidphlandgelehhi")
bind(mainMod .. " + SHIFT + w", "exec", menu)

-- Navigation
-- Navigation (using hy3 dispatchers for the hy3 layout)
bind(mainMod .. " + left",  "hy3:movefocus", "l")
bind(mainMod .. " + right", "hy3:movefocus", "r")
bind(mainMod .. " + up",    "hy3:movefocus", "u")
bind(mainMod .. " + down",  "hy3:movefocus", "d")

-- Move windows (using hyprland built-in dispatchers as fallback or hy3 if available via hyprctl)
-- Move windows
bind(mainMod .. " + SHIFT + J", "hy3:movewindow", "l")
bind(mainMod .. " + SHIFT + K", "hy3:movewindow", "d")
bind(mainMod .. " + SHIFT + L", "hy3:movewindow", "u")
bind(mainMod .. " + SHIFT + semicolon", "hy3:movewindow", "r")

-- hy3 specifics
bind(mainMod .. " + SHIFT + left",  "hy3:movewindow", "l")
bind(mainMod .. " + SHIFT + down",  "hy3:movewindow", "d")
bind(mainMod .. " + SHIFT + up",    "hy3:movewindow", "u")
bind(mainMod .. " + SHIFT + right", "hy3:movewindow", "r")

bind(mainMod .. " + F", "fullscreen", "0")
bind(mainMod .. " + SHIFT + SPACE", "togglefloating")
bind(mainMod .. " + Q", "killactive")

bind(mainMod .. " + SHIFT + s", "exec", "sudo poweroff")
bind("XF86HomePage", "exec", "dolphin")
bind("XF86Calculator", "exec", "octave")
bind(mainMod .. " + r", "exec", "hyprctl reload; " .. nixcfg .. "/shell/hyprland/waybar-multi-start")

-- Monitor workspace move
bind(mainMod .. " + CTRL + 2", "moveworkspacetomonitor", "0")
bind(mainMod .. " + CTRL + 1", "moveworkspacetomonitor", "1")
bind(mainMod .. " + CTRL + M", "exec", nixcfg .. "/shell/hyprland/move-window-to-other-monitor")

-- Workspace switching
bind("F1", "workspace", "1")
bind(mainMod .. " + 2", "workspace", "2")
bind("F3", "workspace", "3")
bind("F4", "workspace", "4")
bind("F5", "workspace", "5")
bind("F6", "workspace", "6")
bind("F7", "workspace", "7")
bind("F8", "workspace", "8")
bind("F9", "workspace", "9")
bind("F10", "workspace", "10")
bind("F11", "workspace", "11")
bind("F12", "workspace", "12")
bind(mainMod .. " + Print", "workspace", "13")
bind("Pause", "workspace", "14")
bind(mainMod .. " + Insert", "workspace", "15")
bind("Home", "workspace", "16")
bind("Page_Up", "workspace", "17")
bind(mainMod .. " + Delete", "workspace", "18")
bind("End", "workspace", "19")
bind("Page_Down", "workspace", "20")
bind(mainMod .. " + F1", "workspace", "21")
bind(mainMod .. " + F2", "workspace", "22")
bind(mainMod .. " + F3", "workspace", "23")
bind(mainMod .. " + F4", "workspace", "24")
bind(mainMod .. " + F5", "workspace", "25")
bind(mainMod .. " + F6", "workspace", "26")
bind(mainMod .. " + F7", "workspace", "27")
bind(mainMod .. " + F8", "workspace", "28")
bind(mainMod .. " + F9", "workspace", "29")
bind(mainMod .. " + F10", "workspace", "30")
bind(mainMod .. " + F11", "workspace", "31")
bind(mainMod .. " + F12", "workspace", "32")
bind(mainMod .. " + Pause", "workspace", "33")

-- Move window to workspace
for i = 1, 10 do
    bind(mainMod .. " + SHIFT + " .. (i % 10), "movetoworkspace", tostring(i))
end

bind(mainMod .. " + SHIFT + F1", "movetoworkspace", "11")
bind(mainMod .. " + SHIFT + F2", "movetoworkspace", "12")
bind(mainMod .. " + SHIFT + F3", "movetoworkspace", "13")
bind(mainMod .. " + SHIFT + F4", "movetoworkspace", "14")
bind(mainMod .. " + SHIFT + F5", "movetoworkspace", "15")
bind(mainMod .. " + SHIFT + F6", "movetoworkspace", "16")
bind(mainMod .. " + SHIFT + F7", "movetoworkspace", "17")
bind(mainMod .. " + SHIFT + F8", "movetoworkspace", "18")
bind(mainMod .. " + SHIFT + F9", "movetoworkspace", "19")
bind(mainMod .. " + SHIFT + F10", "movetoworkspace", "20")
bind(mainMod .. " + SHIFT + F11", "movetoworkspace", "21")
bind(mainMod .. " + SHIFT + F12", "movetoworkspace", "22")
bind(mainMod .. " + SHIFT + Print", "movetoworkspace", "23")
bind(mainMod .. " + SHIFT + Pause", "movetoworkspace", "24")
bind(mainMod .. " + SHIFT + Insert", "movetoworkspace", "25")
bind(mainMod .. " + SHIFT + Home", "movetoworkspace", "26")
bind(mainMod .. " + SHIFT + Page_Up", "movetoworkspace", "27")
bind(mainMod .. " + SHIFT + Delete", "movetoworkspace", "28")
bind(mainMod .. " + SHIFT + End", "movetoworkspace", "29")
bind(mainMod .. " + SHIFT + Page_Down", "movetoworkspace", "30")
bind(mainMod .. " + SHIFT + grave", "movetoworkspace", "31")
bind(mainMod .. " + SHIFT + minus", "movetoworkspace", "32")
bind(mainMod .. " + SHIFT + equal", "movetoworkspace", "33")

-- Terminal
bind(mainMod .. " + tab", "exec", terminal)
bind(mainMod .. " + RETURN", "exec", terminal)
bind(mainMod .. " + k", "exec", "kitty")
bind(mainMod .. " + SHIFT + tab", "exec", "focus-terminal")

-- System controls
bind("XF86AudioRaiseVolume", "exec", "pactl set-sink-volume @DEFAULT_SINK@ +5%")
bind("XF86AudioLowerVolume", "exec", "pactl set-sink-volume @DEFAULT_SINK@ -5%")
bind("XF86AudioMute", "exec", "pactl set-sink-mute @DEFAULT_SINK@ toggle")
bind("XF86AudioPlay", "exec", "playerctl play-pause")
bind("XF86AudioNext", "exec", "playerctl next")
bind("XF86AudioPrev", "exec", "playerctl previous")

----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({ match = { initial_class = "org.kde.ksecretd" }, workspace = 1 })
hl.window_rule({ match = { initial_class = "SpaceCadetPinball" }, float = true })
hl.window_rule({ match = { initial_class = "eog" }, float = true, size = "1000 700", center = true })
hl.window_rule({ match = { initial_class = "org.gnome.eog" }, float = true, size = "1000 700", center = true })
hl.window_rule({ match = { initial_class = "steam_app_1343400" }, tile = true, suppress_event = "activate activatefocus" })
hl.window_rule({ match = { title = "Gmail" }, float = true })
hl.window_rule({ match = { initial_title = "Gmail" }, float = true })
hl.window_rule({ match = { title = "Google Chrome" }, float = true })
hl.window_rule({ match = { initial_title = "Google Chrome" }, float = true })
hl.window_rule({ match = { class = "Alacritty" }, opacity = "0.8 0.8" })
hl.window_rule({ match = { class = "kitty" }, opacity = "0.6 0.6", workspace = 2, float = true, size = "815 400", move = "1104 679" })
hl.window_rule({ match = { initial_class = ".blueman-manager-wrapped" }, workspace = 3 })
hl.window_rule({ match = { initial_class = "winboat" }, workspace = 4 })
hl.window_rule({ match = { initial_class = "Code" }, workspace = 5 })
hl.window_rule({ match = { initial_class = "antigravity" }, workspace = 5 })
hl.window_rule({ match = { initial_class = "xfreerdp" }, workspace = 6 })
hl.window_rule({ match = { title = "ved" }, workspace = 7 })
hl.window_rule({ match = { initial_title = "ged" }, workspace = 7 })
hl.window_rule({ match = { initial_class = "ffxivlauncher64.exe" }, workspace = 8 })
hl.window_rule({ match = { initial_class = "ffxiv_dx11.exe" }, workspace = 8 })
hl.window_rule({ match = { initial_class = "chrome-hnpfjngllnobngcgfapefoaidbinmjnm-Default" }, workspace = 9 })
hl.window_rule({ match = { initial_class = "chrome-mdpkiolbdkhdjpekfbkbmhigcaggjagi-Default" }, workspace = 10 })
hl.window_rule({ match = { title = "Google Chat - Chat" }, workspace = 10 })
hl.window_rule({ match = { initial_class = "discord" }, workspace = 11 })
hl.window_rule({ match = { title = "WhatsApp Web" }, workspace = 12 })
hl.window_rule({ match = { initial_class = "org.kde.dolphin" }, workspace = 13 })
hl.window_rule({ match = { initial_class = "org.kde.kdeconnect.app" }, workspace = 14 })
hl.window_rule({ match = { initial_class = "chrome-akpamiohjfcnimfljfndmaldlcfphjmp-Default" }, workspace = 16 })
hl.window_rule({ match = { initial_class = "net.lutris.Lutris" }, workspace = 17 })
hl.window_rule({ match = { initial_class = "chrome-jneocipojkkahfcibhjaiilegofacenn-Default" }, workspace = 19 })
hl.window_rule({ match = { initial_class = "steam" }, workspace = 21 })
hl.window_rule({ match = { initial_class = "steam_app_218620" }, workspace = 22 })
hl.window_rule({ match = { initial_class = "texstudio" }, workspace = 24 })
hl.window_rule({ match = { title = "Virtual Machine Manager" }, workspace = 28 })
hl.window_rule({ match = { initial_class = "DiscoveryStudio2025-bin" }, workspace = 32 })
hl.window_rule({ match = { initial_class = "org.openchemistry.Avogadro2" }, workspace = 32 })
hl.window_rule({ match = { initial_class = "PyMOL" }, workspace = 32 })
hl.window_rule({ match = { initial_class = "org-openscience-jmol-app-jmolpanel-JmolPanel" }, workspace = 32 })
hl.window_rule({ match = { initial_class = "install4j-chemaxon-marvin-Sketch_msketch" }, workspace = 32 })
hl.window_rule({ match = { title = "2019 Skype.png - 853x909 - 100% - Gwenview" }, workspace = 33 })
hl.window_rule({ match = { title = "DP 2018.png - 427x550 - 100% - Gwenview" }, workspace = 33 })

---------------------
---- PLUGIN SETS ----
---------------------



bind(mainMod .. " + t", "hy3:makegroup", "tab")
bind(mainMod .. " + a", "hy3:expand", "expand")
bind(mainMod .. " + SHIFT + p", "hy3:focustab", "l")
bind(mainMod .. " + x", "exec", nixcfg .. "/shell/hyprland/waybar-toggle-monitor")
bind(mainMod .. " + SHIFT + x", "hy3:focustab", "r")

for i = 1, 9 do
    bind(mainMod .. " + ALT + " .. i, "hy3:focustab", "index " .. i)
end
bind(mainMod .. " + ALT + 0", "hy3:focustab", "index 10")

for i = 1, 10 do
    bind(mainMod .. " + ALT + F" .. i, "hy3:focustab", "index " .. (10 + i))
end

--------------------
---- DEVICES ----
--------------------

hl.device({
    name = "telink-wireless-receiver",
    kb_layout = "us,br",
})

bind(mainMod .. " + space", "exec", "hyprctl switchxkblayout current next")

