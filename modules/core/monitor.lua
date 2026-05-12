-- ~/.dotfiles/modules/core/monitor.lua
-- Monitor management and hot-plug detection

local Monitor = {}

-- Monitor state tracking
Monitor.monitors = {}
Monitor.roles = {
    primary = {},
    secondary = {},
    tertiary = {},
}

-- Get current monitor topology
function Monitor.get_topology()
    local handle = io.popen("hyprctl monitors -j")
    if not handle then return {} end

    local result = handle:read("*a")
    handle:close()

    -- Parse JSON (simplified - would use proper JSON lib)
    return result
end

-- Detect monitor roles based on position and size
function Monitor.detect_roles()
    local monitors = Monitor.get_topology()

    -- Simple logic: leftmost is primary, middle is secondary, etc.
    -- In production: read from config/monitors.yaml

    return {
        primary = monitors[1] or {},
        secondary = monitors[2] or {},
        tertiary = monitors[3] or {},
    }
end

-- Handle monitor connection
function Monitor.on_connect(monitor_name)
    log("Monitor connected: " .. monitor_name)

    -- Check for saved profile
    local profile = Monitor.load_profile(monitor_name)
    if profile then
        Monitor.apply_profile(monitor_name, profile)
    end

    -- Restore workspace layout
    Monitor.restore_workspaces()

    -- Trigger UI refresh
    os.execute("pkill waybar")
    os.execute("waybar &")
end

-- Handle monitor disconnection
function Monitor.on_disconnect(monitor_name)
    log("Monitor disconnected: " .. monitor_name)

    -- Fold workspaces to remaining monitors
    Monitor.fold_workspaces(monitor_name)

    -- Save current state
    Monitor.save_state()
end

-- Load monitor profile from config
function Monitor.load_profile(monitor_name)
    local profile_file = os.getenv("HOME") ..
        "/.dotfiles/state/monitors/" .. monitor_name .. ".json"

    local handle = io.open(profile_file)
    if not handle then return nil end

    local content = handle:read("*a")
    handle:close()

    return content
end

-- Apply monitor profile (resolution, position, refresh rate)
function Monitor.apply_profile(monitor_name, profile)
    -- Extract resolution, position, scale from profile
    -- Apply via hyprctl dispatch monitor command
    os.execute("hyprctl dispatch monitor ...")
end

-- Restore workspace layouts for this monitor
function Monitor.restore_workspaces()
    local state_file = os.getenv("HOME") .. "/.dotfiles/state/workspaces.json"

    local handle = io.open(state_file)
    if not handle then return end

    local state = handle:read("*a")
    handle:close()

    -- Restore each workspace's layout and windows
    -- Implementation details omitted for brevity
end

-- Intelligently fold workspaces when monitor disconnects
function Monitor.fold_workspaces(disconnected_monitor)
    -- Move workspaces from disconnected monitor to remaining ones
    -- Preserve window arrangement where possible
end

-- Save current monitor state to disk
function Monitor.save_state()
    local monitors = Monitor.get_topology()
    local state_file = os.getenv("HOME") .. "/.dotfiles/state/monitors.json"

    local handle = io.open(state_file, "w")
    if handle then
        handle:write(monitors)
        handle:close()
    end
end

-- Navigate focus between monitors
function Monitor.navigate(direction)
    local next_monitor = Monitor.get_next_monitor(direction)
    if next_monitor then
        os.execute("hyprctl dispatch focusmonitor " .. next_monitor)
    end
end

-- Get next monitor in given direction
function Monitor.get_next_monitor(direction)
    -- Logic to determine next monitor based on physical layout
    local topology = Monitor.detect_roles()

    if direction == "left" then
        return topology.primary.name
    elseif direction == "right" then
        return topology.secondary.name or topology.tertiary.name
    end
end

return Monitor
