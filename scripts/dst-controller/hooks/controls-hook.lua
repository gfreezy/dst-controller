-- Controls Widget Hook
-- Injects cursor widget into HUD
-- Extracted from virtual-cursor-hook.lua

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local CursorWidget = require("dst-controller/virtual-cursor/cursor_widget")

local ControlsHook = {}

-- Install Controls widget hook
function ControlsHook.Install()
    -- Hook into HUD to add cursor widget
    G.AddClassPostConstruct("widgets/controls", function(self)
        -- Create cursor widget and add to HUD
        local cursor_widget = self:AddChild(CursorWidget())
        cursor_widget:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
        cursor_widget:MoveToFront()  -- Ensure cursor is always on top

        -- Register widget with VirtualCursor core
        VirtualCursor.SetCursorWidget(cursor_widget)

        -- Store reference in playercontroller for updates
        if G.ThePlayer and G.ThePlayer.components.playercontroller then
            G.ThePlayer.components.playercontroller._cursor_widget = cursor_widget
        end
    end)
end

return ControlsHook
