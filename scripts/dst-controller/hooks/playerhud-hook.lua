-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud to block default actions when modifier buttons are pressed

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local TaskConfigHook = require("dst-controller.screens.taskconfig-actions")

local PlayerHudHook = {}


-- Hook: PlayerHud:OnUpdate (wrap)
local function InstallOnUpdate(self)
    local old_OnUpdate = self.OnUpdate

    self.OnUpdate = function(self, dt)
        -- If cursor mode is active, update cursor position from right stick
        if VirtualCursor.OnUpdate(self, dt) then
            return true
        end

        -- Call original OnUpdate
        return old_OnUpdate(self, dt)
    end
end

-- Hook: PlayerHud:OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(hud_self, control, down)
        -- Check task config screen shortcut (LB+RB+Y)
        if TaskConfigHook.OnControl(control, down) then
            return true
        end

        -- If LB or RB is pressed (and virtual cursor not active), block default actions, pass through other controls
        if Helpers.IsButtonPressed("LB") or Helpers.IsButtonPressed("RB") then
            return false
        end

        -- When virtual cursor is active, block default actions for LT/RT, pass through other controls
        if VirtualCursor.IsCursorModeActive() and (Helpers.IsButtonPressed("LT") or Helpers.IsButtonPressed("RT")) then
            return false
        end

        return old_OnControl(hud_self, control, down)
    end
end


-- Install HUD hook
function PlayerHudHook.Install()
    -- Hook PlayerHud:OnControl to block button combinations at HUD level
    -- This is necessary because HUD's OnControl runs before PlayerController's
    G.AddClassPostConstruct("screens/playerhud", function(self)
        InstallOnControl(self)
        InstallOnUpdate(self)
    end)
end

return PlayerHudHook
