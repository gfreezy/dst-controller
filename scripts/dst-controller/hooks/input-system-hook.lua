-- Input System Hook
-- Hooks TheInput global object for virtual cursor support
-- Extracted from virtual-cursor-hook.lua

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local Helpers = require("dst-controller/utils/helpers")

local InputSystemHook = {}

-- Store original Input methods
local original_input_methods = {}

-- Install TheInput hooks
function InputSystemHook.Install()
    -- Hook IsControlPressed to return button state for virtual cursor
    -- This is critical for drag detection (DST checks if CONTROL_PRIMARY is held)
    original_input_methods.IsControlPressed = G.TheInput.IsControlPressed
    G.TheInput.IsControlPressed = function(self, control)
        if VirtualCursor.IsCursorModeActive() then
            -- Check if it's primary/secondary control
            if control == G.CONTROL_PRIMARY then
                ---@type {primary: boolean, secondary: boolean}
                local button_states = VirtualCursor.GetButtonStates()
                return button_states.primary
            elseif control == G.CONTROL_SECONDARY then
                ---@type {primary: boolean, secondary: boolean}
                local button_states = VirtualCursor.GetButtonStates()
                return button_states.secondary
            end
        end
        return original_input_methods.IsControlPressed(self, control)
    end

    -- Hook ControllerAttached to return false when virtual cursor is active
    -- This is THE KEY to switching to mouse mode!
    -- When ControllerAttached() returns false, the entire game switches to mouse/keyboard mode
    original_input_methods.ControllerAttached = G.TheInput.ControllerAttached
    G.TheInput.ControllerAttached = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return false  -- Pretend no controller is attached → mouse mode
        end
        return original_input_methods.ControllerAttached(self)
    end

    -- Hook ClearCachedController to auto-close virtual cursor when pause menu opens
    -- When pause menu or other screens call ClearCachedController(), they want to switch to mouse mode
    -- We should close virtual cursor to avoid conflicts
    original_input_methods.ClearCachedController = G.TheInput.ClearCachedController
    G.TheInput.ClearCachedController = function(self)
        -- If virtual cursor is active, close it first
        if VirtualCursor.IsCursorModeActive() then
            Helpers.DebugPrint("Auto-closing virtual cursor (pause menu opened)")
            VirtualCursor.ToggleCursorMode(false)  -- Force close cursor mode
        end
        -- Call original method
        return original_input_methods.ClearCachedController(self)
    end
end

return InputSystemHook
