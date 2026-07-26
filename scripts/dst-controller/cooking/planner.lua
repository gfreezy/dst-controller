-- Pure planning helpers for Search & Cook.

local Planner = {}

local INGREDIENT_ALIASES = {
    cookedsmallmeat = "smallmeat_cooked",
    cookedmonstermeat = "monstermeat_cooked",
    cookedmeat = "meat_cooked",
}

local MAX_DYNAMIC_COMBINATIONS = 50000

local function CountIngredients(ingredients)
    local required = {}
    for _, prefab in ipairs(ingredients or {}) do
        if type(prefab) ~= "string" or prefab == "" then
            return nil
        end
        required[prefab] = (required[prefab] or 0) + 1
    end
    return required
end

local function HasRequiredCounts(required, available)
    for prefab, amount in pairs(required) do
        if (available[prefab] or 0) < amount then
            return false
        end
    end
    return true
end

---Find a discovered four-slot combination that is both available and valid for
---the selected cooker. calculate_recipe mirrors cooking.CalculateRecipe.
function Planner.Find(product, discovered_recipes, available, cooker_prefab,
                      calculate_recipe)
    if type(product) ~= "string" or type(discovered_recipes) ~= "table" or
        type(available) ~= "table" or type(calculate_recipe) ~= "function" then
        return nil, "invalid_request"
    end

    for _, ingredients in ipairs(discovered_recipes) do
        if type(ingredients) == "table" and #ingredients == 4 then
            local required = CountIngredients(ingredients)
            if required ~= nil and HasRequiredCounts(required, available) then
                local ok, calculated_product = pcall(
                    calculate_recipe, cooker_prefab, ingredients)
                if ok and calculated_product == product then
                    local copy = {}
                    for index, prefab in ipairs(ingredients) do
                        copy[index] = prefab
                    end
                    return {
                        product = product,
                        cooker_prefab = cooker_prefab,
                        ingredients = copy,
                        required = required,
                    }
                end
            end
        end
    end
    return nil, "insufficient_ingredients"
end

local function IsCookingIngredient(cooking_api, prefab)
    if type(cooking_api.IsCookingIngredient) ~= "function" then
        return false
    end
    local ok, result = pcall(cooking_api.IsCookingIngredient, prefab)
    return ok and result == true
end

local function BuildIngredientData(cooking_api, combination)
    local names = {}
    local tags = {}
    for _, prefab in ipairs(combination) do
        local normalized = INGREDIENT_ALIASES[prefab] or prefab
        names[normalized] = (names[normalized] or 0) + 1
        local ingredient = cooking_api.ingredients and
            cooking_api.ingredients[normalized]
        for tag, value in pairs(ingredient and ingredient.tags or {}) do
            tags[tag] = (tags[tag] or 0) + value
        end
    end
    return names, tags
end

-- CalculateRecipe deliberately randomizes between recipes with the same top
-- priority. Automatic cooking only accepts a combination where the selected
-- product is the unique highest-priority result.
local function MakesProductDeterministically(product, cooker_prefab,
                                              combination, cooking_api)
    local cooker_recipes = cooking_api.recipes and
        cooking_api.recipes[cooker_prefab]
    local target = cooker_recipes and cooker_recipes[product]
    if type(target) ~= "table" or type(target.test) ~= "function" then
        return false
    end

    local names, tags = BuildIngredientData(cooking_api, combination)
    local ok, matches = pcall(target.test, cooker_prefab, names, tags)
    if not ok or not matches then
        return false
    end

    local target_priority = target.priority or 0
    for recipe_name, recipe in pairs(cooker_recipes) do
        if recipe_name ~= product and type(recipe) == "table" and
            type(recipe.test) == "function" and
            (recipe.priority or 0) >= target_priority then
            local recipe_ok, recipe_matches = pcall(
                recipe.test, cooker_prefab, names, tags)
            if recipe_ok and recipe_matches then
                return false
            end
        end
    end
    return true
end

---Find a deterministic four-slot combination directly from nearby available
---ingredients. This does not use TheCookbook or require a discovered recipe.
function Planner.FindAvailable(product, available, cooker_prefab, cooking_api)
    if type(product) ~= "string" or type(available) ~= "table" or
        type(cooker_prefab) ~= "string" or type(cooking_api) ~= "table" then
        return nil, "invalid_request"
    end

    local candidates = {}
    for prefab, count in pairs(available) do
        if type(prefab) == "string" and type(count) == "number" and
            count > 0 and IsCookingIngredient(cooking_api, prefab) then
            table.insert(candidates, {
                prefab = prefab,
                count = math.floor(count),
            })
        end
    end
    table.sort(candidates, function(a, b)
        -- Try plentiful ingredients first to find common recipes quickly and
        -- avoid spending scarce alternatives where possible.
        return a.count > b.count or
            (a.count == b.count and a.prefab < b.prefab)
    end)

    local combination = {}
    local tested = 0
    local function Search(start_index, slot)
        if tested >= MAX_DYNAMIC_COMBINATIONS then
            return nil
        elseif slot == 5 then
            tested = tested + 1
            if MakesProductDeterministically(product, cooker_prefab,
                    combination, cooking_api) then
                local ingredients = {}
                for index = 1, 4 do
                    ingredients[index] = combination[index]
                end
                return {
                    product = product,
                    cooker_prefab = cooker_prefab,
                    ingredients = ingredients,
                    required = CountIngredients(ingredients),
                }
            end
            return nil
        end

        for index = start_index, #candidates do
            local candidate = candidates[index]
            local used = 0
            for previous = 1, slot - 1 do
                if combination[previous] == candidate.prefab then
                    used = used + 1
                end
            end
            if used < candidate.count then
                combination[slot] = candidate.prefab
                local plan = Search(index, slot + 1)
                if plan ~= nil then
                    return plan
                end
            end
        end
        combination[slot] = nil
        return nil
    end

    local plan = Search(1, 1)
    return plan, plan ~= nil and nil or "insufficient_ingredients"
end

function Planner.ResolveCookerPrefabs(cooking_api, product)
    local result = {}
    for cooker_prefab, recipes in pairs(
        cooking_api and cooking_api.recipes or {}) do
        if type(recipes) == "table" and recipes[product] ~= nil then
            table.insert(result, cooker_prefab)
        end
    end
    table.sort(result, function(a, b)
        local priority = {
            cookpot = 1,
            archive_cookpot = 2,
            portablecookpot = 3,
        }
        local a_priority = priority[a] or 100
        local b_priority = priority[b] or 100
        return a_priority < b_priority or
            (a_priority == b_priority and a < b)
    end)
    return result
end

return Planner
