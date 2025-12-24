-- Virtual Cursor Widget
-- Displays cursor icon on screen

local G = require("dst-controller/global")
local Widget = require("widgets/widget")
local Image = require("widgets/image")

local CursorWidget = G.Class(Widget, function(self)
    Widget._ctor(self, "CursorWidget")

    -- 光标图片尺寸和偏移（用于对齐左上角热点）
    self.cursor_offset_x = 0
    self.cursor_offset_y = 0

    -- 先用默认光标，稍后替换为自定义光标
    self.cursor_image = self:AddChild(Image("images/frontend.xml", "nav_cursor.tex"))
    self.cursor_image:SetScale(1.0)
    self.cursor_image:SetClickable(false)

    -- Colors
    self.normal_color = {1, 1, 1, 1}    -- White (fully opaque)
    self.drag_color = {1, 0.8, 0, 1}    -- Yellow/Orange when dragging

    self:SetNormalColor()
    self:Hide()

    -- 延迟加载自定义光标（等待 Assets 加载完成）
    self.inst:DoTaskInTime(0.5, function()
        self:LoadCustomCursor()
    end)
end)

function CursorWidget:LoadCustomCursor()
    local modname = G.modname or "enhanced_controller"
    local cursor_atlas = "../mods/" .. modname .. "/images/cursor.xml"

    print("[CursorWidget] Loading custom cursor: " .. cursor_atlas)

    local success = pcall(function()
        -- 移除旧光标
        if self.cursor_image then
            self.cursor_image:Kill()
        end
        -- 创建新光标
        self.cursor_image = self:AddChild(Image(cursor_atlas, "cursor.tex"))

        -- 光标图片大小: 48x48, 缩放 0.6 = 显示大小约 29x29
        -- 鼠标热点在左上角，需要偏移图片使左上角对齐到位置
        local scale = 0.6
        local cursor_size = 48 * scale  -- 约 29 像素
        self.cursor_image:SetScale(scale)
        self.cursor_image:SetClickable(false)

        -- 偏移：向右下移动半个光标大小，使左上角对齐到位置点
        self.cursor_offset_x = cursor_size / 2
        self.cursor_offset_y = -cursor_size / 2  -- Y轴向下是负方向

        self:SetNormalColor()
    end)

    if success then
        print("[CursorWidget] Custom cursor loaded!")
    else
        print("[CursorWidget] Failed to load custom cursor")
    end
end

function CursorWidget:SetNormalColor()
    self.cursor_image:SetTint(
        self.normal_color[1],
        self.normal_color[2],
        self.normal_color[3],
        self.normal_color[4]
    )
end

function CursorWidget:SetDragColor()
    self.cursor_image:SetTint(
        self.drag_color[1],
        self.drag_color[2],
        self.drag_color[3],
        self.drag_color[4]
    )
end

function CursorWidget:SetPosition(x, y)
    -- Widget 位置是实际点击位置
    Widget.SetPosition(self, x, y, 0)
    -- 光标图片偏移，使左上角热点对齐到位置
    if self.cursor_image then
        self.cursor_image:SetPosition(self.cursor_offset_x, self.cursor_offset_y, 0)
    end
end

return CursorWidget
