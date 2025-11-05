-- Enhanced Controller - Task Configurations
-- Defines button combination tasks and their actions

-- Default tasks (normal gamepad mode)
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
        on_press = { },
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
        on_press = { },
        on_release = {},
    },
    RB_B = {
        on_press = { "cycle_body" },
        on_release = {},
    },
    RB_X = {
        on_press = { "cycle_hand" },
        on_release = {},
    },
    RB_Y = {
        on_press = { "cycle_head" },
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

-- Virtual cursor mode tasks (when virtual cursor is active)
-- Note: RT and RB are used for mouse clicks in virtual cursor mode
local VIRTUAL_CURSOR_TASKS = {
    -- LB button combinations
    LB_A = {
        on_press = { },
        on_release = {},
    },
    LB_B = {
        on_press = { },
        on_release = {},
    },
    LB_X = {
        on_press = { },
        on_release = {},
    },
    LB_Y = {
        on_press = { },
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

    -- RB button combinations (RB is used for right-click in virtual cursor mode)
    RB_A = {
        on_press = { },
        on_release = {},
    },
    RB_B = {
        on_press = { },
        on_release = {},
    },
    RB_X = {
        on_press = { },
        on_release = {},
    },
    RB_Y = {
        on_press = { },
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

return {
    TASKS = TASKS,
    VIRTUAL_CURSOR_TASKS = VIRTUAL_CURSOR_TASKS,
}
