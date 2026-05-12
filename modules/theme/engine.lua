-- ~/.dotfiles/modules/theme/engine.lua
-- Dynamic theme compilation and live reload

local ThemeEngine = {}

ThemeEngine.current_theme = nil
ThemeEngine.current_wallpaper = nil
ThemeEngine.modes = {
    light = false,
    dark = true,
    auto = "system",
}

-- Compile theme from definition
function ThemeEngine.compile(theme_name, wallpaper_path)
    log("Compiling theme: " .. theme_name)

    -- Load theme definition
    local theme_def = ThemeEngine.load_definition(theme_name)
    if not theme_def then
        error("Theme not found: " .. theme_name)
        return false
    end

    -- Extract palette from wallpaper if specified
    if wallpaper_path then
        local palette = ThemeEngine.extract_palette(wallpaper_path)
        if palette then
            theme_def.palette = palette
        end
    end

    -- Generate all config files
    ThemeEngine.generate_configs(theme_name, theme_def)

    -- Update theme state
    ThemeEngine.current_theme = theme_name
    ThemeEngine.current_wallpaper = wallpaper_path

    log("Theme compiled successfully: " .. theme_name)
    return true
end

-- Load theme definition from YAML
function ThemeEngine.load_definition(theme_name)
    local def_file = os.getenv("HOME") ..
        "/.dotfiles/themes/" .. theme_name .. "/definition.yaml"

    -- In production: use proper YAML parser
    -- Simplified here - would parse YAML file

    local handle = io.open(def_file)
    if not handle then return nil end

    local content = handle:read("*a")
    handle:close()

    return content
end

-- Extract color palette from wallpaper
function ThemeEngine.extract_palette(wallpaper_path)
    -- Call external tool: colorz, wal, or similar
    -- Returns dominant colors from image

    local cmd = "colorz -n 5 '" .. wallpaper_path .. "' 2>/dev/null"
    local handle = io.popen(cmd)
    if not handle then return nil end

    local result = handle:read("*a")
    handle:close()

    -- Parse color output into palette
    return result
end

-- Generate config files from theme
function ThemeEngine.generate_configs(theme_name, theme_def)
    local runtime_dir = os.getenv("HOME") .. "/.dotfiles/runtime"

    -- Generate Waybar CSS
    ThemeEngine.generate_waybar_css(runtime_dir, theme_def)

    -- Generate SwayNC CSS
    ThemeEngine.generate_swaync_css(runtime_dir, theme_def)

    -- Generate Kitty colors
    ThemeEngine.generate_kitty_colors(runtime_dir, theme_def)

    -- Generate Rofi theme
    ThemeEngine.generate_rofi_theme(runtime_dir, theme_def)

    -- Generate GTK settings
    ThemeEngine.generate_gtk_settings(runtime_dir, theme_def)

    -- Save Lua color module
    ThemeEngine.generate_lua_colors(runtime_dir, theme_def)
end

-- Generate Waybar CSS with theme colors
function ThemeEngine.generate_waybar_css(runtime_dir, theme_def)
    local output = runtime_dir .. "/waybar/style.css"

    local css = [[
/* Generated Waybar CSS */
@define-color base ]] .. theme_def.colors.base .. [[;
@define-color surface ]] .. theme_def.colors.surface .. [[;
@define-color text ]] .. theme_def.colors.text .. [[;
@define-color accent ]] .. theme_def.colors.accent .. [[;

window#waybar {
    background: @base;
    color: @text;
}

#workspaces button.active {
    color: @accent;
    border: 1px solid @accent;
}
]]

    local handle = io.open(output, "w")
    if handle then
        handle:write(css)
        handle:close()
    end
end

-- Generate Kitty color scheme
function ThemeEngine.generate_kitty_colors(runtime_dir, theme_def)
    local output = runtime_dir .. "/kitty/colors.conf"

    local conf = "# Kitty colors\n"
    conf = conf .. "foreground " .. theme_def.colors.text .. "\n"
    conf = conf .. "background " .. theme_def.colors.base .. "\n"

    local handle = io.open(output, "w")
    if handle then
        handle:write(conf)
        handle:close()
    end
end

-- Generate Lua color module
function ThemeEngine.generate_lua_colors(runtime_dir, theme_def)
    local output = runtime_dir .. "/theme-colors.lua"

    local lua = "-- Generated theme colors\nreturn {\n"
    for name, color in pairs(theme_def.colors) do
        lua = lua .. "    " .. name .. " = '" .. color .. "',\n"
    end
    lua = lua .. "}\n"

    local handle = io.open(output, "w")
    if handle then
        handle:write(lua)
        handle:close()
    end
end

-- Generate other config files (simplified)
function ThemeEngine.generate_swaync_css(runtime_dir, theme_def)
    -- Similar to waybar
end

function ThemeEngine.generate_rofi_theme(runtime_dir, theme_def)
    -- Similar to waybar
end

function ThemeEngine.generate_gtk_settings(runtime_dir, theme_def)
    -- Generate GTK configuration
end

-- Live reload theme without logout
function ThemeEngine.reload()
    log("Reloading theme...")

    -- Reload Waybar
    os.execute("pkill waybar")
    os.execute("sleep 0.5")
    os.execute("waybar &")

    -- Reload SwayNC
    os.execute("pkill swaync")
    os.execute("sleep 0.5")
    os.execute("swaync &")

    -- Notify all Hyprland clients of color change
    os.execute("hyprctl notify 0 5000 'rgb(255, 200, 124)' 'Theme reloaded'")

    log("Theme reloaded successfully")
end

-- Set theme mode (light, dark, auto)
function ThemeEngine.set_mode(mode)
    if mode == "light" then
        ThemeEngine.compile(ThemeEngine.current_theme .. "-light")
    elseif mode == "dark" then
        ThemeEngine.compile(ThemeEngine.current_theme .. "-dark")
    elseif mode == "auto" then
        -- Detect system preference
        local is_dark = os.execute("gsettings get org.gnome.desktop.interface gtk-application-prefer-dark-theme") == "true"
        if is_dark then
            ThemeEngine.compile(ThemeEngine.current_theme .. "-dark")
        else
            ThemeEngine.compile(ThemeEngine.current_theme .. "-light")
        end
    end

    ThemeEngine.reload()
end

return ThemeEngine
