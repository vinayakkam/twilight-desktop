-- Twilight: Hyprland session configuration.
--
-- Everything Hyprland-specific lives in ~/.config/hypr and
-- ~/.config/quickshell/twilight. KDE Plasma's configuration is never read or
-- written from here. Display layouts saved by nwg-displays land in
-- monitors.lua and are loaded below.

local HOME     = os.getenv("HOME")
local HYPR     = HOME .. "/.config/hypr"
local SCRIPTS  = HYPR .. "/scripts"
-- Set by the test launcher when Hyprland runs as a window inside KDE: skip
-- everything that would touch the host session (D-Bus env, idle, polkit).
-- Also true when started from inside a running KDE session (KDE_FULL_SESSION
-- is inherited): never touch KDE's environment or rerun login apps then.
local NESTED   = os.getenv("TWILIGHT_NESTED") == "1" or os.getenv("KDE_FULL_SESSION") ~= nil

-- Values chosen in the Settings app (Super + I). Written to twilight.lua by
-- the shell; defaults below apply until then.
local S = {
    gaps_in = 4, gaps_out = 8, rounding = 12, blur = true, animations = true,
    border_a = "rgba(f2683aee)", border_b = "rgba(f3b651ee)",
    natural_scroll = true, tap_to_click = true, sensitivity = 0, kb_layout = "us",
    title_bars = true, buttons_left = false,
    laptop_scale = 1, left_handed = false, repeat_delay = 400, repeat_rate = 30, cursor_size = 24,
}
do
    local ok, t = pcall(dofile, HYPR .. "/twilight.lua")
    if ok and type(t) == "table" then for k, v in pairs(t) do S[k] = v end end
end

-- Konsole with the Twilight profile: right-click menu with Copy / Paste.
local terminal    = "konsole --profile Twilight"
local fileManager = "dolphin"
local browser     = "flatpak run app.zen_browser.zen"
local shellIpc    = "qs -c twilight ipc call shell "


-----------------------
---- ENVIRONMENT ----
-----------------------

hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", tostring(S.cursor_size))
hl.env("HYPRCURSOR_SIZE", tostring(S.cursor_size))
-- Private dconf database: GTK theme, dark mode and fonts changed here never
-- reach KDE's ~/.config/dconf/user.
hl.env("DCONF_PROFILE", HYPR .. "/dconf/profile")
-- Qt/KDE apps use KDE's own platform theme, which only *reads* your KDE
-- colours and icons (Dolphin, Discover look as they do in Plasma). qt6ct was
-- tested and rejected: Kirigami apps ignore its palette and render light.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("KITTY_CONFIG_DIRECTORY", HYPR .. "/kitty")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
-- Qt apps (incl. the shell) must exit with Hyprland, never reattach to the
-- next compositor - otherwise they could reappear inside a later KDE login.
hl.env("QT_WAYLAND_RECONNECT", "0")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- KDE apps (Dolphin "Open with", file associations, Kate…) find installed
-- applications through Plasma's menu file; read-only, KDE itself uses the same.
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Your personal tool folders (Claude Code, pnpm, …) on PATH even if the
-- login didn't go through your shell profile.
do
    local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"
    for _, d in ipairs({ HOME .. "/.local/share/pnpm", HOME .. "/.local/bin" }) do
        if not (":" .. path .. ":"):find(":" .. d .. ":", 1, true) then path = d .. ":" .. path end
    end
    hl.env("PATH", path)
end

-- KDE apps (and the shell's icons) use your KDE icon theme and colours, which
-- Plasma keeps in ~/.config/kdedefaults and adds to this search path at login.
do
    local dirs = os.getenv("XDG_CONFIG_DIRS") or "/etc/xdg"
    local kd = HOME .. "/.config/kdedefaults"
    if not (":" .. dirs .. ":"):find(":" .. kd .. ":", 1, true) then dirs = kd .. ":" .. dirs end
    -- Twilight's own overrides (e.g. the theme-coloured icons) come first.
    local tw = HYPR .. "/kde-overrides"
    if not (":" .. dirs .. ":"):find(":" .. tw .. ":", 1, true) then dirs = tw .. ":" .. dirs end
    hl.env("XDG_CONFIG_DIRS", dirs)
end

-- Flatpak apps (Zen, Discord, Steam…) must be visible to the launcher even
-- when the session isn't started from a login shell.
do
    local dirs = os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    for _, d in ipairs({ "/var/lib/flatpak/exports/share", HOME .. "/.local/share/flatpak/exports/share" }) do
        if not (":" .. dirs .. ":"):find(":" .. d .. ":", 1, true) then dirs = d .. ":" .. dirs end
    end
    hl.env("XDG_DATA_DIRS", dirs)
end


------------------
---- MONITORS ----
------------------

-- Any display that appears gets its preferred mode, placed to the right.
-- Nothing assumes an external display is present.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = S.laptop_scale })

