local widget_updates = 0
local mouse_move_calls = 0
local position_calls = 0
local widget_shows = 0
local widget_hides = 0
local pressed_buttons = {}
local analog_values = {}
local gameplay_hud = {
    HasInputFocus = function() return false end,
}
local active_screen = gameplay_hud

package.loaded["dst-controller/global"] = {
    ThePlayer = { HUD = gameplay_hud },
    TheFrontEnd = {
        GetActiveScreen = function() return active_screen end,
    },
    TheSim = {
        GetScreenSize = function() return 1920, 1080 end,
    },
    TheInput = {
        GetAnalogControlValue = function(_, control)
            return analog_values[control] or 0
        end,
        OnMouseMove = function(_, x, y, from_touch)
            mouse_move_calls = mouse_move_calls + 1
            assert(type(x) == "number" and type(y) == "number", "mouse notification needs coordinates")
            assert(from_touch == true, "virtual mouse notification must be marked synthetic")
        end,
        UpdatePosition = function(_, x, y, from_touch)
            position_calls = position_calls + 1
            assert(type(x) == "number" and type(y) == "number", "position notification needs coordinates")
            assert(from_touch == true, "virtual position notification must be marked synthetic")
        end,
    },
    CONTROL_PRESET_RSTICK_RIGHT = 31,
    CONTROL_PRESET_RSTICK_LEFT = 32,
    CONTROL_PRESET_RSTICK_UP = 33,
    CONTROL_PRESET_RSTICK_DOWN = 34,
}
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeSettings = function()
        return {
            virtual_cursor_settings = {
                cursor_speed = 1,
                dead_zone = 0.2,
                cursor_magnetism = false,
            },
        }
    end,
}
package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function() end,
    DebugPrintf = function() end,
    IsButtonPressed = function(button)
        return pressed_buttons[button] == true
    end,
}
package.loaded["dst-controller/actions/helpers"] = {
    GetPlayerController = function() return nil end,
    GetInventory = function() return nil end,
}
package.loaded["dst-controller/virtual-cursor/core"] = nil

local VirtualCursor = require("dst-controller/virtual-cursor/core")
local state = VirtualCursor.GetState()
state.cursor_mode_active = true
state.cursor_screen_pos.x = 100
state.cursor_screen_pos.y = 100
state.base_cursor_speed = 20

VirtualCursor.SetCursorWidget({
    SetPosition = function(_, x, y)
        widget_updates = widget_updates + 1
        assert(type(x) == "number" and type(y) == "number", "widget update needs coordinates")
    end,
    Show = function()
        widget_shows = widget_shows + 1
    end,
    Hide = function()
        widget_hides = widget_hides + 1
    end,
})

VirtualCursor.OnPhysicalMouseMove(90, 90)
assert(VirtualCursor.IsPhysicalMouseActive(), "a physical move must select the native cursor")
assert(widget_hides == 1, "a physical move must hide the custom cursor")
widget_updates = 0

VirtualCursor.UpdateCursorPositionDelta(1 / 60, 1, 0)

assert(not VirtualCursor.IsPhysicalMouseActive(), "right-stick movement must restore virtual input")
assert(widget_shows == 1, "right-stick movement must show the custom cursor again")
assert(widget_updates == 1, "one virtual movement frame must write the widget only once")
assert(mouse_move_calls == 1, "one virtual movement frame must send one UI mouse notification")
assert(position_calls == 1, "one virtual movement frame must send one input position notification")
assert(not VirtualCursor.IsDispatchingInputPosition(), "input dispatch guard must be cleared")
assert(state.cursor_screen_pos.x > 96 and state.cursor_screen_pos.x < 97 and
    state.cursor_screen_pos.y == 90,
    "the normal setting must use the reduced full-stick speed baseline")

analog_values[31] = 1
pressed_buttons.LB = true
local camera_only_x = state.cursor_screen_pos.x
assert(not VirtualCursor.OnUpdate(nil, 1 / 60) and
       state.cursor_screen_pos.x == camera_only_x,
    "LB+right stick without a trigger must remain owned by the camera")

pressed_buttons.LT = true
assert(VirtualCursor.ShouldPrioritizeCursorRightStick(),
    "LB+LT in gameplay should give right-stick priority to the cursor")
assert(VirtualCursor.OnUpdate(nil, 1 / 60) and
       state.cursor_screen_pos.x > camera_only_x,
    "LB+LT+right stick should move the virtual cursor")

pressed_buttons.LT = false
pressed_buttons.RT = true
local right_click_x = state.cursor_screen_pos.x
assert(VirtualCursor.ShouldPrioritizeCursorRightStick() and
       VirtualCursor.OnUpdate(nil, 1 / 60) and
       state.cursor_screen_pos.x > right_click_x,
    "LB+RT+right stick should also move the virtual cursor")

active_screen = { name = "MapScreen" }
assert(not VirtualCursor.ShouldPrioritizeCursorRightStick(),
    "the cursor priority chord must not alter map controls")
assert(not VirtualCursor.OnUpdate(nil, 1 / 60),
    "LB+RT+right stick must retain map ownership outside PlayerHUD")
active_screen = gameplay_hud
pressed_buttons.LB = false
pressed_buttons.RT = false

local before_small_input = state.cursor_screen_pos.x
state.smoothed_stick_intensity = 0
VirtualCursor.UpdateCursorPositionDelta(1 / 60, 0.05, 0)
assert(state.cursor_screen_pos.x > before_small_input,
    "a small non-zero stick value must not be blocked by the saved mod dead zone")

VirtualCursor.SetModeBlocked("map-test", true)
assert(VirtualCursor.IsModeBlocked() and
    not VirtualCursor.IsCursorModeActive(),
    "a map blocker must immediately suspend virtual cursor mode")
VirtualCursor.ToggleCursorMode(true)
assert(not VirtualCursor.IsCursorModeActive(),
    "cursor mode must not be enabled while MapScreen owns a blocker")
VirtualCursor.SetModeBlocked("map-test", false)
assert(not VirtualCursor.IsModeBlocked(),
    "removing the map blocker must allow later cursor restoration")
