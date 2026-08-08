local postconstruct = nil
local combo_owns_trigger = false
local observed = {}
local native_calls = 0
local player = { GUID = 801 }
local active_screen = nil

package.loaded["dst-controller/global"] = {
    AddClassPostConstruct = function(path, fn)
        assert(path == "screens/playerhud")
        postconstruct = fn
    end,
    TheFrontEnd = {
        GetActiveScreen = function() return active_screen end,
    },
}
package.loaded["dst-controller.screens.taskconfig-actions"] = {
    OnControl = function() return false end,
}
package.loaded["dst-controller/executor/button-handler"] = {
    ObserveModifierControl = function(routed_player, control, down)
        assert(routed_player == player)
        observed[#observed + 1] = { control, down }
    end,
    ShouldHandleControl = function(routed_player)
        assert(routed_player == player)
        return combo_owns_trigger
    end,
}
package.loaded["dst-controller/hooks/playerhud-hook"] = nil

require("dst-controller/hooks/playerhud-hook").Install()
assert(type(postconstruct) == "function")

local hud = {
    owner = player,
    OnControl = function()
        native_calls = native_calls + 1
        return true -- crafting/inventory would consume LT/RT here
    end,
}
postconstruct(hud)
active_screen = hud

combo_owns_trigger = true
assert(hud:OnControl(46, true) == false,
    "configured shoulder+LT should bypass the native crafting-menu trigger")
assert(hud:OnControl(45, false) == false,
    "captured shoulder+RT releases should bypass native inventory handling")
assert(native_calls == 0 and #observed == 2,
    "PlayerHud should observe input but not run fixed trigger behavior for combos")

combo_owns_trigger = false
assert(hud:OnControl(46, true) == true and native_calls == 1,
    "bare or unconfigured LT should retain the native crafting-menu behavior")

active_screen = { name = "MapScreen" }
combo_owns_trigger = true
assert(hud:OnControl(46, true) == true and native_calls == 2,
    "an inactive PlayerHud must not intercept map trigger controls")
assert(#observed == 3,
    "an inactive PlayerHud must not observe shortcut modifier state")
