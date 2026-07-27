# DST 原生 UI 组件与布局实用手册

> 适用范围：本仓库中的《饥荒联机版》客户端 MOD。内容以仓库当前保存的 `scripts-raw` 游戏源码为准，重点介绍适合自定义界面复用的通用组件，而不是某个游戏业务专用的 Widget。

## 1. 先看结论：应该选哪个组件

| 需求 | 首选 | 说明 |
| --- | --- | --- |
| 组织一组子控件 | `Widget` | 所有 UI 的基础容器，负责父子关系、位置、缩放、显隐和焦点转发 |
| 独立全屏或弹出界面 | `Screen` | 能被 `TheFrontEnd:PushScreen` 管理，有激活、失活和默认焦点生命周期 |
| 文本 | `Text` | 支持颜色、字号、区域、对齐、换行和截断 |
| 图片、背景、图标 | `Image` | 使用 atlas 与 texture，支持拉伸、染色和鼠标状态纹理 |
| 普通文字按钮 | `TEMPLATES.StandardButton` | 优先使用，外观和原版 Redux 菜单一致 |
| 图标按钮 | `TEMPLATES.IconButton` | 适合纯图标或图标旁带标签的按钮 |
| 完全自定义纹理按钮 | `ImageButton` | 需要自己提供 normal/focus/disabled/down 等纹理 |
| 一行或一列按钮 | `Menu` / `TEMPLATES.StandardMenu` | 自动排列并连接相邻按钮的手柄焦点 |
| 数量固定的小网格 | `Grid` | 自动定位并连接上下左右焦点；不负责滚动 |
| 长列表或动态数据网格 | `TEMPLATES.ScrollingGrid` | 推荐方案，内部使用虚拟化的 `TrueScrollList`，只创建可见行 |
| 少量固定控件分页显示 | `PagedList` | 复用一组固定 Widget，整页切换数据 |
| 标签页 | `HeaderTabs` | 原版 Redux 窗口顶部标签样式 |
| 设置项选择 | `TEMPLATES.LabelSpinner` | 带标签的选项切换器，选项格式为 `{ text, data }` |
| 数字设置 | `TEMPLATES.LabelNumericSpinner` | 指定最小值、最大值的数字切换器 |
| 文本输入 | `TEMPLATES.LabelTextbox` | 带标签的单行输入框 |
| 复选项 | `TEMPLATES.StandardCheckbox` / `LabelCheckbox` | 标准原版复选框 |
| 普通面板 | `TEMPLATES.RectangleWindow` | Redux 灰褐色九宫格窗口，适合内容面板 |
| 强调型弹窗 | `TEMPLATES.CurlyWindow` | 黑金装饰窗口，适合确认、设置等模态弹窗 |
| 简单提示或确认 | `PopupDialogScreen` | 已封装标题、正文、按钮和手柄输入 |
| 让用户输入名称 | `InputDialogScreen` | 已封装输入框、按钮和模态行为 |
| UI 动画资源 | `UIAnim` | 播放原版 `AnimState` build/bank/animation |

日常开发的优先级可以简单记成：**先找 Redux `TEMPLATES`，再用基础 Widget 自己拼；列表优先 `ScrollingGrid`，不要一开始就手写滚动逻辑。**

## 2. 源码入口与引用方式

最值得反复查看的源码：

- [Widget 基类](scripts-raw/widgets/widget.lua)
- [Screen 基类](scripts-raw/widgets/screen.lua)
- [Redux 通用模板](scripts-raw/widgets/redux/templates.lua)
- [Grid 静态网格](scripts-raw/widgets/grid.lua)
- [TrueScrollList 虚拟滚动列表](scripts-raw/widgets/truescrolllist.lua)
- [HeaderTabs 标签页](scripts-raw/widgets/redux/headertabs.lua)
- [PopupDialogScreen](scripts-raw/screens/redux/popupdialog.lua)
- [InputDialogScreen](scripts-raw/screens/redux/inputdialog.lua)

基础引用：

```lua
local Widget = require("widgets/widget")
local Screen = require("widgets/screen")
local Image = require("widgets/image")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")
local Grid = require("widgets/grid")
local HeaderTabs = require("widgets/redux/headertabs")
local TEMPLATES = require("widgets/redux/templates")
```

