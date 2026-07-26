package.loaded["dst-controller/virtual-cursor/magnetism"] = nil

local Magnetism = require("dst-controller/virtual-cursor/magnetism")

local function assert_close(actual, expected, tolerance, message)
    assert(math.abs(actual - expected) <= tolerance,
        string.format("%s: expected %.6f, got %.6f", message, expected, actual))
end

assert(Magnetism.GetScreenRadius(1, 1920, 1080) == 60, "short range must use screen pixels")
assert(Magnetism.GetScreenRadius(2, 1920, 1080) == 90, "medium range must use screen pixels")
assert(Magnetism.GetScreenRadius(3, 1920, 1080) == 126, "long range must use screen pixels")
assert(Magnetism.GetScreenRadius(2, 3840, 2160) == 180,
    "assist radius must scale with high-resolution displays")

assert_close(Magnetism.GetAlignment(1, 0, 10, 0), 1, 0.000001,
    "a target in the stick direction must have full alignment")
assert_close(Magnetism.GetAlignment(1, 0, -10, 0), -1, 0.000001,
    "a target behind the stick direction must have negative alignment")

local close_score = Magnetism.ScoreCandidate(15, 90, 1, false, 2, false, false)
local far_score = Magnetism.ScoreCandidate(55, 90, 1, false, 2, false, false)
assert(close_score > far_score, "a closer screen-space target must score higher")
assert(Magnetism.ScoreCandidate(15, 90, -1, false, 3, false, false) == nil,
    "deliberate movement away from a target must prevent acquisition")
assert(Magnetism.ScoreCandidate(15, 90, -1, true, 3, false, false) ~= nil,
    "idle acquisition must not depend on a stale movement direction")
assert(Magnetism.ScoreCandidate(110, 90, 1, false, 2, true, false) ~= nil,
    "a locked target must use the larger hysteresis radius")

assert(Magnetism.ShouldRelease(125, 90, true, 1, 0),
    "a target beyond the hysteresis radius must release")
assert(Magnetism.ShouldRelease(20, 90, false, -1, 0.5),
    "strong movement away from a target must release")
assert(not Magnetism.ShouldRelease(20, 90, false, -0.1, 0.5),
    "small directional corrections must retain the target")

local moving_x, moving_y = Magnetism.ApplyAssist(
    0, 0, 10, 0, 50, 0, 100, false, 0, 1, 1 / 60)
assert(moving_x > 0 and moving_x < 10 and moving_y == 0,
    "movement toward a nearby target must be slowed without snapping")

local free_x, free_y = Magnetism.ApplyAssist(
    0, 0, 10, 5, 50, 0, 100, false, 0, 0, 1 / 60)
assert(free_x == 10 and free_y == 5,
    "movement not aimed at the target must remain unmodified")

local waiting_x = Magnetism.ApplyAssist(
    0, 0, 0, 0, 30, 0, 90, true, 0.04, 1, 1 / 60)
assert(waiting_x == 0, "idle pull must wait briefly before moving the cursor")

local pulled_x = Magnetism.ApplyAssist(
    0, 0, 0, 0, 30, 0, 90, true, 0.1, 1, 1 / 60)
assert(pulled_x > 0 and pulled_x < 30,
    "idle assist must approach a target gradually")

local snapped_x, snapped_y = Magnetism.ApplyAssist(
    0, 0, 0, 0, 6, 4, 90, true, 0.1, 1, 1 / 60)
assert(snapped_x == 6 and snapped_y == 4,
    "an idle cursor very close to a target must snap exactly")
