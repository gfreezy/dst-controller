package.loaded["dst-controller/virtual-cursor/motion"] = nil

local Motion = require("dst-controller/virtual-cursor/motion")

local function assert_close(actual, expected, tolerance, message)
    assert(math.abs(actual - expected) <= tolerance,
        string.format("%s: expected %.6f, got %.6f", message, expected, actual))
end

local idle, direction_x, direction_y, intensity = Motion.ResolveStick(0.1, 0, 0.2, 2)
assert(idle, "input inside the radial dead zone must be idle")
assert(direction_x == 0 and direction_y == 0 and intensity == 0,
    "idle input must not retain movement")

idle, direction_x, direction_y, intensity = Motion.ResolveStick(0.6, 0, 0.2, 2)
assert(not idle, "input outside the radial dead zone must move")
assert_close(direction_x, 1, 0.000001, "horizontal direction")
assert_close(direction_y, 0, 0.000001, "horizontal direction y")
assert_close(intensity, 0.25, 0.000001,
    "the quadratic response should preserve fine control at half travel")

idle, direction_x, direction_y, intensity = Motion.ResolveStick(1, 1, 0.2, 2)
assert(not idle, "diagonal input must move")
assert_close(direction_x, math.sqrt(0.5), 0.000001, "diagonal x normalization")
assert_close(direction_y, math.sqrt(0.5), 0.000001, "diagonal y normalization")
assert_close(intensity, 1, 0.000001, "full diagonal input must reach maximum speed")

local one_step = Motion.SmoothIntensity(0, 1, 1 / 30, 30)
local half_step = Motion.SmoothIntensity(0, 1, 1 / 60, 30)
local two_steps = Motion.SmoothIntensity(half_step, 1, 1 / 60, 30)
assert_close(two_steps, one_step, 0.000001,
    "smoothing must remain stable across update rates")
assert(Motion.SmoothIntensity(one_step, 0, 1 / 60, 30) == 0,
    "released input must stop without cursor drift")

assert_close(Motion.ClampDeltaTime(0.2, 0.05), 0.05, 0.000001,
    "a stalled frame must not cause a large cursor jump")
assert(Motion.ClampDeltaTime(-1, 0.05) == 0,
    "negative delta time must not move the cursor")