本项目要求通过统一代理访问 `GLOBAL` 和 MOD 环境，因此项目代码还会使用：

```lua
local G = require("dst-controller/global")
```

例如常量写成 `G.ANCHOR_MIDDLE`、`G.MOVE_DOWN`、`G.CONTROL_CANCEL`，前端管理器写成 `G.TheFrontEnd`。不要在项目模块中另建一套零散的 `GLOBAL.xxx` 引用。

## 3. 基础组件

### 3.1 Widget：容器和所有控件的共同基类

典型自定义 Widget：

```lua
local MyPanel = G.Class(Widget, function(self)
    Widget._ctor(self, "MyPanel")

    self.title = self:AddChild(Text(G.HEADERFONT, 34, "标题"))
    self.title:SetPosition(0, 120)

    self.icon = self:AddChild(Image("images/my_ui.xml", "my_icon.tex"))
    self.icon:SetPosition(-120, 20)
end)
```

常用方法分组如下：

| 类别 | 常用方法 |
| --- | --- |
| 子控件 | `AddChild`、`RemoveChild`、`KillAllChildren`、`GetChildren`、`GetParent` |
| 生命周期 | `Show`、`Hide`、`Kill`、`Enable`、`Disable`、`IsVisible`、`IsEnabled` |
| 变换 | `SetPosition`、`Nudge`、`SetScale`、`SetRotation` |
| 屏幕适配 | `SetHAnchor`、`SetVAnchor`、`SetScaleMode`、`SetMaxPropUpscale` |
| 层级 | `MoveToFront`、`MoveToBack` |
| 焦点 | `SetFocus`、`SetFocusChangeDir`、`ClearFocusDirs`、`focus_forward` |
| 鼠标 | `SetClickable`、`FollowMouse`、`SetTooltip`、`SetHoverText` |
| 动画 | `ScaleTo`、`MoveTo`、`RotateTo`、`TintTo` 及相应的 `Cancel...` |
| 更新 | `StartUpdating`、`StopUpdating`、`OnUpdate`、`UpdateWhilePaused` |

注意：Widget 默认在游戏暂停时仍更新。只有动画或逻辑必须跟随模拟时间时，才调用 `UpdateWhilePaused(false)`。

### 3.2 Screen：可压栈管理的界面

`Screen` 继承 `Widget`，额外提供：

- `OnCreate` / `OnDestroy`
- `OnBecomeActive` / `OnBecomeInactive`
- `default_focus`
- `GetHelpText`
- `AddEventHandler` / `RemoveEventHandler`

打开与关闭：

```lua
G.TheFrontEnd:PushScreen(MyScreen())
G.TheFrontEnd:PopScreen(screen_instance)
```

界面重新激活时，原版会优先恢复 `last_focus`，否则聚焦 `default_focus`。因此手柄界面一定要给 `default_focus` 赋值。

### 3.3 Text：文本与排版

构造函数：

```lua
Text(font, size, text, colour)
```

最常用的接口：

```lua
text:SetString("新内容")
text:SetColour(1, 0.8, 0.2, 1)
text:SetSize(28)
text:SetRegionSize(420, 80)
text:SetHAlign(G.ANCHOR_LEFT)
text:SetVAlign(G.ANCHOR_MIDDLE)
text:EnableWordWrap(true)
text:SetTruncatedString(long_text, 400, 40, true)
```

仅设置字符串不会自动解决长文本溢出。固定区域中的说明文字通常要同时设置 `SetRegionSize` 和换行或截断。

### 3.4 Image：图片、背景和装饰

构造函数：

```lua
Image(atlas, texture, default_texture)
```

常用接口：

```lua
image:SetTexture("images/my_ui.xml", "icon.tex")
image:ScaleToSize(64, 64)
image:SetTint(1, 1, 1, 0.8)
image:SetClickable(false)
```

纹理由 atlas XML 和其中的 texture 名共同确定。`SetTexture` 会更新图片原始尺寸信息，因此如果切换的新旧纹理尺寸不同，应在切换后重新执行 `ScaleToSize`。

纯装饰 Image 建议显式调用 `SetClickable(false)`，避免它盖在按钮上时抢走鼠标点击。

