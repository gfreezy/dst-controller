package.path = table.concat({
    "./scripts/?.lua",
    "./scripts/?/init.lua",
    package.path,
}, ";")

local test_files = {
    "tests/target_selection_policy_test.lua",
    "tests/mixed_target_scenario_test.lua",
    "tests/actionqueue_integration_test.lua",
    "tests/virtual_cursor_motion_test.lua",
    "tests/virtual_cursor_magnetism_test.lua",
    "tests/virtual_cursor_update_test.lua",
    "tests/virtual_cursor_magnetism_runtime_test.lua",
    "tests/input_system_hook_test.lua",
    "tests/material_planner_test.lua",
    "tests/container_cache_scope_test.lua",
    "tests/action_executor_async_test.lua",
    "tests/crafting_menu_policy_test.lua",
    "tests/crafting_return_policy_test.lua",
}

for _, path in ipairs(test_files) do
    local chunk, load_error = loadfile(path)
    assert(chunk, load_error)
    chunk()
end

print(string.format("ok - %d test file(s)", #test_files))
