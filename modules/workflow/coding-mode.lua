-- ~/.dotfiles/modules/workflow/coding-mode.lua
-- IDE-optimized layout and keybindings

local CodingMode = {
    name = "coding",
    enabled = false,
}

-- Layout configuration
CodingMode.layout = {
    -- Primary monitor: IDE + terminal (60/40)
    [1] = {
        layout = "dwindle",
        gaps = {in = 5, out = 5},
        split_ratio = 0.6,
        description = "Editor + Terminal",
    },

    -- Secondary monitor: Browser/reference
    [2] = {
        layout = "dwindle",
        gaps = {in = 5, out = 5},
        description = "Browser",
    },

    -- Tertiary monitor: Docs/chat
    [3] = {
        layout = "dwindle",
        gaps = {in = 0, out = 5},
        description = "Documentation",
    },
}

-- App routing rules
CodingMode.app_routing = {
    -- IDE/Editor
    kitty = 1,
    neovim = 1,
    code = 1,
    vim = 1,
    emacs = 1,

    -- Browser (for API docs, etc.)
    brave = 2,
    firefox = 2,
    chromium = 2,

    -- Reference
    zeal = 3,
    devdocs = 3,
    discord = 3,
}

-- Window placement rules
CodingMode.window_rules = {
    -- Don't float IDE windows
    {class = "kitty", floating = false},
    {class = "code", floating = false},
    {class = "neovim", floating = false},

    -- Float utility windows
    {class = "pavucontrol", floating = true, size = "400x300"},
    {class = "nm-applet", floating = true},
    {class = "blueman-manager", floating = true},
}

-- Contextual keybindings in coding mode
CodingMode.keybinds = {
    -- Window navigation (hjkl)
    ["Super+H"] = "movefocus left",
    ["Super+J"] = "movefocus down",
    ["Super+K"] = "movefocus up",
    ["Super+L"] = "movefocus right",

    -- Window swapping
    ["Super+Alt+H"] = "swapwindow l",
    ["Super+Alt+J"] = "swapwindow d",
    ["Super+Alt+K"] = "swapwindow u",
    ["Super+Alt+L"] = "swapwindow r",

    -- Window management
    ["Super+Q"] = "killactive",
    ["Super+T"] = "togglefloating",
    ["Super+F"] = "fullscreen 0",
    ["Super+Y"] = "layoutmsg togglesplit",

    -- Workspace navigation
    ["Super+1"] = "workspace 1",
    ["Super+2"] = "workspace 2",
    ["Super+3"] = "workspace 3",

    -- Move window to workspace
    ["Super+Shift+1"] = "movetoworkspace 1",
    ["Super+Shift+2"] = "movetoworkspace 2",
    ["Super+Shift+3"] = "movetoworkspace 3",

    -- Terminal quick-open
    ["Super+Return"] = "exec kitty",

    -- Focus mode toggle
    ["Super+F12"] = "lua ~/.dotfiles/modules/workflow/focus-mode.lua:activate",
}

-- Activation trigger: detect IDE startup
function CodingMode.detect()
    -- Check for IDE-related window classes
    local handle = io.popen("hyprctl clients -j")
    if not handle then return false end

    local clients = handle:read("*a")
    handle:close()

    -- Check if any IDE is open
    for _, ide in ipairs({"code", "neovim", "vim", "emacs", "intellij", "eclipse"}) do
        if string.find(clients, ide) then
            return true
        end
    end

    return false
end

-- Activate coding mode
function CodingMode.activate()
    log("Activating Coding Mode")

    CodingMode.enabled = true

    -- Apply layout rules
    for ws_id, rules in pairs(CodingMode.layout) do
        CodingMode.apply_layout(ws_id, rules)
    end

    -- Apply window rules
    for _, rule in ipairs(CodingMode.window_rules) do
        CodingMode.apply_window_rule(rule)
    end

    -- Apply keybindings
    CodingMode.apply_keybinds()

    -- Restore previous session if available
    CodingMode.restore_session()

    log("Coding Mode activated")
end

-- Deactivate coding mode
function CodingMode.deactivate()
    log("Deactivating Coding Mode")

    CodingMode.enabled = false

    -- Save current session
    CodingMode.save_session()

    log("Coding Mode deactivated")
end

-- Apply layout to workspace
function CodingMode.apply_layout(workspace_id, layout_rules)
    -- Apply gaps
    os.execute("hyprctl dispatch workspace " .. workspace_id)
    os.execute("hyprctl keyword dwindle:gaps_in " .. layout_rules.gaps.in)
    os.execute("hyprctl keyword dwindle:gaps_out " .. layout_rules.gaps.out)
end

-- Apply window-specific rule
function CodingMode.apply_window_rule(rule)
    -- In production: modify Hyprland windowrule config
    -- Simplified here
end

-- Apply keybindings for this mode
function CodingMode.apply_keybinds()
    for key_combo, action in pairs(CodingMode.keybinds) do
        -- Register keybinding (implementation depends on Hyprland API)
        os.execute("hyprctl keyword bind '$mainMod', " .. key_combo .. ", " .. action)
    end
end

-- Restore previous coding session
function CodingMode.restore_session()
    local session_file = os.getenv("HOME") ..
        "/.dotfiles/state/sessions/coding-mode.json"

    local handle = io.open(session_file)
    if not handle then return end

    local session = handle:read("*a")
    handle:close()

    -- Reopen files, restore positions, etc.
end

-- Save current coding session
function CodingMode.save_session()
    local session_file = os.getenv("HOME") ..
        "/.dotfiles/state/sessions/coding-mode.json"

    -- Capture current state
    local state = {
        workspaces = {},
        windows = {},
        -- ... more state
    }

    local handle = io.open(session_file, "w")
    if handle then
        -- Write JSON-serialized state
        handle:write("{}")  -- Simplified
        handle:close()
    end
end

-- Log function (would be defined in parent module)
local function log(msg)
    io.stderr:write("[CodingMode] " .. msg .. "\n")
end

return CodingMode
