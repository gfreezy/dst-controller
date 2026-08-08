-- Central controller-mode gate. InputSystemHook registers DST's original
-- ControllerAttached method before virtual cursor mode overrides the public
-- method to emulate mouse input.

local G = require("dst-controller/global")

local ControlMode = {}
local original_controller_attached = nil

function ControlMode.SetOriginalControllerAttached(fn)
    original_controller_attached = type(fn) == "function" and fn or nil
end

function ControlMode.IsControllerActive()
    local input = G.TheInput
    local accessor = original_controller_attached or
        (input and input.ControllerAttached)
    if type(accessor) ~= "function" then
        -- Keep isolated modules and early initialization safe. DST provides
        -- this method before runtime hooks begin handling input.
        return true
    end
    return accessor(input) == true
end

function ControlMode._ResetForTests()
    original_controller_attached = nil
end

return ControlMode
