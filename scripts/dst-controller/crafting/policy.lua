-- Enhanced Controller - Automatic crafting policy

local ConfigManager = require("dst-controller/utils/config_manager")

local Policy = {
    SEARCH_RADIUS = 6,
    POLL_INTERVAL = 0.1,
    MENU_REFRESH_INTERVAL = 0.75,
    ACTION_TIMEOUT = 8,
    BUILD_TIMEOUT = 5,
    MAX_RECIPE_DEPTH = 12,
    CACHE_VERSION = 1,
    CACHE_FILE_NAME = "enhanced_controller_container_cache.json",
    CACHE_TTL_SECONDS = 30 * 24 * 60 * 60,
    CACHE_TIMESTAMP_REFRESH_SECONDS = 24 * 60 * 60,
    CACHE_MAX_SCOPES = 16,
    CACHE_MAX_CONTAINERS_PER_SCOPE = 512,
}

function Policy.GetAutomationSettings()
    local settings = ConfigManager.GetRuntimeSettings()
    local crafting = settings and settings.auto_crafting_settings or nil
    return {
        search_radius = crafting and crafting.search_radius or Policy.SEARCH_RADIUS,
        search_mode = crafting and crafting.search_mode or "smart",
        max_containers = crafting and crafting.max_containers or 24,
    }
end

local UNSAFE_CONTAINER_TYPES = {
    cooker = true,
    hand_inv = true,
}

local PROXY_SOURCE_PREFABS = {
    chester = "shadow_container",
    magician_chest = "shadow_container",
    rabbitkinghorn_chest = "rabbitkinghorn_container",
}

-- Container proxies expose the interaction target on the visible entity, but
-- their slots live on a separate pocket-dimension container. Remember that
-- source after it becomes visible to the local player's HUD.
local resolved_proxy_sources = setmetatable({}, { __mode = "kv" })

local PROTECTED_STAGE_TAGS = {
    "backpack",
    "bundle",
    "cursed",
    "heavy",
    "irreplaceable",
    "nosteal",
    "nonpotatable",
    "personal",
    "soul",
    "unique",
}

function Policy.IsCraftingItem(item)
    return item ~= nil and item:IsValid() and not item:HasTag("nocrafting")
end

function Policy.GetStorageOpener(entity)
    if entity == nil then
        return nil
    end
    local container = entity.replica and entity.replica.container
    if container ~= nil then
        return container
    end
    return entity.components and entity.components.container_proxy or nil
end

function Policy.CanOpenStorage(entity)
    local opener = Policy.GetStorageOpener(entity)
    return opener ~= nil and opener.CanBeOpened ~= nil and opener:CanBeOpened()
end

function Policy.IsStorageOpenedBy(entity, player)
    local opener = Policy.GetStorageOpener(entity)
    return opener ~= nil and opener.IsOpenedBy ~= nil and opener:IsOpenedBy(player)
end

function Policy.CaptureOpenContainers(player)
    local inventory = player and player.replica and player.replica.inventory
    local open = inventory and inventory:GetOpenContainers() or nil
    local result = {}
    for entity in pairs(open or {}) do
        result[entity] = true
    end
    return result
end

local function IsOpenContainerSource(entity, player)
    if entity == nil or entity.replica == nil then
        return false
    end
    local container = entity.replica.container
    return container ~= nil and
        (entity.IsValid == nil or entity:IsValid()) and
        (container.IsOpenedBy == nil or container:IsOpenedBy(player))
end

local function FindProxySource(entity, player, previously_open)
    local mapped = resolved_proxy_sources[entity]
    if IsOpenContainerSource(mapped, player) then
        return mapped
    end
    resolved_proxy_sources[entity] = nil

    local inventory = player and player.replica and player.replica.inventory
    local open = inventory and inventory:GetOpenContainers() or nil
    if open == nil then
        return nil
    end

    local expected_prefab = PROXY_SOURCE_PREFABS[entity.prefab]
    local new_sources = {}
    local all_sources = {}
    for source in pairs(open) do
        if IsOpenContainerSource(source, player) then
            table.insert(all_sources, source)
            if previously_open ~= nil and not previously_open[source] then
                table.insert(new_sources, source)
            end
        end
    end

    local function Select(sources)
        if expected_prefab ~= nil then
            for _, source in ipairs(sources) do
                if source.prefab == expected_prefab then
                    return source
                end
            end
        end
        if #sources == 1 then
            return sources[1]
        end
    end

    mapped = Select(new_sources) or Select(all_sources)
    if mapped ~= nil then
        resolved_proxy_sources[entity] = mapped
    end
    return mapped
end

-- Returns the slot-bearing replica. For ordinary chests this is attached to
-- the target itself; for proxy storage (such as Shadow Chester) it is the
-- newly opened pocket-dimension container.
function Policy.GetStorageContainer(entity, player, previously_open)
    local container = entity and entity.replica and entity.replica.container
    if container ~= nil then
        return container
    end
    if not Policy.IsStorageOpenedBy(entity, player) then
        return nil
    end
    local source = FindProxySource(entity, player, previously_open)
    return source and source.replica and source.replica.container or nil
end

function Policy.IsStorageContainer(entity, player)
    if entity == nil or not entity:IsValid() or entity == player or
        entity:HasTag("INLIMBO") or entity:HasTag("NOCLICK") then
        return false
    end

    local container = entity.replica and entity.replica.container
    local opener = Policy.GetStorageOpener(entity)
    if opener == nil then
        return false
    end

    -- Chester closes its container while locomoting. Keep it as a candidate
    -- and let the coordinator wait for its idle state instead of permanently
    -- dropping it from the material search.
    if not Policy.CanOpenStorage(entity) and not entity:HasTag("chester") then
        return false
    end

    if container ~= nil then
        if container:IsReadOnlyContainer() or container.excludefromcrafting then
            return false
        end

        if UNSAFE_CONTAINER_TYPES[container.type] or container.usespecificslotsforitems then
            return false
        end

        local widget = container.GetWidget and container:GetWidget() or container.widget
        if widget ~= nil and (widget.buttoninfo ~= nil or widget.overrideactionfn ~= nil) then
            return false
        end
    end

    local inventory_item = entity.replica and entity.replica.inventoryitem
    if inventory_item ~= nil and inventory_item:IsGrandOwner(player) then
        return false
    end

    return true
end

function Policy.IsGroundCraftingItem(entity, player)
    if entity == nil or not entity:IsValid() or entity:HasTag("INLIMBO") or
        entity:HasTag("NOCLICK") or entity:HasTag("heavy") then
        return false
    end

    local inventory_item = entity.replica and entity.replica.inventoryitem
    return inventory_item ~= nil and
        not inventory_item:IsHeld() and
        inventory_item:CanBePickedUp(player) and
        Policy.IsCraftingItem(entity)
end

function Policy.CanStageItem(item, needed_prefabs)
    if item == nil or not item:IsValid() or
        (needed_prefabs ~= nil and needed_prefabs[item.prefab]) or
        (item.replica ~= nil and item.replica.container ~= nil) then
        return false
    end

    for _, tag in ipairs(PROTECTED_STAGE_TAGS) do
        if item:HasTag(tag) then
            return false
        end
    end
    return true
end

function Policy.ShouldReturnExternalRemainder(initial_counts, prefab)
    return (initial_counts[prefab] or 0) <= 0
end

return Policy
