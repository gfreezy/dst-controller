-- Enhanced Controller - Optimistic crafting menu state

local Policy = require("dst-controller/crafting/policy")
local Finder = require("dst-controller/crafting/material-finder")
local Coordinator = require("dst-controller/crafting/coordinator")

local MenuPolicy = {}

function MenuPolicy.CanAutoCraft(player, recipe, stock)
    if player == nil or recipe == nil or player.replica == nil or player.replica.builder == nil then
        return false
    end

    local builder = player.replica.builder
    if builder:IsBuildBuffered(recipe.name) or builder:HasIngredients(recipe) then
        return false
    end

    local can_use = Coordinator.CanUseRecipe(player, recipe)
    if not can_use then
        return false
    end

    stock = stock or Finder.BuildMenuStock(player, Policy.SEARCH_RADIUS)

    -- The requested optimistic policy: every unseen eligible container is
    -- treated as potentially sufficient. The coordinator verifies it before
    -- moving or crafting any item.
    if #stock.unknown_containers > 0 then
        return true
    end

    local plan = Coordinator.BuildPlan(player, recipe, stock.owned, stock.external, stock.max_stacks)
    return plan ~= nil
end

function MenuPolicy.ApplyToRecipeStates(player, valid_recipes)
    local stock = Finder.BuildMenuStock(player, Policy.SEARCH_RADIUS)
    for _, data in pairs(valid_recipes or {}) do
        local meta = data.meta
        local recipe = data.recipe
        meta._enhanced_native_can_build = meta.can_build
        meta._enhanced_original_build_state = meta.build_state
        meta._enhanced_auto_craftable = false

        if not meta.can_build and
            (meta.build_state == "no_ingredients" or meta.build_state == "prototype") and
            MenuPolicy.CanAutoCraft(player, recipe, stock) then
            meta._enhanced_auto_craftable = true
            meta.can_build = true
        end
    end
end

return MenuPolicy
