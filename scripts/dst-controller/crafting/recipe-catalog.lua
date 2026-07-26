-- Searchable recipe catalog used by the task action editor.
-- The catalog is built from AllRecipes at runtime so recipes added by other
-- mods are available without maintaining a fixed preset list.

local RecipeCatalog = {}

local function Normalize(value)
    if value == nil then
        return ""
    end

    local normalized = string.lower(tostring(value))
        :gsub("[_%-]+", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    return normalized
end

local function AddUnique(values, seen, value)
    if value == nil or value == "" or seen[value] then
        return
    end

    seen[value] = true
    table.insert(values, value)
end

local function GetNameKey(recipe)
    local name = recipe.nameoverride or recipe.name or recipe.product
    return name and string.upper(name) or nil
end

local function GetLocalizedName(recipe, names)
    local name_key = GetNameKey(recipe)
    local product_key = recipe.product and string.upper(recipe.product) or nil
    return (name_key and names[name_key])
        or (product_key and names[product_key])
        or recipe.name
        or recipe.product
end

local function GetBilingualNames(recipe, aliases)
    local candidates = {}
    if recipe.nameoverride then table.insert(candidates, recipe.nameoverride) end
    if recipe.name then table.insert(candidates, recipe.name) end
    if recipe.product then table.insert(candidates, recipe.product) end

    for _, candidate in ipairs(candidates) do
        local alias = candidate and aliases[string.upper(candidate)] or nil
        if alias then
            return alias[1], alias[2]
        end
    end

    return nil, nil
end

local function IsMatch(entry, query)
    if query == "" then
        return true
    end

    for token in string.gmatch(query, "%S+") do
        if not string.find(entry.search_text, token, 1, true) then
            return false
        end
    end

    return true
end

local function GetMatchScore(entry, query)
    if query == "" then
        return 4
    end

    if entry.normalized_recipe_name == query then
        return 0
    end

    for _, name in ipairs(entry.normalized_names) do
        if name == query then
            return 0
        end
    end

    if string.sub(entry.normalized_recipe_name, 1, #query) == query then
        return 1
    end

    for _, name in ipairs(entry.normalized_names) do
        if string.sub(name, 1, #query) == query then
            return 2
        end
    end

    return 3
end

---Build a recipe catalog from the currently loaded recipes.
---@param all_recipes table<string, table>
---@param names table<string, string>|nil Current-language STRINGS.NAMES table.
---@param aliases table<string, table>|nil Bilingual aliases keyed by STRINGS.NAMES key.
---@param is_valid fun(recipe_name: string): boolean|nil Optional game-mode validity filter.
---@return table
function RecipeCatalog.Build(all_recipes, names, aliases, is_valid)
    names = names or {}
    aliases = aliases or {}

    local entries = {}
    for recipe_key, recipe in pairs(all_recipes or {}) do
        if type(recipe) == "table" then
            local recipe_name = recipe.name or recipe_key
            local valid = type(recipe_name) == "string" and recipe_name ~= ""
            if valid and is_valid then
                valid = is_valid(recipe_name) == true
            end

            if valid then
                local localized_name = GetLocalizedName(recipe, names) or recipe_name
                local english_name, chinese_name = GetBilingualNames(recipe, aliases)
                local search_values = {}
                local seen = {}

                AddUnique(search_values, seen, recipe_name)
                AddUnique(search_values, seen, recipe.product)
                AddUnique(search_values, seen, recipe.nameoverride)
                AddUnique(search_values, seen, localized_name)
                AddUnique(search_values, seen, english_name)
                AddUnique(search_values, seen, chinese_name)

                local normalized_names = {}
                local normalized_seen = {}
                for _, value in ipairs(search_values) do
                    local normalized = Normalize(value)
                    AddUnique(normalized_names, normalized_seen, normalized)
                end

                local display_text = localized_name
                if Normalize(localized_name) ~= Normalize(recipe_name) then
                    display_text = string.format("%s (%s)", localized_name, recipe_name)
                end

                table.insert(entries, {
                    recipe_name = recipe_name,
                    product = recipe.product,
                    localized_name = localized_name,
                    english_name = english_name,
                    chinese_name = chinese_name,
                    display_text = display_text,
                    normalized_recipe_name = Normalize(recipe_name),
                    normalized_names = normalized_names,
                    search_text = table.concat(normalized_names, "\n"),
                })
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.display_text == b.display_text then
            return a.recipe_name < b.recipe_name
        end
        return a.display_text < b.display_text
    end)

    return entries
end

---Return matching entries, with exact and prefix matches first.
---@param entries table
---@param query string|nil
---@param limit number|nil
---@return table
function RecipeCatalog.Search(entries, query, limit)
    local normalized_query = Normalize(query)
    local matches = {}

    for _, entry in ipairs(entries or {}) do
        if IsMatch(entry, normalized_query) then
            table.insert(matches, {
                entry = entry,
                score = GetMatchScore(entry, normalized_query),
            })
        end
    end

    table.sort(matches, function(a, b)
        if a.score ~= b.score then
            return a.score < b.score
        end
        if a.entry.display_text ~= b.entry.display_text then
            return a.entry.display_text < b.entry.display_text
        end
        return a.entry.recipe_name < b.entry.recipe_name
    end)

    local results = {}
    local count = limit and math.min(#matches, limit) or #matches
    for index = 1, count do
        table.insert(results, matches[index].entry)
    end

    return results, #matches
end

function RecipeCatalog.Find(entries, recipe_name)
    for _, entry in ipairs(entries or {}) do
        if entry.recipe_name == recipe_name then
            return entry
        end
    end
end

function RecipeCatalog.ToSpinnerOptions(entries)
    local options = {}
    for _, entry in ipairs(entries or {}) do
        table.insert(options, {
            data = entry.recipe_name,
            text = entry.display_text,
        })
    end
    return options
end

return RecipeCatalog
