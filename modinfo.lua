name = "Enhanced Controller"
description = [[强化手柄功能 - 自定义组合键和视角控制

核心功能：
• 游戏内配置界面 (键盘: Ctrl+K, 手柄: LB+RB+Y 同时按)
• 可自定义 12 种按钮组合的行为 (LB/RB + A/B/X/Y/LT/RT)
• 支持多动作序列和参数化动作
• 配置自动保存并在重启后加载
• 完整的手柄操作支持

视角控制：
• LB + 右摇杆左右: 旋转视角
• LB + 右摇杆上下: 缩放视角

可用动作包括：
• 攻击、检查、装备切换
• 物品使用、制作
• 自定义参数动作

使用说明：
1. 打开配置界面 (键盘: Ctrl+K, 手柄: LB+RB+Y)
2. 选择要配置的按钮组合
3. 添加按下/松开时的动作序列
4. 点击应用保存配置

配置文件位置：
client_save/enhanced_controller_config.json
]]

author = "feichao"
version = "2.0.1"

forumthread = ""
api_version = 10

dst_compatible = true
client_only_mod = true
all_clients_require_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {}

-- 所有配置都通过游戏内配置界面进行设置（Ctrl+K 或 LB+RB+Y）
configuration_options = {}
