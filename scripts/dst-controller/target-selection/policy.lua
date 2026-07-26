-- Pure target-selection policies shared by the runtime selector and tests.

local TargetPolicy = {}

TargetPolicy.SECONDARY_TARGET_CHANGE_DELAY = 0.2
TargetPolicy.ITEM_USE_TARGET_SCAN_INTERVAL = 0.1
TargetPolicy.BASE_TARGET_SCAN_INTERVAL = 1 / 30

-- Publish a newly discovered target immediately so the first button press is
-- usable. Debounce only switches between two existing targets.
function TargetPolicy.UpdateStableSecondaryTarget(controller, target_key, pending_key, age_key, candidate, dt)
    local current = controller[target_key]

    if candidate == current then
        controller[pending_key] = nil
        controller[age_key] = 0
        return
    end

    if current == nil or candidate == nil then
        controller[target_key] = candidate
        controller[pending_key] = nil
        controller[age_key] = 0
        return
    end

    if controller[pending_key] ~= candidate then
        controller[pending_key] = candidate
        controller[age_key] = dt or 0
    else
        controller[age_key] = (controller[age_key] or 0) + (dt or 0)
    end

    if controller[age_key] >= TargetPolicy.SECONDARY_TARGET_CHANGE_DELAY then
        controller[target_key] = candidate
        controller[pending_key] = nil
        controller[age_key] = 0
    end
end

-- Point actions such as TERRAFORM have a position but no entity target. They
-- must not turn the entity whose position was sampled into a fake B target.
function TargetPolicy.IsEntityTargetedAction(action, target)
    return action ~= nil and action.target == target
end

return TargetPolicy
