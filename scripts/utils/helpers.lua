-- Enhanced Controller - Utility Helper Functions
-- Common utility functions used across the mod

local Helpers = {}

-- Check if a specific button (logical name) is currently pressed
-- @param button_name: Logical button name (e.g., "LB", "RB", "A", "B", "X", "Y")
-- @param button_mappings: Table mapping logical names to CONTROL constants
-- @return boolean: true if any mapped control for this button is pressed
function Helpers.IsButtonPressed(button_name, button_mappings)
    local controls = button_mappings[button_name]
    if not controls then
        return false
    end

    for _, control in ipairs(controls) do
        if TheInput:IsControlPressed(control) then
            return true
        end
    end

    return false
end

-- Check if a specific control is pressed (direct CONTROL constant check)
-- @param control: CONTROL constant
-- @return boolean: true if pressed
function Helpers.IsControlPressed(control)
    return TheInput:IsControlPressed(control)
end

-- Print debug message with mod prefix
-- @param message: Message to print
function Helpers.DebugPrint(message)
    print(string.format("[Enhanced Controller] %s", message))
end

-- Print formatted debug message
-- @param format: Format string
-- @param ...: Format arguments
function Helpers.DebugPrintf(format, ...)
    Helpers.DebugPrint(string.format(format, ...))
end

return Helpers
