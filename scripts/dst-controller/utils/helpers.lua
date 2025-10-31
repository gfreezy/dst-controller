-- Enhanced Controller - Utility Helper Functions
-- Common utility functions used across the mod

---@type GlobalReferences
local G = require("dst-controller/global")

local Helpers = {}

---@alias ButtonName "LB"|"RB"|"LT"|"RT"|"A"|"B"|"X"|"Y"

-- Check if a specific button (logical name) is currently pressed
---@param button_name ButtonName Logical button name (e.g., "LB", "RB", "A", "B", "X", "Y")
---@return boolean true if any mapped control for this button is pressed
function Helpers.IsButtonPressed(button_name)
    local controls = G.BUTTON_MAPPINGS[button_name]
    if not controls then
        return false
    end

    for _, control in ipairs(controls) do
        if Helpers.IsControlPressed(control) then
            return true
        end
    end

    return false
end

---@param button_names ButtonName[] List of button names (e.g., {"LB", "RB", "RT"})
---@return boolean true if all buttons are pressed
function Helpers.IsComboButtonPressed(button_names)
    for _, button_name in ipairs(button_names) do
        if not Helpers.IsButtonPressed(button_name) then
            return false
        end
    end
    return true
end


---@param button_names ButtonName[] List of button names (e.g., {"LB", "RB", "RT"})
---@return boolean true if any button is pressed
function Helpers.IsAnyButtonPressed(button_names)
    for _, button_name in ipairs(button_names) do
        if Helpers.IsButtonPressed(button_name) then
            return true
        end
    end
    return false
end


-- Check if a specific control is pressed (direct CONTROL constant check)
---@param control number CONTROL constant
---@return boolean true if pressed
function Helpers.IsControlPressed(control)
    return G.TheSim:GetDigitalControl(control)
end

-- Check if a control ID matches a logical button name
---@param control number CONTROL constant (e.g., CONTROL_ACCEPT)
---@param button_name ButtonName Logical button name (e.g., "A", "B", "LB", "RT")
---@return boolean true if the control is mapped to this button
function Helpers.IsControlNamedButton(control, button_name)
    local controls = G.BUTTON_MAPPINGS[button_name]
    if not controls then
        return false
    end

    for _, mapped_control in ipairs(controls) do
        if control == mapped_control then
            return true
        end
    end

    return false
end

---@param control number CONTROL constant
---@param button_names ButtonName[] List of button names (e.g., {"LB", "RB", "RT"})
---@return boolean true if the control is mapped to any of the buttons
function Helpers.IsControlAnyOf(control, button_names)
    for _, button_name in ipairs(button_names) do
        if Helpers.IsControlNamedButton(control, button_name) then
            return true
        end
    end
    return false
end


-- Print debug message with mod prefix
---@param message string Message to print
function Helpers.DebugPrint(message)
    print(string.format("[Enhanced Controller] %s", message))
end

-- Print formatted debug message
---@param format string Format string
---@param ... any Format arguments
function Helpers.DebugPrintf(format, ...)
    Helpers.DebugPrint(string.format(format, ...))
end

return Helpers