### 3.5 Button、ImageButton 与标准按钮

直接使用 [Button](scripts-raw/widgets/button.lua) 的情况很少，它主要是按钮状态和输入回调的基类。自定义纹理时使用：

```lua
local button = ImageButton(
    "images/my_ui.xml",
    "normal.tex",
    "focus.tex",
    "disabled.tex",
    "down.tex",
    "selected.tex"
)
button:SetOnClick(function() DoSomething() end)
button:ForceImageSize(180, 48)
button:SetText("执行")
```

普通按钮优先使用原版模板：

```lua
local button = TEMPLATES.StandardButton(
    function() DoSomething() end,
    "执行",
    { 220, 48 }
)
```

重要状态区别：

- `SetFocus()` 表示当前由鼠标或手柄聚焦。
- `Select()` 表示被选中，视觉上更接近锁定/已选择状态，不等于焦点。
- `Disable()` 禁止交互；`Hide()` 只控制显隐。临时隐藏交互控件时，通常两者一起做最稳妥。
- 自定义 `ImageButton` 如果选中状态下也必须显示焦点，可使用 `UseFocusOverlay(texture)`；常常还要设置 `scale_on_focus = false`，避免覆盖层跟随缩放产生跳动。

### 3.6 TextEdit、Spinner 和 Checkbox

单行输入优先使用：

```lua
local field = TEMPLATES.LabelTextbox(
    "名称", "", 120, 300, 44, 10
)
field.textbox:SetTextLengthLimit(40)
```

选项切换器的数据格式：

```lua
local options = {
    { text = "关闭", data = false },
    { text = "开启", data = true },
}

local setting = TEMPLATES.LabelSpinner(
    "功能", options, 180, 180, 44, 10,
    nil, nil, nil,
    function(selected_data)
        -- selected_data 为 false 或 true
    end
)

setting.spinner:SetSelected(true)
local value = setting.spinner:GetSelectedData()
```

常用表单模板集中在 [Redux templates](scripts-raw/widgets/redux/templates.lua)：

| 模板 | 用途 |
| --- | --- |
| `StandardSingleLineTextEntry` | 无标签单行输入框 |
| `LabelTextbox` | 带标签单行输入框 |
| `StandardSpinner` | 无标签选项切换器 |
| `LabelSpinner` | 带标签选项切换器 |
| `StandardNumericSpinner` | 数字切换器 |
| `LabelNumericSpinner` | 带标签数字切换器 |
| `StandardCheckbox` | 标准复选框 |
| `LabelCheckbox` / `OptionsLabelCheckbox` | 带文字的复选项 |
| `LabelButton` | 左侧标签、右侧按钮的设置行 |

## 4. 窗口、弹窗和标签页

### 4.1 RectangleWindow 与 CurlyWindow

两个窗口的签名相同：

```lua
TEMPLATES.RectangleWindow(
    width, height, title_text,
    bottom_buttons, button_spacing, body_text
)
```

底部按钮格式：

```lua
local buttons = {
    { text = "确定", cb = Confirm },
    { text = "取消", cb = Cancel },
}
```

窗口生成后常用字段：

- `window.title`：标题文本，传入标题时存在。
- `window.body`：正文文本，传入正文时存在。
- `window.actions`：底部 `Menu`，传入按钮时存在。
- `window.actions.items[1]`：第一个底部按钮。
- `RectangleWindow` 还有 `top`、`bottom`、`SetBackgroundTint`、`HideBackground`、`InsertWidget`。

尺寸注意事项：两个模板内部都会调用 `SetScale(0.7)`。传入的是九宫格的逻辑尺寸，不是最终屏幕像素尺寸。`CurlyWindow` 的尺寸会限制到约 `190..1000 × 90..500`，`RectangleWindow` 会限制到约 `90..1190 × 50..620`。面板内容位置需要结合这层缩放实际检查。

### 4.2 HeaderTabs

```lua
local tabs = self:AddChild(HeaderTabs({
    { text = "玩家", cb = function() self:SetTab("players") end },
    { text = "收藏", cb = function() self:SetTab("favorites") end },
}, true)) -- true 表示焦点可循环

tabs:SelectButton(1)
self.focus_forward = tabs
```

