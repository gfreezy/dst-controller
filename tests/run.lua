package.path = table.concat({
    "./scripts/?.lua",
    "./scripts/?/init.lua",
    package.path,
}, ";")

local test_files = {
    "tests/action_catalog_test.lua",
    "tests/combat_action_test.lua",
    "tests/button_handler_test.lua",
    "tests/config_manager_test.lua",
    "tests/cooking_planner_test.lua",
    "tests/cookbook_action_test.lua",
    "tests/pathfinding_policy_test.lua",
    "tests/client_pathfinder_search_test.lua",
    "tests/target_selection_policy_test.lua",
    "tests/mixed_target_scenario_test.lua",
    "tests/actionqueue_integration_test.lua",
    "tests/actionqueue_config_test.lua",
    "tests/modifier_keys_test.lua",
    "tests/virtual_cursor_motion_test.lua",
    "tests/virtual_cursor_magnetism_test.lua",
    "tests/virtual_cursor_update_test.lua",
    "tests/virtual_cursor_magnetism_runtime_test.lua",
    "tests/input_system_hook_test.lua",
    "tests/controller_mode_gate_test.lua",
    "tests/material_planner_test.lua",
    "tests/container_cache_scope_test.lua",
    "tests/storage_access_policy_test.lua",
    "tests/action_executor_async_test.lua",
    "tests/crafting_menu_policy_test.lua",
    "tests/crafting_return_policy_test.lua",
    "tests/recipe_catalog_test.lua",
    "tests/item_catalog_test.lua",
    "tests/world_action_test.lua",
    "tests/location_protocol_test.lua",
    "tests/location_chat_transport_test.lua",
    "tests/favorite_locations_test.lua",
    "tests/player_location_service_test.lua",
    "tests/mapscreen_location_window_test.lua",
    "tests/skill_catalog_test.lua",
    "tests/skill_actions_test.lua",
    "tests/playerhud_trigger_combo_test.lua",
    "tests/gameplay_shortcut_scope_test.lua",
}

for _, path in ipairs(test_files) do
    local chunk, load_error = loadfile(path)
    assert(chunk, load_error)
    chunk()
end

print(string.format("ok - %d test file(s)", #test_files))
