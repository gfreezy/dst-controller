-- Layout Helper - 布局辅助函数
-- 提供简单的横向/纵向布局工具
--
-- ============================================================================
-- DST 坐标系统说明
-- ============================================================================
--
-- 1. 屏幕坐标系统：
--    - 原点 (0, 0) 在屏幕中心
--    - X 轴：负数向左，正数向右（-640 到 +640）
--    - Y 轴：负数向下，正数向上（-360 到 +360）
--    - 分辨率基准：1280x720
--
-- 2. Widget 坐标系统：
--    - 每个 widget 都有自己的局部坐标系
--    - widget:SetPosition(x, y, z) 设置相对于父容器的位置
--    - 默认情况下，widget 的锚点在其自身中心
--
-- 3. ScrollableList 内部：
--    - ScrollableList 的原点在列表中心
--    - 列表项从左上角开始排列：(-width/2, height/2)
--    - 向右为正 X，向下为负 Y
--
-- 4. 本布局工具的假设：
--    - 所有 widget 的锚点都在其中心
--    - SetPosition(x, y) 会把 widget 的中心放在 (x, y)
--    - width 参数是 widget 的实际宽度
--
-- ============================================================================

local Layout = {}

---@class LayoutOptions
---@field spacing? number 元素之间的间距
---@field padding? number 开始位置的偏移
---@field start_x? number 起始 X 坐标
---@field start_y? number 起始 Y 坐标
---@field anchor? string 锚点位置 "left", "center", "right" (水平) 或 "top", "center", "bottom" (垂直)

