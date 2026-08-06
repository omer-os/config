hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
	hl.exec_cmd("wl-paste --watch cliphist store")
end)

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

local terminal = "kitty"
local fileManager = "dolphin"
local menu = "wofi --show drun"
local browser = "google-chrome-stable"

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
	general = {
		gaps_in = 0,
		gaps_out = 0,
		border_size = 1,
		col = {
			active_border = "rgba(1f8a44ff)",
			inactive_border = "rgba(0d2415ff)",
		},
		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},
	-- Flat and opaque: no blur, no shadows, no transparency, square corners.
	decoration = {
		rounding = 0,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = false,
		},
		blur = {
			enabled = false,
		},
	},
	animations = {
		enabled = true,
	},
})

-- Only windows moving and resizing animate. Everything else -- workspace
-- switches, opens, closes, fades -- stays instant.
-- Speeds are in deciseconds, so 2.5 == 250ms.
hl.curve("smooth", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 2.5, bezier = "smooth" })
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "smooth" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "smooth" })
hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({
	master = {
		new_status = "master",
	},
})

hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

hl.config({
	misc = {
		-- hyprpaper owns the background now, so the built-in wallpaper and logo
		-- are off -- otherwise they flash underneath before hyprpaper starts.
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		-- Without these, keyboard/mouse resizes and drags snap instantly and
		-- skip the windowsMove animation entirely.
		animate_manual_resizes = true,
		animate_mouse_windowdragging = true,
	},
})

hl.config({
	input = {
		kb_layout = "us,ara",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

local mainMod = "ALT"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close())

hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(browser))

-- Toggle keyboard layout (us <-> ara) via dispatcher to avoid xkb's grp toggle
-- leaving the Alt modifier stuck after switching. Goes through the waybar
-- script so the EN/AR indicator refreshes instantly too.
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("~/.config/waybar/scripts/language.sh toggle"))

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
-- Pauses the recording if one is running, otherwise falls back to pseudo.
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh pause"))
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.move({ direction = "right" }))

-- Resize active window (hold to repeat)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -60, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.resize({ x = 60, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -60, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.resize({ x = 0, y = 60, relative = true }), { repeating = true })

-- Direct workspace switching: ALT+N goes straight to workspace N. workspace.py
-- keeps workspaces 1..(highest in use) persistent, so clearing a middle
-- workspace leaves it empty-but-present instead of collapsing the numbering.
local wsScript = "$HOME/.config/hypr/scripts/workspace.py"
for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd(wsScript .. " focus " .. i))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd(wsScript .. " move " .. i))
end

-- ALT + S saves the recording if one is running, otherwise takes a screenshot.
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh save"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh toggle"))
-- hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))


hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("wdisplays"))
hl.bind("ALT + Escape", hl.dsp.exec_cmd("wlogout"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("bash -c 'cliphist list | wofi --dmenu | cliphist decode | wl-copy'"))

hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-eDP.sh"))

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Waydroid renders Android at the fixed resolution set in waydroid.sh and
-- can't reflow, so stretching it to fill a tile would just crop the phone
-- screen. Pseudotiling keeps it in the tiling layout -- it still takes its
-- slot and everything else tiles around it -- while rendering at exactly the
-- size Android asks for.
hl.window_rule({
	name = "pseudo-waydroid",
	match = { class = "^Waydroid$" },
	pseudo = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-eDP.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/win11.sh"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/waydroid.sh"))
