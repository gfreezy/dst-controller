-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud to block default actions when modifier buttons are pressed

local G = require("global")
local Helpers = require("utils/helpers")

local HudHook = {}

-- Install HUD hook
function HudHook.Install()
    -- Hook PlayerHud:OnControl to block button combinations at HUD level
    -- This is necessary because HUD's OnControl runs before PlayerController's
    G.AddClassPostConstruct("screens/playerhud", function(self)
        local OldHudOnControl = self.OnControl

        self.OnControl = function(hud_self, control, down)
            -- If LB or RB is pressed, block all controls to prevent default HUD actions
            if Helpers.IsButtonPressed("LB") or
               Helpers.IsButtonPressed("RB") then
                return false
            end

            -- Custom RT behavior: toggle inventory selection mode
            if control == G.CONTROL_OPEN_INVENTORY and down then
                -- Only handle when controller is attached
                if G.TheInput:ControllerAttached() then
                    local inventory = hud_self.owner.replica.inventory

                    -- If inventory is already open, close it
                    if hud_self:IsControllerInventoryOpen() then
                        Helpers.DebugPrint("RT: Closing controller inventory")
                        hud_self:CloseControllerInventory()
                        return true
                    end

                    -- If inventory is visible and has slots, open it
                    if inventory ~= nil and inventory:IsVisible() and inventory:GetNumSlots() > 0 then
                        Helpers.DebugPrint("RT: Opening controller inventory")
                        hud_self:OpenControllerInventory()
                        return true
                    end
                end
            end

            return OldHudOnControl(hud_self, control, down)
        end

        Helpers.DebugPrint("HUD hook installed")
    end)
end

return HudHook
