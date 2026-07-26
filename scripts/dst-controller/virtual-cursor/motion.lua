-- Virtual cursor movement math kept separate from the game-facing cursor code.

local Motion = {}

-- Apply a radial dead zone, normalize the direction, and shape the remaining
-- stick travel. An exponent above 1 keeps small movements precise without
-- reducing the maximum speed available at full deflection.
function Motion.ResolveStick(stick_x, stick_y, dead_zone, response_exponent)
    stick_x = stick_x or 0
    stick_y = stick_y or 0
    dead_zone = math.max(0, math.min(0.99, dead_zone or 0))

    local raw_magnitude = math.sqrt(stick_x * stick_x + stick_y * stick_y)
    if raw_magnitude <= dead_zone then
        return true, 0, 0, 0
    end

    local clamped_magnitude = math.min(1, raw_magnitude)
    local linear_intensity = (clamped_magnitude - dead_zone) / math.max(0.001, 1 - dead_zone)
    local exponent = math.max(1, response_exponent or 1)

    return false,
        stick_x / raw_magnitude,
        stick_y / raw_magnitude,
        linear_intensity ^ exponent
end

-- Frame-rate-independent exponential response. Snapping to zero on release is
-- intentional: a cursor must stop immediately instead of drifting after the
-- player lets go of the stick.
function Motion.SmoothIntensity(current, target, dt, response_rate)
    if target <= 0 then
        return 0
    end

    current = math.max(0, current or 0)
    dt = math.max(0, dt or 0)
    response_rate = math.max(0, response_rate or 0)
    local alpha = 1 - math.exp(-response_rate * dt)
    return current + (target - current) * alpha
end

function Motion.ClampDeltaTime(dt, maximum)
    return math.max(0, math.min(dt or 0, maximum))
end

return Motion
