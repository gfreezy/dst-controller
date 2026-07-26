-- Enhanced Controller - Persistent favorite world positions

local G = require("dst-controller/global")
local Scope = require("dst-controller/locations/scope")

local FavoritesStore = {}

local FILE_NAME = "enhanced_controller_favorite_locations.json"
local DATA_VERSION = 1

local state = {
    loaded = false,
    loading = false,
    callbacks = {},
    listeners = {},
    sequence = 0,
    data = { version = DATA_VERSION, worlds = {} },
}

local function Notify()
    for listener in pairs(state.listeners) do
        listener()
    end
end

local function NormalizeName(name)
    name = tostring(name or ""):gsub("[\r\n]", " ")
    name = name:match("^%s*(.-)%s*$") or ""
    return name
end

local function NormalizeData(data)
    if type(data) ~= "table" then
        return { version = DATA_VERSION, worlds = {} }
    end
    data.version = DATA_VERSION
    data.worlds = type(data.worlds) == "table" and data.worlds or {}
    return data
end

local function CurrentShard(create)
    local session_id = Scope.GetSessionId()
    local shard_id = Scope.GetShardId()
    local world = state.data.worlds[session_id]
    if world == nil and create then
        world = { shards = {} }
        state.data.worlds[session_id] = world
    end
    if world == nil then
        return nil
    end
    world.shards = type(world.shards) == "table" and world.shards or {}
    local shard = world.shards[shard_id]
    if shard == nil and create then
        shard = {
            world_type = Scope.GetWorldType(),
            locations = {},
        }
        world.shards[shard_id] = shard
    end
    if shard ~= nil then
        shard.world_type = shard.world_type or Scope.GetWorldType()
        shard.locations = type(shard.locations) == "table" and
            shard.locations or {}
    end
    return shard
end

local function FindInCurrentWorld(id)
    local world = state.data.worlds[Scope.GetSessionId()]
    for _, shard in pairs(world and world.shards or {}) do
        for index, entry in ipairs(shard.locations or {}) do
            if entry.id == id then
                return shard, index, entry
            end
        end
    end
    return nil, nil, nil
end

local function FinishLoad(success, encoded)
    if success and type(encoded) == "string" and encoded ~= "" then
        local ok, decoded = pcall(G.json.decode, encoded)
        state.data = ok and NormalizeData(decoded) or
            { version = DATA_VERSION, worlds = {} }
    else
        state.data = { version = DATA_VERSION, worlds = {} }
    end
    state.loaded = true
    state.loading = false
    local callbacks = state.callbacks
    state.callbacks = {}
    for _, callback in ipairs(callbacks) do
        callback(state.data)
    end
    Notify()
end

function FavoritesStore.Load(callback)
    if state.loaded then
        if callback ~= nil then
            callback(state.data)
        end
        return
    end
    if callback ~= nil then
        state.callbacks[#state.callbacks + 1] = callback
    end
    if state.loading then
        return
    end
    state.loading = true
    G.TheSim:GetPersistentString(FILE_NAME, FinishLoad)
end

function FavoritesStore.Save(callback)
    if not state.loaded then
        if callback ~= nil then
            callback(false)
        end
        return false
    end
    local ok, encoded = pcall(G.json.encode, state.data)
    if not ok then
        if callback ~= nil then
            callback(false)
        end
        return false
    end
    G.TheSim:SetPersistentString(FILE_NAME, encoded, false, function()
        if callback ~= nil then
            callback(true)
        end
    end)
    return true
end

function FavoritesStore.IsLoaded()
    return state.loaded
end

function FavoritesStore.AddCurrent(name)
    local player = G.ThePlayer
    name = NormalizeName(name)
    if not state.loaded or name == "" or player == nil or
        not player:IsValid() or player.Transform == nil then
        return nil
    end
    local x, _, z = player.Transform:GetWorldPosition()
    state.sequence = state.sequence + 1
    local now = os.time()
    local entry = {
        id = string.format("location_%d_%d", now, state.sequence),
        name = name,
        x = x,
        z = z,
        created_at = now,
    }
    local shard = CurrentShard(true)
    shard.locations[#shard.locations + 1] = entry
    FavoritesStore.Save()
    Notify()
    return entry
end

function FavoritesStore.Rename(id, name)
    name = NormalizeName(name)
    if not state.loaded or name == "" then
        return false
    end
    local _, _, entry = FindInCurrentWorld(id)
    if entry ~= nil then
        entry.name = name
        FavoritesStore.Save()
        Notify()
        return true
    end
    return false
end

function FavoritesStore.Remove(id)
    if not state.loaded then
        return false
    end
    local shard, index = FindInCurrentWorld(id)
    if shard ~= nil then
        table.remove(shard.locations, index)
        FavoritesStore.Save()
        Notify()
        return true
    end
    return false
end

function FavoritesStore.GetCurrentShard()
    local result = {}
    local shard = state.loaded and CurrentShard(false) or nil
    for _, entry in ipairs(shard and shard.locations or {}) do
        result[#result + 1] = {
            id = entry.id,
            name = entry.name,
            x = entry.x,
            z = entry.z,
            created_at = entry.created_at,
            shard_id = Scope.GetShardId(),
            world_type = shard.world_type,
            current_shard = true,
        }
    end
    return result
end

function FavoritesStore.GetCurrentWorld()
    local result = {}
    local world = state.loaded and state.data.worlds[Scope.GetSessionId()] or nil
    for shard_id, shard in pairs(world and world.shards or {}) do
        for _, entry in ipairs(shard.locations or {}) do
            result[#result + 1] = {
                id = entry.id,
                name = entry.name,
                x = entry.x,
                z = entry.z,
                created_at = entry.created_at,
                shard_id = shard_id,
                world_type = shard.world_type or shard_id,
                current_shard = Scope.IsCurrentShard(shard_id),
            }
        end
    end
    table.sort(result, function(a, b)
        if a.current_shard ~= b.current_shard then
            return a.current_shard
        end
        return (a.created_at or 0) > (b.created_at or 0)
    end)
    return result
end

function FavoritesStore.Subscribe(listener)
    state.listeners[listener] = true
    return function()
        state.listeners[listener] = nil
    end
end

function FavoritesStore._ResetForTests()
    state.loaded = false
    state.loading = false
    state.callbacks = {}
    state.listeners = {}
    state.sequence = 0
    state.data = { version = DATA_VERSION, worlds = {} }
end

FavoritesStore.FILE_NAME = FILE_NAME

return FavoritesStore
