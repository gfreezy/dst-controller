# 饥荒联机版 - 增强手柄控制 Mod

[English](README_EN.md) | 简体中文

一个强大的饥荒联机版（Don't Starve Together）手柄增强 Mod，提供自定义按键组合、虚拟光标、游戏内配置界面等功能。

## ✨ 核心功能

### 🎮 自定义按键组合

支持 **12 种按键组合**，每个组合可配置按下和释放时的动作：

- **LB + A/B/X/Y/LT/RT**
- **RB + A/B/X/Y/LT/RT**

每个组合支持：
- 按下时执行动作 (`on_press`)
- 释放时执行动作 (`on_release`)
- 动作序列（可连续执行多个动作）

### 🖱️ 虚拟光标系统

使用手柄右摇杆控制鼠标光标，实现完整的鼠标模式操作：

**功能特性**：
- ✅ 右摇杆控制光标移动（全屏范围）
- ✅ RT 按键 = 鼠标左键
- ✅ RB 按键 = 鼠标右键
- ✅ 支持悬停检测和实体高亮
- ✅ 支持拖拽行走（8帧检测阈值）
- ✅ 支持点击 UI 元素（物品栏、制作菜单等）
- ✅ 可配置光标速度（0.5x - 2.0x）
- ✅ 可配置死区（0.0 - 0.5）
- ✅ 可显示/隐藏光标图标

**默认切换按键**: LB + RB + RT（同时按下）

### 🎯 多目标选择系统

智能目标选择，支持三种独立目标：

1. **主目标** (`controller_target`) - A键交互
   - 支持主动作的实体

2. **副目标** (`controller_alternative_target`) - B键交互
   - 只有副动作的实体
   - 主目标有副动作时自动清除

3. **检查目标** (`controller_examine_target`) - Y键检查
   - 只能检查的实体（如装饰品）
   - 主目标和副目标可检查时自动清除

**目标选择特性**：
- 独立评分系统
- 支持 360° 选择或前向选择
- 距离和角度权重计算
- 不可穿透实体优先

### ⚙️ 游戏内配置界面

按 **Ctrl+K**（键盘）或 **LB+RB+Y**（手柄）打开配置界面：

**功能**：
- 🎨 3层界面：主界面 → 详情界面 → 动作编辑器
- 🎮 完整手柄支持（A/B 选择/取消，LB/RB 切换标签）
- 💾 实时保存配置
- 🔄 即时生效（无需重启）
- 🎯 两个标签页：
  - **按键配置**: 配置 12 种按键组合
  - **Mod 设置**: 调整攻击角度、交互角度、强制攻击模式、虚拟光标设置

### 📐 视角控制增强

- **LB + 右摇杆左右**: 旋转视角
- **LB + 右摇杆上下**: 缩放视角
- 可配置旋转和缩放速度

## 🎬 可用动作

### 战斗类
- **attack**: 攻击目标
- **force_attack**: 强制攻击（忽略友军）

### 检查类
- **examine**: 检查目标
- **inspect_self**: 检查自己

### 装备类
- **equip_item**: 装备指定物品
- **cycle_head**: 循环切换头部装备
- **cycle_hand**: 循环切换手部装备
- **cycle_body**: 循环切换身体装备

### 物品类
- **use_item**: 对目标使用物品
- **use_item_on_self**: 对自己使用物品
- **save_hand_item**: 保存手持物品到缓存
- **restore_hand_item**: 恢复缓存的物品到手上

### 制作类
- **craft_item**: 制作指定物品

### 角色类
- **start_channeling**: 开始引导（Wanda）
- **stop_channeling**: 停止引导

## 📦 安装方法

### 方法 1: Steam 创意工坊（推荐）
1. 在 Steam 创意工坊搜索 "Enhanced Controller"
2. 点击订阅
3. 启动游戏，自动加载

### 方法 2: 手动安装
1. 下载最新版本
2. 解压到 Mods 目录：
   - **Windows**: `Documents/Klei/DoNotStarveTogether/mods/`
   - **Mac**: `~/Documents/Klei/DoNotStarveTogether/mods/`
   - **Linux**: `~/.klei/DoNotStarveTogether/mods/`
3. 启动游戏
4. 主菜单 → Mods → 启用 "Enhanced Controller"

## 🎯 快速开始

### 1. 打开配置界面
- **键盘**: `Ctrl+K`
- **手柄**: `LB+RB+Y`（同时按下）

### 2. 配置按键组合
1. 选择一个按键组合（如 `LB_A`）
2. 选择 `按下时` 或 `释放时` 标签
3. 点击 `+ 添加动作`
4. 选择动作类型和参数
5. 点击 `应用` 保存

### 3. 使用虚拟光标
1. 按 `LB+RB+RT` 开启虚拟光标模式
2. 使用右摇杆移动光标
3. `RT` = 鼠标左键，`RB` = 鼠标右键
4. 再次按 `LB+RB+RT` 退出

