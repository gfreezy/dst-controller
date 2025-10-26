-- Enhanced Controller - Action Helpers
-- Helper functions used by action modules

local ActionHelpers = {}

-- Helper function to find an item by prefab name in inventory
-- Searches both main inventory and overflow container (backpack)
function ActionHelpers.FindItemByName(player, item_prefab)
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

return ActionHelpers
