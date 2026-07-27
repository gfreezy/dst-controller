-- Input System Hook
-- Hooks TheInput global object for virtual cursor support
-- Extracted from virtual-cursor-hook.lua

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local InputSystemHook = {}
local installed = false

-- Store original Input methods
local original_input_methods = {}
local original_profile_methods = setmetatable({}, { __mode = "k" })

local function IsInventoryNavigationControl(control)
    return control == G.VIRTUAL_CONTROL_INV_UP or
        control == G.VIRTUAL_CONTROL_INV_DOWN or
        control == G.VIRTUAL_CONTROL_INV_LEFT or
        control == G.VIRTUAL_CONTROL_INV_RIGHT
end

-- Virtual cursor mode deliberately makes DST believe no controller is
-- attached. Mod features that still consume physical gamepad input must use
-- this accessor instead of the overridden TheInput:ControllerAttached().
function InputSystemHook.IsControllerPhysicallyAttached()
    local controller_attached = original_input_methods.ControllerAttached or
        (G.TheInput ~= nil and G.TheInput.ControllerAttached)
    return controller_attached ~= nil and
        controller_attached(G.TheInput) == true
end

function InputSystemHook.GetPhysicalControllerID()
    local get_controller_id = original_input_methods.GetControllerID or
        (G.TheInput ~= nil and G.TheInput.GetControllerID)
    return get_controller_id ~= nil and get_controller_id(G.TheInput) or 0
end

-- Profile is not guaranteed to exist when client mods are first loaded. Some
-- native HUD widgets read it directly instead of using TheInput, so install
-- the runtime scheme override both eagerly and again at late lifecycle points.
function InputSystemHook.EnsureProfileControlSchemeOverride()
    local profile = G.Profile
    if profile == nil or type(profile.GetControlScheme) ~= "function" then
        return false
    elseif original_profile_methods[profile] ~= nil then
        return true
    end

    local old_GetControlScheme = profile.GetControlScheme
    original_profile_methods[profile] = old_GetControlScheme
    profile.GetControlScheme = function(self, scheme_id, ...)
        if scheme_id == G.CONTROL_SCHEME_CAM_AND_INV then
            return 2
        end
        return old_GetControlScheme(self, scheme_id, ...)
    end
    return true
end

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
            elseif IsInventoryNavigationControl(control) then
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
        InputSystemHook.EnsureProfileControlSchemeOverride()
        if scheme_id == G.CONTROL_SCHEME_CAM_AND_INV then
            return 2
        end
        return original_input_methods.GetActiveControlScheme(
            self, scheme_id, ...)
    end

    InputSystemHook.EnsureProfileControlSchemeOverride()
    if G.AddGamePostInit ~= nil then
        G.AddGamePostInit(function()
            InputSystemHook.EnsureProfileControlSchemeOverride()
        end)
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
