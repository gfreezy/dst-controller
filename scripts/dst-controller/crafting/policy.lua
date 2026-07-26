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

function Policy.IsStorageContainer(entity, player)
    if entity == nil or not entity:IsValid() or entity == player or
        entity:HasTag("INLIMBO") or entity:HasTag("NOCLICK") then
        return false
    end

    local container = entity.replica and entity.replica.container
    if container == nil or not container:CanBeOpened() or
        container:IsReadOnlyContainer() or container.excludefromcrafting then
        return false
    end

    if UNSAFE_CONTAINER_TYPES[container.type] or container.usespecificslotsforitems then
        return false
    end

    local widget = container.GetWidget and container:GetWidget() or container.widget
    if widget ~= nil and (widget.buttoninfo ~= nil or widget.overrideactionfn ~= nil) then
        return false
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
