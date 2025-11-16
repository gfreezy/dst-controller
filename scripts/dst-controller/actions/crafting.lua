-- Enhanced Controller - Crafting Actions
-- Crafting and recipe-related actions

local CraftingActions = {}

-- Craft item by recipe name (automatically crafts intermediate ingredients)
-- Uses DST's MakeRecipeFromMenu which handles intermediate crafting automatically
function CraftingActions.craft_item(player, recipe_name)
    if not recipe_name then
        print("[Enhanced Controller] Error: No recipe name provided")
        return
    end

    local builder = (player.replica and player.replica.builder) or (player.components and player.components.builder)
    if not builder then
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
    if not builder:KnowsRecipe(recipe) and
       not builder:CanLearn(recipe.name) then
        print(string.format("[Enhanced Controller] Cannot craft '%s': Recipe not known and cannot be learned", recipe_name))
        return
    end

    -- MakeRecipeFromMenu will automatically:
    -- 1. Check if we have ingredients
    -- 2. If missing ingredients, try to craft them first (intermediate products)
    -- 3. Craft the final item
    builder:MakeRecipeFromMenu(recipe)
    print(string.format("[Enhanced Controller] Action: Craft Item (%s)", recipe_name))
end

return CraftingActions
