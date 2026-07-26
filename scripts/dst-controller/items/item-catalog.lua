-- Searchable item-prefab catalog for parameterized inventory actions.

local SearchCatalog = require("dst-controller/crafting/recipe-catalog")

local ItemCatalog = {}

local function AddItem(candidates, prefab_name, prefabs, allow_unknown)
    if type(prefab_name) ~= "string" or prefab_name == "" then
        return
    end

    local prefab = prefabs and prefabs[prefab_name] or nil
    if prefab and prefab.is_skin then
        return
    end
    if prefabs and not prefab and not allow_unknown then
        return
    end
    if string.sub(prefab_name, 1, 4) == "MOD_" then
        return
    end

    candidates[prefab_name] = {
        name = prefab_name,
        product = prefab_name,
    }
end

local function AddInventoryItems(candidates, items, prefabs)
    for _, item in pairs(items or {}) do
        if item and item.prefab then
            AddItem(candidates, item.prefab, prefabs, true)
        end
    end
end

local function CollectPlayerItems(candidates, player, prefabs)
    local inventory = player
        and player.replica
        and player.replica.inventory
        or nil
    if not inventory then
        return
    end

    if inventory.GetItems then
        AddInventoryItems(candidates, inventory:GetItems(), prefabs)
    end
    if inventory.GetEquips then
        AddInventoryItems(candidates, inventory:GetEquips(), prefabs)
    end

    local overflow = inventory.GetOverflowContainer
        and inventory:GetOverflowContainer()
        or nil
    if overflow then
        local overflow_items = overflow.GetItems and overflow:GetItems() or nil
        if (not overflow_items or next(overflow_items) == nil)
                and overflow.classified
                and overflow.classified.GetItems then
            overflow_items = overflow.classified:GetItems()
        end
        AddInventoryItems(candidates, overflow_items, prefabs)
    end
end

local function HasInventoryImage(check_image, prefab_name)
    if type(check_image) ~= "function" then
        return false
    end
    local ok, has_image = pcall(check_image, prefab_name)
    return ok and has_image == true
end

local function AddRegisteredItems(candidates, registered_prefabs, scrapbook_types,
                                  check_image)
    for prefab_name in pairs(registered_prefabs or {}) do
        -- Scrapbook type data is authoritative when it exists. For prefabs not
        -- represented there (especially mod items), an inventory icon is the
        -- safest client-side signal that the prefab can be carried.
        if scrapbook_types[prefab_name] == nil and
            HasInventoryImage(check_image, prefab_name) then
            AddItem(candidates, prefab_name, registered_prefabs, true)
        end
    end
end

---Build the inventory-item catalog from current game data.
---The scrapbook supplies every known vanilla item/food independent of player
---ownership. Registered prefabs with inventory icons cover mod items, while
---currently carried items remain a fallback for unusual prefabs.
---@param options table
---@return table
function ItemCatalog.Build(options)
    options = options or {}
    local candidates = {}
    local prefabs = options.prefabs
    local scrapbook_types = {}

    for key, entry in pairs(options.scrapbook_data or {}) do
        if type(entry) == "table" then
            local prefab_name = entry.prefab or key
            scrapbook_types[prefab_name] = entry.type or false
            if entry.type == "item" or entry.type == "food" then
                -- Scrapbook membership is already sufficient validation; do not
                -- require the item to be loaded or currently owned.
                AddItem(candidates, prefab_name, prefabs, true)
            end
        end
    end

    AddRegisteredItems(candidates, prefabs, scrapbook_types,
        options.has_inventory_image)
    for _, mod in ipairs(options.mods or {}) do
        AddRegisteredItems(candidates, mod.Prefabs, scrapbook_types,
            options.has_inventory_image)
    end

    CollectPlayerItems(candidates, options.player, prefabs)

    local entries = SearchCatalog.Build(
        candidates,
        options.names,
        options.aliases
    )
    for _, entry in ipairs(entries) do
        entry.prefab_name = entry.recipe_name
    end
    return entries
end

ItemCatalog.Search = SearchCatalog.Search
ItemCatalog.ToSpinnerOptions = SearchCatalog.ToSpinnerOptions

return ItemCatalog
