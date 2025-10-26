-- Enhanced Controller - Equipment Actions
-- Equipment management, cycling, swapping, and save/restore functionality

local ActionHelpers = require("actions/helpers")

local EquipmentActions = {}

-- ============================================================================
-- Equipment History Tracking
-- ============================================================================

-- Track last equipped items for each slot per player
-- Structure: [player_guid][slot_name] = last_item
local equipment_history = {}

-- Initialize equipment tracking for a player
local function InitEquipmentTracking(player)
    local guid = player.GUID
    if not equipment_history[guid] then
        equipment_history[guid] = {
            [EQUIPSLOTS.HANDS] = nil,
            [EQUIPSLOTS.HEAD] = nil,
            [EQUIPSLOTS.BODY] = nil,
        }

        -- Listen to unequip events to track last equipped item
        -- When an item is unequipped, save it as the last item for swapping
        player:ListenForEvent("unequip", function(_, data)
            local slot = data.eslot
            local item = data.item
            if equipment_history[guid] and item then
                -- Save the unequipped item as last for this slot
                equipment_history[guid][slot] = item
            end
        end)
    end
end

-- Swap to last equipped item in a slot
local function SwapToLastEquipped(player, equipslot)
    if not player.components.inventory then return nil end

    local guid = player.GUID
    local last_item = equipment_history[guid] and equipment_history[guid][equipslot]

    -- Try to equip the last item
    if last_item and last_item:IsValid() then
        -- Check if item is still in inventory (check both main inventory and overflow container/backpack)
        local found = false

        -- Check main inventory slots
        for i = 1, player.components.inventory.maxslots do
            local item = player.components.inventory:GetItemInSlot(i)
            if item == last_item then
                found = true
                break
            end
        end

        -- Check overflow container (backpack)
        if not found then
            local overflow = player.components.inventory:GetOverflowContainer()
            if overflow then
                for i = 1, overflow.numslots do
                    local item = overflow:GetItemInSlot(i)
                    if item == last_item then
                        found = true
                        break
                    end
                end
            end
        end

        if found then
            player.components.inventory:Equip(last_item)
            return last_item.prefab
        else
            -- Item no longer available, clear history
            equipment_history[guid][equipslot] = nil
        end
    end

    return nil
end