-- Layout saved from the graphical display tool (nwg-displays), if any.
local f = io.open(HYPR .. "/monitors.lua", "r")
if f then
    f:close()
    local ok, err = pcall(dofile, HYPR .. "/monitors.lua")
    if not ok then
        hl.notification.create({ text = "monitors.lua ignored: " .. tostring(err), timeout = 8000 })
    end
end

local function lidClosed()
    local lid = io.open("/proc/acpi/button/lid/LID0/state", "r")
    if not lid then return false end
    local state = lid:read("*a")
    lid:close()
    return state:find("closed") ~= nil
end

local function externalActive()
    for _, m in ipairs(hl.get_monitors({ all = true }) or {}) do
        if not m.name:match("^eDP") and m.enabled then return true end
    end
    return false
end

-- Safety net: the laptop panel is only switched off when the lid is closed
-- AND another display is active. Unplugging a projector always brings the
-- laptop panel back, even if a saved layout disabled it.
if not NESTED then
    if lidClosed() and externalActive() then
        hl.monitor({ output = "eDP-1", disabled = true })
    elseif not externalActive() then
        hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = S.laptop_scale })
    end
end

local reloadTimer = nil
local function reloadSoon()
    if reloadTimer then reloadTimer:set_enabled(false) end
    reloadTimer = hl.timer(function() hl.dispatch(hl.dsp.reload_config()) end,
                           { timeout = 600, type = "oneshot" })
end

if not NESTED then
    hl.bind("switch:on:Lid Switch",  reloadSoon, { locked = true })
    hl.bind("switch:off:Lid Switch", reloadSoon, { locked = true })
    hl.on("monitor.added", reloadSoon)
    hl.on("monitor.removed", reloadSoon)
end


-- Keep floating windows' title bars below the top bar so they can always be
-- grabbed. Checked only while the pointer is still (never mid-drag); windows
-- are moved down, never resized. Maximised/fullscreen/minimised are skipped.
local lastCursor = nil
local function topReserved(m)
    local r = m.reserved
    if type(r) ~= "table" then return 0 end
    return r.top or r[2] or 0
end
local TASKBAR_ZONE = 70   -- taskbar height incl. gaps (shell Theme: 54 + 2*8)
local lastOverlap = nil
local function keepBelowBar()
    local c = hl.get_cursor_pos()
    local still = c and lastCursor and c.x == lastCursor.x and c.y == lastCursor.y
    lastCursor = c and { x = c.x, y = c.y } or nil
    local overlap = {}
    for _, w in ipairs(hl.get_windows() or {}) do
        local ws = w.workspace
        if w.floating and w.mapped and not w.hidden and w.fullscreen == 0 and w.monitor
           and ws and not ws.special and ws.visible then
            local m = w.monitor
            local x, y = w.at.x or w.at[1], w.at.y or w.at[2]
            local h = w.size.y or w.size[2]
            -- A window reaching into the taskbar area makes the taskbar step aside.
            if y + h > (m.y or 0) + (m.height or 0) - TASKBAR_ZONE then overlap[m.name] = true end
            -- Window title bars (hyprbars, 30 px) sit above the window itself.
            local top = (m.y or 0) + topReserved(m) + (hl.plugin.hyprbars and 30 or 0)
            if still and y < top then
                hl.dispatch(hl.dsp.window.move({ x = x, y = top, window = w }))
            end
        end
    end
    local names = {}
    for n in pairs(overlap) do names[#names + 1] = n end
    table.sort(names)
    local key = table.concat(names, ",")
    if key ~= lastOverlap then
        lastOverlap = key
        hl.exec_cmd("qs -c twilight ipc call shell windowsOverTaskbar '" .. key .. "'")
    end
end
-- Started once Hyprland runs (creating it during config checks would crash).
local keepTimer = nil
local function startKeepBelowBar()
    -- No monitors means a config check, not a running session.
    if not keepTimer and hl.get_active_monitor() then keepTimer = hl.timer(function() pcall(keepBelowBar) end, { timeout = 700, type = "repeat" }) end
end
hl.on("hyprland.start", startKeepBelowBar)
hl.on("config.reloaded", startKeepBelowBar)


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    if not NESTED then
        hl.exec_cmd(SCRIPTS .. "/session-env.sh import")
        hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
        -- Unlock KWallet with the login password, as KDE does at login, so
        -- saved logins (Git Credential Manager for GitPilot, Wi-Fi, …) work.
        hl.exec_cmd("/usr/lib/pam_kwallet_init")
        hl.exec_cmd("hypridle")
        -- Discover's update notifier (KDE only autostarts it inside Plasma).
        hl.exec_cmd("sh -c 'echo $$ > \"$XDG_RUNTIME_DIR/twilight-notifier.pid\"; exec /usr/lib/DiscoverNotifier --check-delay 300'")
        -- Your own login apps from ~/.config/autostart (e.g. LatchVerify, which
        -- your Claude MCP servers run through).
        hl.exec_cmd(SCRIPTS .. "/xdg-autostart.sh")
        hl.exec_cmd(SCRIPTS .. "/chromium-system-titlebar.sh")
    end
    hl.exec_cmd("qs -n -c twilight")
end)

