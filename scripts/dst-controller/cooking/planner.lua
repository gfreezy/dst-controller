-- Pure planning helpers for Search & Cook.

local Planner = {}

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