-- Helper function to cycle equipment forward
local function CycleEquipment(player, equipslot, direction)
    if not player.components.inventory then return end

    local current_equipped = player.components.inventory:GetEquippedItem(equipslot)
    local items = {}
    local current_index = nil

    -- Collect all equippable items for this slot from main inventory
    for i = 1, player.components.inventory.maxslots do
        local item = player.components.inventory:GetItemInSlot(i)
        if item and item.components.equippable and item.components.equippable.equipslot == equipslot then
            table.insert(items, item)
            if current_equipped and item == current_equipped then
                current_index = #items
            end
        end
    end

    -- Also check overflow container (backpack)
    local overflow = player.components.inventory:GetOverflowContainer()
    if overflow then
        for i = 1, overflow.numslots do
            local item = overflow:GetItemInSlot(i)
            if item and item.components.equippable and item.components.equippable.equipslot == equipslot then
                table.insert(items, item)
                if current_equipped and item == current_equipped then
                    current_index = #items
                end
            end
        end
    end

    if #items == 0 then
        return nil
    end

    -- Items are collected in inventory slot order
    -- Players can organize their inventory to control cycle order
    local next_item = nil
    if not current_index then
        -- Nothing equipped, use first or last based on direction
        next_item = direction > 0 and items[1] or items[#items]
    else
        -- Calculate next index
        local next_index = current_index + direction
        if next_index > #items then
            next_index = 1  -- Wrap to first
        elseif next_index < 1 then
            next_index = #items  -- Wrap to last
        end
        next_item = items[next_index]
    end

    -- If only one item and it's equipped, unequip it
    if #items == 1 and current_equipped then
        return nil
    end

    if next_item then
        player.components.inventory:Equip(next_item)
        return next_item.prefab
    end

    return nil
end

-- ============================================================================
-- Basic Equipment Actions
-- ============================================================================

-- Equip item by name (item_name is required)
function EquipmentActions.equip_item(player, item_name)
    if not player.components.inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: equip_item requires item name parameter")
        return
    end

    local target_item = ActionHelpers.FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    if target_item.components.equippable then
        player.components.inventory:Equip(target_item)
        print(string.format("[Enhanced Controller] Action: Equip Item (%s)", target_item.prefab))
    else
        print(string.format("[Enhanced Controller] Item '%s' is not equippable", item_name))
    end
end

-- ============================================================================
-- Equipment Cycling Actions
-- ============================================================================

-- Cycle through hand equipment (weapons/tools) - forward
function EquipmentActions.cycle_hand(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HANDS, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Next) -> %s", result))
    end
end

-- Cycle through hand equipment (weapons/tools) - backward
function EquipmentActions.cycle_hand_prev(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HANDS, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Prev) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - forward
function EquipmentActions.cycle_head(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HEAD, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Next) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - backward
function EquipmentActions.cycle_head_prev(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HEAD, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Prev) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - forward
function EquipmentActions.cycle_body(player)
    local result = CycleEquipment(player, EQUIPSLOTS.BODY, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Next) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - backward
function EquipmentActions.cycle_body_prev(player)
    local result = CycleEquipment(player, EQUIPSLOTS.BODY, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Prev) -> %s", result))
    end
end

-- ============================================================================
-- Equipment Swapping Actions
-- ============================================================================

-- Swap to last equipped hand item
function EquipmentActions.swap_hand_last(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.HANDS)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Hand Last -> %s", result))
    end
end

-- Swap to last equipped head item
function EquipmentActions.swap_head_last(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.HEAD)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Head Last -> %s", result))
    end
end

-- Swap to last equipped body item
function EquipmentActions.swap_body_last(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.BODY)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Body Last -> %s", result))
    end
end

-- ============================================================================
-- Save/Restore Equipment Actions
-- ============================================================================

-- Save currently equipped hand item for later restoration
function EquipmentActions.save_hand_item(player)
    if not player.components.inventory then return end

    local current_hand = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if current_hand then
        player._saved_hand_item = current_hand.prefab
        print(string.format("[Enhanced Controller] Action: Saved hand item (%s)", current_hand.prefab))
    else
        player._saved_hand_item = nil
        print("[Enhanced Controller] Action: No hand item to save")
    end
end

-- Restore previously saved hand item
-- Does nothing if no item was saved (safe to call without save_hand_item)
function EquipmentActions.restore_hand_item(player)
    if not player.components.inventory then return end

    -- Only restore if there was a saved item
    if player._saved_hand_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_hand_item)
        if saved_item and saved_item.components.equippable then
            player.components.inventory:Equip(saved_item)
            print(string.format("[Enhanced Controller] Action: Restored hand item (%s)", player._saved_hand_item))
        else
            print(string.format("[Enhanced Controller] Cannot restore hand item: %s not found", player._saved_hand_item))
        end
        player._saved_hand_item = nil
    else
        -- No saved item, do nothing (safe behavior)
        print("[Enhanced Controller] Action: No saved hand item to restore")
    end
end

-- Save currently equipped head item for later restoration
function EquipmentActions.save_head_item(player)
    if not player.components.inventory then return end

    local current_head = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HEAD)
    if current_head then
        player._saved_head_item = current_head.prefab
        print(string.format("[Enhanced Controller] Action: Saved head item (%s)", current_head.prefab))
    else
        player._saved_head_item = nil
        print("[Enhanced Controller] Action: No head item to save")
    end
end

-- Restore previously saved head item
function EquipmentActions.restore_head_item(player)
    if not player.components.inventory then return end

    if player._saved_head_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_head_item)
        if saved_item and saved_item.components.equippable then
            player.components.inventory:Equip(saved_item)
            print(string.format("[Enhanced Controller] Action: Restored head item (%s)", player._saved_head_item))
        else
            print(string.format("[Enhanced Controller] Cannot restore head item: %s not found", player._saved_head_item))
        end
        player._saved_head_item = nil
    else
        print("[Enhanced Controller] Action: No saved head item to restore")
    end
end

-- Save currently equipped body item for later restoration
function EquipmentActions.save_body_item(player)
    if not player.components.inventory then return end

    local current_body = player.components.inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    if current_body then
        player._saved_body_item = current_body.prefab
        print(string.format("[Enhanced Controller] Action: Saved body item (%s)", current_body.prefab))
    else
        player._saved_body_item = nil
        print("[Enhanced Controller] Action: No body item to save")
    end
end

-- Restore previously saved body item
function EquipmentActions.restore_body_item(player)
    if not player.components.inventory then return end

    if player._saved_body_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_body_item)
        if saved_item and saved_item.components.equippable then
            player.components.inventory:Equip(saved_item)
            print(string.format("[Enhanced Controller] Action: Restored body item (%s)", player._saved_body_item))
        else
            print(string.format("[Enhanced Controller] Cannot restore body item: %s not found", player._saved_body_item))
        end
        player._saved_body_item = nil
    else
        print("[Enhanced Controller] Action: No saved body item to restore")
    end
end

-- ============================================================================
-- Module Exports
-- ============================================================================

-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
EquipmentActions.InitEquipmentTracking = InitEquipmentTracking

return EquipmentActions
