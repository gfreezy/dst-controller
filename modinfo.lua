name = "Enhanced Controller"
description = "强化手柄功能 - 自定义组合键和视角控制\n\n功能:\n- LB + 右摇杆左右: 旋转视角\n- LB + 右摇杆上下: 缩放视角\n- LB/RB + A/B/X/Y: 可自定义行为"
author = "Your Name"
version = "1.0.0"

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
        label = "攻击目标类型",
        hover = "控制是否可以攻击所有目标，还是仅攻击敌对生物",
        options = {
            {description = "仅敌对生物", data = "hostile_only", hover = "只能攻击敌对的怪物和正在攻击你的生物"},
            {description = "所有目标", data = "force_attack", hover = "可以攻击任何目标，包括盟友（原版行为）"},
        },
        default = "hostile_only",
    },
    {
        name = "lb_a_action",
        label = "LB + A 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "lb_b_action",
        label = "LB + B 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "lb_x_action",
        label = "LB + X 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "lb_y_action",
        label = "LB + Y 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "rb_a_action",
        label = "RB + A 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "rb_b_action",
        label = "RB + B 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "rb_x_action",
        label = "RB + X 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
    {
        name = "rb_y_action",
        label = "RB + Y 动作",
        options = {
            {description = "无", data = "none"},
            {description = "攻击", data = "attack"},
            {description = "检查", data = "examine"},
            {description = "自动装备", data = "equip"},
        },
        default = "none",
    },
}
