hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
	-- App launcher daemon. Runs hidden and is toggled over IPC by ALT + R,
	-- so opening it costs a frame instead of a Qt cold start.
	hl.exec_cmd("qs -c launcher")
	hl.exec_cmd("wl-paste --watch cliphist store")
	-- On-screen volume/brightness/caps-lock indicator.
	hl.exec_cmd("swayosd-server")
	-- Blue-light filter. Runs all day and follows the profiles in
	-- hyprsunset.conf, so there is nothing to turn on by hand.
	hl.exec_cmd("hyprsunset")
	-- Phone link. Backs the waybar phone button; without the daemon running
	-- the button has nothing to talk to.
	hl.exec_cmd("kdeconnectd")
end)
hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

local terminal = "kitty"
local fileManager = "nautilus"
local menu = "qs -c launcher ipc call launcher toggle"
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
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
-- Pauses the recording if one is running, otherwise falls back to pseudo.
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh pause"))
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))
-- Zen mode: hide waybar and window borders for distraction-free focus.
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/zen.sh"))

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

-- ALT + S saves the recording if one is running, otherwise takes a region
-- screenshot; ALT + SHIFT + S grabs the whole screen with no selection step.
-- Both open in satty first, so the shot can be drawn on before it is saved.
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh save"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenshot.sh full"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/screenrecord.sh toggle"))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Audio and brightness go through swayosd-client rather than wpctl and
-- brightnessctl directly: it applies the change *and* draws the on-screen
-- bar, so there is no separate notification to keep in sync.
local osd = function(args)
	return hl.dsp.exec_cmd("swayosd-client " .. args)
end

hl.bind("XF86AudioRaiseVolume", osd("--output-volume raise --max-volume 100"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", osd("--output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", osd("--output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute", osd("--input-volume mute-toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", osd("--brightness raise 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", osd("--brightness lower 5"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F6", osd("--brightness raise 5"), { locked = true, repeating = true })
hl.bind(mainMod .. " + F5", osd("--brightness lower 5"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("wdisplays"))
hl.bind("ALT + Escape", hl.dsp.exec_cmd("wlogout"))
hl.bind("ALT + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock"))

-- Manual blue-light override. hyprsunset.conf already switches on its own at
-- sunset/sunrise; this forces warm now (or back to normal) without waiting.
-- `hyprctl hyprsunset temperature` reports the active value, so no state file.
hl.bind(
	mainMod .. " + B",
	hl.dsp.exec_cmd(
		'bash -c \'t=$(hyprctl hyprsunset temperature | grep -o "[0-9]\\+" | head -1); '
			.. 'if [ "${t:-6500}" -ge 6000 ]; '
			.. "then hyprctl hyprsunset temperature 4000; "
			.. "else hyprctl hyprsunset identity; fi'"
	)
)
-- Clipboard history in the launcher's own clipboard mode rather than a
-- separate wofi menu, so both pickers look and behave the same.
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs -c launcher ipc call launcher clipboard"))

hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/toggle-eDP.sh"))

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

-- Waydroid picks its resolution when the session starts and never renegotiates,
-- so the window has to sit at exactly that size or Android gets scaled and
-- goes soft. This used to be pseudotiled, which is what made the width reset
-- when the phone was moved around: Hyprland rescales a pseudotiled window to
-- fit whatever tile it lands in, so a busier workspace shrank it. Floating
-- keeps the size fixed wherever it is dragged.
--
-- The two marked lines are rewritten by "waydroid.sh size", which also sets
-- persist.waydroid.{width,height} and restarts the session so Android actually
-- re-renders at the new size. Both have to stay in agreement -- edit via that
-- command rather than by hand.
hl.window_rule({
	name = "waydroid-phone",
	match = { class = "^Waydroid$" },

	float = true,
	size = "446 966", -- waydroid-size
	move = "monitor_w-466 32", -- waydroid-move
	keep_aspect_ratio = true,
	no_max_size = true,
})

-- The screenshot editor sizes itself to the shot it was handed; tiling it
-- would stretch the image away from the pixels it is annotating.
hl.window_rule({
	name = "swappy-floating",
	match = { class = "^swappy(-mini)?$" },
	float = true,
})

-- The weekly update terminal from the waybar module: float it in the middle
-- so it reads as a dialog rather than shoving the workspace layout around.
hl.window_rule({
	name = "sysupdate-float",
	match = { class = "^sysupdate-float$" },
	float = true,
	size = "60% 70%",
	center = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/win11.sh"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/waydroid.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("$HOME/.config/hypr/scripts/waydroid.sh size"))

-- Steam's main window tiles like anything else, but its satellite windows
-- (friends list, settings, the download/screenshot popups) are dialogs that
-- Steam sizes itself. Tiling them squashes the layout, so they float.
hl.window_rule({
	name = "steam-dialogs",
	match = {
		class = "^steam$",
		title = "^(Friends List|Steam Settings|Special Offers|Screenshot Uploader|Steam - News|Sign in to Steam)$",
	},
	float = true,
})

-- Steam's "Add a Game"/library popups come through with no title set at all.
hl.window_rule({
	name = "steam-untitled-popups",
	match = { class = "^steam$", title = "^$" },
	float = true,
})

-- Games run fullscreen and want the compositor out of the way: no gaps, no
-- border, and no idle timeout firing during a long cutscene or a gamepad
-- session where the keyboard is never touched.
hl.window_rule({
	name = "games-fullscreen",
	match = { fullscreen = true },
	idle_inhibit = "fullscreen",
	border_size = 0,
	rounding = 0,
})
