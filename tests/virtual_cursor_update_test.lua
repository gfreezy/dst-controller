local widget_updates = 0
local mouse_move_calls = 0
local position_calls = 0
local widget_shows = 0
local widget_hides = 0

package.loaded["dst-controller/global"] = {
    ThePlayer = nil,
    TheFrontEnd = nil,
    TheSim = {
        GetScreenSize = function() return 1920, 1080 end,
    },
    TheInput = {
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