`HeaderTabs` 会把激活项设为 selected 状态，并将焦点转发给内部 `Menu`。切换数据页时，业务状态和 `SelectButton(index)` 要同步更新。

### 4.3 PopupDialogScreen 与 InputDialogScreen

简单确认框：

```lua
local PopupDialogScreen = require("screens/redux/popupdialog")

local dialog
dialog = PopupDialogScreen("删除收藏", "确定删除这个位置吗？", {
    {
        text = "删除",
        cb = function()
            G.TheFrontEnd:PopScreen(dialog)
            DeleteFavorite()
        end,
    },
    {
        text = "取消",
        cb = function() G.TheFrontEnd:PopScreen(dialog) end,
    },
})
G.TheFrontEnd:PushScreen(dialog)
```

`PopupDialogScreen` 还接受 `spacing_override`、`longness` 和 `style`。常见 `longness` 为 `small`、`medium`、`big`、`bigger`；常见 `style` 为 `dark`、`dark_wide`、`light`。

输入名称：

```lua
local InputDialogScreen = require("screens/redux/inputdialog")

local dialog
local function Confirm()
    local value = dialog:GetActualString():match("^%s*(.-)%s*$") or ""
    if value ~= "" then
        G.TheFrontEnd:PopScreen(dialog)
        SaveName(value)
    end
end

dialog = InputDialogScreen("位置名称", {
    { text = "确定", cb = Confirm },
    { text = "取消", cb = function() G.TheFrontEnd:PopScreen(dialog) end },
}, true)
dialog:OverrideText("新的位置")
dialog.edit_text:SetTextLengthLimit(40)
dialog.edit_text.OnTextEntered = Confirm
G.TheFrontEnd:PushScreen(dialog)
```

项目内完整实例可查看 [location-panel.lua](scripts/dst-controller/widgets/location-panel.lua)。

## 5. 布局组件怎么选

### 5.1 Menu：固定的一行或一列按钮

```lua
local menu = self:AddChild(TEMPLATES.StandardMenu({
    { text = "应用", cb = Apply },
    { text = "关闭", cb = Close },
}, 240, true)) -- 间距 240，true 为横向
```

底层 `Menu(menuitems, offset, horizontal, style, wrap, text_size)` 会自动定位项目，并连接相邻项目的焦点。项目可写成 `{ text, cb, offset, style, control }`，也可以用 `{ widget = custom_widget, offset = ... }` 放入自定义控件。

### 5.2 Grid：固定数量的小网格

```lua
local items = {}
for i = 1, 6 do
    items[i] = TEMPLATES.StandardButton(
        function() SelectItem(i) end,
        tostring(i),
        { 120, 45 }
    )
end

local grid = self:AddChild(Grid())
grid:FillGrid(3, 140, 60, items) -- 3 列、列间距 140、行间距 60
grid:SetLooping(true, false)
self.focus_forward = grid
```

`Grid` 会自动建立上下左右焦点关系。它本身不接收最终焦点，`grid:SetFocus()` 实际会把焦点交给某个子项。`FillGrid` 适合初始化静态内容，不建议在每帧更新中反复重建。

### 5.3 ScrollingGrid：动态长列表的首选

`TEMPLATES.ScrollingGrid` 是对 `TrueScrollList + Grid` 的封装。它只创建“可见行数 + 2”行控件，滚动时把新数据重新绑定到旧 Widget，适合玩家列表、收藏列表、配置项和菜谱列表。

完整骨架：

```lua
local ROW_WIDTH = 600
local ROW_HEIGHT = 52

local function MakeRow(_, index)
    local row = Widget("my_row_" .. tostring(index))
    row.button = row:AddChild(TEMPLATES.StandardButton(
        function() Activate(row.data) end,
        "",
        { 560, 46 }
    ))

    row.focus_forward = row.button
    row:SetOnGainFocus(function()
        if self.list ~= nil then
            self.list:OnWidgetFocus(row)
        end
    end)
    return row
end

local function ApplyRow(_, row, data, data_index)
    row.data = data

    if data == nil then
        row:Hide()
        row:Disable()
        return
    end

    row:Show()
    row:Enable()
    row.button:SetText(data.name)
    row.button:Enable()
end

self.list = self:AddChild(TEMPLATES.ScrollingGrid({}, {
    scroll_context = { owner = self },
    widget_width = ROW_WIDTH,
    widget_height = ROW_HEIGHT,
    num_visible_rows = 7,
    num_columns = 1,
    item_ctor_fn = MakeRow,
    apply_fn = ApplyRow,
    scrollbar_offset = 18,
    scrollbar_height_offset = -35,
    peek_percent = 0,
    scroll_per_click = 1,
}))

self.list:SetItemsData(data)
```

