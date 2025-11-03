-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud for task config screen shortcut

local G = require("dst-controller/global")
local TaskConfigHook = require("dst-controller.screens.taskconfig-actions")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local PlayerHudHook = {}

-- Hook: PlayerHud:OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(hud_self, control, down)
        -- Check task config screen shortcut (LB+RB+Y)
        if TaskConfigHook.OnControl(hud_self, control, down) then
            return true
        end

        if VirtualCursor.ToggleOnControl(control, down) then
            return true
        end

        return old_OnControl(hud_self, control, down)
    end
end


-- Install HUD hook
function PlayerHudHook.Install()
    -- Hook PlayerHud:OnControl for task config shortcut
    G.AddClassPostConstruct("screens/playerhud", function(self)
        InstallOnControl(self)
    end)
end

return PlayerHudHook
