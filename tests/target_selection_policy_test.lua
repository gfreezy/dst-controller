local TargetPolicy = require("dst-controller/target-selection/policy")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

do
    local controller = {}
    local first_target = {}

    TargetPolicy.UpdateStableSecondaryTarget(controller, "target", "pending", "age", first_target, 0.016)

    assert_equal(controller.target, first_target, "first secondary target is immediate")
    assert_equal(controller.pending, nil, "first secondary target has no pending switch")
end

do
    local first_target = {}
    local second_target = {}
    local controller = { target = first_target, age = 0 }

    TargetPolicy.UpdateStableSecondaryTarget(controller, "target", "pending", "age", second_target, 0.1)
    assert_equal(controller.target, first_target, "existing target is stable during debounce")
    assert_equal(controller.pending, second_target, "replacement target is pending")

    TargetPolicy.UpdateStableSecondaryTarget(controller, "target", "pending", "age", second_target, 0.1)
    assert_equal(controller.target, second_target, "replacement target commits after debounce")
end

do
    local controller = { target = {}, pending = {}, age = 0.1 }

    TargetPolicy.UpdateStableSecondaryTarget(controller, "target", "pending", "age", nil, 0.016)

    assert_equal(controller.target, nil, "missing secondary target clears immediately")
    assert_equal(controller.pending, nil, "clear removes pending target")
end

do
    local entity = {}
    local other_entity = {}

    assert_equal(TargetPolicy.IsEntityTargetedAction({ target = entity }, entity), true,
        "entity action is accepted")
    assert_equal(TargetPolicy.IsEntityTargetedAction({ target = nil, pos = {} }, entity), false,
        "point action is rejected")
    assert_equal(TargetPolicy.IsEntityTargetedAction({ target = other_entity }, entity), false,
        "action for another entity is rejected")
end