关键规则：

1. `item_ctor_fn(context, index)` 只负责创建可复用的行 Widget。
2. `apply_fn(context, widget, data, data_index)` 必须重置这一行的**所有可变状态**，因为这个 Widget 上一刻可能显示的是另一条数据。
3. 空数据行要明确隐藏、禁用；重新使用时要明确显示、启用。
4. 行获得焦点时调用 `list:OnWidgetFocus(row)`，滚动区域才能自动跟随焦点。
5. 更新数据使用 `SetItemsData(new_data)`；仅需重新绑定当前数据时可使用 `RefreshView()`。
6. 需要程序化跳到某项时使用 `ScrollToDataIndex(index)`。

常用选项：

| 选项 | 作用 |
| --- | --- |
| `widget_width` / `widget_height` | 单元格尺寸和排列间距 |
| `num_visible_rows` / `num_columns` | 可见行数和列数 |
| `scrollbar_offset` | 滚动条相对列表右边缘的水平偏移 |
| `scrollbar_height_offset` | 滚动条高度修正 |
| `scroll_per_click` | 每次滚动的行数 |
| `peek_percent` / `peek_height` | 底部露出下一行的比例或高度；设为 0 可关闭 |
| `scissor_pad` | 裁剪区额外宽度 |
| `end_offset` | 列表末端的滚动余量 |
| `allow_bottom_empty_row` | 是否允许底部露出空行 |

项目内带标签页、多按钮行和焦点边界修正的实例见 [location-panel.lua](scripts/dst-controller/widgets/location-panel.lua)。

### 5.4 TrueScrollList、ScrollableList 和 PagedList

- `TEMPLATES.ScrollingGrid`：绝大多数新列表的首选。
- `TrueScrollList`：需要自定义裁剪区、滚动方式或非标准排列时直接使用。构造参数较多，能用模板时不必直接用。
- `ScrollableList`：较老的实现，通常持有实际子控件列表；新增的长列表不建议优先选择。
- `PagedList(width, updatefn, widgetstoupdate)`：有固定数量槽位、希望整页切换时使用。它会把每页数据传给固定 Widget，并自动显示左右翻页箭头。

### 5.5 其他通用组件索引

下面这些也是游戏提供的通用组件，但使用频率较低，或已有更适合新界面的 Redux 替代方案：

| 组件 | 适用场景 | 选择建议 |
| --- | --- | --- |
| [`RadioButtons`](scripts-raw/widgets/radiobuttons.lua) | 少量互斥选项同时展示 | 比 Spinner 占空间，但所有选项一眼可见；支持 `SetSelected`、`GetSelectedData`、`SetOnChangedFn` |
| [`DropDown`](scripts-raw/widgets/dropdown.lua) | 鼠标下拉单选/多选 | 内部基于旧 `ScrollableList`，手柄新界面优先考虑 Spinner 或自建 `ScrollingGrid` |
| [`TrueScrollArea`](scripts-raw/widgets/truescrollarea.lua) | 滚动一个已排版好的任意大内容区 | 调用者必须提供内容 Widget 和内容总尺寸；数据列表仍优先 `ScrollingGrid` |
| [`NineSlice`](scripts-raw/widgets/nineslice.lua) | 用九张纹理拉伸自定义面板 | 优先用 `RectangleWindow` / `CurlyWindow`；只有自有九宫格素材才直接使用 |
| [`ThreeSlice`](scripts-raw/widgets/threeslice.lua) | 拉伸横条、竖条或输入框背景 | 用 `Flow(width, height, horizontal)` 排列两端和中段纹理 |
| [`AnimButton`](scripts-raw/widgets/animbutton.lua) | 用动画状态构成按钮 | 静态图按钮优先 `ImageButton` |
| [`UIAnimButton`](scripts-raw/widgets/uianimbutton.lua) | 使用 build/bank 动画的按钮 | 需要 idle/focus/disabled/down 等动画资源 |
| [`AnimSpinner`](scripts-raw/widgets/animspinner.lua) | 选项切换时同时改变动画 | 普通设置优先 `StandardSpinner` |
| [`TextButton`](scripts-raw/widgets/textbutton.lua) | 无图片背景的纯文字按钮 | 原版风格普通操作优先 `StandardButton` |
| [`TabGroup`](scripts-raw/widgets/tabgroup.lua) / [`Tab`](scripts-raw/widgets/tab.lua) | HUD 边缘可展开、收起的旧式标签组 | Redux 顶部标签优先 `HeaderTabs` |
| [`Wheel`](scripts-raw/widgets/wheel.lua) | 环形选项轮盘 | 输入和布局约束较强，开发前先参考原版调用方 |

