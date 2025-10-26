-- Enhanced Controller - Task Configurations
-- Defines button combination tasks and their actions

local TASKS = {
    -- LB button combinations
    LB_A = {
        on_press = { "attack" },
        on_release = {},
    },
    LB_B = {
        on_press = {
            "save_hand_item",
            {"equip_item", "lighter"},
            "start_channeling"
        },
        on_release = {
            "stop_channeling",
            "restore_hand_item"
        },
    },
    LB_X = {
        on_press = { "force_attack" },
        on_release = {},
    },
    LB_Y = {
        on_press = { "examine" },
        on_release = {},
    },
    LB_LT = {
        on_press = {},
        on_release = {},
    },
    LB_RT = {
        on_press = {},
        on_release = {},
    },

    -- RB button combinations
    RB_A = {
        on_press = { "cycle_hand" },
        on_release = {},
    },
    RB_B = {
        on_press = { "cycle_body" },
        on_release = {},
    },
    RB_X = {
        on_press = { "cycle_head" },
        on_release = {},
    },
    RB_Y = {
        on_press = { "inspect_self" },
        on_release = {},
    },
    RB_LT = {
        on_press = {},
        on_release = {},
    },
    RB_RT = {
        on_press = {},
        on_release = {},
    },
}

return TASKS
