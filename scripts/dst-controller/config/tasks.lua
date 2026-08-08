-- Enhanced Controller - Task Configurations
-- Defines button combination tasks and their actions

local ButtonCombos = require("dst-controller/config/button-combos")

-- Default tasks (normal gamepad mode)
local TASKS = {
    -- LB button combinations
    LB_A = {
        on_press = { "attack" },
        on_release = {},
    },
    LB_B = {
        on_press = {
        },
        on_release = {
        },
    },
    LB_X = {
        on_press = { "force_attack" },
        on_release = {},
    },
    LB_Y = {
        on_press = { "open_skill_panel" },
        on_release = {},
    },
    LB_LT = {
        on_press = {},
        on_release = {},
    },
    LB_RT = {
        on_press = { "open_skill_wheel" },
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

TASKS.LB_DPAD_UP = {
    on_press = { "toggle_cooking_menu" },
    on_release = {},
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

-- New combinations default to disabled. An empty task deliberately falls
-- through to DST's native input behavior.
for _, combo_key in ipairs(ButtonCombos.GetKeys()) do
    if TASKS[combo_key] == nil then
        TASKS[combo_key] = { on_press = {}, on_release = {} }
    end
    if VIRTUAL_CURSOR_TASKS[combo_key] == nil then
        VIRTUAL_CURSOR_TASKS[combo_key] = { on_press = {}, on_release = {} }
    end
end

return {
    TASKS = TASKS,
    VIRTUAL_CURSOR_TASKS = VIRTUAL_CURSOR_TASKS,
}
