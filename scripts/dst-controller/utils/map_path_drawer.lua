-- Enhanced Controller - Map Path Drawer
-- 在地图界面上绘制寻路路径

local G = require("dst-controller/global")

local MapPathDrawer = {}

-- 当前地图屏幕实例
local current_mapscreen = nil
-- 路径装饰数据
local path_decorations = {}

-- 世界坐标转换为地图屏幕坐标
local function WorldPosToScreenPos(mapscreen, wx, wz)
    if not mapscreen or not mapscreen.minimap then
        return nil, nil
    end

    local w, h = G.TheSim:GetScreenSize()
    local mx, my = mapscreen.minimap:WorldPosToMapPos(wx, wz, 0)
    return mx * w * 0.5, my * h * 0.5
end

-- 清除所有路径装饰
function MapPathDrawer.ClearPathDecorations()
    if not current_mapscreen or not current_mapscreen.decorationrootstatic then
        return
    end

    for guid, decor_data in pairs(path_decorations) do
        if decor_data.widget and decor_data.widget.inst:IsValid() then
            decor_data.widget:Kill()
        end
    end

    path_decorations = {}
end

-- 绘制路径点（使用Image widget）
function MapPathDrawer.DrawPathPoints(key_points, player_pos)
    print("[MapPathDrawer] DrawPathPoints called with " .. #key_points .. " points")
    if not current_mapscreen then
        print("[MapPathDrawer] No mapscreen!")
        return
    end
    if not current_mapscreen.decorationrootstatic then
        print("[MapPathDrawer] No decorationrootstatic!")
        return
    end

    -- 清除旧的装饰
    MapPathDrawer.ClearPathDecorations()

    local Image = require("widgets/image")
    local zoom = current_mapscreen.minimap:GetZoom()
    local zoomscale = 0.75 / zoom
    print("[MapPathDrawer] Zoom: " .. zoom .. ", zoomscale: " .. zoomscale)

    -- 连接线点的大小
    local line_dot_scale = math.max(0.08, zoomscale * 0.15)

    -- 绘制从玩家到第一个关键点的线（用多个点模拟）
    if key_points[1] then
        local start_pos = player_pos
        local end_pos = key_points[1]
        local distance = math.sqrt((end_pos.x - start_pos.x)^2 + (end_pos.z - start_pos.z)^2)
        local num_dots = math.max(3, math.floor(distance / 8))  -- 每8米一个点

        for i = 0, num_dots do
            local t = i / num_dots
            local wx = start_pos.x + (end_pos.x - start_pos.x) * t
            local wz = start_pos.z + (end_pos.z - start_pos.z) * t
            local sx, sy = WorldPosToScreenPos(current_mapscreen, wx, wz)

            if sx and sy then
                local dot = current_mapscreen.decorationrootstatic:AddChild(Image("images/global.xml", "square.tex"))
                dot:SetTint(0, 1, 0, 0.8)  -- 绿色
                dot:SetPosition(sx, sy)
                dot:SetScale(line_dot_scale, line_dot_scale, 1)

                local guid = string.format("path_line_0_%d", i)
                path_decorations[guid] = {
                    widget = dot,
                    wx = wx,
                    wz = wz,
                }
            end
        end
    end

    -- 绘制关键点之间的线
    for i = 1, #key_points - 1 do
        local start_pos = key_points[i]
        local end_pos = key_points[i + 1]
        local distance = math.sqrt((end_pos.x - start_pos.x)^2 + (end_pos.z - start_pos.z)^2)
        local num_dots = math.max(3, math.floor(distance / 8))  -- 每8米一个点

        for j = 0, num_dots do
            local t = j / num_dots
            local wx = start_pos.x + (end_pos.x - start_pos.x) * t
            local wz = start_pos.z + (end_pos.z - start_pos.z) * t
            local sx, sy = WorldPosToScreenPos(current_mapscreen, wx, wz)

            if sx and sy then
                local dot = current_mapscreen.decorationrootstatic:AddChild(Image("images/global.xml", "square.tex"))
                dot:SetTint(0, 1, 0, 0.8)  -- 绿色
                dot:SetPosition(sx, sy)
                dot:SetScale(line_dot_scale, line_dot_scale, 1)

                local guid = string.format("path_line_%d_%d", i, j)
                path_decorations[guid] = {
                    widget = dot,
                    wx = wx,
                    wz = wz,
                }
            end
        end
    end

    -- 关键点的大小（比连接线点稍大）
    local keypoint_scale = math.max(0.12, zoomscale * 0.25)

    -- 绘制关键点标记（黄色圆点）
    for i, point in ipairs(key_points) do
        local sx, sy = WorldPosToScreenPos(current_mapscreen, point.x, point.z)

        if sx and sy then
            local marker = current_mapscreen.decorationrootstatic:AddChild(Image("images/global.xml", "square.tex"))
            marker:SetTint(1, 1, 0, 1)  -- 黄色
            marker:SetPosition(sx, sy)
            marker:SetScale(keypoint_scale, keypoint_scale, 1)

            local guid = string.format("path_keypoint_%d", i)
            path_decorations[guid] = {
                widget = marker,
                wx = point.x,
                wz = point.z,
                is_keypoint = true,
            }
        end
    end
end

-- 更新装饰位置和缩放（地图缩放/平移时调用）
function MapPathDrawer.UpdateDecorations()
    if not current_mapscreen or not current_mapscreen.minimap then
        return
    end

    local zoomscale = 0.75 / current_mapscreen.minimap:GetZoom()
    local line_dot_scale = math.max(0.08, zoomscale * 0.15)
    local keypoint_scale = math.max(0.12, zoomscale * 0.25)

    for guid, decor_data in pairs(path_decorations) do
        if decor_data.widget and decor_data.widget.inst:IsValid() then
            local sx, sy = WorldPosToScreenPos(current_mapscreen, decor_data.wx, decor_data.wz)
            if sx and sy then
                decor_data.widget:SetPosition(sx, sy)
                local scale = decor_data.is_keypoint and keypoint_scale or line_dot_scale
                decor_data.widget:SetScale(scale, scale, 1)
            end
        end
    end
end

-- 设置当前地图屏幕
function MapPathDrawer.SetMapScreen(mapscreen)
    current_mapscreen = mapscreen
end

-- 获取当前地图屏幕
function MapPathDrawer.GetMapScreen()
    return current_mapscreen
end

return MapPathDrawer
