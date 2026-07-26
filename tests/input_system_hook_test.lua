local cursor_active = true
local dispatching = false
local set_position_calls = 0
local physical_move_calls = 0
local mouse_move_calls = 0
local position_calls = 0

local input = {
    IsControlPressed = function() return false end,
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
    TheInput = input,
    CONTROL_PRIMARY = 1,
    CONTROL_SECONDARY = 2,
    VIRTUAL_CONTROL_INV_UP = 3,
    VIRTUAL_CONTROL_INV_DOWN = 4,
    VIRTUAL_CONTROL_INV_LEFT = 5,
    VIRTUAL_CONTROL_INV_RIGHT = 6,
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
}
package.loaded["dst-controller/hooks/input-system-hook"] = nil

local InputSystemHook = require("dst-controller/hooks/input-system-hook")
InputSystemHook.Install()

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
