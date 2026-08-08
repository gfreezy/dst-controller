-- Resolves ActionQueue RB3's own configured queue key without duplicating that
-- setting in Enhanced Controller.

local G = require("dst-controller/global")
local InputHook = require("dst-controller/hooks/input-hook")

local ActionQueueConfig = {}

local WORKSHOP_MOD = "workshop-2873533916"
local cached_modname = nil
local searched = false

local function IsActionQueueInfo(modname, info)
    if modname == WORKSHOP_MOD then
        return true
    end
    local name = type(info) == "table" and tostring(info.name or ""):lower() or ""
    return name:find("actionqueue rb3", 1, true) ~= nil
end

local function FindModName()
    if searched then
        return cached_modname
    end
    searched = true

    local index = G.KnownModIndex
    if index == nil or type(index.GetModsToLoad) ~= "function" or
       type(index.GetModInfo) ~= "function" then
        return nil
    end

    local ok, modnames = pcall(index.GetModsToLoad, index, true)
    if not ok or type(modnames) ~= "table" then
        return nil
    end
    for _, modname in ipairs(modnames) do
        local info_ok, info = pcall(index.GetModInfo, index, modname)
        if info_ok and IsActionQueueInfo(modname, info) then
            cached_modname = modname
            break
        end
    end
    return cached_modname
end

local function ReadConfiguredKey()
    local modname = FindModName()
    local get_config = G.GetGlobal ~= nil and G.GetGlobal("GetModConfigData") or nil
    if modname == nil or type(get_config) ~= "function" then
        return nil
    end

    local ok, configured = pcall(get_config, "action_queue_key", modname, true)
    if not ok then
        return nil
    end
    if configured == false then
        return false
    end
    if type(configured) == "string" then
        configured = G[configured]
    end
    return type(configured) == "number" and configured or nil
end

function ActionQueueConfig.GetModifier()
    local key = ReadConfiguredKey()
    if key == false then
        return nil
    end
    if key ~= nil then
        return InputHook.GetModifierForKey(key)
    end
    return nil
end

function ActionQueueConfig._ResetForTests()
    cached_modname = nil
    searched = false
end

return ActionQueueConfig
