-- Enhanced Controller - Per-world/per-shard container snapshots

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")

local ContainerCache = {}

local state = {
    loaded = false,
    loading = false,
    data = {
        version = Policy.CACHE_VERSION,
        scopes = {},
    },
    save_task = nil,
}

local function GetNow()
    return os.time()
end

local function GetTimestamp(value)
    return type(value) == "number" and value or 0
end

local function RoundPosition(value)
    return math.floor((value or 0) * 10 + 0.5) / 10
end

function ContainerCache.GetScopeId()
    local session_id = "unknown-session"
    if G.TheNet ~= nil and G.TheNet.GetSessionIdentifier ~= nil then
        local value = G.TheNet:GetSessionIdentifier()
        if value ~= nil and value ~= "" then
            session_id = tostring(value)
        end
    elseif G.TheWorld ~= nil and G.TheWorld.meta ~= nil and G.TheWorld.meta.session_identifier ~= nil then
        session_id = tostring(G.TheWorld.meta.session_identifier)
    end

    local shard_id = "unknown-shard"
    if G.TheShard ~= nil and G.TheShard.GetShardId ~= nil then
        shard_id = tostring(G.TheShard:GetShardId())
    end

    return session_id .. "|" .. shard_id
end

function ContainerCache.GetContainerKey(entity)
    if entity == nil or entity.Transform == nil then
        return nil
    end
    local x, _, z = entity.Transform:GetWorldPosition()
    return table.concat({
        tostring(entity.prefab or "container"),
        tostring(RoundPosition(x)),
        tostring(RoundPosition(z)),
    }, "|")
end

local function GetScope(create)
    local scope_id = ContainerCache.GetScopeId()
    local scope = state.data.scopes[scope_id]
    if scope == nil and create then
        scope = { containers = {}, updated_at = GetNow() }
        state.data.scopes[scope_id] = scope
    end
    return scope, scope_id
end

local function TrimOldest(records, maximum, get_timestamp)
    local entries = {}
    for key, value in pairs(records) do
        table.insert(entries, { key = key, timestamp = get_timestamp(value) })
    end
    if #entries <= maximum then
        return false
    end
    table.sort(entries, function(a, b) return a.timestamp < b.timestamp end)
    for index = 1, #entries - maximum do
        records[entries[index].key] = nil
    end
    return true
end

local function PruneData()
    local changed = false
    local cutoff = GetNow() - Policy.CACHE_TTL_SECONDS
    for scope_id, scope in pairs(state.data.scopes) do
        if type(scope) ~= "table" or GetTimestamp(scope.updated_at) < cutoff then
            state.data.scopes[scope_id] = nil
            changed = true
        else
            scope.containers = type(scope.containers) == "table" and scope.containers or {}
            for key, record in pairs(scope.containers) do
                if type(record) ~= "table" or GetTimestamp(record.updated_at) < cutoff then
                    scope.containers[key] = nil
                    changed = true
                end
            end
            changed = TrimOldest(scope.containers,
                Policy.CACHE_MAX_CONTAINERS_PER_SCOPE,
                function(record) return GetTimestamp(record.updated_at) end) or changed
        end
    end
    changed = TrimOldest(state.data.scopes, Policy.CACHE_MAX_SCOPES,
        function(scope) return GetTimestamp(scope.updated_at) end) or changed
    return changed
end

local function EncodeAndSave()
    state.save_task = nil
    if G.TheSim == nil or G.json == nil then
        return
    end

    PruneData()
    local ok, encoded = pcall(G.json.encode, state.data)
    if not ok then
        print("[Enhanced Controller] Failed to encode container cache")
        return
    end

    G.TheSim:SetPersistentString(Policy.CACHE_FILE_NAME, encoded, false, function() end)
end

local function QueueSave()
    if state.save_task ~= nil then
        return
    end
    if G.TheWorld ~= nil and G.TheWorld.DoTaskInTime ~= nil then
        state.save_task = G.TheWorld:DoTaskInTime(1, EncodeAndSave)
    else
        EncodeAndSave()
    end
end

local function MergeLoadedData(loaded)
    if type(loaded) ~= "table" or type(loaded.scopes) ~= "table" then
        return
    end
    for scope_id, loaded_scope in pairs(loaded.scopes) do
        if type(loaded_scope) ~= "table" then
            -- Pruning cannot inspect a scalar scope safely; ignore it here.
        elseif state.data.scopes[scope_id] == nil then
            state.data.scopes[scope_id] = loaded_scope
        elseif type(loaded_scope.containers) == "table" then
            local current = state.data.scopes[scope_id]
            current.containers = current.containers or {}
            for key, record in pairs(loaded_scope.containers) do
                local existing = current.containers[key]
                if type(record) == "table" and
                    (existing == nil or GetTimestamp(record.updated_at) >
                        GetTimestamp(existing.updated_at)) then
                    current.containers[key] = record
                end
            end
        end
    end
