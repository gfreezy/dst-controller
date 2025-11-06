-- Enhanced Controller - Item Actions
-- Item usage actions

local G = require("dst-controller/global")
local ActionHelpers = require("dst-controller/actions/helpers")

local ItemActions = {}

-- Use item on self by name (item_name is required)
-- Uses DST's official API for proper state checking and network sync
function ItemActions.use_item_on_self(player, item_name)
    if not player.components.inventory then return end
    if not player.components.playercontroller then return end

    if not item_name then
        print("[Enhanced Controller] Error: use_item_on_self requires item name parameter")
        return
    end

    -- Find specific item by name
    local target_item = ActionHelpers.FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    -- Use official DST API - handles state checking, network sync, and action selection
    player.components.playercontroller:DoControllerUseItemOnSelfFromInvTile(target_item)
    print(string.format("[Enhanced Controller] Action: Use Item On Self (%s)", target_item.prefab))
end

-- Use item on scene/target by name (item_name is required)
-- Uses DST's official API for proper target detection and network sync
function ItemActions.use_item_on_scene(player, item_name)
    if not player.components.inventory then return end
    if not player.components.playercontroller then return end

    if not item_name then
        print("[Enhanced Controller] Error: use_item_on_scene requires item name parameter")
        return
    end

    -- Find specific item by name
    local target_item = ActionHelpers.FindItemByName(player, item_name)
    if not target_item then
        print(string.format("[Enhanced Controller] Item '%s' not found in inventory", item_name))
        return
    end

    -- Use official DST API - handles target detection, range checking, and action selection
    player.components.playercontroller:DoControllerUseItemOnSceneFromInvTile(target_item)
    print(string.format("[Enhanced Controller] Action: Use Item On Scene (%s)", target_item.prefab))
end

-- Use currently active item on self (no parameter needed)
-- Active item is the item currently selected in inventory (not necessarily equipped)
function ItemActions.use_active_item_on_self(player)
    if not player.components.inventory then return end
    if not player.components.playercontroller then return end

    -- Get the active item (currently selected inventory slot)
    local active_item = player.components.inventory:GetActiveItem()
    if not active_item then
        print("[Enhanced Controller] No active item selected")
        return
    end

    -- Use official DST API
    player.components.playercontroller:DoControllerUseItemOnSelfFromInvTile(active_item)
    print(string.format("[Enhanced Controller] Action: Use Active Item On Self (%s)", active_item.prefab))
end

-- Use currently active item on scene/target (no parameter needed)
-- Active item is the item currently selected in inventory (not necessarily equipped)
function ItemActions.use_active_item_on_scene(player)
    if not player.components.inventory then return end
    if not player.components.playercontroller then return end

    -- Get the active item (currently selected inventory slot)
    local active_item = player.components.inventory:GetActiveItem()
    if not active_item then
        print("[Enhanced Controller] No active item selected")
        return
    end

    -- Use official DST API
    player.components.playercontroller:DoControllerUseItemOnSceneFromInvTile(active_item)
    print(string.format("[Enhanced Controller] Action: Use Active Item On Scene (%s)", active_item.prefab))
end

return ItemActions
