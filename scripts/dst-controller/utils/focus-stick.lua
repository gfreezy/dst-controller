-- Enhanced Controller - Discrete focus navigation driven by an analog stick

local FocusStick = {}

local DEFAULTS = {
    activation_threshold = 0.55,
    release_threshold = 0.35,
    initial_repeat_delay = 0.32,
    repeat_interval = 0.12,
}

local function DirectionComponent(direction, x, y)
    if direction == "left" then
        return -x, math.abs(y)
    elseif direction == "right" then
        return x, math.abs(y)
    elseif direction == "up" then
        return y, math.abs(x)
    elseif direction == "down" then
        return -y, math.abs(x)
    end
    return 0, 0
end

local function ResolveDirection(state, x, y, options)
    if state.direction ~= nil then
        local component, cross_component = DirectionComponent(
            state.direction, x, y)
        if component >= options.release_threshold and
            component >= cross_component * 0.75 then
            return state.direction
        end
    end

    local abs_x = math.abs(x)
    local abs_y = math.abs(y)
    if math.max(abs_x, abs_y) < options.activation_threshold then
        return nil
    end
    if abs_x >= abs_y then
        return x < 0 and "left" or "right"
    end
    return y < 0 and "down" or "up"
end

function FocusStick.Reset(state)
    state.direction = nil
    state.repeat_time = 0
end

-- Returns a direction only on the initial deflection or a repeat tick.
function FocusStick.Update(state, dt, x, y, overrides)
    local options = overrides or DEFAULTS
    local direction = ResolveDirection(state, x, y, options)
    if direction == nil then
        FocusStick.Reset(state)
        return nil
    end

    if direction ~= state.direction then
        state.direction = direction
        state.repeat_time = options.initial_repeat_delay
        return direction
    end

    state.repeat_time = (state.repeat_time or options.initial_repeat_delay) - dt
    if state.repeat_time <= 0 then
        state.repeat_time = options.repeat_interval
        return direction
    end
    return nil
end

FocusStick.DEFAULTS = DEFAULTS

return FocusStick
