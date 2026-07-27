-- Enhanced Controller - Cooking menu actions

local Helpers = require("dst-controller/utils/helpers")
local ButtonHandler = require("dst-controller/executor/button-handler")

local CookingActions = {}

function CookingActions.toggle_cooking_menu(player)
    local hud = player and player.HUD
    if hud ~= nil and type(hud.OpenCookbookScreen) == "function" then
        hud:OpenCookbookScreen()
        if player.DoTaskInTime ~= nil then
            player:DoTaskInTime(0, function()
                ButtonHandler.ClearPressedStates(player)
            end)
        end
        return nil
    end
    Helpers.DebugPrint("Cooking menu is not available")
    return nil
end

return CookingActions
