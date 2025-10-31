-- Virtual Cursor Widget
-- Displays cursor icon on screen

local G = require("dst-controller/global")
local Widget = require("widgets/widget")
local Image = require("widgets/image")

local CursorWidget = G.Class(Widget, function(self)
    Widget._ctor(self, "CursorWidget")

    -- Create cursor image using DST's navigation cursor texture
    self.cursor_image = self:AddChild(Image("images/frontend.xml", "nav_cursor.tex"))
    self.cursor_image:SetScale(0.8)  -- Scale to appropriate size
    self.cursor_image:SetClickable(false)

    -- Colors
    self.normal_color = {1, 1, 1, 1}    -- White (fully opaque)
    self.drag_color = {1, 0.8, 0, 1}    -- Yellow/Orange when dragging

    self:SetNormalColor()
    self:Hide()
end)

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
