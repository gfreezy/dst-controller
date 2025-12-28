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

-- Helper to get item from container slot, bypassing opener check for client-side access
-- On client, container_replica:GetItemInSlot requires opener to be set,
-- which only happens when the container UI is open. For backpacks that are
-- just equipped (not opened), we need to access classified directly.
local function GetContainerItemInSlot(container, slot)
    if not container then
        return nil
    end

    -- Try normal access first (works on server or when container is open)
    local item = container:GetItemInSlot(slot)
    if item then
        return item
    end

    -- On client, if opener is nil but classified exists, access classified directly
    -- This happens when backpack is equipped but inventory UI is not open
    if container.classified and container.classified.GetItemInSlot then
        local classified_item = container.classified:GetItemInSlot(slot)
        if classified_item then
            -- Debug: only log when we actually find something via fallback
            print(string.format("[GetContainerItemInSlot] Fallback to classified worked! Slot %d -> %s", slot, classified_item.prefab))
        end
        return classified_item
    end

    return nil
end

local function IterateContainerSlots(container, slot_offset, fn)
    if not container or not fn then
        return false
    end

    local slot_count = GetContainerSlotCount(container)
    local items_found = 0
    for idx = 1, slot_count do
        local item = GetContainerItemInSlot(container, idx)
        if item then
            items_found = items_found + 1
        end
        if fn(item, slot_offset + idx, container) then
            return true
        end
    end
    print(string.format("[IterateContainerSlots] Iterated %d slots, found %d items (offset=%d)", slot_count, items_found, slot_offset))

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

    -- Debug: count main inventory slots
    local main_slots = GetContainerSlotCount(inventory)
    print(string.format("[ForEachInventoryItem] Main inventory slots: %d", main_slots))

    if IterateContainerSlots(inventory, 0, fn) then
        return
    end

    if inventory.GetOverflowContainer then
        local overflow = inventory:GetOverflowContainer()
        if overflow then
            local overflow_slots = GetContainerSlotCount(overflow)
            print(string.format("[ForEachInventoryItem] Overflow container found, slots: %d", overflow_slots))

            -- Debug: check if classified is accessible
            if overflow.classified then
                print("[ForEachInventoryItem] Overflow classified is accessible")
            else
                print("[ForEachInventoryItem] WARNING: Overflow classified is nil!")
            end

            IterateContainerSlots(overflow, main_slots, fn)
        else
            print("[ForEachInventoryItem] No overflow container")
        end
    end
end

-- Helper function to find an item by prefab name in inventory
-- Searches: equipped slots, main inventory, and overflow container (backpack)
function ActionHelpers.FindItemByName(player, item_prefab)
    if not player or not item_prefab then
        return nil
    end

    local inventory = GetInventory(player)
    if not inventory then
        return nil
    end

    -- First check equipped slots (HANDS, HEAD, BODY)
    local G = require("dst-controller/global")
    local equip_slots = { G.EQUIPSLOTS.HANDS, G.EQUIPSLOTS.HEAD, G.EQUIPSLOTS.BODY }
    for _, slot in ipairs(equip_slots) do
        local equipped = inventory:GetEquippedItem(slot)
        if equipped and equipped.prefab == item_prefab then
            return equipped
        end
    end

    -- Then search inventory slots and overflow container
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
