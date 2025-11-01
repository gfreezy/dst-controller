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
    original_input_methods.IsControlPressed = G.TheInput.IsControlPressed
    G.TheInput.IsControlPressed = function(self, control)
        if VirtualCursor.IsCursorModeActive() then
            -- Check if it's primary/secondary control
            if control == G.CONTROL_PRIMARY then
                ---@type {primary: boolean, secondary: boolean}
                local button_states = VirtualCursor.GetButtonStates()
                -- print("[InputSystemHook] IsControlPressed", control, "primary", button_states.primary)
                return button_states.primary
            elseif control == G.CONTROL_SECONDARY then
                ---@type {primary: boolean, secondary: boolean}
                local button_states = VirtualCursor.GetButtonStates()
                -- print("[InputSystemHook] IsControlPressed", control, "secondary", button_states.secondary)
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

    original_input_methods.OnMouseMove = G.TheInput.OnMouseMove
    G.TheInput.OnMouseMove = function(self, p, q, from_touch)
        if VirtualCursor.IsCursorModeActive() then
            VirtualCursor.SetCursorPosition(p, q)
            -- print("[InputSystemHook] OnMouseMove", p, q)
        end
        return original_input_methods.OnMouseMove(self, p, q, from_touch)
    end

    original_input_methods.OnPosition = G.TheInput.OnPosition
    G.TheInput.OnPosition = function(self, p, q)
        if VirtualCursor.IsCursorModeActive() then
            VirtualCursor.SetCursorPosition(p, q)
        end
        return original_input_methods.OnPosition(self, p, q)
    end
end

return InputSystemHook