--- 水平布局（从左到右）
--- @param widgets table Widget 数组
--- @param options LayoutOptions 布局选项
--- @return number 总宽度
function Layout.Horizontal(widgets, options)
    options = options or {}
    local spacing = options.spacing or 0
    local padding = options.padding or 0
    local start_x = options.start_x or 0
    local start_y = options.start_y or 0
    local anchor = options.anchor or "left"  -- left, center, right

    -- 计算总宽度（用于居中对齐）
    local total_width = padding * 2
    if #widgets > 0 then
        total_width = total_width + (#widgets - 1) * spacing
    end

    -- 如果需要计算每个 widget 的宽度，这里可以扩展
    -- 目前假设 spacing 已经包含了 widget 的实际宽度

    local x = start_x

    -- 根据锚点调整起始位置
    if anchor == "center" then
        x = start_x - (total_width - padding * 2) / 2
    elseif anchor == "right" then
        x = start_x - (total_width - padding * 2)
    end

    x = x + padding

    for i, widget in ipairs(widgets) do
        if widget then
            widget:SetPosition(x, start_y, 0)
            x = x + spacing
        end
    end

    return total_width
end

--- 垂直布局（从上到下）
--- @param widgets table Widget 数组
--- @param options LayoutOptions 布局选项
--- @return number 总高度
function Layout.Vertical(widgets, options)
    options = options or {}
    local spacing = options.spacing or 0
    local padding = options.padding or 0
    local start_x = options.start_x or 0
    local start_y = options.start_y or 0
    local anchor = options.anchor or "top"  -- top, center, bottom

    -- 计算总高度（用于居中对齐）
    local total_height = padding * 2
    if #widgets > 0 then
        total_height = total_height + (#widgets - 1) * spacing
    end

    local y = start_y

    -- 根据锚点调整起始位置
    if anchor == "center" then
        y = start_y + (total_height - padding * 2) / 2
    elseif anchor == "bottom" then
        y = start_y + (total_height - padding * 2)
    end

    y = y - padding

    for i, widget in ipairs(widgets) do
        if widget then
            widget:SetPosition(start_x, y, 0)
            y = y - spacing
        end
    end

    return total_height
end

--- 水平行布局（从左到右，自动计算宽度和位置）
--- @param widgets table Widget 数组，每个元素可以是 {widget=widget, width=number} 或直接是 widget
--- @param options LayoutOptions 布局选项
--- @return number 总宽度
function Layout.HorizontalRow(widgets, options)
    options = options or {}
    local spacing = options.spacing or 0
    local padding = options.padding or 0
    local start_x = options.start_x or 0
    local start_y = options.start_y or 0
    local anchor = options.anchor or "left"  -- left, center, right

    -- 计算总宽度（包括 nil widget 的占位）
    local total_width = padding * 2
    for i, item in ipairs(widgets) do
        local width = 0
        if type(item) == "table" and item.width then
            width = item.width
        end
        total_width = total_width + width
        if i < #widgets then
            total_width = total_width + spacing
        end
    end

    local x = start_x

    -- 根据锚点调整起始位置
    -- total_width 包含了 padding*2，所以减去 padding*2 得到实际内容宽度
    local content_width = total_width - padding * 2

    if anchor == "center" then
        -- 居中：从内容宽度的负一半开始
        x = start_x - content_width / 2
    elseif anchor == "right" then
        -- 右对齐：从内容宽度的负值开始
        x = start_x - content_width
    else
        -- 左对齐：直接从 start_x 开始
        x = start_x
    end

    x = x + padding

    for i, item in ipairs(widgets) do
        local widget = item
        local width = 0

        if type(item) == "table" then
            widget = item.widget
            width = item.width or 0
        end

        if widget then
            -- 将 widget 放在当前元素的中心
            widget:SetPosition(x + width / 2, start_y, 0)
            x = x + width + spacing
        end
    end

    return total_width
end

--- 创建一个网格布局器
--- @param cols number 列数
--- @param rows number 行数
--- @param cell_width number 单元格宽度
--- @param cell_height number 单元格高度
--- @param spacing_x number 水平间距
--- @param spacing_y number 垂直间距
--- @return table 网格布局器对象
function Layout.Grid(cols, rows, cell_width, cell_height, spacing_x, spacing_y)
    local grid = {
        cols = cols,
        rows = rows,
        cell_width = cell_width,
        cell_height = cell_height,
        spacing_x = spacing_x or 0,
        spacing_y = spacing_y or 0,
    }

    --- 获取网格单元格的位置
    --- @param col number 列索引 (1-based)
    --- @param row number 行索引 (1-based)
    --- @param anchor string 锚点 "topleft", "center"
    --- @return number, number X 和 Y 坐标
    function grid:GetCellPosition(col, row, anchor)
        anchor = anchor or "center"

        local total_width = self.cols * self.cell_width + (self.cols - 1) * self.spacing_x
        local total_height = self.rows * self.cell_height + (self.rows - 1) * self.spacing_y

        local x, y

        if anchor == "center" then
            -- 从中心开始计算
            x = -total_width / 2 + (col - 0.5) * self.cell_width + (col - 1) * self.spacing_x
            y = total_height / 2 - (row - 0.5) * self.cell_height - (row - 1) * self.spacing_y
        elseif anchor == "topleft" then
            -- 从左上角开始计算
            x = (col - 1) * (self.cell_width + self.spacing_x)
            y = -(row - 1) * (self.cell_height + self.spacing_y)
        end

        return x, y
    end

    --- 将 widget 放置到指定的网格单元格
    --- @param widget table Widget 对象
    --- @param col number 列索引 (1-based)
    --- @param row number 行索引 (1-based)
    --- @param anchor string 锚点
    function grid:PlaceWidget(widget, col, row, anchor)
        local x, y = self:GetCellPosition(col, row, anchor)
        widget:SetPosition(x, y, 0)
    end

    return grid
end

--- 辅助函数：创建一个居中的水平布局容器
--- @param parent table 父 widget
--- @param items table 布局项数组，格式：{{widget=w1, width=100}, {widget=w2, width=50}, ...}
--- @param y number Y 坐标
--- @param spacing number 间距
--- @return table 容器 widget
function Layout.CreateCenteredRow(parent, items, y, spacing)
    local Widget = require("widgets/widget")
    local container = parent:AddChild(Widget("centered_row"))
    container:SetPosition(0, y, 0)

    Layout.HorizontalRow(items, {
        spacing = spacing or 10,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    return container
end

return Layout
