-- Enhanced Controller - Crafting Actions
-- Crafting and recipe-related actions

local CraftingActions = {}
local Coordinator = require("dst-controller/crafting/coordinator")
local Helpers = require("dst-controller/utils/helpers")

-- Craft an item through the same verified automatic-crafting coordinator used
-- by the crafting menu. The returned task pauses subsequent configured actions.
function CraftingActions.craft_item(player, recipe_name)
    if not recipe_name then
        Helpers.DebugPrint("No recipe name provided")
        return nil
    end

    -- 客户端只能访问 replica.builder
    -- components.builder 只在服务器端存在
    local builder = player.replica and player.replica.builder
    if not builder then
        Helpers.DebugPrint("Player has no builder replica")
        return nil
    end

    -- Get the recipe
    local recipe = GetValidRecipe(recipe_name)
    if not recipe then
        Helpers.DebugPrintf("Recipe '%s' not found or invalid", recipe_name)
        return nil
    end

    local can_use, reason = Coordinator.CanUseRecipe(player, recipe)
    if not can_use then
        Helpers.DebugPrintf("Cannot craft '%s': %s", recipe_name, tostring(reason))
        return nil
    end

    return Coordinator.Start(player, recipe)
end

return CraftingActions
