-- Enhanced Controller - Item Actions
-- Item usage actions

local ActionHelpers = require("actions/helpers")

local ItemActions = {}

-- Use item by name (item_name is required)
function ItemActions.use_item(player, item_name)
    if not player.components.inventory then return end

    if not item_name then
        print("[Enhanced Controller] Error: use_item requires item name parameter")
        return
    end

    -- Find specific item by name
    local target_item = ActionHelpers.FindItemByName(player, item_name)
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
function ItemActions.use_item_on_self(player, item_name)
    if not player.components.inventory then return end

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

    local action = BufferedAction(player, player, ACTIONS.USEITEM, target_item)
    if player.components.playercontroller then
        player.components.playercontroller:DoAction(action)
        print(string.format("[Enhanced Controller] Action: Use Item On Self (%s)", target_item.prefab))
    end
end

return ItemActions
