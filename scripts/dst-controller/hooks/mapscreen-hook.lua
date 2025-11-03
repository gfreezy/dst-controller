-- Enhanced Controller - MapScreen Hook
-- Hook MapScreen to draw pathfinding paths and handle virtual cursor clicks

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local Helpers = require("dst-controller/utils/helpers")

local MapScreenHook = {}

local function StartPathfinding(wx, wy, wz)
    local player = G.ThePlayer
    if not player then
        return
    end
    local locomotor = player.components.locomotor

    -- 注意：GetWorldPositionAtCursor 返回 (x, 0, z)，其中 y=0 是地面高度
    print(string.format("StartPathfinding world pos: (%.1f, %.1f, %.1f)", wx, wy, wz))

    local target_pos = G.Vector3(wx, wy, wz)
    MapPathDrawer.DrawPathPoints({target_pos}, player:GetPosition())

    if locomotor then
        local action = G.BufferedAction(player, nil, G.ACTIONS.WALKTO, nil, target_pos)
        locomotor:PushAction(action, true)
    end
end

-- Hook MapScreen constructor
function MapScreenHook.Install()
    G.AddClassPostConstruct("screens/mapscreen", function(self)
        -- 设置当前地图屏幕
        MapPathDrawer.SetMapScreen(self)

        -- Hook OnBecomeActive - 地图打开时
        local old_OnBecomeActive = self.OnBecomeActive
        self.OnBecomeActive = function(self)
            old_OnBecomeActive(self)
            MapPathDrawer.SetMapScreen(self)
        end

        -- Hook OnDestroy - 地图关闭时清理
        local old_OnDestroy = self.OnDestroy
        self.OnDestroy = function(self)
            MapPathDrawer.ClearPathDecorations()
            MapPathDrawer.SetMapScreen(nil)
            old_OnDestroy(self)
        end

        -- Hook DoZoomIn/DoZoomOut - 缩放时更新装饰位置
        local old_DoZoomIn = self.DoZoomIn
        self.DoZoomIn = function(self, ...)
            old_DoZoomIn(self, ...)
            MapPathDrawer.UpdateDecorations()
        end

        local old_DoZoomOut = self.DoZoomOut
        self.DoZoomOut = function(self, ...)
            old_DoZoomOut(self, ...)
            MapPathDrawer.UpdateDecorations()
        end


        -- Hook minimap:Offset - 平移时更新装饰位置
        if self.minimap then
            local old_Offset = self.minimap.Offset
            self.minimap.Offset = function(minimap_self, ...)
                old_Offset(minimap_self, ...)
                MapPathDrawer.UpdateDecorations()
            end
        end

        -- Hook OnUpdate - 完全替换地图更新逻辑
        self.OnUpdate = function(self, dt)
            -- ===== 原始 MapScreen:OnUpdate 逻辑 =====

            -- Hack: 忽略持续按下的控制（来自原始实现）
            if self._hack_ignore_held_controls then
                self._hack_ignore_held_controls = self._hack_ignore_held_controls - dt
                if self._hack_ignore_held_controls < 0 then
                    self._hack_ignore_held_controls = nil
                end
            end

            local s = -100 * dt -- per second, not per repeat

            -- 左摇杆控制地图平移
            local xdir = G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_RIGHT) - G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_LEFT)
            local ydir = G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_UP) - G.TheInput:GetAnalogControlValue(G.CONTROL_MOVE_DOWN)
            local xmag = xdir * xdir + ydir * ydir
            local deadzone = G.TUNING.CONTROLLER_DEADZONE_RADIUS
            if xmag >= deadzone * deadzone then
                self.minimap:Offset(xdir * s, ydir * s)
                self.decorationdata.dirty = true
            end

            -- ===== 修改：使用 LB + 右摇杆垂直轴控制缩放 =====
            local ZOOM_CLAMP_MIN = 1
            local ZOOM_CLAMP_MAX = 20
            local TIMETOZOOM = 0.1

            if Helpers.IsButtonPressed("LB") then
                local zoom_in_value = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ZOOM_IN)
                local zoom_out_value = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ZOOM_OUT)
                local inoutdir = zoom_out_value - zoom_in_value

                if math.abs(inoutdir) > deadzone then
                    self.zoom_target_time = TIMETOZOOM
                    local exponential_factor = 1 / 60
                    -- 控制器不需要额外速度增强
                    local zoom_delta = self.zoomsensitivity * inoutdir * exponential_factor * math.abs(inoutdir)
                    self.zoom_target = math.clamp(self.zoom_target + zoom_delta, ZOOM_CLAMP_MIN, ZOOM_CLAMP_MAX)
                    self.zoom_old = self.minimap:GetZoom()
                end
            end

            -- 缩放插值处理
            if self.zoom_target_time > 0 then
                self.zoom_target_time = math.max(0, self.zoom_target_time - dt)
                local Lerp = _G.Lerp or G.Lerp
                local zoom_desired = Lerp(self.zoom_old, self.zoom_target, 1.0 - self.zoom_target_time / TIMETOZOOM)
                local zoom_delta = zoom_desired - self.minimap:GetZoom()
                if zoom_delta < 0 then
                    self:DoZoomIn(zoom_delta)
                elseif zoom_delta > 0 then
                    self:DoZoomOut(zoom_delta)
                end
            end

            -- 更新地图动作和装饰
            local x, y, z = self:GetWorldPositionAtCursor()
            local aax, aay, aaz = self:AutoAimToStaticDecorations(x, y, z)
            local LMBaction, RMBaction = self:UpdateMapActions(aax, aay, aaz)
            self:UpdateMapActionsDecorations(x, y, z, LMBaction, RMBaction)

            -- ===== 新增：LB + 右摇杆水平轴控制相机旋转 =====
            if Helpers.IsButtonPressed("LB") then
                local GetStaticTime = _G.GetStaticTime or G.GetStaticTime
                local Profile = _G.Profile or G.Profile
                local Remap = _G.Remap or G.Remap
                local controller = G.ThePlayer and G.ThePlayer.components.playercontroller

                if controller then
                    local time = GetStaticTime()
                    local invert_rotation = Profile:GetInvertCameraRotation()

                    -- 右摇杆水平轴控制旋转
                    local xdir_rot = G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ROTATE_RIGHT) -
                                     G.TheInput:GetAnalogControlValue(G.VIRTUAL_CONTROL_CAMERA_ROTATE_LEFT)
                    local absxdir = math.abs(xdir_rot)

                    -- 旋转相机
                    if absxdir >= deadzone then
                        local right = xdir_rot > 0
                        if invert_rotation then
                            right = not right
                        end
                        local speed = Remap(math.min(1, absxdir), deadzone, 1, 2, 3)
                        if right then
                            controller:RotRight(speed)
                        else
                            controller:RotLeft(speed)
                        end
                        controller.lastrottime = time
                        MapPathDrawer.UpdateDecorations()
                    end
                end
            end
        end

        -- Hook OnControl - 检测虚拟光标点击启动寻路
        local old_OnControl = self.OnControl
        self.OnControl = function(self, control, down)
            -- 如果按下的是LB或RB，跳过
            if Helpers.IsControlAnyOf(control, {"LB", "RB", "LT", "RT"}) then
                return false
            end

            print("MapScreen OnControl control: " .. tostring(control) .. " down: " .. tostring(down))
            -- 检查是否是虚拟光标模式下的左键点击
            if VirtualCursor.IsCursorModeActive() then
                if control == G.CONTROL_ACCEPT and down then
                -- 获取光标位置的世界坐标
                    local wx, wy, wz = self:GetWorldPositionAtCursor()

                    if wx and wz then
                        print(string.format("[MapScreen] Virtual cursor clicked at world position: (%.1f, %.1f, %.1f)", wx, wy, wz))

                        -- 关闭地图
                        -- G.TheFrontEnd:PopScreen()

                        -- 启动寻路
                        StartPathfinding(wx, wy, wz)
                        MapPathDrawer.UpdateDecorations()

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
