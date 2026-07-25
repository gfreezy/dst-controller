package.path = table.concat({
    "./scripts/?.lua",
    "./scripts/?/init.lua",
    package.path,
}, ";")

local test_files = {
    "tests/target_selection_policy_test.lua",
    "tests/mixed_target_scenario_test.lua",
    "tests/actionqueue_integration_test.lua",
}

for _, path in ipairs(test_files) do
    local chunk, load_error = loadfile(path)
    assert(chunk, load_error)
    chunk()
end

print(string.format("ok - %d test file(s)", #test_files))
