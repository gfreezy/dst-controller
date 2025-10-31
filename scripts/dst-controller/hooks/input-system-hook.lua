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
    -- Hook Input:OnUpdate to ensure mouse_enabled stays true when cursor is active
    -- This is critical because DST only checks hover when mouse_enabled is true
    original_input_methods.OnUpdate = G.TheInput.OnUpdate
    G.TheInput.OnUpdate = function(self)
        -- If virtual cursor is active, force enable mouse before hover detection
        if VirtualCursor.IsCursorModeActive() then
            if not self.mouse_enabled then
                self.mouse_enabled = true
                Helpers.DebugPrint("[VirtualCursor] Force enabled mouse_enabled in OnUpdate")
            end
        end

        -- Call original OnUpdate (will do hover detection with mouse_enabled=true)
        return original_input_methods.OnUpdate(self)
    end
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

    -- Hook GetActiveControlScheme to always return scheme 2
    -- Scheme 2: R.Stick for camera (with modifier), R.Stick for inventory, twin-stick aiming
    original_input_methods.GetActiveControlScheme = G.TheInput.GetActiveControlScheme
    G.TheInput.GetActiveControlScheme = function()
        return 2  -- Force scheme 2 for all control schemes
    end

    -- Hook GetControllerID to return 0 (keyboard/mouse) when virtual cursor is active
    -- This fixes hover text showing "not bound" for controller bindings
    -- When we pretend no controller is attached, we should also pretend we're using keyboard/mouse
    original_input_methods.GetControllerID = G.TheInput.GetControllerID
    G.TheInput.GetControllerID = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return 0  -- Return keyboard/mouse device ID
        end
        return original_input_methods.GetControllerID(self)
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
