-- Enhanced Controller - Read-only player and favorite markers on the map

local G = require("dst-controller/global")
local PlayerService = require("dst-controller/locations/player-service")
local FavoritesStore = require("dst-controller/locations/favorites-store")

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local MapVisualizer = {}

local current_mapscreen = nil
local decorations = {}
local subscriptions_installed = false

local function WorldPosToScreenPos(wx, wz)
    if current_mapscreen == nil or current_mapscreen.minimap == nil then
        return nil, nil
    end
    local width, height = G.TheSim:GetScreenSize()
    local mx, my = current_mapscreen.minimap:WorldPosToMapPos(wx, wz, 0)
    return mx * width * 0.5, my * height * 0.5
end

local function AddMarker(kind, name, x, z, colour)
    if current_mapscreen == nil or
        current_mapscreen.decorationrootstatic == nil then
        return
    end
    local sx, sy = WorldPosToScreenPos(x, z)
    if sx == nil then
        return
    end

    local root = current_mapscreen.decorationrootstatic:AddChild(
        Widget("enhanced_location_" .. kind))
    root:SetPosition(sx, sy)
    root:SetClickable(false)

    local icon = root:AddChild(Image("images/global.xml", "square.tex"))
    icon:ScaleToSize(kind == "favorite" and 13 or 15,
        kind == "favorite" and 13 or 15)
    icon:SetClickable(false)
    if kind == "favorite" then
        icon:SetTint(1, 0.72, 0.1, 0.95)
        icon:SetRotation(45)
    else
        local tint = type(colour) == "table" and colour or { 0.2, 0.85, 1, 1 }
        icon:SetTint(tint[1] or 0.2, tint[2] or 0.85,
            tint[3] or 1, tint[4] or 1)
    end

    local label = root:AddChild(Text(
        G.CHATFONT_OUTLINE or G.BODYTEXTFONT, 18, tostring(name or ""),
        kind == "favorite" and { 1, 0.85, 0.35, 1 } or
            { 0.9, 1, 1, 1 }))
    label:SetTruncatedString(tostring(name or ""), 180, 30, true)
    label:SetPosition(0, 19)
    label:SetClickable(false)

    decorations[#decorations + 1] = {
        widget = root,
        wx = x,
        wz = z,
    }
end

function MapVisualizer.Clear()
    for _, decoration in ipairs(decorations) do
        if decoration.widget ~= nil and decoration.widget.inst:IsValid() then
            decoration.widget:Kill()
        end
    end
    decorations = {}
end

function MapVisualizer.Refresh()
    MapVisualizer.Clear()
    if current_mapscreen == nil then
        return
    end
    for _, player in ipairs(PlayerService.GetCurrentShardPositions()) do
        AddMarker("player", player.name, player.x, player.z, player.colour)
    end
    for _, favorite in ipairs(FavoritesStore.GetCurrentShard()) do
        AddMarker("favorite", favorite.name, favorite.x, favorite.z)
    end
end

function MapVisualizer.UpdateDecorations()
    if current_mapscreen == nil or current_mapscreen.minimap == nil then
        return
    end
    for _, decoration in ipairs(decorations) do
        if decoration.widget ~= nil and decoration.widget.inst:IsValid() then
            local sx, sy = WorldPosToScreenPos(decoration.wx, decoration.wz)
            if sx ~= nil then
                decoration.widget:SetPosition(sx, sy)
            end
        end
    end
end

function MapVisualizer.SetMapScreen(mapscreen)
    if mapscreen == current_mapscreen then
        return
    end
    MapVisualizer.Clear()
    current_mapscreen = mapscreen
    if mapscreen ~= nil then
        MapVisualizer.Refresh()
    end
end

function MapVisualizer.InstallSubscriptions()
    if subscriptions_installed then
        return
    end
    subscriptions_installed = true
    PlayerService.Subscribe(MapVisualizer.Refresh)
    FavoritesStore.Subscribe(MapVisualizer.Refresh)
end

return MapVisualizer
