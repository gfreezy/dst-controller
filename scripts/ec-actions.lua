-- Action definitions for Enhanced Controller mod
-- Each action is a function that takes a player instance as parameter

-- Access global environment (required for mod files loaded via require)
local ACTIONS = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Helper function to find an item by prefab name in inventory
-- Searches both main inventory and overflow container (backpack)
local function FindItemByName(player, item_prefab)
    if not player.components.inventory then return nil end

    -- Check main inventory slots
    for i = 1, player.components.inventory.maxslots do
        local item = player.components.inventory:GetItemInSlot(i)
        if item and item.prefab == item_prefab then
            return item
        end
    end

    -- Check overflow container (backpack)
    local overflow = player.components.inventory:GetOverflowContainer()
    if overflow then
        for i = 1, overflow.numslots do
            local item = overflow:GetItemInSlot(i)
            if item and item.prefab == item_prefab then
                return item
            end
        end
    end

    return nil
end

-- ============================================================================
-- Combat Actions
-- ============================================================================

-- Attack using controller targeting (uses controller_attack_target or finds nearest enemy)
-- This mimics the game's native controller attack behavior
ACTIONS.attack = function(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Use the game's native controller attack function
    -- This will automatically use controller_attack_target or find the nearest valid target
    player.components.playercontroller:DoControllerAttackButton()
    print("[Enhanced Controller] Action: Attack (Controller)")
end

-- Force attack (even allies) using controller targeting
ACTIONS.force_attack = function(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Get controller attack target or current combat target
    local target = player.components.playercontroller.controller_attack_target
    if not target and player.components.combat then
        target = player.components.combat:GetTarget()
    end

    if target then
        local action = BufferedAction(player, target, ACTIONS.ATTACK)
        action.action.canforce = true  -- Enable force attack
        player.components.playercontroller:DoAction(action)
        print("[Enhanced Controller] Action: Force Attack (Controller)")
    else
        print("[Enhanced Controller] Force Attack: No target available")
    end
end

-- ============================================================================
-- Inspection Actions
-- ============================================================================

-- Examine/inspect target using controller targeting
ACTIONS.examine = function(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Use controller_target (for interactable objects) or controller_attack_target (for entities)
    local target = player.components.playercontroller.controller_target or
                   player.components.playercontroller.controller_attack_target

    if target then
        local action = BufferedAction(player, target, ACTIONS.LOOKAT)
        player.components.playercontroller:DoAction(action)
        print("[Enhanced Controller] Action: Examine (Controller)")
    else
        print("[Enhanced Controller] Examine: No target available")
    end
end

-- Inspect self (open character screen)
ACTIONS.inspect_self = function(player)
    if player.HUD then
        player.HUD:InspectSelf()
        print("[Enhanced Controller] Action: Inspect Self")
    end
end

-- ============================================================================
-- Equipment Actions
-- ============================================================================

-- Equip item by name (item_name is required)
ACTIONS.equip_item = function(player, item_name)
    if not player.components.inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: equip_item requires item name parameter")
        return
    end

    local target_item = FindItemByName(player, item_name)
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
-- Item Usage Actions
-- ============================================================================

-- Use item by name (item_name is required)
ACTIONS.use_item = function(player, item_name)
    if not player.components.inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: use_item requires item name parameter")
        return
    end

    -- Find specific item by name
    local target_item = FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    if target_item.components.useableitem then
        target_item.components.useableitem:Use(player)
        print(string.format("[Enhanced Controller] Action: Use Item (%s)", target_item.prefab))
    else
        print(string.format("[Enhanced Controller] Item '%s' is not useable", item_name))
    end
end

-- Use item on self by name (item_name is required)
ACTIONS.use_item_on_self = function(player, item_name)
    if not player.components.inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: use_item_on_self requires item name parameter")
        return
    end

    -- Find specific item by name
    local target_item = FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    local action = BufferedAction(player, player, ACTIONS.USEITEM, target_item)
    if player.components.playercontroller then
        player.components.playercontroller:DoAction(action)
        print(string.format("[Enhanced Controller] Action: Use Item On Self (%s)", target_item.prefab))
    end
end

-- ============================================================================
-- Smart Equipment Switching
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

-- Cycle through hand equipment (weapons/tools) - forward
ACTIONS.cycle_hand = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HANDS, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Next) -> %s", result))
    end
end

-- Cycle through hand equipment (weapons/tools) - backward
ACTIONS.cycle_hand_prev = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HANDS, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Hand (Prev) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - forward
ACTIONS.cycle_head = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HEAD, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Next) -> %s", result))
    end
end

-- Cycle through head equipment (hats/helmets) - backward
ACTIONS.cycle_head_prev = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.HEAD, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Head (Prev) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - forward
ACTIONS.cycle_body = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.BODY, 1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Next) -> %s", result))
    end
end

-- Cycle through body equipment (armor) - backward
ACTIONS.cycle_body_prev = function(player)
    local result = CycleEquipment(player, EQUIPSLOTS.BODY, -1)
    if result then
        print(string.format("[Enhanced Controller] Action: Cycle Body (Prev) -> %s", result))
    end
end

-- Swap to last equipped hand item
ACTIONS.swap_hand_last = function(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.HANDS)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Hand Last -> %s", result))
    end
end

