local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"
local fileManager = _G.fileManager or "nautilus"
local browser = _G.browser or "firefox"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize windows (Super + Shift + Arrow)
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

-- Move window position (Super + Ctrl + Arrow)
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

-- Workspace switching with Arrow / D-Pad (Super + Arrow)
hl.bind(mainMod .. " + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ workspace = "r+1" }))

-- Focus movement (Alt + Arrow)
hl.bind("ALT + Left", hl.dsp.focus({ direction = "left" }))
hl.bind("ALT + Right", hl.dsp.focus({ direction = "right" }))
hl.bind("ALT + Up", hl.dsp.focus({ direction = "up" }))
hl.bind("ALT + Down", hl.dsp.focus({ direction = "down" }))

-- Overview Mode (Quickshell Overview)
hl.bind(mainMod .. " + Backspace", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))

-- Core Actions requested:
-- Super + Enter: Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))

-- Super + Q: Close active window
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

-- Super + Space: App Launcher (Serpantinum Launcher)
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))

-- Window states
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + V", hl.dsp.window.float({ action = "toggle" }))

-- Serpantinum Shell Quick Toggles & Actions
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("serpantinum msg toggle music"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle system"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle guide"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("serpantinum msg toggle autohide"))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("serpantinum msg toggle notch"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("serpantinum reload"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true })

-- Launchers
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(browser))

-- Brightness & Screenshots
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --edit"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("serpantinum screenshot --full --edit"), { locked = true })

-- Audio & Media Controls
hl.bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true })

-- Workspaces switching and moving via Serpantinum
for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"))
end
