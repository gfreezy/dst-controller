-- Wormhole Tracker - Core Module
-- Tracks wormhole connections by recording entry/exit pairs
-- Since teleporter component is server-only, we learn connections through actual usage

local G = require("dst-controller/global")

local WormholeTracker = {}

-- Internal state
local wormhole_data = {
    pairs = {},           -- {[pos_key] = pos_key} - bidirectional mapping
    pending_entry = nil,  -- Entry position key waiting for exit
    pending_entry_time = nil, -- When the entry was recorded
}

-- Config
local ENTRY_TIMEOUT = 10  -- Seconds to wait for exit after entry
local SEARCH_RADIUS = 6   -- Radius to search for nearby wormhole on exit

-- Generate a unique key for world (using session identifier)
local function GetWorldKey()
    if G.TheNet and G.TheNet.GetSessionIdentifier then
        local session = G.TheNet:GetSessionIdentifier()
        if session and session ~= "" then
            return session
        end
    end
    return "unknown_world"
end

-- Generate a position key for storage
local function PosToKey(x, z)
    -- Round to integer to handle minor position differences
    return string.format("%.0f_%.0f", math.floor(x + 0.5), math.floor(z + 0.5))
end

-- Parse position key back to coordinates
local function KeyToPos(key)
    local x, z = key:match("([%-?%d]+)_([%-?%d]+)")
    if x and z then
        return tonumber(x), tonumber(z)
    end
    return nil, nil
end

-- Get persistent filename for current world
local function GetFilename()
    local world_key = GetWorldKey()
    -- Sanitize world key for filename
    world_key = world_key:gsub("[^%w_%-]", "_")
    return "wormhole_pairs_" .. world_key .. ".json"
end

-- Save pairs to persistent storage
function WormholeTracker.Save()
    if not wormhole_data.pairs or not next(wormhole_data.pairs) then
        return
    end

    local filename = GetFilename()
    local success, json_str = pcall(G.json.encode, wormhole_data.pairs)

    if success and json_str then
        G.TheSim:SetPersistentString(filename, json_str, false, function()
            print("[WormholeTracker] Saved " .. WormholeTracker.GetPairCount() .. " connections to " .. filename)
        end)
    else
        print("[WormholeTracker] Failed to encode wormhole data")
    end
end

-- Load pairs from persistent storage
function WormholeTracker.Load(callback)
    local filename = GetFilename()

    G.TheSim:GetPersistentString(filename, function(success, data)
        if success and data and data ~= "" then
            local ok, pairs = pcall(G.json.decode, data)
            if ok and type(pairs) == "table" then
                wormhole_data.pairs = pairs
                print("[WormholeTracker] Loaded " .. WormholeTracker.GetPairCount() .. " connections from " .. filename)
            else
                print("[WormholeTracker] Failed to decode saved data")
                wormhole_data.pairs = {}
            end
        else
            print("[WormholeTracker] No saved wormhole data found for this world")
            wormhole_data.pairs = {}
        end

        if callback then
            callback(wormhole_data.pairs)
        end
    end)
end

-- Record entry into a wormhole
function WormholeTracker.OnEnterWormhole(wormhole)
    if not wormhole or not wormhole:IsValid() then
        return
    end

    local x, _, z = wormhole.Transform:GetWorldPosition()
    local new_entry = PosToKey(x, z)
    local current_time = G.GetTime and G.GetTime() or os.time()

    -- Deduplicate: ignore if same entry within 2 seconds
    if wormhole_data.pending_entry == new_entry and
       wormhole_data.pending_entry_time and
       (current_time - wormhole_data.pending_entry_time) < 2 then
        return
    end

    wormhole_data.pending_entry = new_entry
    wormhole_data.pending_entry_time = current_time
    wormhole_data.entry_pos = {x = x, z = z}

    print("[WormholeTracker] Entering wormhole at " .. wormhole_data.pending_entry)

    -- Start a timer to detect exit by position change
    WormholeTracker.StartExitDetection()
end

-- Detect exit by checking if player moved far from entry
function WormholeTracker.StartExitDetection()
    if wormhole_data.exit_task then
        wormhole_data.exit_task:Cancel()
    end

    local check_count = 0
    local max_checks = 20  -- Check for up to 10 seconds (20 * 0.5s)

    local function CheckForExit()
        check_count = check_count + 1

        if not wormhole_data.pending_entry or not wormhole_data.entry_pos then
            return
        end

        local player = G.ThePlayer
        if not player or not player:IsValid() then
            return
        end

        local px, _, pz = player.Transform:GetWorldPosition()
        local entry = wormhole_data.entry_pos
        local dist = math.sqrt((px - entry.x)^2 + (pz - entry.z)^2)

        -- If player moved more than 50 units, they likely teleported
        if dist > 50 then
            print("[WormholeTracker] Position change detected! Distance: " .. string.format("%.1f", dist))
            WormholeTracker.OnExitWormhole(player)
            return
        end

        -- Continue checking if not exceeded max
        if check_count < max_checks then
            wormhole_data.exit_task = player:DoTaskInTime(0.5, CheckForExit)
        else
            print("[WormholeTracker] Exit detection timed out")
            wormhole_data.pending_entry = nil
            wormhole_data.entry_pos = nil
        end
    end

    -- Start checking after a short delay
    if G.ThePlayer then
        wormhole_data.exit_task = G.ThePlayer:DoTaskInTime(0.5, CheckForExit)
    end
