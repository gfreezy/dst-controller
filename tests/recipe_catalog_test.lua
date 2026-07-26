local RecipeCatalog = require("dst-controller/crafting/recipe-catalog")
local VanillaAliases = require("dst-controller/crafting/recipe-aliases")

assert(VanillaAliases.RESEARCHLAB[1] == "Science Machine"
        and VanillaAliases.RESEARCHLAB[2] == "科学机器",
    "generated vanilla aliases should contain both languages")

local recipes = {
    torch = { name = "torch", product = "torch" },
    researchlab = { name = "researchlab", product = "researchlab" },
    mod_recipe = {
        name = "mod_recipe",
        product = "mod_product",
        nameoverride = "mod_display_name",
    },
    invalid_recipe = { name = "invalid_recipe", product = "invalid_recipe" },
}

local names = {
    TORCH = "火炬",
    RESEARCHLAB = "科学机器",
    MOD_DISPLAY_NAME = "模组工作台",
}

local aliases = {
    TORCH = { "Torch", "火炬" },
    RESEARCHLAB = { "Science Machine", "科学机器" },
}

local catalog = RecipeCatalog.Build(recipes, names, aliases, function(recipe_name)
    return recipe_name ~= "invalid_recipe"
end)

assert(#catalog == 3, "invalid recipes should be omitted")

local chinese_results = RecipeCatalog.Search(catalog, "科学机器")
assert(#chinese_results == 1 and chinese_results[1].recipe_name == "researchlab",
    "Chinese display names should be searchable")

local english_results = RecipeCatalog.Search(catalog, "science machine")
assert(#english_results == 1 and english_results[1].recipe_name == "researchlab",
    "English aliases should be searchable on a Chinese client")

local internal_results = RecipeCatalog.Search(catalog, "mod recipe")
assert(#internal_results == 1 and internal_results[1].recipe_name == "mod_recipe",
    "underscores and spaces should be normalized for internal-name search")

local mod_results = RecipeCatalog.Search(catalog, "模组")
assert(#mod_results == 1 and mod_results[1].recipe_name == "mod_recipe",
    "dynamically added mod recipes should use their current localized name")

local token_results = RecipeCatalog.Search(catalog, "machine science")
assert(#token_results == 1 and token_results[1].recipe_name == "researchlab",
    "multi-word searches should be token based")

local options = RecipeCatalog.ToSpinnerOptions(chinese_results)
assert(options[1].data == "researchlab", "spinner data must remain the canonical recipe name")
assert(string.find(options[1].text, "researchlab", 1, true),
    "spinner text should expose the canonical recipe name")
