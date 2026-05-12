-- ~/.dotfiles/scripts/internal/config-generator.lua
-- Runtime configuration generation from templates

local ConfigGenerator = {}

-- Load and compile configuration template
function ConfigGenerator.generate_hyprland_config()
    log("Generating Hyprland configuration...")

    -- Load template
    local template = ConfigGenerator.load_template("hyprland.template.conf")
    if not template then
        error("Template not found")
        return false
    end

    -- Gather context data
    local context = {
        monitors = ConfigGenerator.get_monitor_config(),
        theme = ConfigGenerator.get_theme_colors(),
        system = ConfigGenerator.get_system_info(),
        user_settings = ConfigGenerator.load_user_settings(),
    }

    -- Render template
    local config = ConfigGenerator.render_template(template, context)

    -- Write output
    local output_path = os.getenv("HOME") .. "/.dotfiles/runtime/gen/hyprland.conf"
    ConfigGenerator.write_config(output_path, config)

    log("Hyprland config generated")
    return true
end

-- Load Jinja2 template
function ConfigGenerator.load_template(template_name)
    local path = os.getenv("HOME") .. "/.dotfiles/templates/" .. template_name

    local handle = io.open(path)
    if not handle then
        error("Template not found: " .. path)
        return nil
    end

    local content = handle:read("*a")
    handle:close()

    return content
end

-- Get monitor configuration
function ConfigGenerator.get_monitor_config()
    local handle = io.popen("hyprctl monitors -j")
    if not handle then return {} end

    local monitors = handle:read("*a")
    handle:close()

    -- Parse JSON monitors into config format
    -- Example:
    -- monitors = {
    --     {name="DP-1", res="1920x1080", hz=120, x=0, y=0},
    --     {name="HDMI-1", res="1920x1080", hz=60, x=1920, y=0},
    -- }

    return {}
end

-- Get current theme colors
function ConfigGenerator.get_theme_colors()
    local color_file = os.getenv("HOME") .. "/.dotfiles/runtime/theme-colors.lua"

    local handle = io.open(color_file)
    if not handle then return {} end

    local colors = handle:read("*a")
    handle:close()

    -- Load Lua color definitions
    return dofile(color_file) or {}
end

-- Get system information
function ConfigGenerator.get_system_info()
    return {
        hostname = os.execute("hostname") or "localhost",
        profile = os.getenv("HYPRLAND_PROFILE") or "laptop",
        gpu = ConfigGenerator.detect_gpu(),
        display_scale = os.getenv("SCALE") or "1.0",
    }
end

-- Load user settings override
function ConfigGenerator.load_user_settings()
    local path = os.getenv("HOME") .. "/.dotfiles/profile.env"

    local settings = {}
    local handle = io.open(path)
    if not handle then return settings end

    for line in handle:lines() do
        if not line:match("^#") and line:match("=") then
            local key, value = line:match("^([^=]+)=(.*)$")
            if key then
                settings[key:gsub("^%s*(.-)%s*$", "%1")] =
                    value:gsub("^%s*(.-)%s*$", "%1")
            end
        end
    end

    handle:close()
    return settings
end

-- Detect GPU (for optimizations)
function ConfigGenerator.detect_gpu()
    local handle = io.popen("lspci | grep -i vga")
    if not handle then return "unknown" end

    local result = handle:read("*a"):lower()
    handle:close()

    if string.find(result, "nvidia") then
        return "nvidia"
    elseif string.find(result, "amd") or string.find(result, "radeon") then
        return "amd"
    elseif string.find(result, "intel") then
        return "intel"
    else
        return "unknown"
    end
end

-- Render Jinja2-like template with Lua context
function ConfigGenerator.render_template(template, context)
    -- Simple template rendering (would use proper Jinja2 in production)

    local output = template

    -- Replace {{ variable }} patterns
    for key, value in pairs(context) do
        if type(value) == "table" then
            -- Handle nested tables
            for subkey, subvalue in pairs(value) do
                output = output:gsub("{{%s*" .. key .. "%." .. subkey .. "%s*}}",
                    tostring(subvalue))
            end
        else
            output = output:gsub("{{%s*" .. key .. "%s*}}", tostring(value))
        end
    end

    -- Handle conditionals: {% if condition %} ... {% endif %}
    -- (simplified implementation)

    return output
end

-- Write generated config to file
function ConfigGenerator.write_config(path, content)
    -- Create directory if needed
    os.execute("mkdir -p '" .. path:match("(.*/)[^/]*$") .. "'")

    local handle = io.open(path, "w")
    if not handle then
        error("Cannot write config: " .. path)
        return false
    end

    handle:write(content)
    handle:close()

    -- Set permissions
    os.execute("chmod 644 '" .. path .. "'")

    return true
end

-- Generate all runtime configs
function ConfigGenerator.generate_all()
    log("Generating all runtime configurations...")

    ConfigGenerator.generate_hyprland_config()
    ConfigGenerator.generate_waybar_config()
    ConfigGenerator.generate_swaync_config()
    ConfigGenerator.generate_kitty_config()
    ConfigGenerator.generate_rofi_config()

    log("All configurations generated")
end

-- Log function
local function log(msg)
    io.stderr:write("[ConfigGenerator] " .. msg .. "\n")
end

-- Entry point
if arg[1] == "generate-all" then
    ConfigGenerator.generate_all()
else
    ConfigGenerator.generate_all()
end

return ConfigGenerator