end

function ContainerCache.Initialize(callback)
    if state.loaded then
        if callback ~= nil then callback(true) end
        return
    elseif state.loading or G.TheSim == nil then
        if callback ~= nil then callback(false) end
        return
    end

    state.loading = true
    G.TheSim:GetPersistentString(Policy.CACHE_FILE_NAME, function(success, encoded)
        state.loading = false
        if success and encoded ~= nil and encoded ~= "" and G.json ~= nil then
            local ok, loaded = pcall(G.json.decode, encoded)
            if ok and type(loaded) == "table" and
                loaded.version == Policy.CACHE_VERSION then
                MergeLoadedData(loaded)
            end
        end
        local pruned = PruneData()
        state.loaded = true
        if pruned then QueueSave() end
        if callback ~= nil then callback(true) end
    end)
end

local function GetStackCount(item)
    local stackable = item.replica and item.replica.stackable
    return stackable ~= nil and stackable:StackSize() or 1
end

local function MakeItemCounts(container)
    local counts = {}
    local items = container:GetItems() or {}
    for _, item in pairs(items) do
        if Policy.IsCraftingItem(item) then
            counts[item.prefab] = (counts[item.prefab] or 0) + GetStackCount(item)
        end
    end
    return counts
end

local function CountsSignature(counts)
    local parts = {}
    for prefab, count in pairs(counts) do
        table.insert(parts, prefab .. ":" .. tostring(count))
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function ContainerCache.Snapshot(entity, player)
    if not Policy.IsStorageContainer(entity, player) then
        return false
    end

    local container = entity.replica.container
    if not container:IsOpenedBy(player) then
        return false
    end

    local key = ContainerCache.GetContainerKey(entity)
    if key == nil then
        return false
    end

    local x, _, z = entity.Transform:GetWorldPosition()
    local counts = MakeItemCounts(container)
    local signature = CountsSignature(counts)
    local scope = GetScope(true)
    local previous = scope.containers[key]
    local changed = previous == nil or previous.signature ~= signature or previous.guid ~= entity.GUID
    local now = GetNow()
    local should_refresh_timestamp = previous == nil or
        GetTimestamp(previous.updated_at) < now - Policy.CACHE_TIMESTAMP_REFRESH_SECONDS

    scope.containers[key] = {
        guid = entity.GUID,
        prefab = entity.prefab,
        x = RoundPosition(x),
        z = RoundPosition(z),
        items = counts,
        signature = signature,
        updated_at = now,
    }
    scope.updated_at = now

    if changed or should_refresh_timestamp then
        QueueSave()
    end
    return changed
end

function ContainerCache.Get(entity)
    local key = ContainerCache.GetContainerKey(entity)
    local scope = GetScope(false)
    local record = scope ~= nil and key ~= nil and scope.containers[key] or nil
    if record ~= nil and GetTimestamp(record.updated_at) < GetNow() - Policy.CACHE_TTL_SECONDS then
        scope.containers[key] = nil
        QueueSave()
        return nil
    end
    if record ~= nil and record.guid ~= nil and entity ~= nil and
        entity.GUID ~= nil and record.guid ~= entity.GUID then
        scope.containers[key] = nil
        QueueSave()
        return nil
    end
    return record
end

function ContainerCache.GetCurrentScopeRecords()
    local scope = GetScope(false)
    return scope ~= nil and scope.containers or {}
end

function ContainerCache.UpdateOpenContainers(player)
    local inventory = player and player.replica and player.replica.inventory
    local open = inventory and inventory:GetOpenContainers()
    local changed = false
    if open ~= nil then
        for entity in pairs(open) do
            changed = ContainerCache.Snapshot(entity, player) or changed
        end
    end
    return changed
end

function ContainerCache.Prune()
    local changed = PruneData()
    if changed then QueueSave() end
    return changed
end

-- Test support: resets runtime state without touching the persistent file.
function ContainerCache._ResetForTests()
    state.loaded = true
    state.loading = false
    state.save_task = nil
    state.data = { version = Policy.CACHE_VERSION, scopes = {} }
end

return ContainerCache
