-- Helper functions used by action modules

local ActionHelpers = {}

-- ============================================================================
-- Internal helpers
-- ============================================================================

local function GetInventory(player)
    if not player then
        return nil
    end

    -- 客户端只能访问 replica.inventory
    -- components.inventory 只在服务器端存在
    if player.replica and player.replica.inventory then
        return player.replica.inventory
    end

    return nil
end

local function GetPlayerController(player)
    if player and player.components then
        return player.components.playercontroller
    end
end

local function GetContainerSlotCount(container)
    if not container then
        return 0
    end

    if container.GetNumSlots then
        return container:GetNumSlots()
    end

    return container.numslots or container.maxslots or 0
end

local function IterateContainerSlots(container, slot_offset, fn)
    if not container or not fn then
        return false
    end

    local slot_count = GetContainerSlotCount(container)
    for idx = 1, slot_count do
        local item = container:GetItemInSlot(idx)
        if fn(item, slot_offset + idx, container) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- Public API
-- ============================================================================

function ActionHelpers.GetInventory(player)
    return GetInventory(player)
end

function ActionHelpers.GetPlayerController(player)
    return GetPlayerController(player)
end

function ActionHelpers.ForEachInventoryItem(player, fn)
    local inventory = GetInventory(player)
    if not inventory or not fn then
        return
    end

    if IterateContainerSlots(inventory, 0, fn) then
        return
    end

    if inventory.GetOverflowContainer then
        local overflow = inventory:GetOverflowContainer()
        if overflow then
            IterateContainerSlots(overflow, GetContainerSlotCount(inventory), fn)
        end
    end
end

-- Helper function to find an item by prefab name in inventory
-- Searches both main inventory and overflow container (backpack)
function ActionHelpers.FindItemByName(player, item_prefab)
    if not player or not item_prefab then
        return nil
    end

    local found_item = nil
    ActionHelpers.ForEachInventoryItem(player, function(item)
        if item and item.prefab == item_prefab then
            found_item = item
            return true
        end
    end)

    return found_item
end

function ActionHelpers.DoControllerUseItemOnSelf(player, item)
    local controller = GetPlayerController(player)
    if controller and item and item:IsValid() then
        controller:DoControllerUseItemOnSelfFromInvTile(item)
        return true
    end
    return false
end

function ActionHelpers.DoControllerUseItemOnScene(player, item)
    local controller = GetPlayerController(player)
    if controller and item and item:IsValid() then
        controller:DoControllerUseItemOnSceneFromInvTile(item)
        return true
    end
    return false
end

return ActionHelpers
