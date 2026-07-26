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
            -- Clear the legacy field as well so a live update cannot leave an
            -- old optimistic state attached to a recipe row.
            meta._enhanced_auto_craftable = false
            meta._enhanced_cache_craftable = false
            meta._enhanced_search_enabled = false
        end
    end
end

-- Search availability is independent of cached material counts. The
-- coordinator performs the authoritative nearby scan after the click.
function MenuPolicy.CanSearchAndBuild(player, recipe)
    if player == nil or recipe == nil or player.replica == nil or player.replica.builder == nil then
        return false
    end

    local builder = player.replica.builder
    if builder:IsBuildBuffered(recipe.name) or builder:HasIngredients(recipe) then
        return false
    end

    local can_use = Coordinator.CanUseRecipe(player, recipe)
    return can_use == true
end

-- Cached/visible stock affects presentation only. A complete local plan makes
-- the recipe appear buildable, but a missing plan must not disable searching.
function MenuPolicy.HasCachedPlan(player, recipe, stock)
    if not MenuPolicy.CanSearchAndBuild(player, recipe) then
        return false
    end

    stock = stock or Finder.BuildMenuStock(
        player, Policy.GetAutomationSettings().search_radius)

    local plan = Coordinator.BuildPlan(player, recipe, stock.owned, stock.external, stock.max_stacks)
    if plan ~= nil then
        return true
    end
    return false
end

-- Backward-compatible name for callers from older live-loaded versions.
MenuPolicy.CanAutoCraft = MenuPolicy.HasCachedPlan

function MenuPolicy.ApplyToRecipeStates(player, valid_recipes)
    local stock = Finder.BuildMenuStock(
        player, Policy.GetAutomationSettings().search_radius)
    for _, data in pairs(valid_recipes or {}) do
        local meta = data.meta
        local recipe = data.recipe
        meta._enhanced_native_can_build = meta.can_build
        meta._enhanced_original_build_state = meta.build_state
        meta._enhanced_auto_craftable = false
        meta._enhanced_cache_craftable = false
        meta._enhanced_search_enabled = false

        local eligible_state = not meta.can_build and
            (meta.build_state == "no_ingredients" or meta.build_state == "prototype")
        if eligible_state and MenuPolicy.CanSearchAndBuild(player, recipe) then
            meta._enhanced_search_enabled = true
            if MenuPolicy.HasCachedPlan(player, recipe, stock) then
                meta._enhanced_cache_craftable = true
            end
        end
    end
end

return MenuPolicy
