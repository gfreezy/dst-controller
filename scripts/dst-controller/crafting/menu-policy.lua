-- Enhanced Controller - Optimistic crafting menu state

local Policy = require("dst-controller/crafting/policy")
local Finder = require("dst-controller/crafting/material-finder")
local Coordinator = require("dst-controller/crafting/coordinator")

local MenuPolicy = {}

function MenuPolicy.RestoreRecipeStates(valid_recipes)
    for _, data in pairs(valid_recipes or {}) do
        local meta = data.meta
        if meta ~= nil and meta._enhanced_auto_craftable then
            meta.can_build = meta._enhanced_native_can_build
            meta.build_state = meta._enhanced_original_build_state
        end
        if meta ~= nil then
            meta._enhanced_auto_craftable = false
            meta._enhanced_search_required = false
        end
    end
end

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

    stock = stock or Finder.BuildMenuStock(
        player, Policy.GetAutomationSettings().search_radius)

    local plan = Coordinator.BuildPlan(player, recipe, stock.owned, stock.external, stock.max_stacks)
    if plan ~= nil then
        return true, false
    end

    -- Unknown containers make a search possible, but no known complete plan
    -- exists yet. Keep this distinct from a verified Auto Build in the UI.
    if #stock.unknown_containers > 0 then
        return true, true
    end
    return false, false
end

function MenuPolicy.ApplyToRecipeStates(player, valid_recipes)
    local stock = Finder.BuildMenuStock(
        player, Policy.GetAutomationSettings().search_radius)
    for _, data in pairs(valid_recipes or {}) do
        local meta = data.meta
        local recipe = data.recipe
        meta._enhanced_native_can_build = meta.can_build
        meta._enhanced_original_build_state = meta.build_state
        meta._enhanced_auto_craftable = false
        meta._enhanced_search_required = false

        local eligible_state = not meta.can_build and
            (meta.build_state == "no_ingredients" or meta.build_state == "prototype")
        local can_auto, search_required = false, false
        if eligible_state then
            can_auto, search_required = MenuPolicy.CanAutoCraft(player, recipe, stock)
        end
        if can_auto then
            meta._enhanced_auto_craftable = true
            meta._enhanced_search_required = search_required
            meta.can_build = true
        end
    end
end

return MenuPolicy
