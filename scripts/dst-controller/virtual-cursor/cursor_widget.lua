-- Virtual Cursor Widget
-- Displays cursor icon on screen

local G = require("dst-controller/global")
local Widget = require("widgets/widget")
local Image = require("widgets/image")

local CursorWidget = G.Class(Widget, function(self)
    Widget._ctor(self, "CursorWidget")

    -- Create cursor image using DST's built-in square texture
    self.cursor_image = self:AddChild(Image("images/global.xml", "square.tex"))
    self.cursor_image:SetScale(0.03, 0.03)  -- Small square as cursor (about 10x10 pixels)
    self.cursor_image:SetClickable(false)

    -- Colors
    self.normal_color = {1, 1, 1, 0.9}  -- White
    self.drag_color = {1, 0.5, 0, 1}    -- Orange

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

function CursorWidget:UpdateDragState(is_dragging)
    if is_dragging then
        self:SetDragColor()
    else
        self:SetNormalColor()
    end
end

return CursorWidget
