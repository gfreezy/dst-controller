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
        name = "camera_rotation_speed",
        label = "视角旋转速度",
        options = {
            {description = "慢", data = 1},
            {description = "正常", data = 2},
            {description = "快", data = 3},
        },
        default = 2,
    },
    {
        name = "camera_zoom_speed",
        label = "视角缩放速度",
        options = {
            {description = "慢", data = 0.5},
            {description = "正常", data = 1},
            {description = "快", data = 1.5},
        },
        default = 1,
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
