-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud to block default actions when modifier buttons are pressed

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local HudHook = {}

-- Install HUD hook
function HudHook.Install()
    -- Hook PlayerHud:OnControl to block button combinations at HUD level
    -- This is necessary because HUD's OnControl runs before PlayerController's
    G.AddClassPostConstruct("screens/playerhud", function(self)
        local OldHudOnControl = self.OnControl

        self.OnControl = function(hud_self, control, down)
            -- If LB or RB is pressed (and virtual cursor not active), block controls
            -- to prevent default HUD actions when using button combinations
            if Helpers.IsButtonPressed("LB") or Helpers.IsButtonPressed("RB") then
                return false
            end

            -- When virtual cursor is active, let HUD work normally (mouse mode behavior)
            if VirtualCursor.IsCursorModeActive() then
                return OldHudOnControl(hud_self, control, down)
            end

            return OldHudOnControl(hud_self, control, down)
        end

        Helpers.DebugPrint("HUD hook installed")
    end)
end

return HudHook
