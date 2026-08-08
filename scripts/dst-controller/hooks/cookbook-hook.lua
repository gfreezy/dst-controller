-- Enhanced Controller - Search & Cook button for the native cookbook.

local G = require("dst-controller/global")
local ContainerCache = require("dst-controller/crafting/container-cache")
local Planner = require("dst-controller/cooking/planner")
local Coordinator = require("dst-controller/cooking/coordinator")
local L = require("dst-controller/localization").L
local ControlMode = require("dst-controller/utils/control-mode")

local CookbookHook = {}

local function CopyRecipes(recipes)
    local result = {}
    for recipe_index, ingredients in ipairs(recipes or {}) do
        local copy = {}
        for ingredient_index, prefab in ipairs(ingredients) do
            copy[ingredient_index] = prefab
        end
        result[recipe_index] = copy
    end
    return result
end

local function ApplyFocus(page)
    if page.recipe_grid == nil then
        return
    end
    local button = page._enhanced_cook_button
    page.recipe_grid:SetFocusChangeDir(G.MOVE_RIGHT, button)
    if button ~= nil then
        button:SetFocusChangeDir(G.MOVE_LEFT, page.recipe_grid)
        button:SetFocusChangeDir(G.MOVE_UP, page.recipe_grid)
        button:SetFocusChangeDir(G.MOVE_DOWN, page.recipe_grid)
    end
end

local function CanAddButton(page, data, cooker_prefabs)
    return ControlMode.IsControllerActive() and
        G.ThePlayer ~= nil and G.TheWorld ~= nil and
        page.parent_screen == G.ThePlayer and
        data ~= nil and data.unlocked and
        type(data.recipes) == "table" and #data.recipes > 0 and
        #cooker_prefabs > 0
end

function CookbookHook.Install()
    ContainerCache.Initialize()
    G.AddClassPostConstruct(
        "widgets/redux/cookbookpage_crockpot", function(page)
            local TEMPLATES = require("widgets/redux/templates")
            local cooking = require("cooking")
            local old_PopulateRecipeDetailPanel =
                page.PopulateRecipeDetailPanel
            local old_DoFocusHookups = page._DoFocusHookups

            page.PopulateRecipeDetailPanel = function(self, data)
                self._enhanced_cook_button = nil
                local root = old_PopulateRecipeDetailPanel(self, data)
                local cooker_prefabs = Planner.ResolveCookerPrefabs(
                    cooking, data and data.prefab)
                if CanAddButton(self, data, cooker_prefabs) then
                    local request = {
                        product = data.prefab,
                        recipes = CopyRecipes(data.recipes),
                        cooker_prefabs = cooker_prefabs,
                    }
                    local button
                    button = root:AddChild(TEMPLATES.StandardButton(function()
                        if not ControlMode.IsControllerActive() then
                            return
                        end
                        if button ~= nil then
                            button:Disable()
                        end
                        local player = G.ThePlayer
                        G.TheFrontEnd:PopScreen()
                        if player ~= nil and player:IsValid() then
                            player:DoTaskInTime(0, function()
                                if player:IsValid() then
                                    Coordinator.Start(player, request)
                                end
                            end)
                        end
                    end, L("SEARCH_AND_COOK"), { 180, 42 }))
                    button:SetPosition(0, -218)
                    self._enhanced_cook_button = button
                end
                ApplyFocus(self)
                return root
            end

            page._DoFocusHookups = function(self, ...)
                local result = old_DoFocusHookups(self, ...)
                ApplyFocus(self)
                return result
            end

            -- The constructor populated the selected detail before this hook
            -- was attached, so rebuild that one panel once.
            local cookbook = G.TheCookbook
            local selected_index = cookbook ~= nil and
                cookbook.selected ~= nil and
                cookbook.selected[page.category] or 1
            local selected = page.all_recipes and
                page.all_recipes[selected_index]
            if selected ~= nil and page.details_root ~= nil then
                page.details_root:KillAllChildren()
                page.details_root:AddChild(
                    page:PopulateRecipeDetailPanel(selected))
            end
            ApplyFocus(page)
        end)
end

return CookbookHook
