local ItemCatalog = require("dst-controller/items/item-catalog")

local scrapbook_data = {
    torch = { prefab = "torch", type = "item" },
    berries = { prefab = "berries", type = "food" },
    researchlab = { prefab = "researchlab", type = "thing" },
}

local prefabs = {
    torch = {},
    berries = {},
    researchlab = {},
    mod_wand = {},
    unowned_tool = {},
    hidden_fx = {},
    bee = {},
}

local player = {
    replica = {
        inventory = {
            GetItems = function()
                return { { prefab = "bee" } }
            end,
            GetEquips = function()
                return {}
            end,
            GetOverflowContainer = function()
                return nil
            end,
        },
    },
}

local catalog = ItemCatalog.Build({
    scrapbook_data = scrapbook_data,
    prefabs = prefabs,
    mods = { { Prefabs = { mod_wand = prefabs.mod_wand } } },
    player = player,
    names = {
        TORCH = "火炬",
        BERRIES = "浆果",
        MOD_WAND = "模组法杖",
        BEE = "蜜蜂",
    },
    aliases = {
        TORCH = { "Torch", "火炬" },
        BERRIES = { "Berries", "浆果" },
    },
    has_inventory_image = function(prefab_name)
        return prefab_name == "mod_wand" or prefab_name == "unowned_tool" or
            prefab_name == "researchlab"
    end,
})

assert(#ItemCatalog.Search(catalog, "torch") == 1,
    "internal item prefab names should be searchable")
assert(ItemCatalog.Search(catalog, "火炬")[1].prefab_name == "torch",
    "Chinese item names should be searchable")
assert(ItemCatalog.Search(catalog, "berries")[1].prefab_name == "berries",
    "English item aliases should be searchable")
assert(ItemCatalog.Search(catalog, "模组法杖")[1].prefab_name == "mod_wand",
    "registered mod prefabs should use their localized name")
assert(ItemCatalog.Search(catalog, "蜜蜂")[1].prefab_name == "bee",
    "items currently carried by the player should be included")
assert(ItemCatalog.Search(catalog, "unowned_tool")[1].prefab_name == "unowned_tool",
    "registered items should be searchable even when the player does not own them")
assert(#ItemCatalog.Search(catalog, "researchlab") == 0,
    "known non-item scrapbook entries should override inventory-icon guesses")
assert(#ItemCatalog.Search(catalog, "hidden_fx") == 0,
    "registered prefabs without item metadata or inventory icons should be excluded")
