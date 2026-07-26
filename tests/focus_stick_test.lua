package.loaded["dst-controller/utils/focus-stick"] = nil
local FocusStick = require("dst-controller/utils/focus-stick")

local state = {}
assert(FocusStick.Update(state, 0.016, 0.4, 0) == nil,
    "small stick movement should not trigger discrete focus navigation")
assert(FocusStick.Update(state, 0.016, 0.8, 0) == "right",
    "the initial stick deflection should move focus immediately")
assert(FocusStick.Update(state, 0.20, 0.8, 0) == nil,
    "a held stick should wait before repeating")
assert(FocusStick.Update(state, 0.13, 0.8, 0) == "right",
    "a held stick should repeat after the initial delay")
assert(FocusStick.Update(state, 0.016, 0, 0) == nil and
    state.direction == nil,
    "returning the stick to neutral should reset navigation")
assert(FocusStick.Update(state, 0.016, 0, 0.9) == "up",
    "vertical stick movement should map to vertical focus navigation")
assert(FocusStick.Update(state, 0.016, -0.9, 0) == "left",
    "changing the dominant stick axis should move immediately")
