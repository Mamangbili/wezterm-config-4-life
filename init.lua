-- Pretty-print a Lua table (supports nested tables, strings, numbers, booleans)
local function inspect(value, indent)
	indent = indent or 0
	local spaces = string.rep("  ", indent)
	if type(value) == "table" then
		local lines = { "{" }
		for k, v in pairs(value) do
			local key_str = type(k) == "string" and '"' .. k .. '"' or tostring(k)
			local val_str
			if type(v) == "table" then
				val_str = inspect(v, indent + 1)
			else
				val_str = type(v) == "string" and '"' .. v .. '"' or tostring(v)
			end
			table.insert(lines, spaces .. "  " .. key_str .. " = " .. val_str .. ",")
		end
		table.insert(lines, spaces .. "}")
		return table.concat(lines, "\n")
	else
		return tostring(value)
	end
end

-- Pull in the wezterm API
local wezterm = require("wezterm")
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
local session_manager = require("wezterm-session-manager/session-manager")

local config = wezterm.config_builder()
config.set_environment_variables = {
	prompt = "$E]7;file://localhost/$P$E\\$E[32m$T$E[0m $E[35m$P$E[36m$_$G$E[0m ",
}
config.default_prog = { "powershell.exe", "-NoLogo" }

-- This will hold the configuration.
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.enable_tab_bar = true
wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

-- session
wezterm.on("save_session", function(window)
	session_manager.save_state(window)
end)
wezterm.on("load_session", function(window)
	session_manager.load_state(window)
end)
wezterm.on("restore_session", function(window)
	session_manager.restore_state(window)
end)

config.keys = {
	{
		key = "s",
		mods = "ALT",
		action = wezterm.action_callback(function(window, pane)
			window:perform_action(wezterm.action.SendString(":wqa\r"), pane)
			window:perform_action(
				wezterm.action.SendKey({
					key = "C",
					mods = "CTRL",
				}),
				pane
			)
			window:perform_action(wezterm.action.SendString("clear\r"), pane)

			local ok, stdout = wezterm.run_child_process({
				"powershell.exe",
				"-noprofile",
				"-command",
				"zoxide query --list",
			})

			local choices = {}
			for line in stdout:gmatch("[^\r\n]+") do
				table.insert(choices, { label = line, id = line })
			end

			-- wezterm.log_info("choices:", inspect(choices))
			window:perform_action(
				wezterm.action.InputSelector({
					title = "switch neovim project",
					fuzzy = true,
					fuzzy_description = "switch neovim project :",
					choices = choices,
					action = wezterm.action_callback(function(window, pane, id, label)
						if not id and not label then
							wezterm.log_info("cancelled")
						else
							wezterm.log_info("you selected ", id, label)
							wezterm.action.SendString(":wqa\n")
							window:perform_action(

								window:perform_action(wezterm.action.SendString("cd " .. label .. "\r"), pane),
								window:perform_action(wezterm.action.SendString("nvim\r"), pane),
								pane
							)
						end
					end),
				}),
				pane
			)
		end),
	},
	{
		key = "S",
		mods = "ALT|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local ok, stdout = wezterm.run_child_process({
				"powershell.exe",
				"-noprofile",
				"-command",
				"zoxide query --list",
			})

			local choices = {}
			for line in stdout:gmatch("[^\r\n]+") do
				table.insert(choices, { label = line, id = line })
			end

			-- wezterm.log_info("choices:", inspect(choices))
			window:perform_action(
				wezterm.action.InputSelector({
					title = "switch neovim project in new tab",
					fuzzy = true,
					fuzzy_description = "switch neovim project in new tab :",
					choices = choices,
					action = wezterm.action_callback(function(window, pane, id, label)
						if not id and not label then
							wezterm.log_info("cancelled")
						else
							wezterm.log_info("you selected ", id, label)
							window:perform_action(
								wezterm.action.SpawnCommandInNewTab({
									args = {
										"powershell.exe",
										"-nologo",
										"-noExit",
										"-command",
										"nvim",
									},
									cwd = label,
								}), -- sending the label
								pane
							)
						end
					end),
				}),
				pane
			)
		end),
	},

	{
		key = "q",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SpawnCommandInNewTab({
			args = { "powershell.exe", "-nologo" },
			cwd = "d:/",
		}),
	},
	-- { key = "S", mods = "CTRL|SHIFT", action = wezterm.action({ EmitEvent = "save_session" }) },
	-- { key = "L", mods = "CTRL|SHIFT", action = wezterm.action({ EmitEvent = "load_session" }) },
	-- { key = "R", mods = "CTRL|SHIFT", action = wezterm.action({ EmitEvent = "restore_session" }) },
	-- ctrl + shift + arrow to resize panes
	{
		key = "LeftArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "RightArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.AdjustPaneSize({ "Right", 5 }),
	},
	{
		key = "UpArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.AdjustPaneSize({ "Up", 5 }),
	},
	{
		key = "DownArrow",
		mods = "CTRL|SHIFT",
		action = wezterm.action.AdjustPaneSize({ "Down", 5 }),
	},

	-- {
	-- 	key = "S",
	-- 	mods = "ALT",
	-- 	action = workspace_switcher.switch_workspace(),
	-- },
	-- {
	-- 	key = "s",
	-- 	mods = "ALT",
	-- 	action = workspace_switcher.switch_to_prev_workspace(),
	-- },
	{
		key = "1",
		mods = "ALT",
		action = wezterm.action.ActivateTabRelative(-1),
	},
	{
		key = "2",
		mods = "ALT",
		action = wezterm.action.ActivateTabRelative(1),
	},
	{
		key = "W",
		mods = "CTRL",
		action = wezterm.action.CloseCurrentPane({ confirm = false }),
	},
	-- + for vertical split - for horizontal split
	{
		key = "-",
		mods = "CTRL",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "=",
		mods = "CTRL",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- pane navigation using ctrl + shift + h/j/k/l
	{
		key = "H",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "L",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	{
		key = "K",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "J",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
}
-- wezterm.on("gui-startup", function(cmd)
-- 	local screen = wezterm.gui.screens().active
-- 	local ratio = 1
-- 	local width, height = screen.width * ratio, screen.height * ratio
-- 	local tab, pane, window = wezterm.mux.spawn_window({
-- 		position = {
-- 			x = (screen.width - width) / 2 - 10,
-- 			y = (screen.height - height) / 2,
-- 			origin = "ActiveScreen",
-- 		},
-- 	})
-- 	window:gui_window():set_inner_size(width, height - 90)
-- end)

-- or, changing the font size and color scheme.
config.font_size = 9
config.window_background_image = "C:/Users/MSiGAMING/Downloads/Knights-fencing.jpg"
-- config.window_background_image = "C:/Users/MSiGAMING/Downloads/knight rest.gif"
config.window_background_image_hsb = {
	brightness = 0.05,
	hue = 0.1,
	saturation = 0.8,
}
config.window_background_opacity = 0.9
-- config.window_background_gradient = {
-- 	orientation = "Vertical",
-- 	colors = { "000000" },
-- }

-- Finally, return the configuration to wezterm:
return config