`scripts-raw/widgets` 中还有大量业务 Widget，例如物品格、状态徽章、制作栏、玩家头像和地图控件。它们并非稳定的基础组件：只有需求与原版业务完全一致时才复用，否则更适合作为实现参考。

此外，[旧版 templates](scripts-raw/widgets/templates.lua) 仍可通过 Redux 模板中的 `TEMPLATES.old` 访问。新界面应优先使用 `widgets/redux/templates`，只有 Redux 没有对应能力或必须匹配旧 HUD 外观时再用旧模板。

## 6. 坐标、锚点、缩放和层级

### 6.1 位置是父级局部坐标

```text
Screen
└── root 位置 (100, 0)，缩放 0.8
    └── button 位置 (50, 20)
```

`button:SetPosition(50, 20)` 是相对 `root` 的局部位置，并会继承父级缩放。遇到位置和尺寸“不按数值显示”，先沿父级向上检查每层 `SetPosition` 和 `SetScale`。

### 6.2 Anchor 与 RegPoint 不同

- `SetHAnchor` / `SetVAnchor`：控件相对屏幕哪个位置锚定。
- `SetHRegPoint` / `SetVRegPoint`：图片自身以左、中、右或上、中、下哪个点作为注册点/轴心。
- 容器内部的普通子控件通常只需 `SetPosition`；全屏根节点、背景和固定 HUD 才经常设置屏幕 Anchor。

### 6.3 常见 ScaleMode

```lua
root:SetHAnchor(G.ANCHOR_MIDDLE)
root:SetVAnchor(G.ANCHOR_MIDDLE)
root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
```

- `SCALEMODE_PROPORTIONAL`：保持比例，适合面板、弹窗和 HUD 根节点。
- `SCALEMODE_FILLSCREEN`：拉伸填满屏幕，适合全屏背景或模态遮罩。

Redux 已提供根节点模板：

```lua
self.root = self:AddChild(TEMPLATES.ScreenRoot("my_root"))
```

### 6.4 绘制层级与点击

通常后加入的子控件会在更前面，也可显式使用 `MoveToFront()` / `MoveToBack()`。九宫格窗口有自己的前景边框，插入复杂内容时，`RectangleWindow:InsertWidget(widget)` 可以把边框重新移到内容前方。

看得见按钮但点不到时，首先检查按钮上方是否有一个可点击的透明 Image 或 ImageButton。

## 7. 手柄焦点与输入

### 7.1 三层焦点入口

一个稳定的手柄界面至少应具备：

1. `screen.default_focus`：Screen 打开时从哪里开始。
2. `container.focus_forward`：焦点落到容器时转给哪个子控件。
3. `SetFocusChangeDir`：上下左右要去哪里。

```lua
self.default_focus = self.tabs
self.content.focus_forward = self.first_button

self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.first_button)
self.first_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
self.first_button:SetFocusChangeDir(G.MOVE_DOWN, self.close_button)
self.close_button:SetFocusChangeDir(G.MOVE_UP, self.first_button)
```

目标也可以是函数，适合内容会变化的界面：

```lua
self.tabs:SetFocusChangeDir(G.MOVE_DOWN, function()
    return self:GetFirstEnabledRow()
end)
```

### 7.2 OnControl 的正确顺序

先让子控件和基类处理输入，再处理界面自己的快捷键：

