-- Task definitions for button combinations
-- Each task defines actions to execute on button press and release

-- Task structure:
-- {
--     on_press = { "action1", "action2", ... },   -- Actions to execute when button is pressed
--     on_release = { "action1", "action2", ... }, -- Actions to execute when button is released
-- }

-- Available actions (see actions.lua for full list):
-- Combat: attack, force_attack
-- Inspection: examine, inspect_self
-- Equipment: equip_item(item_name) - requires item_name parameter
-- Equipment Cycle (Next): cycle_hand, cycle_head, cycle_body
-- Equipment Cycle (Prev): cycle_hand_prev, cycle_head_prev, cycle_body_prev
-- Equipment Swap to Last: swap_hand_last, swap_head_last, swap_body_last
-- Equipment Save/Restore: save_hand_item, restore_hand_item,
--                         save_head_item, restore_head_item,
--                         save_body_item, restore_body_item
-- Items: use_item(item_name), use_item_on_self(item_name) - require item_name parameter
--        drop_item
-- Channeling: start_channeling, stop_channeling
-- Crafting: craft_item(recipe_name) - Auto-crafts intermediate ingredients
-- Character-Specific:
--   Willow: willow_cast_spell
-- Misc: none
--
-- Note: Actions with (parameter) REQUIRE that parameter to be passed
-- Note: Multiple actions can be combined in a task to create complex behaviors

local TASKS = {
    -- LB button combinations
    LB_A = {
        on_press = { "attack" },              -- Quick attack
        on_release = {},
    },
    LB_B = {
        -- Press: Save current weapon, equip lighter, start absorption
        on_press = {
            "save_hand_item",
            {"equip_item", "lighter"},
            "start_channeling"
        },
        -- Release: Stop absorption, restore previous weapon
        on_release = {
            "stop_channeling",
            "restore_hand_item"
        },
    },
    LB_X = {
        on_press = { "cycle_head" },          -- Cycle through head equipment (hats/helmets)
        on_release = {},
    },
    LB_Y = {
        on_press = { "examine" },             -- Examine target
        on_release = {},
    },

    -- RB button combinations
    RB_A = {
        on_press = { "use_item" },            -- Use active item
        on_release = {},
    },
    RB_B = {
        on_press = { "cycle_body" },          -- Cycle through body equipment (armor)
        on_release = {},
    },
    RB_X = {
        on_press = { "drop_item" },           -- Drop active item
        on_release = {},
    },
    RB_Y = {
        on_press = {},
        on_release = { "inspect_self" },      -- Inspect self on release
    },
}

return TASKS
