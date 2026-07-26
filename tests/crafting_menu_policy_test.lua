local stock = {
    owned = {},
    external = {},
    max_stacks = {},
    unknown_containers = { {} },
}
local planned = false
local can_use = true
local has_ingredients = false

package.loaded["dst-controller/crafting/material-finder"] = {
    BuildMenuStock = function() return stock end,
}
package.loaded["dst-controller/crafting/coordinator"] = {
    CanUseRecipe = function() return can_use end,
    BuildPlan = function() return planned and {} or nil end,
}
package.loaded["dst-controller/crafting/menu-policy"] = nil

local MenuPolicy = require("dst-controller/crafting/menu-policy")
local player = {
    replica = {
        builder = {
            IsBuildBuffered = function() return false end,
            HasIngredients = function() return has_ingredients end,
        },
    },
}
local recipe = { name = "test_recipe" }

assert(MenuPolicy.CanSearchAndBuild(player, recipe),
    "an eligible recipe must allow a verified search regardless of cache contents")
assert(not MenuPolicy.HasCachedPlan(player, recipe),
    "unknown-only stock must not be colored as cache-craftable")

stock.unknown_containers = {}
assert(not MenuPolicy.HasCachedPlan(player, recipe),
    "known insufficient sources must retain the missing-material color")
assert(MenuPolicy.CanSearchAndBuild(player, recipe),
    "known insufficient cache results must not disable Search & Build")

local insufficient_data = {
    meta = { can_build = false, build_state = "no_ingredients" },
    recipe = recipe,
}
MenuPolicy.ApplyToRecipeStates(player, { insufficient_data })
assert(insufficient_data.meta._enhanced_search_enabled,
    "an insufficient recipe should expose the Search & Build action")
assert(not insufficient_data.meta.can_build and
    not insufficient_data.meta._enhanced_cache_craftable,
    "search availability must not change the cache-derived missing-material color")

planned = true
assert(MenuPolicy.HasCachedPlan(player, recipe),
    "a complete cached material plan must enable automatic crafting")

local data = {
    meta = { can_build = false, build_state = "no_ingredients" },
    recipe = recipe,
}
MenuPolicy.ApplyToRecipeStates(player, { data })
assert(not data.meta.can_build and data.meta._enhanced_cache_craftable,
    "a known plan should request a buildable color without changing native state")
assert(data.meta._enhanced_search_enabled,
    "a known plan should still use the verified Search & Build flow")
MenuPolicy.RestoreRecipeStates({ data })
assert(not data.meta.can_build and data.meta.build_state == "no_ingredients",
    "recipe rebuilds should restore the native state before recalculation")
assert(not data.meta._enhanced_cache_craftable and
    not data.meta._enhanced_search_enabled,
    "recipe rebuilds should clear cache-colour and search flags")

can_use = false
assert(not MenuPolicy.CanSearchAndBuild(player, recipe),
    "recipes blocked by character or technology requirements must remain unavailable")

can_use = true
has_ingredients = true
assert(not MenuPolicy.CanSearchAndBuild(player, recipe),
    "native-ready recipes should continue through the native crafting path")