```lua
function MyScreen:OnControl(control, down)
    if MyScreen._base.OnControl(self, control, down) then
        return true
    end

    if not down and control == G.CONTROL_CANCEL then
        self:Close()
        return true
    end

    -- 真正的模态界面可吞掉剩余输入，避免传给游戏世界。
    return true
end
```

如果在调用基类前拦截 `CONTROL_ACCEPT`，当前高亮按钮就可能永远收不到 A 键。

### 7.3 底部手柄提示

Screen 可通过 `GetHelpText()` 返回提示文本：

```lua
function MyScreen:GetHelpText()
    local id = G.TheInput:GetControllerID()
    return G.TheInput:GetLocalizedControl(id, G.CONTROL_CANCEL)
        .. " 关闭"
end
```

如果按钮表中带有 `controller_control`，可以直接复用：

```lua
local buttons = {
    { text = "应用", cb = Apply, controller_control = G.CONTROL_MENU_MISC_1 },
    { text = "关闭", cb = Close, controller_control = G.CONTROL_CANCEL },
}

self.button_control_fn, self.button_help_fn =
    TEMPLATES.ControllerFunctionsFromButtons(buttons)

-- 在 Screen 的 OnControl 中先调用基类，再调用：
-- return self.button_control_fn(control, down)
-- 在 GetHelpText 中返回：
-- return self.button_help_fn()
```

不要给可见且能聚焦的普通按钮重复绑定 `CONTROL_ACCEPT`，否则焦点按钮和全局快捷键可能同时处理它。

## 8. 可复制的界面骨架

### 8.1 带遮罩的模态 Screen

```lua
local MyScreen = G.Class(Screen, function(self)
    Screen._ctor(self, "MyScreen")

    self.black = self:AddChild(Image("images/global.xml", "square.tex"))
    self.black:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black:SetTint(0, 0, 0, 0.65)

    self.root = self:AddChild(TEMPLATES.ScreenRoot("my_root"))

    self.window = self.root:AddChild(TEMPLATES.RectangleWindow(
        700, 520, "我的界面", {
            { text = "关闭", cb = function() self:Close() end },
        }
    ))

    self.close_button = self.window.actions.items[1]
    self.default_focus = self.close_button
end)

function MyScreen:Close()
    G.TheFrontEnd:PopScreen(self)
end

function MyScreen:OnControl(control, down)
    if MyScreen._base.OnControl(self, control, down) then
        return true
    end
    if not down and control == G.CONTROL_CANCEL then
        self:Close()
    end
    return true
end

return MyScreen
```

如果遮罩本身还要阻挡鼠标点击，可以改用全屏 `ImageButton` 并设置空的 `SetOnClick(function() end)`。如果 Screen 已经可靠吞掉鼠标输入，则装饰 Image 保持不可点击更简单。

### 8.2 HUD 中的普通面板 Widget

```lua
local MyHudPanel = G.Class(Widget, function(self, on_close)
    Widget._ctor(self, "MyHudPanel")

    self.root = self:AddChild(Widget("root"))
    self.frame = self.root:AddChild(TEMPLATES.RectangleWindow(
        600, 430, "信息", {
            { text = "关闭", cb = on_close },
        }
    ))

    self.content = self.root:AddChild(Widget("content"))
    self.content:SetPosition(0, 0)

    self.label = self.content:AddChild(Text(G.BODYTEXTFONT, 26, "内容"))
    self.focus_forward = self.frame.actions
end)
```

HUD Widget 不要假装成 Screen 压入前端栈；它的显隐、输入占用和焦点恢复应由所在 HUD 或拥有者统一管理。

### 8.3 UIAnim

```lua
local UIAnim = require("widgets/uianim")

local anim = self:AddChild(UIAnim())
local state = anim:GetAnimState()
state:SetBuild("my_ui_build")
state:SetBank("my_ui_bank")
state:PlayAnimation("idle", true)
anim:SetScale(0.7)
```

只有资源本身是动画 build/bank 时才使用 `UIAnim`；静态纹理继续用 `Image`，更简单也更容易控制尺寸。

## 9. 常见问题排查清单

### 按钮可见但鼠标点不到

