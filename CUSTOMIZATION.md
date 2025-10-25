# 自定义指南

本文档说明如何自定义和扩展 Enhanced Controller Mod 的功能。

## 添加新的自定义动作

### 步骤 1: 在 modinfo.lua 中添加配置选项

编辑 [modinfo.lua](modinfo.lua)，在 `configuration_options` 数组中添加新选项：

```lua
{
    name = "lb_a_action",
    label = "LB + A 动作",
    options = {
        {description = "无", data = "none"},
        {description = "攻击", data = "attack"},
        {description = "检查", data = "examine"},
        {description = "自动装备", data = "equip"},
        {description = "丢弃物品", data = "drop"},  -- 新增
        {description = "收集", data = "pickup"},     -- 新增
    },
    default = "none",
},
```

### 步骤 2: 在 modmain.lua 中实现动作

编辑 [modmain.lua](modmain.lua)，在 `ExecuteCustomAction` 函数中添加新的动作处理：

```lua
local function ExecuteCustomAction(action_type)
    if action_type == "none" then
        return
    end

    local player = GLOBAL.ThePlayer
    if not player then return end

    -- 现有动作...

    -- 新增：丢弃物品
    elseif action_type == "drop" then
        if player.components.inventory then
            local active_item = player.components.inventory:GetActiveItem()
            if active_item then
                player.components.inventory:DropItem(active_item)
            end
        end

    -- 新增：收集附近物品
    elseif action_type == "pickup" then
        local x, y, z = player.Transform:GetWorldPosition()
        local ents = GLOBAL.TheSim:FindEntities(x, y, z, 3, {"_inventoryitem"})
        for _, item in ipairs(ents) do
            if item.components.inventoryitem and item.components.inventoryitem.canbepickedup then
                if player.components.inventory:CanAcceptCount(item, 1) > 0 then
                    player.components.inventory:GiveItem(item)
                    break
                end
            end
        end
    end
end
```

## 修改视角控制参数

### 调整旋转速度范围

编辑 [modinfo.lua](modinfo.lua)：

```lua
{
    name = "camera_rotation_speed",
    label = "视角旋转速度",
    options = {
        {description = "极慢", data = 0.5},
        {description = "慢", data = 1},
        {description = "正常", data = 2},
        {description = "快", data = 3},
        {description = "极快", data = 5},
    },
    default = 2,
},
```

### 调整缩放范围

编辑 [modmain.lua](modmain.lua)，找到 `UpdateCameraControl` 函数：

```lua
-- 修改最小和最大缩放距离
local new_distance = GLOBAL.math.clamp(
    distance + right_stick_y * CAMERA_ZOOM_SPEED * dt * 10,
    10,  -- 最小距离（更近）
    60   -- 最大距离（更远）
)
```

## 添加新的组合键

### 添加 LT（左扳机）组合键

1. **在 modmain.lua 中添加 LT 状态追踪**：

```lua
local controller_state = {
    lb_pressed = false,
    rb_pressed = false,
    rt_pressed = false,
    lt_pressed = false,  -- 新增
}
```

2. **在按键处理中添加 LT 检测**：

```lua
-- 在 OnControllerButton 函数中添加
elseif control == GLOBAL.CONTROL_SECONDARY then -- LT
    controller_state.lt_pressed = down
    if down then
        return true
    end
```

3. **添加 LT 组合键处理**：

```lua
-- 在组合键处理部分添加
elseif controller_state.lt_pressed then
    if control == GLOBAL.CONTROL_ACCEPT then
        -- LT + A 的行为
        return true
    end
    -- ... 其他组合
end
```

## 添加连续动作

有时你可能想要一个动作持续执行（如长按），而不是单次触发：

```lua
-- 添加到 modmain.lua
local function ContinuousAction(player, action_type)
    if action_type == "auto_attack" then
        local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()
        if target and player.components.combat and player.components.combat:CanTarget(target) then
            player.components.combat:DoAttack(target)
        end
    end
end

-- 添加周期性任务
AddPlayerPostInit(function(player)
    if not GLOBAL.TheWorld.ismastersim then
        player:DoPeriodicTask(0.1, function()
            if controller_state.continuous_action_enabled then
                ContinuousAction(player, controller_state.continuous_action_type)
            end
        end)
    end
end)
```

## 添加视觉反馈

显示当前激活的组合键模式：

```lua
-- 需要使用饥荒的 UI 系统
local function ShowModeIndicator(mode_text)
    if GLOBAL.ThePlayer and GLOBAL.ThePlayer.HUD then
        -- 显示提示文本
        GLOBAL.ThePlayer.components.talker:Say(mode_text)
    end
end

-- 在 LB 按下时调用
if control == GLOBAL.CONTROL_CONTROLLER_ALTACTION then
    controller_state.lb_pressed = down
    if down then
        ShowModeIndicator("LB 模式")
        return true
    end
end
```

