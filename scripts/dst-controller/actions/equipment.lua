-- Enhanced Controller - Equipment Actions
-- Equipment management, cycling, swapping, and save/restore functionality

local G = require("dst-controller/global")
local ActionHelpers = require("dst-controller/actions/helpers")

local EquipmentActions = {}

-- ============================================================================
-- Equipment History Tracking
-- ============================================================================

-- Track last equipped items for each slot per player
-- Structure: [player_guid][slot_name] = last_item
local equipment_history = {}

local function ItemMatchesEquipSlot(item, equipslot)
    if not item or not equipslot then
        return false
    end

    -- 客户端只能访问 replica.equippable
    -- components.equippable 只在服务器端存在
    if item.replica and item.replica.equippable then
        return item.replica.equippable:EquipSlot() == equipslot
    end

    return false
end

-- Initialize equipment tracking for a player
local function InitEquipmentTracking(player)
    local guid = player.GUID
    if not equipment_history[guid] then
        equipment_history[guid] = {
            [G.EQUIPSLOTS.HANDS] = nil,
            [G.EQUIPSLOTS.HEAD] = nil,
            [G.EQUIPSLOTS.BODY] = nil,
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return nil end

    local guid = player.GUID
    local last_item = equipment_history[guid] and equipment_history[guid][equipslot]

    -- Try to equip the last item
    if last_item and last_item:IsValid() then
        -- Check if item is still in inventory (check both main inventory and overflow container/backpack)
        local found = false
        ActionHelpers.ForEachInventoryItem(player, function(item)
            if item == last_item then
                found = true
                return true
            end
        end)

        if found then
            if ActionHelpers.DoControllerUseItemOnSelf(player, last_item) then
                return last_item.prefab
            end
        else
            -- Item no longer available, clear history
            equipment_history[guid][equipslot] = nil
        end
    end

    return nil
end

-- Helper function to cycle equipment forward
local function CycleEquipment(player, equipslot, direction)
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    local current_equipped = inventory:GetEquippedItem(equipslot)
    local items = {}
    local current_index = nil

    -- Collect all equippable items for this slot from main inventory
    -- Create list with {item, slot_number} pairs for sorting
    local item_list = {}
    local seen_prefabs = {}  -- Track prefabs we've already added

    ActionHelpers.ForEachInventoryItem(player, function(item, slot_number)
        if item and ItemMatchesEquipSlot(item, equipslot) and not seen_prefabs[item.prefab] then
            table.insert(item_list, {item = item, slot = slot_number})
            seen_prefabs[item.prefab] = true
        end
    end)

    -- If something is equipped, add it using its prevslot (only if not already in the list)
    if current_equipped and ItemMatchesEquipSlot(current_equipped, equipslot) then
        local already_in_list = false
        for _, entry in ipairs(item_list) do
            if entry.item == current_equipped then
                already_in_list = true
                break
            end
        end

        if not already_in_list then
            local prevslot = current_equipped.prevslot or 0  -- Use prevslot if available, otherwise put at start
            table.insert(item_list, {item = current_equipped, slot = prevslot})
            seen_prefabs[current_equipped.prefab] = true
        end
    end

    -- Sort by slot number to maintain consistent order
    table.sort(item_list, function(a, b) return a.slot < b.slot end)

    -- Extract items and find current index
    for i, entry in ipairs(item_list) do
        table.insert(items, entry.item)
        if entry.item == current_equipped then
            current_index = i
        end
    end

    if #items == 0 then
        return nil
    end

    -- Items are collected with equipped item first, then inventory order
    -- Players can organize their inventory to control cycle order
    local next_item = nil
    if not current_index then
        -- Nothing equipped, use first item (forward) or last item (backward)
        next_item = direction > 0 and items[1] or items[#items]
    else
        -- Calculate next index with wrapping
        local next_index = current_index + direction
        if next_index > #items then
            next_index = 1  -- Wrap to first
        elseif next_index < 1 then
            next_index = #items  -- Wrap to last
        end
        next_item = items[next_index]
    end

    -- If only one item and it's already equipped, do nothing (keep it equipped)
    if #items == 1 and current_equipped then
        return current_equipped.prefab
    end

    if next_item then
        if ActionHelpers.DoControllerUseItemOnSelf(player, next_item) then
            return next_item.prefab
        end
    end

    return nil
end

-- ============================================================================
-- Basic Equipment Actions
-- ============================================================================

-- Equip item by name (item_name is required)
function EquipmentActions.equip_item(player, item_name)
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: equip_item requires item name parameter")
        return
    end

    local target_item = ActionHelpers.FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    -- 客户端只能访问 replica.equippable
    local equippable = target_item.replica and target_item.replica.equippable
    if not equippable then
        print(string.format("[Enhanced Controller] Item '%s' is not equippable", item_name))
        return
    end

    if ActionHelpers.DoControllerUseItemOnSelf(player, target_item) then
        print(string.format("[Enhanced Controller] Action: Equip Item (%s)", target_item.prefab))
    end
end

-- ============================================================================
-- Equipment Cycling Actions
-- ============================================================================

-- Cycle through hand equipment (weapons/tools) - forward
function EquipmentActions.cycle_hand(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.HANDS, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Next) -> %s", result))
    end
end

-- Cycle through hand equipment (weapons/tools) - backward
function EquipmentActions.cycle_hand_prev(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.HANDS, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Prev) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - forward
function EquipmentActions.cycle_head(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.HEAD, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Next) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - backward
function EquipmentActions.cycle_head_prev(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.HEAD, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Prev) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - forward
function EquipmentActions.cycle_body(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.BODY, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Next) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - backward
function EquipmentActions.cycle_body_prev(player)
    local result = CycleEquipment(player, G.EQUIPSLOTS.BODY, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Prev) -> %s", result))
    end
end

-- ============================================================================
-- Equipment Swapping Actions
-- ============================================================================

-- Swap to last equipped hand item
function EquipmentActions.swap_hand_last(player)
    local result = SwapToLastEquipped(player, G.EQUIPSLOTS.HANDS)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Hand Last -> %s", result))
    end
end

-- Swap to last equipped head item
function EquipmentActions.swap_head_last(player)
    local result = SwapToLastEquipped(player, G.EQUIPSLOTS.HEAD)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Head Last -> %s", result))
    end
end

-- Swap to last equipped body item
function EquipmentActions.swap_body_last(player)
    local result = SwapToLastEquipped(player, G.EQUIPSLOTS.BODY)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Body Last -> %s", result))
    end
end

-- ============================================================================
-- Save/Restore Equipment Actions
-- ============================================================================

-- Save currently equipped hand item for later restoration
function EquipmentActions.save_hand_item(player)
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    local current_hand = inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    -- Only restore if there was a saved item
    if player._saved_hand_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_hand_item)
        if saved_item and ItemMatchesEquipSlot(saved_item, G.EQUIPSLOTS.HANDS) then
            ActionHelpers.DoControllerUseItemOnSelf(player, saved_item)
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    local current_head = inventory:GetEquippedItem(G.EQUIPSLOTS.HEAD)
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    if player._saved_head_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_head_item)
        if saved_item and ItemMatchesEquipSlot(saved_item, G.EQUIPSLOTS.HEAD) then
            ActionHelpers.DoControllerUseItemOnSelf(player, saved_item)
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    local current_body = inventory:GetEquippedItem(G.EQUIPSLOTS.BODY)
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
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    if player._saved_body_item then
        local saved_item = ActionHelpers.FindItemByName(player, player._saved_body_item)
        if saved_item and ItemMatchesEquipSlot(saved_item, G.EQUIPSLOTS.BODY) then
            ActionHelpers.DoControllerUseItemOnSelf(player, saved_item)
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
-- Unequip Item Action
-- ============================================================================

