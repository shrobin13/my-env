-- ~/.dotfiles/modules/core/workspace.lua
-- Intelligent workspace management

local Workspace = {}

-- Workspace configuration
Workspace.config = {
    auto_allocate = true,
    persist_layout = true,
    max_workspaces = 10,
}

-- Workspace state
Workspace.state = {
    current = 1,
    history = {},
    layout_state = {},
}

-- Auto-allocate workspace based on app class
function Workspace.auto_allocate(client_class)
    local routing = {
        -- Development
        kitty = 1,
        neovim = 1,
        code = 1,

        -- Browser
        brave = 3,
        firefox = 3,
        chromium = 3,

        -- Communication
        discord = 5,
        slack = 5,
        telegram = 5,

        -- Media
        vlc = 6,
        mpv = 6,

        -- Documentation
        zeal = 4,
        devdocs = 4,
    }

    return routing[client_class] or Workspace.find_empty()
end

-- Find first empty workspace
function Workspace.find_empty()
    -- Query current workspaces
    -- Return first unused number
    for i = 1, Workspace.config.max_workspaces do
        if not Workspace.is_occupied(i) then
            return i
        end
    end
    return 1
end

-- Check if workspace is occupied
function Workspace.is_occupied(workspace_id)
    local handle = io.popen("hyprctl workspaces -j")
    if not handle then return true end

    local result = handle:read("*a")
    handle:close()

    -- Parse JSON to check if workspace exists and has windows
    return string.find(result, '"id":' .. workspace_id) ~= nil
end

-- Save workspace layout to disk
function Workspace.persist(workspace_id)
    local layout = Workspace.get_layout(workspace_id)
    local state_file = os.getenv("HOME") ..
        "/.dotfiles/state/workspaces/" .. workspace_id .. ".json"

    local handle = io.open(state_file, "w")
    if handle then
        -- Write layout info
        handle:write(layout)
        handle:close()
    end
end

-- Restore workspace layout from disk
function Workspace.restore(workspace_id)
    local state_file = os.getenv("HOME") ..
        "/.dotfiles/state/workspaces/" .. workspace_id .. ".json"

    local handle = io.open(state_file)
    if not handle then return end

    local layout = handle:read("*a")
    handle:close()

    -- Apply layout (reopen windows, restore positions)
    Workspace.apply_layout(workspace_id, layout)
end

-- Get current layout of workspace
function Workspace.get_layout(workspace_id)
    local handle = io.popen("hyprctl clients -j")
    if not handle then return "{}" end

    local result = handle:read("*a")
    handle:close()

    -- Parse and filter for current workspace
    return result
end

-- Apply saved layout to workspace
function Workspace.apply_layout(workspace_id, layout)
    -- Parse layout
    -- Reopen windows
    -- Restore positions and splits
end

-- Navigate between workspaces with history
function Workspace.navigate(workspace_id)
    local current = Workspace.state.current

    -- Add to history
    table.insert(Workspace.state.history, current)
    if #Workspace.state.history > 20 then
        table.remove(Workspace.state.history, 1)
    end

    -- Navigate
    os.execute("hyprctl dispatch workspace " .. workspace_id)

    -- Save previous layout
    Workspace.persist(current)

    -- Update current
    Workspace.state.current = workspace_id
end

-- Go back to previously active workspace (Alt+Tab style)
function Workspace.toggle_previous()
    if #Workspace.state.history > 0 then
        local previous = Workspace.state.history[#Workspace.state.history]
        Workspace.navigate(previous)
    end
end

-- Dynamic workspace creation for projects
function Workspace.create_project(project_name)
    local workspace_id = Workspace.find_empty()

    -- Tag workspace with project name
    Workspace.state.layout_state[workspace_id] = {
        type = "project",
        name = project_name,
        created = os.time(),
    }

    return workspace_id
end

-- Reclaim unused dynamic workspaces
function Workspace.cleanup_empty()
    for i = 1, Workspace.config.max_workspaces do
        if not Workspace.is_occupied(i) and
           Workspace.state.layout_state[i] and
           Workspace.state.layout_state[i].type == "project" then
            Workspace.state.layout_state[i] = nil
        end
    end
end

return Workspace
