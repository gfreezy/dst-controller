-- Input System Hook
-- Hooks TheInput global object for virtual cursor support
-- Extracted from virtual-cursor-hook.lua

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local Helpers = require("dst-controller/utils/helpers")

local InputSystemHook = {}
local installed = false

-- Store original Input methods
local original_input_methods = {}
local original_profile_methods = {}

-- Install TheInput hooks
function InputSystemHook.Install()
    if installed then
        return
    end
    installed = true
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
            elseif control == G.VIRTUAL_CONTROL_INV_UP or
                control == G.VIRTUAL_CONTROL_INV_DOWN or
                control == G.VIRTUAL_CONTROL_INV_LEFT or
                control == G.VIRTUAL_CONTROL_INV_RIGHT then
                -- Return false to prevent right analog stick from triggering focus navigation in inventory and crafting menus
                return false
            end
        end
        return original_input_methods.IsControlPressed(self, control)
    end

    -- Enhanced Controller consistently owns the LB + right-stick camera
    -- gesture. Keep the camera/inventory scheme at type 2 while the mod is
    -- loaded so gameplay, map controls, inventory navigation, and UI hints all
    -- resolve the same bindings. This is a runtime override: it does not write
    -- the user's saved profile setting.
    -- Scheme 2: modified R.Stick for camera, plain R.Stick for inventory.
    original_input_methods.GetActiveControlScheme = G.TheInput.GetActiveControlScheme
    G.TheInput.GetActiveControlScheme = function(self, scheme_id, ...)
        if scheme_id == G.CONTROL_SCHEME_CAM_AND_INV then
            return 2
        end
        return original_input_methods.GetActiveControlScheme(
            self, scheme_id, ...)
    end

    -- A few native widgets bypass TheInput and read Profile directly. Mirror
    -- the runtime override there to prevent behavior/help-text mismatches.
    if G.Profile ~= nil and type(G.Profile.GetControlScheme) == "function" then
        original_profile_methods.GetControlScheme = G.Profile.GetControlScheme
        G.Profile.GetControlScheme = function(self, scheme_id, ...)
            if scheme_id == G.CONTROL_SCHEME_CAM_AND_INV then
                return 2
            end
            return original_profile_methods.GetControlScheme(
                self, scheme_id, ...)
        end
    end

    -- Hook GetControllerID to return 0 (keyboard/mouse) when virtual cursor is active
    -- This fixes hover text showing "not bound" for controller bindings
    -- When we pretend no controller is attached, we should also pretend we're using keyboard/mouse
    original_input_methods.GetControllerID = G.TheInput.GetControllerID
    G.TheInput.GetControllerID = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return 0 -- Return keyboard/mouse device ID
        end
        return original_input_methods.GetControllerID(self)
    end

    -- Hook ControllerAttached to return false when virtual cursor is active
    -- This is THE KEY to switching to mouse mode!
    -- When ControllerAttached() returns false, the entire game switches to mouse/keyboard mode
    original_input_methods.ControllerAttached = G.TheInput.ControllerAttached
    G.TheInput.ControllerAttached = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return false -- Pretend no controller is attached → mouse mode
        end
        return original_input_methods.ControllerAttached(self)
    end

    original_input_methods.OnMouseMove = G.TheInput.OnMouseMove
    G.TheInput.OnMouseMove = function(self, p, q, from_touch)
        if VirtualCursor.IsCursorModeActive() and
            not VirtualCursor.IsDispatchingInputPosition() then
            VirtualCursor.OnPhysicalMouseMove(p, q)
            -- print("[InputSystemHook] OnMouseMove", p, q)
        end
        return original_input_methods.OnMouseMove(self, p, q, from_touch)
    end

    original_input_methods.OnPosition = G.TheInput.OnPosition
    G.TheInput.OnPosition = function(self, p, q)
        if VirtualCursor.IsCursorModeActive() and
            not VirtualCursor.IsDispatchingInputPosition() then
            VirtualCursor.OnPhysicalMouseMove(p, q)
        end
        return original_input_methods.OnPosition(self, p, q)
    end
end

function InputSystemHook._ResetForTests()
    installed = false
end

return InputSystemHook