hl.on("hyprland.shutdown", function()
    -- Stop everything this session started so nothing outlives it. Runs in
    -- the background so signing out isn't held up waiting for services.
    local cmd = "qs kill -c twilight >/dev/null 2>&1"
    if not NESTED then
        cmd = cmd .. '; p="$XDG_RUNTIME_DIR/twilight-notifier.pid"; [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null; rm -f "$p"'
            .. '; pkill -u "$USER" -x hypridle; ' .. SCRIPTS .. "/session-env.sh clear"
    end
    os.execute("setsid sh -c '" .. cmd:gsub("'", "'\\''") .. "' >/dev/null 2>&1 &")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = S.gaps_in,
        gaps_out = S.gaps_out,
        border_size = 2,
        col = {
            active_border   = { colors = { S.border_a, S.border_b }, angle = 45 },
            inactive_border = "rgba(ffffff14)",
        },
        resize_on_border = true,
        -- Dragged windows snap to screen edges and to each other.
        snap = { enabled = true, window_gap = 10, monitor_gap = 10, respect_gaps = true },
        extend_border_grab_area = 12,
        hover_icon_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = S.rounding,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            color        = 0x55000000,
        },

        -- Blur is only visible behind translucent surfaces (the shell's
        -- panels); opaque windows cost nothing. Kept small for Vega 8.
        blur = {
            enabled   = S.blur,
            size      = 6,
            passes    = 2,
            vibrancy  = 0.17,
            new_optimizations = true,
            xray      = false,
            popups    = false,
        },
    },

    animations = { enabled = S.animations },

    cursor = {
        -- Default would write the cursor theme into gsettings; keep off so
        -- nothing is synced outside this session.
        sync_gsettings_theme = false,
        -- Never move the pointer by itself (e.g. when focusing from the taskbar).
        no_warps = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        background_color = "rgb(0b0b14)",
        focus_on_activate = true,
        -- Floating windows always stay fully on screen (never lost off an edge).
        new_float_force_onscreen = 1,
        float_force_onscreen = 1,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
        animate_manual_resizes = false,
        enable_anr_dialog = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },

    xwayland = { force_zero_scaling = true },

    dwindle = { preserve_split = true },

    layers = {
        -- The taskbar must be able to appear over a maximised/fullscreen
        -- window when the pointer reaches the bottom edge.
        allow_new_top_layers_over_existing_fullscreen = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1} } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 8,    bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5,    bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.2,  spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3.6,  spring = "easy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.4,  bezier = "linear", style = "popin 90%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.6,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.4,  bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,    bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.5,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 3.5,  bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.5,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "slidevert" })


-- Shell surfaces: subtle glass behind the translucent panels. The shell
-- animates its own popups, so Hyprland's layer animation is off for them.
-- Inside a KDE window everything is composited twice: skip the costly effects.
if NESTED then
    hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })
end

hl.layer_rule({
    name  = "twilight-glass",
    -- Only on surfaces that don't fade: blur under a fading surface pops on
    -- and off part-way through the animation and looks glitchy.
    match = { namespace = "^twilight-(bar|taskbar)$" },
    blur = true,
    ignore_alpha = 0.35,
    no_anim = true,
})
hl.layer_rule({
    name  = "twilight-wallpaper",
    match = { namespace = "^twilight-wallpaper$" },
    no_anim = true,
})


