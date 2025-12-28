-- Wormhole Map Visualizer
-- Draws wormhole pair numbers on the map screen

local G = require("dst-controller/global")
local WormholeTracker = require("dst-controller/wormhole-tracker/core")

local WormholeMapVisualizer = {}

-- Internal state
local current_mapscreen = nil
local wormhole_decorations = {}
local is_enabled = true

-- Text style settings
local TEXT_FONT = G.NUMBERFONT or G.BODYTEXTFONT or "opensans"
local TEXT_SIZE = 28
local TEXT_COLOR = {1, 1, 0, 1}  -- Yellow

-- World position to screen position conversion
local function WorldPosToScreenPos(mapscreen, wx, wz)
    if not mapscreen or not mapscreen.minimap then
        return nil, nil
    end

    local w, h = G.TheSim:GetScreenSize()
    local mx, my = mapscreen.minimap:WorldPosToMapPos(wx, wz, 0)
    return mx * w * 0.5, my * h * 0.5
end

-- Parse position key to coordinates
local function KeyToPos(key)
    local x, z = key:match("([%-?%d]+)_([%-?%d]+)")
    if x and z then
        return tonumber(x), tonumber(z)
    end
    return nil, nil
end

-- Clear all wormhole decorations
function WormholeMapVisualizer.ClearDecorations()
    for guid, decor_data in pairs(wormhole_decorations) do
        if decor_data.widget and decor_data.widget.inst and decor_data.widget.inst:IsValid() then
            decor_data.widget:Kill()
        end
    end
    wormhole_decorations = {}
end

-- Draw a number label at a wormhole position
local function DrawNumberLabel(mapscreen, wx, wz, number, label_id)
    local Text = require("widgets/text")
    local zoom = mapscreen.minimap:GetZoom()

    -- Scale text size based on zoom (smaller when zoomed out)
    local scale = math.max(0.5, math.min(1.5, 1.0 / zoom))

    local sx, sy = WorldPosToScreenPos(mapscreen, wx, wz)

    if sx and sy then
        local label = mapscreen.decorationrootstatic:AddChild(Text(TEXT_FONT, TEXT_SIZE, tostring(number)))
        label:SetColour(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], TEXT_COLOR[4])
        -- Offset slightly to not overlap with wormhole icon
        label:SetPosition(sx + 15, sy + 15)
        label:SetScale(scale, scale, 1)

        local guid = string.format("wormhole_label_%s", label_id)
        wormhole_decorations[guid] = {
            widget = label,
            wx = wx,
            wz = wz,
            is_label = true,
        }
    end
end

-- Draw all wormhole connections
function WormholeMapVisualizer.DrawConnections()
    if not current_mapscreen or not current_mapscreen.decorationrootstatic then
        return
    end

    if not is_enabled then
        return
    end

    -- Clear old decorations
    WormholeMapVisualizer.ClearDecorations()

    -- Get all known pairs
    local known_pairs = WormholeTracker.GetAllPairs()
    if not known_pairs or not next(known_pairs) then
        return
    end

    -- Assign numbers to each pair
    local pair_numbers = {}  -- {conn_id = number}
    local processed = {}     -- Track which keys we've already processed
    local current_number = 1

    for key, paired_key in pairs(known_pairs) do
        -- Create a unique connection ID (sorted to avoid duplicates)
        local conn_id = key < paired_key and (key .. "|" .. paired_key) or (paired_key .. "|" .. key)

        -- Assign number to this pair if not already assigned
        if not pair_numbers[conn_id] then
            pair_numbers[conn_id] = current_number
            current_number = current_number + 1
        end

        -- Draw number label for this wormhole (only once)
        if not processed[key] then
            processed[key] = true
            local x, z = KeyToPos(key)
            if x and z then
                DrawNumberLabel(current_mapscreen, x, z, pair_numbers[conn_id], key)
            end
        end

        -- Draw number label for paired wormhole (only once)
        if not processed[paired_key] then
            processed[paired_key] = true
            local x, z = KeyToPos(paired_key)
            if x and z then
                DrawNumberLabel(current_mapscreen, x, z, pair_numbers[conn_id], paired_key)
            end
        end
    end

    local count = 0
    for _ in pairs(pair_numbers) do count = count + 1 end
    if count > 0 then
        print("[WormholeMapVisualizer] Drew " .. count .. " wormhole pair number(s)")
    end
end

-- Update decoration positions and scales (called on map zoom/pan)
function WormholeMapVisualizer.UpdateDecorations()
    if not current_mapscreen or not current_mapscreen.minimap then
        return
    end

    local zoom = current_mapscreen.minimap:GetZoom()
    local scale = math.max(0.5, math.min(1.5, 1.0 / zoom))

    for guid, decor_data in pairs(wormhole_decorations) do
        if decor_data.widget and decor_data.widget.inst and decor_data.widget.inst:IsValid() then
            local sx, sy = WorldPosToScreenPos(current_mapscreen, decor_data.wx, decor_data.wz)
            if sx and sy then
                -- Offset slightly to not overlap with wormhole icon
                decor_data.widget:SetPosition(sx + 15, sy + 15)
                decor_data.widget:SetScale(scale, scale, 1)
            end
        end
    end
end

-- Set the current map screen
function WormholeMapVisualizer.SetMapScreen(mapscreen)
    current_mapscreen = mapscreen
end

-- Get the current map screen
function WormholeMapVisualizer.GetMapScreen()
    return current_mapscreen
end

-- Enable/disable visualization
function WormholeMapVisualizer.SetEnabled(enabled)
    is_enabled = enabled
    if not enabled then
        WormholeMapVisualizer.ClearDecorations()
    end
end

-- Check if visualization is enabled
function WormholeMapVisualizer.IsEnabled()
    return is_enabled
end

-- Toggle visualization
function WormholeMapVisualizer.Toggle()
    is_enabled = not is_enabled
    if is_enabled then
        WormholeMapVisualizer.DrawConnections()
    else
        WormholeMapVisualizer.ClearDecorations()
    end
    return is_enabled
end

return WormholeMapVisualizer
