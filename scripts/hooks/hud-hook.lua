-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud to block default actions when modifier buttons are pressed

local Helpers = require("utils/helpers")

local HudHook = {}

-- Install HUD hook
function HudHook.Install(button_mappings)
    -- Hook PlayerHud:OnControl to block button combinations at HUD level
    -- This is necessary because HUD's OnControl runs before PlayerController's
    AddClassPostConstruct("screens/playerhud", function(self)
        local OldHudOnControl = self.OnControl

        self.OnControl = function(hud_self, control, down)
            -- If LB or RB is pressed, block all controls to prevent default HUD actions
            if Helpers.IsButtonPressed("LB", button_mappings) or
               Helpers.IsButtonPressed("RB", button_mappings) then
                return false
            end

            return OldHudOnControl(hud_self, control, down)
        end

        Helpers.DebugPrint("HUD hook installed")
    end)
end

return HudHook
