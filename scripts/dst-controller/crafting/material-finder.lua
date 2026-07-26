-- Enhanced Controller - Client-visible material and container discovery

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")
local ContainerCache = require("dst-controller/crafting/container-cache")

local Finder = {}

local function AddCount(counts, prefab, amount)
    counts[prefab] = (counts[prefab] or 0) + amount
end

function Finder.GetStackCount(item)
    local stackable = item and item.replica and item.replica.stackable
    return stackable ~= nil and stackable:StackSize() or 1
end

function Finder.GetMaxStack(item)
    local stackable = item and item.replica and item.replica.stackable
    return stackable ~= nil and stackable:MaxSize() or 1
end

local function AddContainerItems(result, container, owner_entity, allow_classified_fallback)
    if container == nil then
        return
    end
    for slot = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(slot)
        if item == nil and allow_classified_fallback and container.classified ~= nil and
            container.classified.GetItemInSlot ~= nil then
            item = container.classified:GetItemInSlot(slot)
        end
        if item ~= nil then
            table.insert(result, {
                item = item,
                prefab = item.prefab,
                count = Finder.GetStackCount(item),
                max_stack = Finder.GetMaxStack(item),
                container = container,
                container_entity = owner_entity,
                slot = slot,
            })
        end
    end
end

function Finder.GetPersonalItems(player)
    local result = {}
    local inventory = player and player.replica and player.replica.inventory
    if inventory == nil then
        return result
    end

    AddContainerItems(result, inventory, player)
    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil then
        -- Equipped side containers remain authoritative personal inventory even
        -- when their widget is closed; their classified is already owned by the
        -- local player.
        AddContainerItems(result, overflow, overflow.inst, true)
    end

    local active_item = inventory:GetActiveItem()
    if active_item ~= nil then
        table.insert(result, {
            item = active_item,
            prefab = active_item.prefab,
            count = Finder.GetStackCount(active_item),
            max_stack = Finder.GetMaxStack(active_item),
            container = inventory,
            container_entity = player,
            active = true,
        })
    end
    return result
end

function Finder.GetPersonalCounts(player)
    local counts = {}
    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        if Policy.IsCraftingItem(record.item) then
            AddCount(counts, record.prefab, record.count)
        end
    end
    return counts
end

function Finder.GetPersonalCount(player, prefab)
    local count = 0
    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        if record.prefab == prefab and Policy.IsCraftingItem(record.item) then
            count = count + record.count
        end
    end
    return count
end

local function DistanceSq(player, entity)
    if player.GetDistanceSqToInst ~= nil then
        return player:GetDistanceSqToInst(entity)
    end
    local px, _, pz = player.Transform:GetWorldPosition()
    local ex, _, ez = entity.Transform:GetWorldPosition()
    local dx, dz = px - ex, pz - ez
    return dx * dx + dz * dz
end

function Finder.FindNearbyEntities(player, radius)
    if player == nil or player.Transform == nil or G.TheSim == nil then
        return {}
    end
    local x, y, z = player.Transform:GetWorldPosition()
    return G.TheSim:FindEntities(x, y, z, radius or Policy.SEARCH_RADIUS, nil,
        { "INLIMBO", "NOCLICK", "FX", "DECOR" }) or {}
end

function Finder.FindNearbyContainers(player, radius)
    local containers = {}
    for _, entity in ipairs(Finder.FindNearbyEntities(player, radius)) do
        if Policy.IsStorageContainer(entity, player) then
            table.insert(containers, entity)
        end
    end
    table.sort(containers, function(a, b)
        return DistanceSq(player, a) < DistanceSq(player, b)
    end)
    return containers
end

function Finder.FindNearbyGroundItems(player, radius)
    local items = {}
    for _, entity in ipairs(Finder.FindNearbyEntities(player, radius)) do
        if (entity.replica == nil or entity.replica.container == nil) and
            Policy.IsGroundCraftingItem(entity, player) then
            table.insert(items, entity)
        end
    end
    table.sort(items, function(a, b)
        return DistanceSq(player, a) < DistanceSq(player, b)
    end)
    return items
