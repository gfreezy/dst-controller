name = "Enhanced Controller"
description = [[强化手柄功能 - 自定义组合键、视角控制和智能寻路

核心功能：
• 游戏内配置界面 (键盘: Ctrl+K, 手柄: LB+RB+Y 同时按)
• 可自定义 12 种按钮组合的行为 (LB/RB + A/B/X/Y/LT/RT)
• 支持多动作序列和参数化动作
• 动作间自动延迟 (0.3秒)，支持联机同步
• 配置自动保存并在重启后加载
• 完整的手柄操作支持

地图寻路功能：
• 打开地图后启用虚拟光标 (LB+RB+RT)
• 点击地图任意位置自动寻路
• 智能规避海洋和障碍物
• 沿海岸线自动寻找绕路
• 单机和联机模式均可用
• 实时路径可视化

虫洞追踪功能 (NEW!)：
• 自动记录虫洞配对关系
• 地图上显示配对编号 (相同数字 = 一对)
• 数据持久化保存 (每个世界独立)
• 无需手动标记

视角控制：
• LB + 右摇杆左右: 旋转视角
• LB + 右摇杆上下: 缩放视角
• 地图模式支持缩放和旋转

可用动作包括：
• 装备切换、物品使用
• 检查、制作
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
version = "2.3.0"

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
