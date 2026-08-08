local module_names = {
    "dst-controller/global",
    "dst-controller/utils/helpers",
    "dst-controller/hooks/input-hook",
    "dst-controller/utils/config_manager",
    "dst-controller/virtual-cursor/core",
    "dst-controller/integrations/shoulder-modifiers",
}
local saved_modules = {}
for _, name in ipairs(module_names) do
    saved_modules[name] = package.loaded[name]
end

local physical_keys = {}
local raw_events = {}
local controller_pressed = { LB = false, RB = false }
local cursor_active = true
local mappings = { LB = "shift", RB = "shift" }
local input = {
    IsKeyDown = function(_, key)
        return physical_keys[key] == true
    end,
    OnRawKey = function(_, key, down)
        table.insert(raw_events, { key = key, down = down })
    end,
}

package.loaded["dst-controller/global"] = {
    TheInput = input,
    KEY_LSHIFT = 1, KEY_RSHIFT = 2, KEY_SHIFT = 3,
    KEY_LALT = 4, KEY_RALT = 5, KEY_ALT = 6,
    KEY_LCTRL = 7, KEY_RCTRL = 8, KEY_CTRL = 9,
    KEY_LSUPER = 10, KEY_RSUPER = 11,
}
package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function() end,
    DebugPrintf = function() end,
    IsControlNamedButton = function(control, button)
        return (control == 20 and button == "LB") or
            (control == 21 and button == "RB")
    end,
    IsButtonPressed = function(button)
        return controller_pressed[button] == true
    end,
}
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeSettings = function()
        return {
            virtual_cursor_settings = {
                modifier_keys = mappings,
            },
        }
    end,
}
package.loaded["dst-controller/virtual-cursor/core"] = {
    IsCursorModeActive = function() return cursor_active end,
}
package.loaded["dst-controller/hooks/input-hook"] = nil
package.loaded["dst-controller/integrations/shoulder-modifiers"] = nil

local InputHook = require("dst-controller/hooks/input-hook")
InputHook.Install()
local ShoulderModifiers =
    require("dst-controller/integrations/shoulder-modifiers")

controller_pressed.LB = true
ShoulderModifiers.OnControl(20, true)
assert(input:IsKeyDown(1) and input:IsKeyDown(2) and input:IsKeyDown(3),
    "a Shift shoulder mapping should satisfy left, right, and aggregate aliases")
assert(#raw_events == 1 and raw_events[1].down == true,
    "the first Shift source should emit one key-down transition")

physical_keys[1] = true
input:OnRawKey(1, true)
physical_keys[1] = false
input:OnRawKey(1, false)
assert(#raw_events == 1,
    "physical transitions must not duplicate a shoulder-owned modifier")

controller_pressed.RB = true
ShoulderModifiers.OnControl(21, true)
assert(#raw_events == 1,
    "a second shoulder sharing Shift must not emit a duplicate key-down")

controller_pressed.LB = false
ShoulderModifiers.OnControl(20, false)
assert(input:IsKeyDown(1) and #raw_events == 1,
    "releasing one Shift shoulder must keep the other source held")

controller_pressed.RB = false
ShoulderModifiers.OnControl(21, false)
assert(not input:IsKeyDown(1) and #raw_events == 2 and
       raw_events[2].down == false,
    "the final Shift source should emit the only key-up transition")

mappings.LB = "alt"
controller_pressed.LB = true
ShoulderModifiers.OnControl(20, true)
assert(input:IsKeyDown(4) and not input:IsKeyDown(1),
    "runtime mappings should select the configured semantic modifier")

physical_keys[7] = true
mappings.RB = "ctrl"
controller_pressed.RB = true
ShoulderModifiers.OnControl(21, true)
controller_pressed.RB = false
ShoulderModifiers.OnControl(21, false)
assert(input:IsKeyDown(7),
    "virtual modifier release must not mask a physically held keyboard key")

cursor_active = false
ShoulderModifiers.OnCursorModeChanged(false)
assert(not input:IsKeyDown(4),
    "leaving virtual cursor mode should clear every shoulder-owned modifier")

for _, name in ipairs(module_names) do
    package.loaded[name] = saved_modules[name]
end
