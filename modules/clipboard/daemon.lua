-- ~/.dotfiles/modules/clipboard/daemon.lua
-- Professional Wayland clipboard daemon

local ClipboardDaemon = {
    history_file = os.getenv("HOME") .. "/.dotfiles/state/clipboard-history.json",
    max_size = 100 * 1024 * 1024,  -- 100MB total
    max_items = 500,
    ttl_sensitive = 300,  -- 5 min for passwords
    sensitivity_keywords = {"password", "token", "secret", "key"},
}

-- Initialize daemon
function ClipboardDaemon.init()
    log("Initializing Clipboard Daemon")

    -- Load history from disk
    ClipboardDaemon.load_history()

    -- Start watching clipboard
    ClipboardDaemon.start_watch()

    log("Clipboard Daemon initialized")
end

-- Watch for clipboard changes
function ClipboardDaemon.start_watch()
    -- In production: implement proper watching with wl-paste
    -- This is simplified

    -- Watch text clipboard
    os.execute("wl-paste --watch " ..
        "lua ~/.dotfiles/modules/clipboard/on-change.lua text &")

    -- Watch image clipboard
    os.execute("wl-paste --type image --watch " ..
        "lua ~/.dotfiles/modules/clipboard/on-change.lua image &")
end

-- Store text in clipboard history
function ClipboardDaemon.store_text(content)
    if not content or content == "" then return end

    -- Check if sensitive
    local is_sensitive = ClipboardDaemon.is_sensitive(content)

    -- Create history entry
    local entry = {
        type = "text",
        content = content,
        timestamp = os.time(),
        size = string.len(content),
        hash = ClipboardDaemon.hash_content(content),
        sensitive = is_sensitive,
        ttl = is_sensitive and os.time() + ClipboardDaemon.ttl_sensitive or nil,
    }

    -- Store to history
    ClipboardDaemon.add_to_history(entry)

    -- Cleanup if needed
    ClipboardDaemon.cleanup_if_needed()
end

-- Store image in clipboard history
function ClipboardDaemon.store_image(image_path)
    -- Verify MIME type
    local mime_type = ClipboardDaemon.get_mime_type(image_path)
    if not mime_type:match("^image/") then
        return
    end

    -- Generate thumbnail
    local thumb_path = ClipboardDaemon.generate_thumbnail(image_path)

    -- Extract dominant colors
    local palette = ClipboardDaemon.extract_palette(image_path)

    -- Create history entry
    local entry = {
        type = "image",
        path = image_path,
        thumbnail = thumb_path,
        mime = mime_type,
        timestamp = os.time(),
        palette = palette,
        size = ClipboardDaemon.get_file_size(image_path),
        hash = ClipboardDaemon.hash_file(image_path),
    }

    -- Store
    ClipboardDaemon.add_to_history(entry)

    -- Cleanup
    ClipboardDaemon.cleanup_if_needed()
end

