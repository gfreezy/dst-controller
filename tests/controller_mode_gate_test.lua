local postconstruct = nil
local controller_mode = false
local native_updates = 0
local native_controls = 0
local cursor_updates = 0
local shoulder_updates = 0
local queue_updates = 0
local path_updates = 0
local cleanup_calls = 0

package.loaded["dst-controller/global"] = {
    AddGlobalClassPostConstruct = function(module, name, fn)
        assert(module == "frontend" and name == "FrontEnd")
        postconstruct = fn
    end,
    SCALEMODE_PROPORTIONAL = 1,
}
package.loaded["dst-controller/utils/control-mode"] = {
    IsControllerActive = function() return controller_mode end,
}
package.loaded["dst-controller/virtual-cursor/core"] = {
    SetCursorWidget = function() end,
    IsCursorModeActive = function() return false end,
    OnUpdate = function() cursor_updates = cursor_updates + 1 end,
    ToggleOnControl = function() return false end,
    OnControl = function() return false end,
}
package.loaded["dst-controller/virtual-cursor/cursor_widget"] = function()
    return {
        inst = { IsValid = function() return true end },
        SetScaleMode = function() end,
        MoveToFront = function() end,
    }
end
package.loaded["dst-controller/integrations/actionqueue"] = {
    OnUpdate = function() queue_updates = queue_updates + 1 end,
    OnControl = function() return false end,
    OnCursorModeChanged = function()
        cleanup_calls = cleanup_calls + 1
    end,
}
package.loaded["dst-controller/integrations/shoulder-modifiers"] = {
    OnUpdate = function() shoulder_updates = shoulder_updates + 1 end,
    OnControl = function() return false end,
    OnCursorModeChanged = function()
        cleanup_calls = cleanup_calls + 1
    end,
}
package.loaded["dst-controller/utils/client_pathfinder"] = {
    UpdateSearch = function() path_updates = path_updates + 1 end,
    IsActive = function() return false end,
}
package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function() end,
}
package.loaded["dst-controller/crafting/coordinator"] = {
    Interrupt = function() end,
}
package.loaded["dst-controller/cooking/coordinator"] = {
    Interrupt = function() end,
}
package.loaded["dst-controller/hooks/input-hook"] = {
    ClearAllVirtualModifiers = function()
        cleanup_calls = cleanup_calls + 1
    end,
    ClearAllVirtualKeys = function()
        cleanup_calls = cleanup_calls + 1
    end,
}
package.loaded["dst-controller/executor/button-handler"] = {
    ClearPressedStates = function() end,
}
package.loaded["dst-controller/hooks/thefrontend-hook"] = nil

require("dst-controller/hooks/thefrontend-hook").Install()
assert(type(postconstruct) == "function")

local frontend = {
    overlayroot = {
        AddChild = function(_, widget) return widget end,
    },
    Update = function()
        native_updates = native_updates + 1
    end,
    OnControl = function()
        native_controls = native_controls + 1
        return "native"
    end,
    PushScreen = function(_, screen) return screen end,
}
postconstruct(frontend)

frontend:Update(0.016)
assert(frontend:OnControl(1, true) == "native")
assert(native_updates == 1 and native_controls == 1 and
       cursor_updates == 0 and shoulder_updates == 0 and
       queue_updates == 0 and path_updates == 0,
    "keyboard/mouse mode must bypass every FrontEnd controller feature")
assert(cleanup_calls == 4,
    "entering keyboard/mouse mode should clear controller-owned input state")

frontend:Update(0.016)
assert(cleanup_calls == 4,
    "keyboard/mouse cleanup should run only once per mode transition")

controller_mode = true
frontend:Update(0.016)
assert(cursor_updates == 1 and shoulder_updates == 1 and
       queue_updates == 1 and path_updates == 1,
    "controller features should resume after returning to controller mode")
