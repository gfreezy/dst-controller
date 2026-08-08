local cursor_active = true
local dispatching = false
local set_position_calls = 0
local physical_move_calls = 0
local mouse_move_calls = 0
local position_calls = 0
local pressed_controls = {}
local prioritize_cursor_stick = false
local game_postinit
local profile = {
    GetControlScheme = function(_, scheme_id)
        return scheme_id == 99 and 7 or 1
    end,
}

local input = {
    IsControlPressed = function(_, control)
        return pressed_controls[control] == true
    end,
    GetAnalogControlValue = function(_, control) return control / 10 end,
    GetActiveControlScheme = function() return 1 end,
    GetControllerID = function() return 1 end,
    ControllerAttached = function() return true end,
    OnMouseMove = function()
        mouse_move_calls = mouse_move_calls + 1
    end,
    OnPosition = function()
        position_calls = position_calls + 1
    end,
}

package.loaded["dst-controller/global"] = {
    AddGamePostInit = function(fn) game_postinit = fn end,
    TheInput = input,
    Profile = profile,
    CONTROL_SCHEME_CAM_AND_INV = 10,
    CONTROL_PRIMARY = 1,
    CONTROL_SECONDARY = 2,
    VIRTUAL_CONTROL_INV_UP = 3,
    VIRTUAL_CONTROL_INV_DOWN = 4,
    VIRTUAL_CONTROL_INV_LEFT = 5,
    VIRTUAL_CONTROL_INV_RIGHT = 6,
    VIRTUAL_CONTROL_CAMERA_ZOOM_IN = 7,
    VIRTUAL_CONTROL_CAMERA_ZOOM_OUT = 8,
    VIRTUAL_CONTROL_CAMERA_ROTATE_LEFT = 9,
    VIRTUAL_CONTROL_CAMERA_ROTATE_RIGHT = 10,
}
package.loaded["dst-controller/utils/helpers"] = {}
package.loaded["dst-controller/virtual-cursor/core"] = {
    IsCursorModeActive = function() return cursor_active end,
    IsDispatchingInputPosition = function() return dispatching end,
    OnPhysicalMouseMove = function()
        set_position_calls = set_position_calls + 1
        physical_move_calls = physical_move_calls + 1
    end,
    GetButtonStates = function()
        return { primary = false, secondary = false }
    end,
    ShouldPrioritizeCursorRightStick = function()
        return prioritize_cursor_stick
    end,
}
package.loaded["dst-controller/hooks/input-system-hook"] = nil

local InputSystemHook = require("dst-controller/hooks/input-system-hook")
InputSystemHook.Install()

assert(InputSystemHook.IsControllerPhysicallyAttached(),
    "physical controller detection must bypass virtual cursor mouse mode")
assert(InputSystemHook.GetPhysicalControllerID() == 1,
    "physical controller id must bypass virtual cursor mouse mode")
assert(not input:ControllerAttached(),
    "virtual cursor mode should still present mouse mode to native DST UI")

prioritize_cursor_stick = true
for _, control in ipairs({ 7, 8, 9, 10 }) do
    pressed_controls[control] = true
    assert(not input:IsControlPressed(control) and
           input:GetAnalogControlValue(control) == 0,
        "LB+LT/RT cursor dragging must suppress every native camera axis")
end
assert(input:GetAnalogControlValue(20) == 2,
    "cursor dragging must preserve physical right-stick and unrelated axes")
prioritize_cursor_stick = false
assert(input:IsControlPressed(9) and input:GetAnalogControlValue(9) == 0.9,
    "LB+right stick without a trigger must retain native camera control")

assert(input:GetActiveControlScheme(10) == 2,
    "the camera and inventory controls should use scheme 2")
assert(profile:GetControlScheme(10) == 2,
    "native widgets that read the profile should also see scheme 2")
assert(input:GetActiveControlScheme(99) == 1 and
    profile:GetControlScheme(99) == 7,
    "unrelated control schemes should preserve native behavior")
assert(type(game_postinit) == "function",
    "the profile override must register a late-install fallback")

local late_profile = {
    GetControlScheme = function(_, scheme_id)
        return scheme_id == 99 and 8 or 1
    end,
}
package.loaded["dst-controller/global"].Profile = late_profile
game_postinit()
assert(late_profile:GetControlScheme(10) == 2 and
    late_profile:GetControlScheme(99) == 8,
    "a profile created after mod loading must still expose scheme 2")

input:OnMouseMove(10, 20)
assert(set_position_calls == 1, "a physical mouse move must update the visible cursor")
assert(physical_move_calls == 1, "a physical mouse move must select the native cursor source")
assert(mouse_move_calls == 1, "a physical mouse move must still reach DST")

dispatching = true
input:OnMouseMove(20, 30, true)
input:OnPosition(20, 30)
assert(set_position_calls == 1,
    "a virtual move already applied by the core must not be written back through input hooks")
assert(mouse_move_calls == 2 and position_calls == 1,
    "suppression must not block DST's input notifications")

dispatching = false
input:OnPosition(30, 40)
assert(set_position_calls == 2, "an external position event must update the visible cursor")
assert(physical_move_calls == 2, "an external position event must keep the native cursor source")
assert(position_calls == 2, "an external position event must still reach DST")

cursor_active = false
assert(input:GetActiveControlScheme(10) == 2,
    "normal gameplay should keep using the mod's required scheme")

pressed_controls[3] = true
pressed_controls[20] = true
assert(input:IsControlPressed(3),
    "inventory navigation should keep native behavior outside cursor mode")
assert(input:IsControlPressed(20),
    "unrelated controls should preserve native polling")

local wrapped_is_control_pressed = input.IsControlPressed
InputSystemHook.Install()
assert(input.IsControlPressed == wrapped_is_control_pressed,
    "installing the input hook twice should not stack wrappers")
