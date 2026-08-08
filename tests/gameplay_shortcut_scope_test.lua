local component_postinit = nil
local handled_calls = 0
local active_screen = nil
local controller_mode = true
local hud = {}
local player = {
    GUID = 901,
    HUD = hud,
    components = {},
}

package.loaded["dst-controller/global"] = {
    AddComponentPostInit = function(name, fn)
        assert(name == "playercontroller")
        component_postinit = fn
    end,
    TheFrontEnd = {
        GetActiveScreen = function() return active_screen end,
    },
    CONTROL_MOVE_UP = 1,
    CONTROL_MOVE_DOWN = 2,
    CONTROL_MOVE_LEFT = 3,
    CONTROL_MOVE_RIGHT = 4,
    CONTROL_PRIMARY = 5,
    CONTROL_SECONDARY = 6,
    CONTROL_CONTROLLER_ACTION = 7,
    CONTROL_CONTROLLER_ALTACTION = 8,
    CONTROL_INSPECT = 9,
}
package.loaded["dst-controller/utils/helpers"] = {
    IsControlAnyOf = function() return false end,
    DebugPrint = function() end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/executor/button-handler"] = {
    InitializePlayer = function() end,
    HandleButtonCombination = function()
        handled_calls = handled_calls + 1
        return true
    end,
}
package.loaded["dst-controller/executor/action-executor"] = {
    ExecuteTaskActions = function() end,
}
package.loaded["dst-controller/utils/config_manager"] = {
    LoadTasks = function() return {} end,
    GetRuntimeSettings = function() return {} end,
}
package.loaded["dst-controller/actions/init"] = {
    InitEquipmentTracking = function() end,
}
package.loaded["dst-controller/target-selection/core"] = {
    UpdateControllerTargets = function() end,
}
package.loaded["dst-controller/virtual-cursor/core"] = {}
package.loaded["dst-controller/utils/client_pathfinder"] = {
    IsActive = function() return false end,
}
package.loaded["dst-controller/crafting/coordinator"] = {
    OnUserControl = function() end,
}
package.loaded["dst-controller/cooking/coordinator"] = {
    OnUserControl = function() end,
}
package.loaded["dst-controller/utils/control-mode"] = {
    IsControllerActive = function() return controller_mode end,
}
package.loaded["dst-controller/hooks/playercontroller-hook"] = nil

require("dst-controller/hooks/playercontroller-hook").Install()
assert(type(component_postinit) == "function")

local native_calls = 0
local controller = {
    inst = player,
    GetItemUseAction = function() end,
    OnControl = function()
        native_calls = native_calls + 1
        return "native"
    end,
    IsEnabled = function() return true, false end,
    UsingMouse = function() return false end,
    DoControllerAttackButton = function() end,
}
player.components.playercontroller = controller
component_postinit(controller)

active_screen = { name = "MapScreen" }
assert(controller:OnControl(46, true) == "native" and handled_calls == 0,
    "shortcuts must not execute while the map or another screen is active")

active_screen = hud
assert(controller:OnControl(46, true) == true and handled_calls == 1,
    "shortcuts should execute on the gameplay PlayerHud")
assert(native_calls == 1,
    "a handled gameplay shortcut should not reach native controller behavior")

controller_mode = false
assert(controller:OnControl(46, true) == "native" and handled_calls == 1,
    "keyboard/mouse mode must bypass every gameplay shortcut")
assert(native_calls == 2,
    "keyboard/mouse input should retain native controller behavior unchanged")
