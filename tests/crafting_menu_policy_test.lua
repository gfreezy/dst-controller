local stock = {
    owned = {},
    external = {},
    max_stacks = {},
    unknown_containers = { {} },
}
local planned = false

package.loaded["dst-controller/crafting/material-finder"] = {
    BuildMenuStock = function() return stock end,
}
package.loaded["dst-controller/crafting/coordinator"] = {
    CanUseRecipe = function() return true end,
    BuildPlan = function() return planned and {} or nil end,
}
package.loaded["dst-controller/crafting/menu-policy"] = nil

local MenuPolicy = require("dst-controller/crafting/menu-policy")
local player = {
    replica = {
        builder = {
            IsBuildBuffered = function() return false end,
            HasIngredients = function() return false end,
        },
    },
}
local recipe = { name = "test_recipe" }

local can_search, search_required = MenuPolicy.CanAutoCraft(player, recipe)
assert(can_search,
    "an unknown nearby container must optimistically enable automatic crafting")
assert(search_required, "unknown-only stock should be labeled as a search, not a known plan")

stock.unknown_containers = {}
assert(not MenuPolicy.CanAutoCraft(player, recipe),
    "known insufficient sources must not be reported as automatic-craftable")

planned = true
local can_build, needs_search = MenuPolicy.CanAutoCraft(player, recipe)
assert(can_build,
    "a complete cached material plan must enable automatic crafting")
assert(not needs_search, "a complete known plan should be labeled as Auto Build")

local data = {
    meta = { can_build = false, build_state = "no_ingredients" },
    recipe = recipe,
}
MenuPolicy.ApplyToRecipeStates(player, { data })
assert(data.meta.can_build and data.meta._enhanced_auto_craftable,
    "a known plan should temporarily enable the native build state")
MenuPolicy.RestoreRecipeStates({ data })
assert(not data.meta.can_build and data.meta.build_state == "no_ingredients",
    "recipe rebuilds should restore the native state before recalculation")