end

-- Record exit from a wormhole (called on wormholespit event)
function WormholeTracker.OnExitWormhole(player)
    if not wormhole_data.pending_entry then
        return
    end

    -- Helper to clean up state
    local function CleanupState()
        wormhole_data.pending_entry = nil
        wormhole_data.pending_entry_time = nil
        wormhole_data.entry_pos = nil
        if wormhole_data.exit_task then
            wormhole_data.exit_task:Cancel()
            wormhole_data.exit_task = nil
        end
    end

    -- Check timeout
    local current_time = G.GetTime and G.GetTime() or os.time()
    if wormhole_data.pending_entry_time and
       (current_time - wormhole_data.pending_entry_time) > ENTRY_TIMEOUT then
        print("[WormholeTracker] Entry timed out, ignoring exit")
        CleanupState()
        return
    end

    if not player or not player:IsValid() then
        CleanupState()
        return
    end

    -- Find nearby wormhole (exit point)
    local x, y, z = player.Transform:GetWorldPosition()
    local nearby = G.TheSim:FindEntities(x, y, z, SEARCH_RADIUS, {"wormhole"})

    if nearby and #nearby > 0 then
        local exit_wormhole = nearby[1]
        local ex, _, ez = exit_wormhole.Transform:GetWorldPosition()
        local exit_key = PosToKey(ex, ez)

        -- Only record if entry and exit are different
        if exit_key ~= wormhole_data.pending_entry then
            -- Store bidirectional connection
            wormhole_data.pairs[wormhole_data.pending_entry] = exit_key
            wormhole_data.pairs[exit_key] = wormhole_data.pending_entry

            print("[WormholeTracker] Recorded connection: " .. wormhole_data.pending_entry .. " <-> " .. exit_key)

            -- Save to file
            WormholeTracker.Save()
        end
    else
        print("[WormholeTracker] No wormhole found near exit point")
    end

    CleanupState()
end

-- Get the paired wormhole position for a given wormhole
---@param wormhole table The wormhole entity
---@return number|nil x, number|nil z The paired wormhole's position, or nil if unknown
function WormholeTracker.GetPairedPosition(wormhole)
    if not wormhole or not wormhole:IsValid() then
        return nil, nil
    end

    local x, _, z = wormhole.Transform:GetWorldPosition()
    local key = PosToKey(x, z)
    local paired_key = wormhole_data.pairs[key]

    if paired_key then
        return KeyToPos(paired_key)
    end

    return nil, nil
end

-- Check if a wormhole's connection is known
---@param wormhole table The wormhole entity
---@return boolean
function WormholeTracker.IsConnectionKnown(wormhole)
    if not wormhole or not wormhole:IsValid() then
        return false
    end

    local x, _, z = wormhole.Transform:GetWorldPosition()
    local key = PosToKey(x, z)

    return wormhole_data.pairs[key] ~= nil
end

-- Get all known wormhole pairs
---@return table pairs A table of {entry_key = exit_key, ...}
function WormholeTracker.GetAllPairs()
    return wormhole_data.pairs
end

-- Get count of known connections (pairs, not individual wormholes)
---@return number
function WormholeTracker.GetPairCount()
    local count = 0
    local seen = {}

    for key, paired_key in pairs(wormhole_data.pairs) do
        local pair_id = key < paired_key and (key .. "|" .. paired_key) or (paired_key .. "|" .. key)
        if not seen[pair_id] then
            seen[pair_id] = true
            count = count + 1
        end
    end

    return count
end

-- Clear all recorded connections (for debugging or reset)
function WormholeTracker.Clear()
    wormhole_data.pairs = {}
    wormhole_data.pending_entry = nil
    wormhole_data.pending_entry_time = nil

    -- Delete the saved file
    local filename = GetFilename()
    G.TheSim:ErasePersistentString(filename, function()
        print("[WormholeTracker] Cleared all wormhole data")
    end)
end

-- Find wormhole entity at a given position
---@param x number
---@param z number
---@return table|nil wormhole entity or nil
function WormholeTracker.FindWormholeAt(x, z)
    if not G.TheSim then
        return nil
    end

    local nearby = G.TheSim:FindEntities(x, 0, z, 2, {"wormhole"})
    return nearby and nearby[1] or nil
end

-- Debug: Print all known connections
function WormholeTracker.DebugPrint()
    print("[WormholeTracker] Known connections:")
    local seen = {}

    for key, paired_key in pairs(wormhole_data.pairs) do
        local pair_id = key < paired_key and (key .. "|" .. paired_key) or (paired_key .. "|" .. key)
        if not seen[pair_id] then
            seen[pair_id] = true
            print("  " .. key .. " <-> " .. paired_key)
        end
    end

    if not next(seen) then
        print("  (none)")
    end
end

return WormholeTracker