end

function Finder.GetContainerItems(entity, player)
    local records = {}
    if not Policy.IsStorageContainer(entity, player) then
        return records
    end
    local container = entity.replica.container
    if not container:IsOpenedBy(player) then
        return records
    end
    AddContainerItems(records, container, entity)
    return records
end

local function AddRecordsToCounts(counts, records)
    for _, record in ipairs(records) do
        if Policy.IsCraftingItem(record.item) then
            AddCount(counts, record.prefab, record.count)
        end
    end
end

function Finder.BuildMenuStock(player, radius)
    local owned = Finder.GetPersonalCounts(player)
    local external = {}
    local max_stacks = {}
    local containers = Finder.FindNearbyContainers(player, radius)
    local unknown_containers = {}
    local cached_containers = {}

    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        max_stacks[record.prefab] = math.max(max_stacks[record.prefab] or 1, record.max_stack)
    end

    for _, item in ipairs(Finder.FindNearbyGroundItems(player, radius)) do
        AddCount(external, item.prefab, Finder.GetStackCount(item))
        max_stacks[item.prefab] = math.max(max_stacks[item.prefab] or 1, Finder.GetMaxStack(item))
    end

    for _, entity in ipairs(containers) do
        local container = entity.replica.container
        if container:IsOpenedBy(player) then
            local records = Finder.GetContainerItems(entity, player)
            AddRecordsToCounts(external, records)
            for _, record in ipairs(records) do
                max_stacks[record.prefab] = math.max(max_stacks[record.prefab] or 1, record.max_stack)
            end
        else
            local cached = ContainerCache.Get(entity)
            if cached == nil then
                table.insert(unknown_containers, entity)
            else
                table.insert(cached_containers, { entity = entity, record = cached })
                for prefab, count in pairs(cached.items or {}) do
                    AddCount(external, prefab, count)
                end
            end
        end
    end

    return {
        owned = owned,
        external = external,
        max_stacks = max_stacks,
        containers = containers,
        unknown_containers = unknown_containers,
        cached_containers = cached_containers,
    }
end

function Finder.BuildVerifiedSources(player, verified_containers, radius)
    local sources = {
        ground = {},
        containers = {},
        counts = {},
        max_stacks = {},
    }

    for _, item in ipairs(Finder.FindNearbyGroundItems(player, radius)) do
        table.insert(sources.ground, item)
        AddCount(sources.counts, item.prefab, Finder.GetStackCount(item))
        sources.max_stacks[item.prefab] = math.max(
            sources.max_stacks[item.prefab] or 1,
            Finder.GetMaxStack(item)
        )
    end

    for _, entity in ipairs(verified_containers or {}) do
        local records = Finder.GetContainerItems(entity, player)
        if #records > 0 or entity.replica.container:IsOpenedBy(player) then
            table.insert(sources.containers, entity)
            for _, record in ipairs(records) do
                if Policy.IsCraftingItem(record.item) then
                    AddCount(sources.counts, record.prefab, record.count)
                    sources.max_stacks[record.prefab] = math.max(
                        sources.max_stacks[record.prefab] or 1,
                        record.max_stack
                    )
                end
            end
        end
    end
    return sources
end

function Finder.HasRoomForPrefab(player, prefab)
    local inventory = player and player.replica and player.replica.inventory
    if inventory == nil then
        return false
    end

    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        if record.prefab == prefab and record.item.replica.stackable ~= nil and
            not record.item.replica.stackable:IsFull() then
            return true
        end
    end

    for slot = 1, inventory:GetNumSlots() do
        if inventory:GetItemInSlot(slot) == nil then
            return true
        end
    end
    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil then
        for slot = 1, overflow:GetNumSlots() do
            if overflow:GetItemInSlot(slot) == nil then
                return true
            end
        end
    end
    return false
end

function Finder.FindSafeStageItem(player, needed_prefabs)
    for _, record in ipairs(Finder.GetPersonalItems(player)) do
        if not record.active and Policy.CanStageItem(record.item, needed_prefabs) then
            return record.item
        end
    end
end

return Finder
