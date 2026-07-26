-- Pure data builder for the half-screen cooking menu.

local MenuData = {}

local EXCLUDED_COOKERS = {
    portablespicer = true,
}

local function ProductName(names, prefab)
    local value = names and names[string.upper(prefab)]
    return type(value) == "string" and value or prefab
end

function MenuData.Build(cooking_api, names)
    local by_product = {}
    for cooker_prefab, recipes in pairs(
        cooking_api and cooking_api.recipes or {}) do
        if not EXCLUDED_COOKERS[cooker_prefab] and type(recipes) == "table" then
            for product, recipe_def in pairs(recipes) do
                if type(product) == "string" and type(recipe_def) == "table" then
                    local data = by_product[product]
                    if data == nil then
                        data = {
                            prefab = product,
                            name = ProductName(names, product),
                            recipe_def = recipe_def,
                            cooker_prefabs = {},
                        }
                        by_product[product] = data
                    end
                    table.insert(data.cooker_prefabs, cooker_prefab)
                end
            end
        end
    end

    local priority = {
        cookpot = 1,
        archive_cookpot = 2,
        portablecookpot = 3,
    }
    local products = {}
    for _, data in pairs(by_product) do
        table.sort(data.cooker_prefabs, function(a, b)
            local a_priority = priority[a] or 100
            local b_priority = priority[b] or 100
            return a_priority < b_priority or
                (a_priority == b_priority and a < b)
        end)
        table.insert(products, data)
    end
    table.sort(products, function(a, b)
        local a_name = string.lower(a.name)
        local b_name = string.lower(b.name)
        return a_name < b_name or
            (a_name == b_name and a.prefab < b.prefab)
    end)
    return products
end

return MenuData