--------------------------------
---- WINDOW BUTTONS (hyprbars) ----
--------------------------------

-- Title bars with coloured minimise / maximise / close dots at the top-left
-- of each window. Uses the official hyprbars plugin, built in user space
-- (see README). Without the plugin file Hyprland simply runs without bars.
local HYPRBARS = HOME .. "/.local/lib/hyprland/hyprbars.so"
local barsFile = io.open(HYPRBARS, "r")
if barsFile and S.title_bars then
    barsFile:close()
    -- On a config reload the plugin is already loaded (load() then errors,
    -- harmlessly); on the very first read its Lua functions appear only after
    -- loading finishes, so the bars are configured by one reload at start.
    pcall(hl.plugin.load, HYPRBARS)
    if hl.plugin.hyprbars then
        hl.config({
            plugin = {
                hyprbars = {
                    bar_height = 30,
                    bar_color = "rgba(111a30f2)",
                    ["col.text"] = "rgba(aeb3c8ff)",
                    bar_text_font = "Inter",
                    bar_text_size = 11,
                    bar_text_weight = "500",
                    bar_text_align = "center",
                    bar_buttons_alignment = S.buttons_left and "left" or "right",
                    bar_padding = 12,
                    bar_button_padding = 8,
                    bar_part_of_window = true,
                    bar_precedence_over_border = false,
                    -- Unfocused windows show grey dots, like the reference.
                    inactive_button_color = "rgba(ffffff2e)",
                    icon_on_hover = true,
                    on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']],
                },
            },
        })
        -- Left to right: minimise (amber), maximise (green), close (red).
        -- White glyphs (Nerd Font, via fontconfig fallback) appear only on the
        -- hovered dot.
        local buttons = {
            { bg_color = "rgb(f5a524)", fg_color = "rgb(ffffff)", size = 14, icon = "\u{F1639}",
              action = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']] },
            { bg_color = "rgb(3ec56d)", fg_color = "rgb(ffffff)", size = 14, icon = "\u{F0616}",
              action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']] },
            { bg_color = "rgb(ff5f57)", fg_color = "rgb(ffffff)", size = 14, icon = "\u{F1398}",
              action = [[hyprctl dispatch 'hl.dsp.window.close()']] },
        }
        -- Buttons are placed from the aligned edge inwards; keep the visual
        -- order minimise, maximise, close on either side.
        if S.buttons_left then
            for i = 1, 3 do hl.plugin.hyprbars.add_button(buttons[i]) end
        else
            for i = 3, 1, -1 do hl.plugin.hyprbars.add_button(buttons[i]) end
        end

        -- Apps that draw their own title-bar buttons keep only theirs.
        hl.window_rule({
            name  = "no-bar-for-csd-apps",
            -- Case-insensitive: e.g. Opera's class is "Opera GX".
            -- (Opera/Chrome are switched to the system title bar at login instead.)
            match = { class = "(?i)^(firefox|.*discord.*|steam|com\\.usebottles\\.bottles|jetbrains-.*|.*onlyoffice.*|desktopeditors|twilight-monitor)$" },
            ["hyprbars:no_bar"] = true,
        })
        -- Twilight Settings draws its own window buttons.
        hl.window_rule({
            name  = "no-bar-settings",
            match = { title = "^(Twilight Settings|Get started with Twilight|Snipping Tool)$" },
            ["hyprbars:no_bar"] = true,
        })
    else
        hl.on("hyprland.start", function() hl.dispatch(hl.dsp.reload_config()) end)
    end
end


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = S.kb_layout,
        -- Windows-style: a window gets focus when clicked, not when hovered.
        follow_mouse = 2,
        left_handed = S.left_handed,
        repeat_delay = S.repeat_delay,
        repeat_rate = S.repeat_rate,
        sensitivity = S.sensitivity,
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll = S.natural_scroll,
            tap_to_click = S.tap_to_click,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.6,
        },
    },
    gestures = {
        workspace_swipe_cancel_ratio = 0.25,
    },
    binds = {
        allow_workspace_cycles = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


---------------------
---- KEYBINDINGS ----
---------------------

local mod = "SUPER"

-- Start menu on a lone tap of the Windows key.
hl.bind(mod .. " + SUPER_L", hl.dsp.exec_cmd(shellIpc .. "toggle start"), { release = true })
hl.bind(mod .. " + A", hl.dsp.exec_cmd(shellIpc .. "toggle quicksettings"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd(shellIpc .. "toggle notifications"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd(shellIpc .. "toggle power"))
hl.bind(mod .. " + I", hl.dsp.exec_cmd(shellIpc .. "settings"))
-- Like Windows' Win + P: display / projector options.
hl.bind(mod .. " + P", hl.dsp.exec_cmd(shellIpc .. "settingsPage display"))
-- Windows-style extras.
hl.bind(mod .. " + D",   hl.dsp.exec_cmd(shellIpc .. "showDesktop"))
hl.bind(mod .. " + TAB", hl.dsp.exec_cmd(shellIpc .. "taskView"))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd(shellIpc .. "taskManager"))
hl.bind(mod .. " + PERIOD", hl.dsp.exec_cmd("plasma-emojier"))
hl.bind(mod .. " + F1",  hl.dsp.exec_cmd(shellIpc .. "getStarted"))
-- Recovery: restart the shell (bar, taskbar, menus) if it ever misbehaves.
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("qs kill -c twilight; sleep 0.5; qs -n -d -c twilight"))

hl.bind(mod .. " + T",      hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E",      hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + B",      hl.dsp.exec_cmd(browser))

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4",    hl.dsp.window.close())
hl.bind(mod .. " + UP",   hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + F",    hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + V",    hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J",    hl.dsp.layout("togglesplit"))

hl.bind("ALT + TAB",           hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB",   hl.dsp.window.cycle_next({ next = false }))

hl.bind(mod .. " + LEFT",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
-- The window you click comes to the front, like on Windows. A maximised
-- window counts as fullscreen in Hyprland, and windows opened over it keep an
-- "over fullscreen" flag; sending them to the back clears it.
hl.on("window.active", function(w)
    if not w then return end
    if (w.fullscreen or 0) > 0 then
        local ws = w.workspace and w.workspace.id
        for _, o in ipairs(hl.get_windows() or {}) do
            if o.address ~= w.address and o.workspace and o.workspace.id == ws and o.allowed_over_fullscreen then
                hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = o }))
            end
        end
    elseif w.floating then
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
    end
end)

-- Minimise = park the window on the hidden "minimized" workspace; the
-- taskbar restores it.
local function minimize(w)
    if w then hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = w, follow = false })) end
