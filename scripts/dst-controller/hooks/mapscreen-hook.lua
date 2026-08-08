-- Enhanced Controller - MapScreen Hook
-- Hook MapScreen to draw pathfinding paths and navigate from the center reticle.

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local Helpers = require("dst-controller/utils/helpers")
local ClientPathfinder = require("dst-controller/utils/client_pathfinder")
local WormholeMapVisualizer = require("dst-controller/wormhole-tracker/map_visualizer")
local LocationMapVisualizer = require("dst-controller/locations/map-visualizer")
local PlayerService = require("dst-controller/locations/player-service")
local LocationScreen = require("dst-controller/screens/location-screen")
local MapNavigation = require("dst-controller/utils/map-navigation")
local InputSystemHook = require("dst-controller/hooks/input-system-hook")
local L = require("dst-controller/localization").L

local MapScreenHook = {}
local CURSOR_BLOCK_SOURCE = "enhanced_map_screen"

-- Hook MapScreen constructor
function MapScreenHook.Install()
    LocationMapVisualizer.InstallSubscriptions()
    G.AddClassPostConstruct("screens/mapscreen", function(self)
        -- 设置当前地图屏幕
        MapPathDrawer.SetMapScreen(self)
        WormholeMapVisualizer.SetMapScreen(self)
        LocationMapVisualizer.SetMapScreen(self)
        self.enhanced_location_screen = nil

        self.OpenEnhancedLocationScreen = function(self, ignore_opening_release)
            if self.enhanced_location_screen ~= nil then
                return false
            end
            PlayerService.ClearPositions()
            local screen
            screen = LocationScreen(self, function(closed_screen)
                if self.enhanced_location_screen == closed_screen then
                    self.enhanced_location_screen = nil
                end
            end, ignore_opening_release == true)
            self.enhanced_location_screen = screen
            G.TheFrontEnd:PushScreen(screen)
            return true
        end

        -- Native MapScreen help is hard-coded to the classic scheme (separate
        -- rotate buttons and trigger zoom). Replace it with the controls this
        -- mod actually owns under scheme 2.
        local old_GetHelpText = self.GetHelpText
        self.GetHelpText = function(self)
            if not InputSystemHook.IsControllerPhysicallyAttached() then
                return old_GetHelpText(self)
            end

            local input = G.TheInput
            local controller_id =
                InputSystemHook.GetPhysicalControllerID()
            local localized = function(control)
                return input:GetLocalizedControl(controller_id, control)
            end
            local right_stick = input:GetLocalizedVirtualDirectionalControl(
                controller_id, "rstick",
                G.CONTROL_CAM_AND_INV_MODIFIER, false)
            local hints = {
                localized(G.CONTROL_CAM_AND_INV_MODIFIER) .. " + " ..
                    right_stick .. " " .. L("MAP_HELP_CAMERA"),
            }

            table.insert(hints,
                localized(G.CONTROL_OPEN_CRAFTING) .. " " ..
                    L("MAP_HELP_OPEN_LOCATIONS"))
            table.insert(hints,
                localized(G.CONTROL_CONTROLLER_ACTION) .. " " ..
                    L("MAP_HELP_NAVIGATE"))

            local native_back = G.STRINGS ~= nil and G.STRINGS.UI ~= nil and
                G.STRINGS.UI.HELP ~= nil and G.STRINGS.UI.HELP.BACK or
                L("BUTTON_CLOSE")
            table.insert(hints,
                localized(G.CONTROL_CANCEL) .. " " .. native_back)
            return table.concat(hints, "  ")
        end

        -- Hook OnBecomeActive - 地图打开时
        local old_OnBecomeActive = self.OnBecomeActive
        self.OnBecomeActive = function(self)
            if not self.enhanced_map_cursor_blocked and
                InputSystemHook.IsControllerPhysicallyAttached() then
                self.enhanced_restore_cursor_mode =
                    VirtualCursor.IsCursorModeActive()
                self.enhanced_restore_cursor_auto =
                    self.enhanced_restore_cursor_mode and
                    VirtualCursor.IsAutoActivated()
                VirtualCursor.SetModeBlocked(CURSOR_BLOCK_SOURCE, true)
                self.enhanced_map_cursor_blocked = true
            end
            old_OnBecomeActive(self)
            -- MapScreen can construct mouse zoom controls before its first
            -- OnBecomeActive. Hide that stale layer after switching back to
            -- native controller focus.
            if self.enhanced_map_cursor_blocked and self.mapcontrols ~= nil then
                self.mapcontrols:Hide()
                self.mapcontrols:Disable()
            end
            MapPathDrawer.SetMapScreen(self)
            WormholeMapVisualizer.SetMapScreen(self)
            LocationMapVisualizer.SetMapScreen(self)
            LocationMapVisualizer.Refresh()

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

            Helpers.DebugPrint("Map mode uses native controller focus")
        end

        -- Hook OnDestroy - 地图关闭时清理
        local old_OnDestroy = self.OnDestroy
        self.OnDestroy = function(self)
            MapPathDrawer.ClearPathDecorations()
            MapPathDrawer.SetMapScreen(nil)
            WormholeMapVisualizer.ClearDecorations()
            WormholeMapVisualizer.SetMapScreen(nil)
            LocationMapVisualizer.SetMapScreen(nil)

            -- 注意：关闭地图不停止寻路，让角色继续自动走到目标
            -- 只有用户主动移动时才停止（在 playercontroller-hook 中处理）

            old_OnDestroy(self)

            if self.enhanced_map_cursor_blocked then
                VirtualCursor.SetModeBlocked(CURSOR_BLOCK_SOURCE, false)
                self.enhanced_map_cursor_blocked = false
                if self.enhanced_restore_cursor_mode then
                    VirtualCursor.ToggleCursorMode(
                        true, self.enhanced_restore_cursor_auto)
                end
            end
        end

        -- Hook DoZoomIn/DoZoomOut - 缩放时更新装饰位置
        local old_DoZoomIn = self.DoZoomIn
        self.DoZoomIn = function(self, ...)
            if self.enhanced_block_trigger_zoom then
                return
            end
            old_DoZoomIn(self, ...)
            MapPathDrawer.UpdateDecorations()
            WormholeMapVisualizer.UpdateDecorations()
            LocationMapVisualizer.UpdateDecorations()
        end

        local old_DoZoomOut = self.DoZoomOut
        self.DoZoomOut = function(self, ...)
            if self.enhanced_block_trigger_zoom then
                return
            end
            old_DoZoomOut(self, ...)
            MapPathDrawer.UpdateDecorations()
            WormholeMapVisualizer.UpdateDecorations()
            LocationMapVisualizer.UpdateDecorations()
        end


        -- Hook minimap:Offset - 平移时更新装饰位置
        if self.minimap then
            local old_Offset = self.minimap.Offset
            self.minimap.Offset = function(minimap_self, ...)
                old_Offset(minimap_self, ...)
                MapPathDrawer.UpdateDecorations()
                WormholeMapVisualizer.UpdateDecorations()
                LocationMapVisualizer.UpdateDecorations()
            end
        end

        -- Wrap the native update so DST map behavior and future game changes are
        -- preserved. Add only the controller extensions owned by this mod.
        local old_OnUpdate = self.OnUpdate
        self.OnUpdate = function(self, dt)
            local input = G.TheInput
            local function IsTriggerZoomPressed(control)
                -- GetControlIsMouseWheel is not a reliable source discriminator
                -- here: DST can report controller-bound map zoom controls as
                -- mouse-wheel controls. With a controller attached, disable the
                -- native map zoom controls completely; this mod's LB + right
                -- stick zoom is applied separately below.
                return InputSystemHook.IsControllerPhysicallyAttached() and
                    input:IsControlPressed(control)
            end

            self.enhanced_block_trigger_zoom =
                IsTriggerZoomPressed(G.CONTROL_MAP_ZOOM_IN) or
                IsTriggerZoomPressed(G.CONTROL_MAP_ZOOM_OUT)
            if self.enhanced_block_trigger_zoom then
                local zoom = self.minimap:GetZoom()
                self.zoom_target = zoom
                self.zoom_old = zoom
                self.zoom_target_time = 0
            end
            local result = old_OnUpdate(self, dt)
            if self.enhanced_block_trigger_zoom then
                local zoom = self.minimap:GetZoom()
                self.zoom_target = zoom
                self.zoom_old = zoom
                self.zoom_target_time = 0
            end
            self.enhanced_block_trigger_zoom = false
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
                        LocationMapVisualizer.UpdateDecorations()
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
            LocationMapVisualizer.UpdateDecorations()
            return result
        end

        -- Hook OnControl - A navigates to the world position under the center
        -- reticle. Map mode always uses native controller focus.
        local old_OnControl = self.OnControl
        self.OnControl = function(self, control, down)
            local controller_attached =
                InputSystemHook.IsControllerPhysicallyAttached()
            if controller_attached and
                Helpers.IsControlNamedButton(control, "LT") then
                if down then
                    self:OpenEnhancedLocationScreen(true)
                end
                return true
            end
            -- LT/RT are reserved by this mod in map mode and must never fall
            -- through to native map zoom.
            if Helpers.IsControlAnyOf(control, { "LT", "RT" }) then
                return true
            end
            if Helpers.IsControlAnyOf(control, { "LB", "RB" }) then
                return false
            end

            Helpers.DebugPrintf("Map control: %s, down: %s",
                tostring(control), tostring(down))
            if controller_attached and
                Helpers.IsControlNamedButton(control, "A") then
                if down then
                    local wx, wz = self.minimap:MapPosToWorldPos(0, 0, 0)
                    if wx ~= nil and wz ~= nil then
                        Helpers.DebugPrintf(
                            "Map center selected at (%.1f, %.1f)", wx, wz)
                        local success = MapNavigation.Start(wx, wz)
                        if not success then
                            Helpers.DebugPrint("Unable to start pathfinding")
                            Helpers.DebugPrint(
                                "Target may be unreachable or blocked by ocean")
                        end
                        MapPathDrawer.UpdateDecorations()
                        WormholeMapVisualizer.UpdateDecorations()
                        LocationMapVisualizer.UpdateDecorations()
                    end
                end
                return true
            end

            -- 调用原方法
            return old_OnControl(self, control, down)
        end
    end)
end

return MapScreenHook
