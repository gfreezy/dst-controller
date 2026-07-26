-- Pure screen-space magnetism policy for the virtual cursor.

local Magnetism = {}

Magnetism.SCAN_INTERVAL = 1 / 20
Magnetism.IDLE_DELAY = 0.08
Magnetism.RELEASE_MULTIPLIER = 1.35
Magnetism.SNAP_DISTANCE = 10
Magnetism.WORLD_SEARCH_MAX = 20

local SCREEN_RANGES = {60, 90, 126}
local MOVE_PULL_RATE = 11
local IDLE_PULL_RATE = 14
local MAX_FRICTION = 0.70

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Magnetism.GetScreenRadius(range_level, screen_width, screen_height)
    range_level = math.floor(Clamp(range_level or 2, 1, 3) + 0.5)
    local resolution_scale = Clamp(math.max(screen_width, screen_height) / 1920, 0.75, 2)
    return SCREEN_RANGES[range_level] * resolution_scale
end

function Magnetism.GetAlignment(direction_x, direction_y, delta_x, delta_y)
    local distance = math.sqrt(delta_x * delta_x + delta_y * delta_y)
    if distance <= 0 then
        return 1
    end
    return (direction_x * delta_x + direction_y * delta_y) / distance
end

-- Higher scores win. A target behind deliberate stick movement is not a
-- candidate, while the current target receives hysteresis against flicker.
function Magnetism.ScoreCandidate(distance, acquire_radius, alignment, is_idle,
    action_priority, is_locked, prefer_player, player_distance)
    local allowed_radius = is_locked and
        acquire_radius * Magnetism.RELEASE_MULTIPLIER or acquire_radius
    if distance > allowed_radius then
        return nil
    end
    if not is_idle and alignment < -0.15 then
        return nil
    end

    local normalized_distance = Clamp(distance / allowed_radius, 0, 1)
    local score = (1 - normalized_distance) ^ 2
    score = score + Clamp(action_priority or 0, 0, 3) / 3 * 0.18
    if not is_idle then
        score = score + math.max(0, alignment) * 0.30
    end
    if is_locked then
        score = score + 0.32
    end
    if prefer_player then
        score = score + (1 - Clamp((player_distance or 30) / 30, 0, 1)) * 0.12
    end
    return score
end

function Magnetism.ShouldRelease(distance, acquire_radius, is_idle, alignment, intensity)
    if distance > acquire_radius * Magnetism.RELEASE_MULTIPLIER then
        return true
    end
    return not is_idle and (intensity or 0) > 0.05 and alignment < -0.20
end

-- Apply controller-style aim assist: slow movement near an intended target,
-- add a small directional pull, and snap only after the stick is released.
function Magnetism.ApplyAssist(old_x, old_y, raw_x, raw_y, target_x, target_y,
    acquire_radius, is_idle, idle_time, alignment, dt)
    local delta_x = target_x - old_x
    local delta_y = target_y - old_y
    local distance = math.sqrt(delta_x * delta_x + delta_y * delta_y)
    if distance > acquire_radius * Magnetism.RELEASE_MULTIPLIER then
        return raw_x, raw_y
    end

    dt = math.max(0, math.min(dt or 0, 0.05))
    if is_idle then
        if (idle_time or 0) < Magnetism.IDLE_DELAY then
            return raw_x, raw_y
        end
        if distance <= Magnetism.SNAP_DISTANCE then
            return target_x, target_y
        end

        local proximity = 1 - Clamp(distance / acquire_radius, 0, 1)
        local alpha = 1 - math.exp(-IDLE_PULL_RATE * (0.25 + proximity * 0.75) * dt)
        return raw_x + (target_x - raw_x) * alpha,
            raw_y + (target_y - raw_y) * alpha
    end

    alignment = math.max(0, alignment or 0)
    if alignment <= 0 or distance >= acquire_radius then
        return raw_x, raw_y
    end

    local proximity = (1 - Clamp(distance / acquire_radius, 0, 1)) ^ 2
    local friction = 1 - MAX_FRICTION * proximity * alignment
    local slowed_x = old_x + (raw_x - old_x) * friction
    local slowed_y = old_y + (raw_y - old_y) * friction
    local pull_alpha = 1 - math.exp(-MOVE_PULL_RATE * proximity * alignment * dt)
    local assisted_x = slowed_x + (target_x - slowed_x) * pull_alpha
    local assisted_y = slowed_y + (target_y - slowed_y) * pull_alpha

    -- Directional pull may rotate the movement vector, but it must not undo
    -- the friction zone by accelerating the cursor past its slowed distance.
    local raw_dx, raw_dy = raw_x - old_x, raw_y - old_y
    local maximum_move = math.sqrt(raw_dx * raw_dx + raw_dy * raw_dy) * friction
    local assisted_dx, assisted_dy = assisted_x - old_x, assisted_y - old_y
    local assisted_distance = math.sqrt(assisted_dx * assisted_dx + assisted_dy * assisted_dy)
    if assisted_distance > maximum_move and assisted_distance > 0 then
        local scale = maximum_move / assisted_distance
        assisted_x = old_x + assisted_dx * scale
        assisted_y = old_y + assisted_dy * scale
    end

    return assisted_x, assisted_y
end

return Magnetism
