-- Enhanced Controller - MapScreen Hook
-- Hook MapScreen to draw pathfinding paths and handle virtual cursor clicks

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local Helpers = require("dst-controller/utils/helpers")
local ClientPathfinder = require("dst-controller/utils/client_pathfinder")
local WormholeMapVisualizer = require("dst-controller/wormhole-tracker/map_visualizer")

local MapScreenHook = {}

local function StartPathfinding(wx, wy, wz)
    local player = G.ThePlayer
    if not player then
        return
    end

    -- 注意：GetWorldPositionAtCursor 返回 (x, 0, z)，其中 y=0 是地面高度
    Helpers.DebugPrintf("Path target: (%.1f, %.1f, %.1f)", wx, wy, wz)

    -- 客户端模式：只使用本地地图数据计算路径。
    Helpers.DebugPrint("Starting map pathfinding")
    local success = ClientPathfinder.Start(wx, wz, function(path_ready, path)
        if not path_ready or path == nil or not G.ThePlayer then
            return
        end

        -- 搜索可能跨越多帧，路径完成后再绘制。
        local path_points = {}
        for _, waypoint in ipairs(path) do
            path_points[#path_points + 1] =
                G.Vector3(waypoint.x, 0, waypoint.z)
        end
        MapPathDrawer.DrawPathPoints(path_points, G.ThePlayer:GetPosition())
        MapPathDrawer.UpdateDecorations()
        WormholeMapVisualizer.UpdateDecorations()
    end)

    if not success then
        Helpers.DebugPrint("Unable to start pathfinding")
        Helpers.DebugPrint("Target may be unreachable or blocked by ocean")
    end
end

-- Hook MapScreen constructor
function MapScreenHook.Install()
    G.AddClassPostConstruct("screens/mapscreen", function(self)
        -- 设置当前地图屏幕
        MapPathDrawer.SetMapScreen(self)
        WormholeMapVisualizer.SetMapScreen(self)

        -- Hook OnBecomeActive - 地图打开时
        local old_OnBecomeActive = self.OnBecomeActive
        self.OnBecomeActive = function(self)
            old_OnBecomeActive(self)
            MapPathDrawer.SetMapScreen(self)
            WormholeMapVisualizer.SetMapScreen(self)

            -- 绘制已知虫洞连接
            WormholeMapVisualizer.DrawConnections()

            -- 如果正在寻路，重新显示路径
            if ClientPathfinder.IsActive() then
                Helpers.DebugPrint("Pathfinding is active, restoring path")
                local path = ClientPathfinder.GetCurrentPath()
                Helpers.DebugPrintf("Path: %s, length: %d",
                    tostring(path), path and #path or 0)
                Helpers.DebugPrint(
                    "decorationrootstatic: " .. tostring(self.decorationrootstatic))
                if path and #path > 0 and G.ThePlayer then
                    local path_points = {}
                    -- 只显示从当前 waypoint 开始的剩余路径
                    local current_wp, total_wp = ClientPathfinder.GetProgress()
                    Helpers.DebugPrintf("Pathfinding progress: %d/%d",
                        current_wp, total_wp)
                    for i = current_wp, #path do
                        local waypoint = path[i]
                        table.insert(path_points, G.Vector3(waypoint.x, 0, waypoint.z))
                    end
                    if #path_points > 0 then
                        MapPathDrawer.DrawPathPoints(path_points, G.ThePlayer:GetPosition())
                        Helpers.DebugPrintf(
                            "Restored path visualization with %d points", #path_points)
                    end
                end
            else
                Helpers.DebugPrint("No active pathfinding")
            end

            -- Auto-enable virtual cursor for map mode
            VirtualCursor.AutoEnable()
            Helpers.DebugPrint("Virtual cursor enabled for map mode")
        end

        -- Hook OnDestroy - 地图关闭时清理
        local old_OnDestroy = self.OnDestroy
        self.OnDestroy = function(self)
            MapPathDrawer.ClearPathDecorations()
            MapPathDrawer.SetMapScreen(nil)
            WormholeMapVisualizer.ClearDecorations()
            WormholeMapVisualizer.SetMapScreen(nil)

            -- 注意：关闭地图不停止寻路，让角色继续自动走到目标
            -- 只有用户主动移动时才停止（在 playercontroller-hook 中处理）

            -- Auto-disable virtual cursor if it was auto-activated
            VirtualCursor.AutoDisable()
            Helpers.DebugPrint("Virtual cursor disabled after closing map")

            old_OnDestroy(self)
        end

        -- Hook DoZoomIn/DoZoomOut - 缩放时更新装饰位置
        local old_DoZoomIn = self.DoZoomIn
        self.DoZoomIn = function(self, ...)
            old_DoZoomIn(self, ...)
            MapPathDrawer.UpdateDecorations()
            WormholeMapVisualizer.UpdateDecorations()
        end

        local old_DoZoomOut = self.DoZoomOut
        self.DoZoomOut = function(self, ...)
            old_DoZoomOut(self, ...)
            MapPathDrawer.UpdateDecorations()
            WormholeMapVisualizer.UpdateDecorations()
        end


        -- Hook minimap:Offset - 平移时更新装饰位置
        if self.minimap then
            local old_Offset = self.minimap.Offset
            self.minimap.Offset = function(minimap_self, ...)
                old_Offset(minimap_self, ...)
                MapPathDrawer.UpdateDecorations()
                WormholeMapVisualizer.UpdateDecorations()
            end
        end

        -- Wrap the native update so DST map behavior and future game changes are
        -- preserved. Add only the controller extensions owned by this mod.
        local old_OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, dt)
            local result = old_OnUpdate(self, dt)
            local deadzone = G.TUNING.CONTROLLER_DEADZONE_RADIUS

            if Helpers.IsButtonPressed("LB") then
                local zoom_in_value = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ZOOM_IN)
                local zoom_out_value = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ZOOM_OUT)
                local inoutdir = zoom_out_value - zoom_in_value

                if math.abs(inoutdir) > deadzone then
                    local zoom_delta = self.zoomsensitivity * inoutdir * dt * math.abs(inoutdir)
                    if zoom_delta < 0 then
                        self:DoZoomIn(zoom_delta)
                    else
                        self:DoZoomOut(zoom_delta)
                    end
                end

                local controller = G.ThePlayer and G.ThePlayer.components.playercontroller
                if controller then
                    local xdir_rot = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ROTATE_RIGHT) -
                                     G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ROTATE_LEFT)
                    local absxdir = math.abs(xdir_rot)
                    if absxdir >= deadzone then
                        local right = xdir_rot > 0
                        if G.Profile:GetInvertCameraRotation() then
                            right = not right
                        end
                        local speed = G.Remap(math.min(1, absxdir), deadzone, 1, 2, 3)
                        if right then
                            controller:RotRight(speed)
                        else
                            controller:RotLeft(speed)
                        end
                        controller.lastrottime = G.GetStaticTime()
                        MapPathDrawer.UpdateDecorations()
                        WormholeMapVisualizer.UpdateDecorations()
                    end
                end
            end

            -- 全地图在联机模式下不会暂停世界。自动寻路移动玩家时，MiniMap 的
            -- 世界坐标转换会随玩家位置变化，因此世界锚定的自定义装饰必须逐帧
            -- 重新换算，否则终点和路径会相对底图漂移。
            if ClientPathfinder.IsActive() then
                MapPathDrawer.UpdateDecorations()
                WormholeMapVisualizer.UpdateDecorations()
            end
            return result
        end

        -- Hook OnControl - 检测虚拟光标点击启动寻路
        local old_OnControl = self.OnControl
        self.OnControl = function(self, control, down)
            -- 如果按下的是LB或RB，跳过
            if Helpers.IsControlAnyOf(control, {"LB", "RB", "LT", "RT"}) then
                return false
            end

            Helpers.DebugPrintf("Map control: %s, down: %s",
                tostring(control), tostring(down))
            -- 检查是否是虚拟光标模式下的左键点击
            if VirtualCursor.IsCursorModeActive() then
                if control == G.CONTROL_ACCEPT and down then
                -- 获取光标位置的世界坐标
                    local wx, wy, wz = self:GetWorldPositionAtCursor()

                    if wx and wz then
                        Helpers.DebugPrintf(
                            "Map target selected at (%.1f, %.1f, %.1f)", wx, wy, wz)

                        -- 关闭地图
                        -- G.TheFrontEnd:PopScreen()

                        -- 启动寻路
                        StartPathfinding(wx, wy, wz)
                        MapPathDrawer.UpdateDecorations()
                        WormholeMapVisualizer.UpdateDecorations()

                        return true
                    end
                end
            end

            -- 调用原方法
            return old_OnControl(self, control, down)
        end
    end)
end

return MapScreenHook
