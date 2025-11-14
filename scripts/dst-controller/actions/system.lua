-- Enhanced Controller - System Actions
-- System-level actions for controlling mod features

local VirtualCursor = require("dst-controller/virtual-cursor/core")

local SystemActions = {}

-- ============================================================================
-- Virtual Cursor Actions
-- ============================================================================

-- Enable virtual cursor mode (auto-activation)
function SystemActions.enable_virtual_cursor(player)
    VirtualCursor.AutoEnable()
    print("[Enhanced Controller] Action: Enable Virtual Cursor (auto)")
end

-- Disable virtual cursor mode (only if auto-activated)
function SystemActions.disable_virtual_cursor(player)
    VirtualCursor.AutoDisable()
    print("[Enhanced Controller] Action: Disable Virtual Cursor (auto)")
end

return SystemActions