- 上方是否盖着可点击的透明 Image/ImageButton。
- 按钮或任一父级是否被 `Disable()`。
- 父级是否还处于隐藏、动画过渡或被移出裁剪区的状态。
- 自定义 `OnControl` / 鼠标处理是否提前吞掉事件。
- 装饰图片是否应调用 `SetClickable(false)`。

### 手柄可以移动，但不知道当前高亮哪一项

- focus 纹理或 focus tint 是否和 normal 状态差异太小。
- selected 状态是否覆盖了 focus 状态；必要时使用 `UseFocusOverlay`。
- 是否误把 `Select()` 当成 `SetFocus()`。
- 自定义按钮的 `OnGainFocus` 是否调用了基类。

### 打开界面后没有初始焦点

- Screen 是否设置了 `default_focus`。
- 容器是否设置了 `focus_forward`。
- 默认目标是否可见并启用。
- 动态重建内容后，旧的焦点目标是否已经被 `Kill()`。

### 列表更新后出现旧文字、旧按钮或错误状态

- `apply_fn` 是否完整重置了文字、图标、颜色、显隐、Enable/Disable 和回调使用的数据。
- 空数据是否隐藏并禁用了行。
- 数据改变后是否调用 `SetItemsData` 或 `RefreshView`。
- 闭包是否读取 `row.data`，而不是捕获创建时的旧 `data`。

### 列表手柄焦点滚出可见区域

- 行的 `OnGainFocus` 是否调用了 `scroll_list:OnWidgetFocus(row)`。
- 行内多个按钮是否有明确的左右焦点关系和 `row.focus_forward`。
- 列表边界是否需要显式连接到标签页或底部按钮。

### 尺寸和坐标与预期不一致

- 检查每一层父级的 `SetScale`。
- `CurlyWindow` / `RectangleWindow` 内部已有 `0.7` 缩放。
- 区分屏幕 Anchor、图片 RegPoint 与局部 `SetPosition`。
- 切换纹理后是否需要重新 `ScaleToSize`。
- 是否受 `SetScissor` 裁剪。

### 界面关闭后仍有回调或更新

- `StartUpdating()` 是否有对应的 `StopUpdating()` 或 Widget 已被 `Kill()`。
- 订阅函数是否在销毁时解除。
- 延迟任务回调中是否先检查 `self.inst:IsValid()`。
- `OnDestroy` 是否保留了基类清理行为。

### 输入穿透到游戏世界

- 真正的模态 Screen 是否在自己的处理完成后返回 `true`。
- 是否先调用基类，让当前焦点控件处理输入。
- 全屏鼠标遮罩是否确实覆盖屏幕并捕获点击。
- 关闭界面时是否正确恢复了之前的输入模式和焦点。

## 10. 本项目可参考的现成实现

- [玩家位置与收藏面板](scripts/dst-controller/widgets/location-panel.lua)：`RectangleWindow`、`HeaderTabs`、`ScrollingGrid`、多按钮行、动态焦点和 `InputDialogScreen`。
- [任务配置 Screen](scripts/dst-controller/screens/taskconfig-screen.lua)：模态遮罩、窗口、标签页、动态内容和手柄焦点。
- [Redux 原版制作菜单](scripts-raw/widgets/redux/craftingmenu_hud.lua)：复杂 HUD 菜单、焦点和动画的原版参考。
- [Redux 原版烹饪书](scripts-raw/widgets/redux/cookbookwidget.lua)：页面、数据列表和原版视觉布局参考。

## 11. 最后的开发约定

1. 新界面优先复用 Redux 模板，以保持原版视觉和手柄行为。
2. 每增加一个可交互控件，同时设计鼠标点击、初始焦点和四向焦点路径。
3. 动态长列表统一优先使用 `TEMPLATES.ScrollingGrid`。
4. 业务数据和 Widget 分开：创建 Widget 一次，通过 `apply_fn` 或刷新方法绑定数据。
5. 装饰控件默认不可点击；模态遮罩才有意捕获输入。
6. 使用 atlas/texture 前从源码或资源 XML 核对名称，避免运行时断言。
7. 任何涉及窗口尺寸、缩放、焦点高亮的改动，都应同时用鼠标和手柄实际检查。
8. 游戏更新后若行为变化，以本地最新 `scripts-raw` 实现为准，再同步修正文档。