-- Unequip item from specified slot
-- param: "hand", "head", or "body"
function EquipmentActions.unequip_item(player, slot_type)
    if not player or not player:IsValid() then
        return
    end

    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end

    local equipslot
    if slot_type == "hand" then
        equipslot = G.EQUIPSLOTS.HANDS
    elseif slot_type == "head" then
        equipslot = G.EQUIPSLOTS.HEAD
    elseif slot_type == "body" then
        equipslot = G.EQUIPSLOTS.BODY
    else
        print(string.format("[Enhanced Controller] Invalid slot type: %s (must be hand/head/body)", tostring(slot_type)))
        return
    end

    local equipped_item = inventory:GetEquippedItem(equipslot)
    if equipped_item then
        -- Use DST's official DoControllerUseItemOnSelfFromInvTile
        -- For equipped items, it automatically creates UNEQUIP action
        -- This handles all edge cases: prevention checks, heavy items, etc.
        if ActionHelpers.DoControllerUseItemOnSelf(player, equipped_item) then
            print(string.format("[Enhanced Controller] Action: Unequipping %s from %s slot", equipped_item.prefab, slot_type))
        end
    else
        print(string.format("[Enhanced Controller] Action: No item equipped in %s slot", slot_type))
    end
end

-- ============================================================================
-- Use Equipped Item Action
-- ============================================================================

-- Use the equipped item in specified slot
-- param: "hand", "head", or "body"
function EquipmentActions.use_equip(player, slot_type)
    if not player or not player:IsValid() then
        return
    end

    local inventory = ActionHelpers.GetInventory(player)
    local controller = ActionHelpers.GetPlayerController(player)
    if not inventory or not controller then return end

    local equipslot
    if slot_type == "hand" then
        equipslot = G.EQUIPSLOTS.HANDS
    elseif slot_type == "head" then
        equipslot = G.EQUIPSLOTS.HEAD
    elseif slot_type == "body" then
        equipslot = G.EQUIPSLOTS.BODY
    else
        print(string.format("[Enhanced Controller] Invalid slot type: %s (must be hand/head/body)", tostring(slot_type)))
        return
    end

    local equipped_item = inventory:GetEquippedItem(equipslot)
    if equipped_item then
        -- Use DST's official DoControllerUseItemOnSceneFromInvTile
        -- This will trigger the appropriate action for the equipped item on the scene/target:
        -- - For tools/weapons: uses them on scene/target
        -- - For other equipped items: uses them on detected targets
        controller:DoControllerUseItemOnSceneFromInvTile(equipped_item)
        print(string.format("[Enhanced Controller] Action: Using equipped %s from %s slot on scene", equipped_item.prefab, slot_type))
    else
        print(string.format("[Enhanced Controller] Action: No item equipped in %s slot", slot_type))
    end
end

-- ============================================================================
-- Module Exports
-- ============================================================================

-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
EquipmentActions.InitEquipmentTracking = InitEquipmentTracking

return EquipmentActions
