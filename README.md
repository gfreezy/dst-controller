# 饥荒联机版 - 手柄增强 Mod

这是一个用于饥荒联机版（Don't Starve Together）的手柄增强 Mod，提供更强大的手柄控制功能。

## 功能特性

### 视角控制
- **LB + 右摇杆左右**: 旋转视角
- **LB + 右摇杆上下**: 缩放视角（调整远近）

### 组合键自定义
以下组合键可以在 Mod 设置中自定义行为：
- **LB + A/B/X/Y**: 可自定义动作
- **RB + A/B/X/Y**: 可自定义动作

### 拦截默认行为
- 去掉 LB、RB、RT 的默认行为，避免误操作

## 安装方法

1. 将整个文件夹复制到饥荒联机版的 mods 目录：
   - Windows: `Documents/Klei/DoNotStarveTogether/mods/`
   - Mac: `~/Documents/Klei/DoNotStarveTogether/mods/`
   - Linux: `~/.klei/DoNotStarveTogether/mods/`

2. 启动游戏

3. 在主菜单选择"Mods"

4. 找到"Enhanced Controller"并启用

5. 点击"Configure"配置组合键行为

## 可用的自定义动作

在 Mod 配置界面中，每个组合键可以设置为以下动作之一：

- **无**: 不执行任何动作
- **攻击**: 攻击鼠标指向的目标
- **检查**: 检查鼠标指向的物品
- **自动装备**: 自动装备物品栏中第一个可装备的物品

## 配置选项

### 视角旋转速度
- 慢 / 正常 / 快
- 默认: 正常

### 视角缩放速度
- 慢 / 正常 / 快
- 默认: 正常

### 组合键动作
- LB + A/B/X/Y 动作
- RB + A/B/X/Y 动作

## 手柄按键映射参考

| 按键 | 功能 |
|-----|------|
| LB | 左肩键（触发组合键模式） |
| RB | 右肩键（触发组合键模式） |
| RT | 右扳机键 |
| A | 确认/交互 |
| B | 取消/攻击 |
| X | 动作 |
| Y | 检查物品 |
| 右摇杆 | 配合LB使用控制视角 |

## 注意事项

1. 这是一个**客户端 Mod**（client_only_mod），只需要玩家自己安装即可
2. 不影响其他玩家的游戏体验
3. 可以在多人游戏中使用

## 开发信息

- 版本: 1.0.0
- API 版本: 10
- 兼容性: 饥荒联机版

## 扩展开发

如果你想添加更多自定义动作，可以编辑 `modmain.lua` 中的 `ExecuteCustomAction` 函数。

例如添加"丢弃物品"动作：

```lua
elseif action_type == "drop" then
    if player.components.inventory then
        local active_item = player.components.inventory:GetActiveItem()
        if active_item then
            player.components.inventory:DropItem(active_item)
        end
    end
```

然后在 `modinfo.lua` 的 `configuration_options` 中添加对应的选项。

## 常见问题

**Q: 为什么视角控制不灵敏？**
A: 可以在 Mod 设置中调整"视角旋转速度"和"视角缩放速度"。

**Q: 组合键没有反应？**
A: 确保先按住 LB 或 RB，然后再按其他按键。释放 LB/RB 后再次按键将恢复默认行为。

**Q: 如何恢复默认行为？**
A: 在 Mod 配置中将对应的组合键动作设置为"无"即可。

## 许可证

本项目采用 MIT 许可证。

## 贡献

欢迎提交问题和改进建议！
