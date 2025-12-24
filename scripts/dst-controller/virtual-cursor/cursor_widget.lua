-- Virtual Cursor Widget
-- Displays cursor icon on screen

local G = require("dst-controller/global")
local Widget = require("widgets/widget")
local Image = require("widgets/image")

local CursorWidget = G.Class(Widget, function(self)
    Widget._ctor(self, "CursorWidget")

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
        self.cursor_image:SetScale(0.6)
        self.cursor_image:SetClickable(false)
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
    Widget.SetPosition(self, x, y, 0)
end

return CursorWidget