end
hl.bind(mod .. " + DOWN", function() minimize(hl.get_active_window()) end)
-- Minimise buttons drawn by apps themselves (Zen, Firefox, GTK apps, …).
hl.on("window.minimize", function(w, minimized)
    if minimized == false or minimized == 0 then return end
    minimize(w)
end)
hl.bind(mod .. " + SHIFT + LEFT",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))

for i = 1, 9 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + CTRL + RIGHT", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + CTRL + LEFT",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots (saved to ~/Pictures/Screenshots and copied to the clipboard).
hl.bind("Print",                 hl.dsp.exec_cmd(shellIpc .. "screenshot"))
hl.bind(mod .. " + SHIFT + S",   hl.dsp.exec_cmd(shellIpc .. "screenshot"))
hl.bind(mod .. " + SHIFT + R",   hl.dsp.exec_cmd(SCRIPTS .. "/record.sh toggle"))

-- Laptop keys. Volume and brightness go through the shell so it can show its
-- on-screen indicator; playback goes straight to playerctl.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(shellIpc .. "brightness 5"),  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(shellIpc .. "brightness -5"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd(shellIpc .. "kbdBrightness 1"),  { locked = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(shellIpc .. "kbdBrightness -1"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
hl.bind("XF86Display",    hl.dsp.exec_cmd("nwg-displays"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Windows-style: new windows float and overlap instead of splitting the
-- screen. Super + V tiles a window if you ever want that.
hl.window_rule({
    name  = "float-by-default",
    match = { class = ".*" },
    float = true,
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Utility and settings windows float, centred, like normal dialogs.
hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(nwg-displays|org.pulseaudio.pavucontrol|pavucontrol|kcmshell6|org.kde.kcmshell6|hyprpolkitagent|org.kde.kcalc|xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde)$" },
    float  = true,
    center = true,
})
hl.window_rule({
    name  = "twilight-settings",
    match = { title = "^(Twilight Settings|Get started with Twilight|Snipping Tool)$" },
    float  = true,
    center = true,
})
hl.window_rule({
    name  = "system-monitor",
    match = { class = "^twilight-monitor$" },
    float  = true,
    size   = "1000 640",
    center = true,
})
hl.window_rule({
    name  = "float-pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
})
