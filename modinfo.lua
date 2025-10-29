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
version = "2.0.0"

forumthread = ""
api_version = 10

dst_compatible = true
client_only_mod = true
all_clients_require_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

server_filter_tags = {}

-- 配置选项
configuration_options = {
    {
        name = "attack_angle_mode",
        label = "攻击目标选择范围",
        hover = "控制是否可以选择360度范围内的目标，还是仅选择前方目标",
        options = {
            {description = "仅前方", data = "forward_only", hover = "只能选择玩家面向方向的目标（原版行为）"},
            {description = "360度全方位", data = "all_around", hover = "可以选择任意方向的目标"},
        },
        default = "forward_only",
    },
    {
        name = "force_attack_mode",
        label = "强制攻击模式",
        hover = "控制是否可以攻击所有目标，还是仅攻击敌对生物",
        options = {
            {description = "仅敌对生物", data = "hostile_only", hover = "只能攻击敌对的怪物和正在攻击你的生物"},
            {description = "所有目标", data = "force_attack", hover = "可以攻击任何目标，包括盟友"},
        },
        default = "hostile_only",
    },
}
