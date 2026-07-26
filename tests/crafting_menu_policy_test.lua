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

assert(MenuPolicy.CanAutoCraft(player, recipe),
    "an unknown nearby container must optimistically enable automatic crafting")

stock.unknown_containers = {}
assert(not MenuPolicy.CanAutoCraft(player, recipe),
    "known insufficient sources must not be reported as automatic-craftable")

planned = true
assert(MenuPolicy.CanAutoCraft(player, recipe),
    "a complete cached material plan must enable automatic crafting")
