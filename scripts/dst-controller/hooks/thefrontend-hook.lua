-- Enhanced Controller - TheFrontEnd Hook
-- Hook TheFrontEnd to handle virtual cursor updates and controls globally

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local CursorWidget = require("dst-controller/virtual-cursor/cursor_widget")
local ActionQueueIntegration = require("dst-controller/integrations/actionqueue")
local ShoulderModifiers = require("dst-controller/integrations/shoulder-modifiers")
local ClientPathfinder = require("dst-controller/utils/client_pathfinder")
local Helpers = require("dst-controller/utils/helpers")

local TheFrontEndHook = {}

-- Hook TheFrontEnd
function TheFrontEndHook.Install()
    -- Hook TheFrontEnd after it's created
    G.AddGlobalClassPostConstruct("frontend", "FrontEnd", function(self)
        -- Create cursor widget and add to FrontEnd's overlay root (top-most layer)
        -- This ensures it's above all screens including menus and maps
        local cursor_widget = self.overlayroot:AddChild(CursorWidget())
        cursor_widget:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
        cursor_widget:MoveToFront()

        -- Register widget with VirtualCursor core
        VirtualCursor.SetCursorWidget(cursor_widget)

        Helpers.DebugPrint("Cursor widget ready")

        -- Hook OnUpdate - 处理虚拟光标的位置更新
        local old_Update = self.Update

        self.Update = function(self, dt)
            -- 更新虚拟光标（如果启用）
            VirtualCursor.OnUpdate(self, dt)
            ShoulderModifiers.OnUpdate()
            ActionQueueIntegration.OnUpdate()
            ClientPathfinder.UpdateSearch()

            -- 调用原方法
            return old_Update(self, dt)
        end

        -- Hook OnControl - 处理虚拟光标的输入控制
        local old_OnControl = self.OnControl

        self.OnControl = function(self, control, down)
            -- 处理虚拟光标模式切换
            if VirtualCursor.ToggleOnControl(control, down) then
                local cursor_active = VirtualCursor.IsCursorModeActive()
                ShoulderModifiers.OnCursorModeChanged(cursor_active)
                ActionQueueIntegration.OnCursorModeChanged(cursor_active)
                return true
            end

            -- Publish the configured virtual keyboard state before integrations
            -- inspect this control. Consumption is deferred so ActionQueue and
            -- normal virtual mouse handling can still see the same event.
            local shoulder_handled = ShoulderModifiers.OnControl(control, down)

            -- ActionQueue must run before normal virtual mouse clicks so a
            -- captured selection is not also sent to the game as a click.
            if ActionQueueIntegration.OnControl(control, down) then
                return true
            end

            -- 尝试处理虚拟光标控制
            if VirtualCursor.OnControl(control, down) then
                return true
            end

            if shoulder_handled then
                return true
            end

            -- 调用原方法
            return old_OnControl(self, control, down)
        end

        -- Hook PushScreen - 确保 cursor_widget 始终在最上层
        local old_PushScreen = self.PushScreen

        self.PushScreen = function(self, screen)
            -- 调用原方法
            local result = old_PushScreen(self, screen)

            -- 将 cursor_widget 移到最前面（在所有 screen 之上）
            if cursor_widget and cursor_widget.inst:IsValid() then
                cursor_widget:MoveToFront()
            end
            return result
        end

        Helpers.DebugPrint("Virtual cursor ready")
    end)
end

return TheFrontEndHook
