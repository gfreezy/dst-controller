-- Enhanced Controller - CraftingMenu Hook
-- Hides the bottom layer that covers inventory bar and blocks right stick in virtual cursor mode

local G = require("dst-controller/global")
local Policy = require("dst-controller/crafting/policy")
local ContainerCache = require("dst-controller/crafting/container-cache")
local MenuPolicy = require("dst-controller/crafting/menu-policy")
local Coordinator = require("dst-controller/crafting/coordinator")
local L = require("dst-controller/localization").L

local CraftingMenuHook = {}

-- Install CraftingMenu hook
function CraftingMenuHook.Install()
    ContainerCache.Initialize()

    -- Route optimistic menu clicks into the verified coordinator. Native-ready
    -- recipes retain the original UI path and behavior.
    if not G.GetGlobal("ENHANCED_CONTROLLER_RECIPE_CLICK_INSTALLED") then
        local old_DoRecipeClick = G.GetGlobal("DoRecipeClick")
        if old_DoRecipeClick ~= nil then
            G.SetGlobal("ENHANCED_CONTROLLER_RECIPE_CLICK_INSTALLED", true)
            G.SetGlobal("DoRecipeClick", function(owner, recipe, skin)
                if recipe ~= nil and owner ~= nil and owner.replica ~= nil and
                    owner.replica.builder ~= nil and
                    not owner.replica.builder:HasIngredients(recipe) and
                    MenuPolicy.CanAutoCraft(owner, recipe) then
                    Coordinator.Start(owner, recipe, skin)
                    return true
                end
                return old_DoRecipeClick(owner, recipe, skin)
            end)
        end
    end

    -- Force focus back to inventory before opening craftmenu
    -- This ensures consistent behavior regardless of whether pinbar has focus
    G.AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(hud)
        local old_RebuildRecipes = hud.RebuildRecipes
        hud.RebuildRecipes = function(self, ...)
            local result = old_RebuildRecipes(self, ...)
            MenuPolicy.ApplyToRecipeStates(self.owner, self.valid_recipes)
            return result
        end

        -- The constructor builds once before post construction is installed.
        MenuPolicy.ApplyToRecipeStates(hud.owner, hud.valid_recipes)

        local old_OnUpdate = hud.OnUpdate
        hud._enhanced_cache_refresh_time = 0
        hud._enhanced_cache_position = nil
        hud.OnUpdate = function(self, dt)
            old_OnUpdate(self, dt)
            self._enhanced_cache_refresh_time = self._enhanced_cache_refresh_time + dt
            if self._enhanced_cache_refresh_time >= Policy.MENU_REFRESH_INTERVAL then
                self._enhanced_cache_refresh_time = 0
                local x, _, z = self.owner.Transform:GetWorldPosition()
                local cell = tostring(math.floor(x / 2)) .. ":" .. tostring(math.floor(z / 2))
                local changed = ContainerCache.UpdateOpenContainers(self.owner)
                if changed or cell ~= self._enhanced_cache_position then
                    self._enhanced_cache_position = cell
                    self:UpdateRecipes()
                end
            end
        end

        local old_Open = hud.Open

        hud.Open = function(self, search)
            -- If pinbar has focus in controller mode, move focus back to inventory first
            -- This makes behavior consistent with when pinbar doesn't have focus
            if G.TheInput:ControllerAttached() and self.pinbar and self.pinbar.focus then
                -- Access inventorybar through owner.HUD.controls.inv
                local inv = self.owner and self.owner.HUD and self.owner.HUD.controls and self.owner.HUD.controls.inv
                if inv and inv.SelectDefaultSlot then
                    inv:SelectDefaultSlot()
                end
            end

            -- Call original Open
            return old_Open(self, search)
        end

        print("[CraftingMenuHook] Installed CraftingMenuHUD:Open hook (restore inventory focus)")
    end)

    G.AddClassPostConstruct("widgets/redux/craftingmenu_details", function(details)
        local old_UpdateBuildButton = details.UpdateBuildButton
        details.UpdateBuildButton = function(self, ...)
            local result = old_UpdateBuildButton(self, ...)
            if self.data ~= nil and self.data.meta._enhanced_auto_craftable then
                local button = self.build_button_root and self.build_button_root.button
                local teaser = self.build_button_root and self.build_button_root.teaser
                if G.TheInput:ControllerAttached() then
                    if teaser ~= nil and teaser:IsVisible() then
                        teaser:SetString(G.TheInput:GetLocalizedControl(
                            G.TheInput:GetControllerID(), G.CONTROL_ACCEPT) .. " " .. L("AUTO_CRAFT"))
                    end
                elseif button ~= nil then
                    button:SetText(L("AUTO_CRAFT"))
                    button:Enable()
                end
            end
            return result
        end
    end)

    -- Hide pinbar help text by returning empty string
    G.AddClassPostConstruct("widgets/redux/craftingmenu_pinslot", function(self)

        -- remove pinslot black help message on the bottom of screen
        local Refresh_Old = self.Refresh
        self.Refresh = function (self, ...)
            Refresh_Old(self, ...)
            self.craft_button.GetHelpText = function (_self, ...) return "" end
        end

    end)
end

return CraftingMenuHook
