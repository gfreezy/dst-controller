-- Enhanced Controller - Recursive, low-peak-slot crafting planner

local Policy = require("dst-controller/crafting/policy")

local Planner = {}

local function CopyCounts(source)
    local copy = {}
    for prefab, count in pairs(source or {}) do
        copy[prefab] = count
    end
    return copy
end

local function DefaultRound(value)
    return math.floor(value + 0.5)
end

local function GetIngredientAmount(ingredient, options)
    local ingredient_mod = options.ingredient_mod or 1
    local round = options.round or DefaultRound
    return math.max(1, round(ingredient.amount * ingredient_mod))
end

local function GetYield(recipe, options)
    if options.get_yield ~= nil then
        return math.max(1, options.get_yield(recipe) or 1)
    end
    return math.max(1, recipe.numtogive or 1)
end

local function GetMaxStack(prefab, options)
    if options.get_max_stack ~= nil then
        return math.max(1, options.get_max_stack(prefab) or 1)
    end
    return 40
end

local function CountSlots(counts, options)
    local slots = options.base_slots or 0
    for prefab, count in pairs(counts) do
        if count > 0 then
            local max_stack = GetMaxStack(prefab, options)
            slots = slots + (max_stack == math.huge and 1 or math.ceil(count / max_stack))
        end
    end
    return slots
end

local function ResolveRecipe(prefab, options)
    local recipe = options.resolve_recipe(prefab)
    if recipe == nil then
        return nil, "NO_RECIPE"
    end

    local candidates = { recipe }
    if recipe.forward_ingredients ~= nil then
        for _, recipe_name in ipairs(recipe.forward_ingredients) do
            local forwarded = options.resolve_recipe(recipe_name)
            if forwarded ~= nil then
                table.insert(candidates, forwarded)
            end
        end
    end

    local last_reason = nil
    for _, candidate in ipairs(candidates) do
        local can_craft, reason = options.can_craft_recipe(candidate)
        if can_craft and candidate.product == prefab and
            candidate.placer == nil and not candidate.manufactured then
            return candidate
        end
        if reason ~= nil then
            last_reason = reason
        end
    end
    return nil, last_reason or "RECIPE_UNAVAILABLE"
end

local function EstimateRecipePeak(prefab, options, visiting, depth)
    if depth > Policy.MAX_RECIPE_DEPTH or visiting[prefab] then
        return math.huge
    end

    local recipe = options.resolve_recipe(prefab)
    if recipe == nil or recipe.placer ~= nil or recipe.manufactured then
        return 1
    end

    visiting[prefab] = true
    local child_peaks = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        table.insert(child_peaks, EstimateRecipePeak(ingredient.type, options, visiting, depth + 1))
    end
    visiting[prefab] = nil

    table.sort(child_peaks, function(a, b) return a > b end)
    local peak = 1
    for index, child_peak in ipairs(child_peaks) do
        peak = math.max(peak, child_peak + index - 1)
    end
    return peak
end

local function SortIngredients(recipe, options)
    local ingredients = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        table.insert(ingredients, ingredient)
    end
    table.sort(ingredients, function(a, b)
        local a_peak = EstimateRecipePeak(a.type, options, {}, 1)
        local b_peak = EstimateRecipePeak(b.type, options, {}, 1)
        if a_peak == b_peak then
            return tostring(a.type) < tostring(b.type)
        end
        return a_peak > b_peak
    end)
    return ingredients
end

function Planner.Build(recipe, owned_counts, external_counts, options)
    options = options or {}
    assert(options.resolve_recipe ~= nil, "resolve_recipe is required")
    assert(options.can_craft_recipe ~= nil, "can_craft_recipe is required")

    local final_access, final_reason = options.can_craft_recipe(recipe)
    if not final_access then
        return nil, final_reason or "FINAL_RECIPE_UNAVAILABLE"
    end

    local state = {
        inventory = CopyCounts(owned_counts),
        external = CopyCounts(external_counts),
        steps = {},
        needed_prefabs = {},
        peak_slots = CountSlots(owned_counts or {}, options),
        options = options,
    }

    local function RecordStep(step)
        table.insert(state.steps, step)
        state.peak_slots = math.max(state.peak_slots, CountSlots(state.inventory, options))
    end

    local function Acquire(prefab, amount)
        local available = state.external[prefab] or 0
        local take = math.min(available, amount)
        if take > 0 then
            state.external[prefab] = available - take
            state.inventory[prefab] = (state.inventory[prefab] or 0) + take
            state.needed_prefabs[prefab] = true
            RecordStep({ kind = "acquire", prefab = prefab, amount = take })
        end
        return take
    end

    local EnsureAvailable
    EnsureAvailable = function(prefab, amount, visiting, depth)
        state.needed_prefabs[prefab] = true
        local present = state.inventory[prefab] or 0
        if present >= amount then
            return true
        end

        Acquire(prefab, amount - present)
        present = state.inventory[prefab] or 0
        if present >= amount then
            return true
        end

        if depth > Policy.MAX_RECIPE_DEPTH then
            return false, "RECIPE_DEPTH"
        elseif visiting[prefab] then
            return false, "RECIPE_CYCLE"
        end

        local ingredient_recipe, unavailable_reason = ResolveRecipe(prefab, options)
        if ingredient_recipe == nil then
            return false, unavailable_reason or "MISSING_MATERIAL"
        end

        visiting[prefab] = true
        local yield = GetYield(ingredient_recipe, options)
        local crafts = math.ceil((amount - present) / yield)
        local sorted_ingredients = SortIngredients(ingredient_recipe, options)

        for _ = 1, crafts do
            -- Finish the most slot-expensive child first. Each completed child is
            -- immediately collapsed into its parent as soon as the batch is ready.
            for _, ingredient in ipairs(sorted_ingredients) do
                local required = GetIngredientAmount(ingredient, options)
                local ok, reason = EnsureAvailable(ingredient.type, required, visiting, depth + 1)
                if not ok then
                    visiting[prefab] = nil
                    return false, reason
                end
            end

            for _, ingredient in ipairs(sorted_ingredients) do
                local required = GetIngredientAmount(ingredient, options)
                state.inventory[ingredient.type] = (state.inventory[ingredient.type] or 0) - required
            end
            state.inventory[prefab] = (state.inventory[prefab] or 0) + yield
            RecordStep({
                kind = "craft",
                recipe = ingredient_recipe,
                product = prefab,
                amount = yield,
            })
        end

        visiting[prefab] = nil
        return (state.inventory[prefab] or 0) >= amount, "MISSING_MATERIAL"
    end

    local final_ingredients = SortIngredients(recipe, options)

    -- Reserve every directly available final ingredient before expanding its
    -- deficit. This guarantees that existing boards/cut stone win over logs/rocks.
    for _, ingredient in ipairs(final_ingredients) do
        local required = GetIngredientAmount(ingredient, options)
        local missing = required - (state.inventory[ingredient.type] or 0)
        if missing > 0 then
            Acquire(ingredient.type, missing)
        end
    end

    for _, ingredient in ipairs(final_ingredients) do
        local required = GetIngredientAmount(ingredient, options)
        local ok, reason = EnsureAvailable(ingredient.type, required, {}, 1)
        if not ok then
            return nil, reason, {
                prefab = ingredient.type,
                amount = required,
                available = state.inventory[ingredient.type] or 0,
            }
        end
    end

    RecordStep({ kind = "finish", recipe = recipe })

    return {
        recipe = recipe,
        steps = state.steps,
        needed_prefabs = state.needed_prefabs,
        estimated_peak_slots = state.peak_slots,
        remaining_external = state.external,
    }
end

return Planner
