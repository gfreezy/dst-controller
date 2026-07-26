-- Enhanced Controller - Cooking menu actions

local Helpers = require("dst-controller/utils/helpers")

local CookingActions = {}

function CookingActions.toggle_cooking_menu(player)
    local controls = player and player.HUD and player.HUD.controls
    local menu = controls and controls.enhanced_cooking_menu
    if menu == nil or type(menu.Toggle) ~= "function" then
        Helpers.DebugPrint("Cooking menu is not available")
        return nil
    end
    menu:Toggle()
    return nil
end

return CookingActions
