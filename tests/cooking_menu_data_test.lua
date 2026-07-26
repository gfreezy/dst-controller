local MenuData = require("dst-controller/cooking/menu-data")

local products = MenuData.Build({
    recipes = {
        cookpot = {
            meatballs = { priority = -1 },
            kabobs = { priority = 5 },
        },
        portablecookpot = {
            meatballs = { priority = -1 },
            voltgoatjelly = { priority = 10 },
        },
        portablespicer = {
            meatballs_spice_salt = { priority = 0 },
        },
    },
}, {
    MEATBALLS = "Meatballs",
    KABOBS = "Kabobs",
    VOLTGOATJELLY = "Volt Goat Chaud-Froid",
})

assert(#products == 3,
    "the menu should list all cooker products without cookbook unlock data")
assert(products[1].prefab == "kabobs" and
    products[2].prefab == "meatballs",
    "products should be sorted by localized name")
assert(table.concat(products[2].cooker_prefabs, ",") ==
    "cookpot,portablecookpot",
    "duplicate products should merge compatible cookers")
for _, product in ipairs(products) do
    assert(product.prefab ~= "meatballs_spice_salt",
        "spicer-only recipes do not belong in the four-slot cooking list")
end

local CookingActions = require("dst-controller/actions/cooking")
local toggles = 0
CookingActions.toggle_cooking_menu({
    HUD = {
        controls = {
            enhanced_cooking_menu = {
                Toggle = function()
                    toggles = toggles + 1
                end,
            },
        },
    },
})
assert(toggles == 1,
    "the configurable action should toggle the HUD cooking list")