## ⚙️ 配置选项

### 攻击角度模式
- **前方攻击**: 只攻击前方敌人
- **360度攻击**: 攻击周围所有敌人

### 交互角度模式
- **前方交互**: 只交互前方物品
- **360度交互**: 交互周围所有物品

### 强制攻击模式
- **仅敌对**: 只攻击敌对生物
- **所有生物**: 可攻击所有生物（包括友军）

### 虚拟光标设置
- **光标速度**: 0.5x - 2.0x（默认 1.0x）
- **死区**: 0.0 - 0.5（默认 0.1）
- **显示光标**: 开启/关闭

## 🛠️ 配置文件

配置保存在：`client_save/enhanced_controller_config.json`

**结构**：
```json
{
  "tasks": {
    "LB_A": {
      "on_press": [["attack"], ["examine"]],
      "on_release": []
    },
    ...
  },
  "settings": {
    "attack_angle_mode": "forward_only",
    "interaction_angle_mode": "all_around",
    "force_attack_mode": "hostile_only",
    "virtual_cursor_settings": {
      "enabled": true,
      "toggle_combo": ["LB", "RB", "RT"],
      "left_click_key": "RT",
      "right_click_key": "RB",
      "cursor_speed": 1.0,
      "dead_zone": 0.1,
      "show_cursor": true
    }
  }
}
```

## 🎮 按键映射参考

| Xbox 按键 | PS 按键 | 功能 |
|----------|---------|------|
| LB | L1 | 左肩键（组合键修饰符） |
| RB | R1 | 右肩键（组合键修饰符） |
| LT | L2 | 左扳机 |
| RT | R2 | 右扳机 |
| A | ❌ | 确认/交互 |
| B | ⭕ | 取消/副动作 |
| X | ⬜ | 主动作 |
| Y | 🔺 | 检查 |
| 右摇杆 | R3 | 虚拟光标/视角控制 |

## 📋 注意事项

1. **客户端 Mod**: 只需自己安装，不影响其他玩家
2. **兼容性**: 兼容大部分其他 Mods
3. **配置同步**: 不同角色使用相同配置
4. **暂停功能**: 配置界面会暂停游戏（单机/主机）

## 🔧 开发信息

- **版本**: 2.0.0
- **作者**: feichao
- **API 版本**: 10
- **兼容性**: Don't Starve Together

### 项目结构
```
dst-controller/
├── modinfo.lua                 # Mod 元数据
├── modmain.lua                 # 入口点
├── scripts/dst-controller/
│   ├── global.lua             # 全局引用
│   ├── actions/               # 动作实现
│   ├── core/                  # 核心逻辑
│   │   ├── button-handler.lua
│   │   └── action-executor.lua
│   ├── hooks/                 # 游戏钩子
│   │   ├── registry.lua       # 钩子注册表
│   │   ├── playercontroller-hook.lua
│   │   ├── input-system-hook.lua
│   │   └── controls-hook.lua
│   ├── screens/               # UI 界面
│   │   ├── taskconfig-screen.lua
│   │   └── taskconfig-actions.lua
│   ├── virtual-cursor/        # 虚拟光标
│   │   ├── core.lua
│   │   └── cursor_widget.lua
│   ├── target-selection/      # 目标选择
│   │   └── core.lua
│   └── utils/                 # 工具函数
└── CLAUDE.md                  # 开发文档
```

## 🐛 常见问题

**Q: 虚拟光标模式下无法选择物品栏？**
A: 虚拟光标模式会自动清除物品栏选择，直接用光标点击物品栏即可。

**Q: 配置界面无法打开？**
A: 确保不在其他菜单界面中，按 `Ctrl+K` 或 `LB+RB+Y`。

**Q: 按键组合没反应？**
A: 检查配置界面是否正确设置了动作，确保同时按下组合键。

**Q: 如何恢复默认配置？**
A: 删除 `client_save/enhanced_controller_config.json`，重启游戏。

**Q: 游戏卡顿？**
A: 尝试降低虚拟光标速度或关闭光标显示。

## 📝 更新日志

### v2.0.0 (2025-01-XX)
- ✨ 新增游戏内配置界面
- ✨ 新增虚拟光标系统
- ✨ 新增多目标选择系统（主/副/检查）
- ✨ 重构为命名空间架构
- 🔧 优化钩子系统（集中注册）
- 💾 新增配置持久化
- 🎮 增强手柄支持

### v1.0.0 (初始版本)
- 基础按键组合功能
- 视角控制增强

## 📜 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issues 和 Pull Requests！

### 开发指南
参考 [CLAUDE.md](CLAUDE.md) 了解项目架构和开发规范。

## 🔗 链接

- **Steam 创意工坊**: [即将上传]
- **GitHub**: [项目地址]
- **问题反馈**: [Issues 页面]

## ❤️ 感谢

感谢所有贡献者和使用本 Mod 的玩家！

---

**享受增强的手柄体验！** 🎮✨