-- Swap to last equipped head item
ACTIONS.swap_head_last = function(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.HEAD)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Head Last -> %s", result))
    end
end

-- Swap to last equipped body item
ACTIONS.swap_body_last = function(player)
    local result = SwapToLastEquipped(player, EQUIPSLOTS.BODY)
    if result then
        print(string.format("[Enhanced Controller] Action: Swap Body Last -> %s", result))
    end
end

-- ============================================================================
-- Character-Specific Actions
-- ============================================================================

-- Willow: Cast pyrokinetic spell (requires willow_ember item)
ACTIONS.willow_cast_spell = function(player)
    if not player.components.inventory then return end

    -- Find willow_ember using helper function
    local ember = FindItemByName(player, "willow_ember")

    if ember and ember.components.aoespell then
        -- Get target position: use controller attack target position, or position in front of player
        local target_pos = nil

        -- Try to use controller attack target position if available
        if player.components.playercontroller then
            local controller_target = player.components.playercontroller.controller_attack_target
            if controller_target and controller_target:IsValid() then
                target_pos = controller_target:GetPosition()
            end
        end

        -- If no controller target, cast at position in front of player
        if not target_pos then
            local player_pos = player:GetPosition()
            local player_angle = player.Transform:GetRotation() * DEGREES
            local cast_distance = 3  -- Distance in front of player
            target_pos = Vector3(
                player_pos.x + math.cos(player_angle) * cast_distance,
                0,
                player_pos.z - math.sin(player_angle) * cast_distance
            )
        end

        -- Try to cast the spell
        if ember.components.aoespell:CanCast(player, target_pos) then
            -- Create buffered action to cast AOE spell
            local action = BufferedAction(player, nil, ACTIONS.CASTAOE, ember, target_pos)
            if player.components.playercontroller then
                player.components.playercontroller:DoAction(action)
                print(string.format("[Enhanced Controller] Action: Willow Cast Spell at (%.1f, %.1f, %.1f)",
                    target_pos.x, target_pos.y, target_pos.z))
            end
        else
            print("[Enhanced Controller] Willow cannot cast spell (not enough embers or cooldown)")
        end
    else
        print("[Enhanced Controller] Willow ember not found in inventory")
    end
end

-- Save currently equipped hand item for later restoration
ACTIONS.save_hand_item = function(player)
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
ACTIONS.restore_hand_item = function(player)
    if not player.components.inventory then return end

    -- Only restore if there was a saved item
    if player._saved_hand_item then
        local saved_item = FindItemByName(player, player._saved_hand_item)
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
ACTIONS.save_head_item = function(player)
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
ACTIONS.restore_head_item = function(player)
    if not player.components.inventory then return end

    if player._saved_head_item then
        local saved_item = FindItemByName(player, player._saved_head_item)
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
ACTIONS.save_body_item = function(player)
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
ACTIONS.restore_body_item = function(player)
    if not player.components.inventory then return end

    if player._saved_body_item then
        local saved_item = FindItemByName(player, player._saved_body_item)
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

-- Start channeling with the currently equipped item
ACTIONS.start_channeling = function(player)
    if not player.components.channelcaster then return end

    local equipped = player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if equipped and equipped.components.channelcastable then
        player.components.channelcaster:StartChanneling(equipped)
        print(string.format("[Enhanced Controller] Action: Started channeling (%s)", equipped.prefab))
    else
        print("[Enhanced Controller] Cannot start channeling: No channelable item equipped")
    end
end

-- Stop channeling
ACTIONS.stop_channeling = function(player)
    if player.components.channelcaster and player.components.channelcaster.channeling then
        player.components.channelcaster:StopChanneling()
        print("[Enhanced Controller] Action: Stopped channeling")
    end
end

-- Craft item by recipe name (automatically crafts intermediate ingredients)
-- Uses DST's MakeRecipeFromMenu which handles intermediate crafting automatically
ACTIONS.craft_item = function(player, recipe_name)
    if not recipe_name then
        print("[Enhanced Controller] Error: No recipe name provided")
        return
    end

    if not player.components.builder then
        print("[Enhanced Controller] Error: Player has no builder component")
        return
    end

    -- Get the recipe
    local recipe = GetValidRecipe(recipe_name)
    if not recipe then
        print(string.format("[Enhanced Controller] Error: Recipe '%s' not found or not valid", recipe_name))
        return
    end

    -- Check if player knows this recipe or can learn it
    if not player.components.builder:KnowsRecipe(recipe) and
       not player.components.builder:CanLearn(recipe.name) then
        print(string.format("[Enhanced Controller] Cannot craft '%s': Recipe not known and cannot be learned", recipe_name))
        return
    end

    -- MakeRecipeFromMenu will automatically:
    -- 1. Check if we have ingredients
    -- 2. If missing ingredients, try to craft them first (intermediate products)
    -- 3. Craft the final item
    player.components.builder:MakeRecipeFromMenu(recipe)
    print(string.format("[Enhanced Controller] Action: Craft Item (%s)", recipe_name))
end

-- ============================================================================
-- Helper Actions
-- ============================================================================

-- Do nothing (placeholder)
ACTIONS.none = function(player)
    -- Do nothing
end

-- ============================================================================
-- Module Exports
-- ============================================================================

-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
ACTIONS.InitEquipmentTracking = InitEquipmentTracking

return ACTIONS