## 调试技巧

### 打印调试信息

```lua
-- 在任何地方添加调试输出
print("[Enhanced Controller] 当前状态:", controller_state.lb_pressed)

-- 打印控制键值
local function OnControllerButton(player, data)
    print("[Enhanced Controller] Control:", data.control, "Down:", data.down)
    -- ... 其他代码
end
```

### 查看游戏日志

调试信息会输出到游戏日志文件：
- Windows: `Documents\Klei\DoNotStarveTogether\client_log.txt`
- Mac: `~/Documents/Klei/DoNotStarveTogether/client_log.txt`
- Linux: `~/.klei/DoNotStarveTogether/client_log.txt`

## 常用饥荒 API

### 玩家组件

```lua
-- 物品栏
player.components.inventory:GiveItem(item)
player.components.inventory:DropItem(item)
player.components.inventory:GetActiveItem()
player.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)

-- 战斗
player.components.combat:DoAttack(target)
player.components.combat:CanTarget(target)

-- 健康
player.components.health:GetPercent()
player.components.health:DoDelta(amount)

-- 饥饿
player.components.hunger:GetPercent()

-- 理智
player.components.sanity:GetPercent()
```

### 世界交互

```lua
-- 查找附近实体
local x, y, z = player.Transform:GetWorldPosition()
local ents = GLOBAL.TheSim:FindEntities(x, y, z, radius, must_tags, cant_tags, must_one_of_tags)

-- 获取鼠标指向的实体
local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()

-- 执行动作
local action = GLOBAL.BufferedAction(player, target, GLOBAL.ACTIONS.CHOP)
player.components.playercontroller:DoAction(action)
```

### 常用 ACTIONS

```lua
GLOBAL.ACTIONS.CHOP        -- 砍树
GLOBAL.ACTIONS.MINE        -- 挖矿
GLOBAL.ACTIONS.PICK        -- 采集
GLOBAL.ACTIONS.ATTACK      -- 攻击
GLOBAL.ACTIONS.LOOKAT      -- 查看
GLOBAL.ACTIONS.GIVE        -- 给予
GLOBAL.ACTIONS.EAT         -- 吃
GLOBAL.ACTIONS.EQUIP       -- 装备
GLOBAL.ACTIONS.UNEQUIP     -- 卸下
```

## 手柄控制键值参考

```lua
-- 肩键和扳机
GLOBAL.CONTROL_CONTROLLER_ALTACTION  -- LB
GLOBAL.CONTROL_SECONDARY             -- RB
GLOBAL.CONTROL_ATTACK                -- RT
-- (LT 可能需要查找对应的控制常量)

-- 面部按键
GLOBAL.CONTROL_ACCEPT                -- A
GLOBAL.CONTROL_CANCEL                -- B
GLOBAL.CONTROL_ACTION                -- X
GLOBAL.CONTROL_INVENTORY_EXAMINE     -- Y

-- 摇杆
GLOBAL.CONTROL_MOVE_UP/DOWN/LEFT/RIGHT       -- 左摇杆
GLOBAL.CONTROL_ROTATE_LEFT/RIGHT             -- 右摇杆左右
GLOBAL.CONTROL_MENU_MISC_1/2                 -- 右摇杆上下
```

## 示例：创建快速使用药品功能

```lua
-- 在 modinfo.lua 添加配置
{
    name = "rb_y_action",
    label = "RB + Y 动作",
    options = {
        {description = "无", data = "none"},
        {description = "使用治疗药品", data = "heal"},
    },
    default = "heal",
}

-- 在 modmain.lua 的 ExecuteCustomAction 函数中添加
elseif action_type == "heal" then
    if player.components.inventory then
        -- 查找治疗物品（如蜂蜜药膏、治疗药膏等）
        local healing_items = {"bandage", "healingsalve", "honeypouItice"}

        for _, item_name in ipairs(healing_items) do
            for i = 1, player.components.inventory.maxslots do
                local item = player.components.inventory:GetItemInSlot(i)
                if item and item.prefab == item_name then
                    -- 使用物品
                    player.components.inventory:UseItemFromInvTile(item)
                    return
                end
            end
        end
    end
end
```

## 贡献你的改进

如果你创建了有用的自定义功能，欢迎分享！可以：

1. Fork 项目仓库
2. 创建你的功能分支
3. 提交 Pull Request
4. 或者在 Issues 中分享你的代码片段

Happy Modding!
