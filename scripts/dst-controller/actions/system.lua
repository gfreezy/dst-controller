-- Enhanced Controller - System Actions
-- System-level actions for controlling mod features

local VirtualCursor = require("dst-controller/virtual-cursor/core")

local SystemActions = {}

-- ============================================================================
-- Virtual Cursor Actions
-- ============================================================================

-- Toggle virtual cursor mode on/off
function SystemActions.toggle_virtual_cursor(player)
    VirtualCursor.ToggleCursorMode()
    print(string.format("[Enhanced Controller] Action: Toggle Virtual Cursor (now %s)",
        VirtualCursor.IsCursorModeActive() and "ON" or "OFF"))
end

return SystemActions
