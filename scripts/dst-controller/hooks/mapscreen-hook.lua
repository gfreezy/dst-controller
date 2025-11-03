-- Enhanced Controller - MapScreen Hook
-- Hook MapScreen to draw pathfinding paths and handle virtual cursor clicks

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")
local HybridPathfinding = require("dst-controller/utils/auto_pathfinding_hybrid")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local MapScreenHook = {}

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

        -- Hook OnControl - 检测虚拟光标点击启动寻路
        local old_OnControl = self.OnControl
        self.OnControl = function(self, control, down)
            print("MapScreen OnControl control: " .. tostring(control) .. " down: " .. tostring(down))
            -- 检查是否是虚拟光标模式下的左键点击
            if VirtualCursor.IsCursorModeActive() and control == G.CONTROL_ACCEPT and down then
                -- 获取光标位置的世界坐标
                local wx, wy, wz = self:GetWorldPositionAtCursor()

                if wx and wz then
                    print(string.format("[MapScreen] Virtual cursor clicked at world position: (%.1f, %.1f, %.1f)", wx, wy, wz))

                    -- 关闭地图
                    -- G.TheFrontEnd:PopScreen()

                    -- 启动寻路
                    HybridPathfinding.Start(wx, wy, wz, {
                        avoid_hostiles = true,
                        auto_explore_fog = true,
                        avoid_spider_dens = true
                    })

                    return true
                end
            end

            -- 调用原方法
            return old_OnControl(self, control, down)
        end
    end)
end

return MapScreenHook
