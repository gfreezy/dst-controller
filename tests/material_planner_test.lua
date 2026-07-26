local Planner = require("dst-controller/crafting/material-planner")

local recipes = {}
recipes.board = {
    name = "board",
    product = "board",
    numtogive = 1,
    ingredients = {
        { type = "log", amount = 2 },
        { type = "twigs", amount = 1 },
    },
}
recipes.cutstone = {
    name = "cutstone",
    product = "cutstone",
    numtogive = 1,
    ingredients = { { type = "rocks", amount = 3 } },
}
recipes.machine = {
    name = "machine",
    product = "machine",
    placer = "machine_placer",
    ingredients = {
        { type = "board", amount = 2 },
        { type = "cutstone", amount = 1 },
    },
}

local options = {
    resolve_recipe = function(name) return recipes[name] end,
    can_craft_recipe = function() return true end,
    get_max_stack = function() return 40 end,
}

local plan = assert(Planner.Build(recipes.machine, {}, {
    board = 1,
    log = 2,
    twigs = 1,
    rocks = 3,
}, options))

assert(plan.steps[1].kind == "acquire" and plan.steps[1].prefab == "board",
    "existing direct material must be acquired before expanding its recipe")

local board_craft_index
local finish_index
for index, step in ipairs(plan.steps) do
    if step.kind == "craft" and step.product == "board" then
        board_craft_index = board_craft_index or index
    elseif step.kind == "finish" then
        finish_index = index
    end
end
assert(board_craft_index ~= nil, "missing board should be recursively crafted")
assert(finish_index == #plan.steps, "final recipe must be the final plan step")

local batch_plan = assert(Planner.Build({
    name = "double_board_target",
    product = "target",
    ingredients = { { type = "board", amount = 2 } },
}, {}, { log = 4, twigs = 2 }, options))

local first_board_craft
local second_log_acquire
local log_acquires = 0
for index, step in ipairs(batch_plan.steps) do
    if step.kind == "acquire" and step.prefab == "log" then
        log_acquires = log_acquires + 1
        if log_acquires == 2 then second_log_acquire = index end
    elseif step.kind == "craft" and step.product == "board" and first_board_craft == nil then
        first_board_craft = index
    end
end
assert(first_board_craft < second_log_acquire,
    "one intermediate batch should be crafted before acquiring the next batch")

recipes.loop_a = {
    name = "loop_a", product = "loop_a",
    ingredients = { { type = "loop_b", amount = 1 } },
}
recipes.loop_b = {
    name = "loop_b", product = "loop_b",
    ingredients = { { type = "loop_a", amount = 1 } },
}
local cycle_plan, cycle_reason = Planner.Build({
    name = "cycle_target", product = "cycle_target",
    ingredients = { { type = "loop_a", amount = 1 } },
}, {}, {}, options)
assert(cycle_plan == nil and cycle_reason == "RECIPE_CYCLE", "recipe cycles must terminate")
