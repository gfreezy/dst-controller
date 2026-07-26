local Planner = require("dst-controller/cooking/planner")

local recipes = {
    { "meat", "meat", "berries", "twigs" },
    { "monstermeat", "berries", "berries", "berries" },
}

local function CalculateRecipe(cooker, ingredients)
    if cooker == "cookpot" and ingredients[1] == "meat" then
        return "kabobs"
    elseif cooker == "portablecookpot" and ingredients[1] == "monstermeat" then
        return "monster_special"
    end
    return "wetgoop"
end

local plan = Planner.Find("kabobs", recipes, {
    meat = 2,
    berries = 1,
    twigs = 1,
}, "cookpot", CalculateRecipe)
assert(plan ~= nil and #plan.ingredients == 4,
    "an available discovered recipe should produce a cooking plan")
assert(plan.required.meat == 2 and plan.required.twigs == 1,
    "duplicate ingredients should be counted exactly")

assert(Planner.Find("kabobs", recipes, {
    meat = 1,
    berries = 10,
    twigs = 1,
}, "cookpot", CalculateRecipe) == nil,
    "partial ingredient counts must not produce a plan")

assert(Planner.Find("kabobs", recipes, {
    meat = 2,
    berries = 1,
    twigs = 1,
}, "portablecookpot", CalculateRecipe) == nil,
    "the combination must be revalidated for the selected cooker")

local cooker_prefabs = Planner.ResolveCookerPrefabs({
    recipes = {
        portablecookpot = { kabobs = {} },
        cookpot = { kabobs = {} },
        archive_cookpot = { kabobs = {} },
        unrelated = { other_food = {} },
    },
}, "kabobs")
assert(table.concat(cooker_prefabs, ",") ==
    "cookpot,archive_cookpot,portablecookpot",
    "compatible cookers should be stable and prefer common nearby pots")