-- Get clipboard history with filtering
function ClipboardDaemon.get_history(filter_opts)
    local filter_opts = filter_opts or {}
    local results = {}

    -- Load history
    local history = ClipboardDaemon.load_history()

    -- Apply filters
    for i, entry in ipairs(history) do
        local match = true

        -- Filter by type
        if filter_opts.type and entry.type ~= filter_opts.type then
            match = false
        end

        -- Filter by query (fuzzy search for text)
        if filter_opts.query and entry.type == "text" then
            if not string.find(entry.content:lower(), filter_opts.query:lower()) then
                match = false
            end
        end

        -- Skip sensitive items
        if entry.sensitive and not filter_opts.include_sensitive then
            match = false
        end

        if match then
            table.insert(results, entry)
        end
    end

    -- Return limited number of results
    local limit = filter_opts.limit or 50
    return {table.unpack(results, 1, math.min(limit, #results))}
end

-- Check if content is sensitive (password, token, etc.)
function ClipboardDaemon.is_sensitive(content)
    for _, keyword in ipairs(ClipboardDaemon.sensitivity_keywords) do
        if string.find(content:lower(), keyword) then
            return true
        end
    end
    return false
end

-- Hash content for deduplication
function ClipboardDaemon.hash_content(content)
    -- Simple hash (would use proper SHA256 in production)
    return tostring(content:len())
end

-- Hash file for deduplication
function ClipboardDaemon.hash_file(path)
    local handle = io.popen("sha256sum '" .. path .. "'")
    if not handle then return nil end

    local result = handle:read("*a")
    handle:close()

    return result:match("^%x+")
end

-- Generate thumbnail from image
function ClipboardDaemon.generate_thumbnail(image_path)
    local thumb_dir = os.getenv("HOME") .. "/.dotfiles/state/cache/thumbnails"
    os.execute("mkdir -p '" .. thumb_dir .. "'")

    local thumb_path = thumb_dir .. "/" ..
        ClipboardDaemon.hash_file(image_path) .. ".png"

    -- Generate thumbnail with ImageMagick
    os.execute("convert '" .. image_path .. "' -thumbnail 100x100 '" .. thumb_path .. "'")

    return thumb_path
end

-- Extract dominant colors from image
function ClipboardDaemon.extract_palette(image_path)
    -- Use colorz or similar
    local handle = io.popen("colorz -n 5 '" .. image_path .. "' 2>/dev/null")
    if not handle then return {} end

    local result = handle:read("*a")
    handle:close()

    -- Parse and return colors
    return result
end

-- Get MIME type of file
function ClipboardDaemon.get_mime_type(path)
    local handle = io.popen("file --mime-type -b '" .. path .. "'")
    if not handle then return "" end

    local result = handle:read("*a"):gsub("\n", "")
    handle:close()

    return result
end

-- Get file size
function ClipboardDaemon.get_file_size(path)
    local handle = io.popen("stat -f%z '" .. path .. "' 2>/dev/null || stat -c%s '" .. path .. "'")
    if not handle then return 0 end

    local result = tonumber(handle:read("*a"))
    handle:close()

    return result or 0
end

-- Add entry to history
function ClipboardDaemon.add_to_history(entry)
    local history = ClipboardDaemon.load_history()

    -- Deduplicate
    for _, existing in ipairs(history) do
        if existing.hash == entry.hash then
            return  -- Already exists
        end
    end

    -- Add new entry
    table.insert(history, 1, entry)  -- Newest first

    -- Save
    ClipboardDaemon.save_history(history)
end

-- Load history from disk
function ClipboardDaemon.load_history()
    local handle = io.open(ClipboardDaemon.history_file)
    if not handle then return {} end

    local content = handle:read("*a")
    handle:close()

    -- Parse JSON (would use proper JSON lib)
    return {} -- Simplified
end

-- Save history to disk
function ClipboardDaemon.save_history(history)
    local handle = io.open(ClipboardDaemon.history_file, "w")
    if handle then
        -- Write JSON-serialized history
        handle:write("{}") -- Simplified
        handle:close()
    end
end

-- Cleanup old or sensitive items
function ClipboardDaemon.cleanup_if_needed()
    local history = ClipboardDaemon.load_history()
    local now = os.time()
    local total_size = 0
    local cleaned = {}

    -- Remove expired sensitive items
    for _, entry in ipairs(history) do
        if entry.ttl and entry.ttl < now then
            -- Skip (expired)
        elseif entry.type == "image" then
            total_size = total_size + entry.size
            if total_size <= ClipboardDaemon.max_size then
                table.insert(cleaned, entry)
            end
        else
            table.insert(cleaned, entry)
        end
    end

    -- Limit to max items
    if #cleaned > ClipboardDaemon.max_items then
        cleaned = {table.unpack(cleaned, 1, ClipboardDaemon.max_items)}
    end

    ClipboardDaemon.save_history(cleaned)
end

-- Log function
local function log(msg)
    io.stderr:write("[ClipboardDaemon] " .. msg .. "\n")
end

return ClipboardDaemon
