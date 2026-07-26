-- Pure helpers for the client A* pathfinder.

local PathfindingPolicy = {}

-- Road/carpet is the cheapest traversable terrain currently configured.
PathfindingPolicy.MIN_GROUND_COST = 0.77

function PathfindingPolicy.EstimateCost(gx, gz, end_gx, end_gz)
    local dx = math.abs(end_gx - gx)
    local dz = math.abs(end_gz - gz)
    local diagonal = math.min(dx, dz)
    local straight = math.max(dx, dz) - diagonal
    return (diagonal * 1.414 + straight) * PathfindingPolicy.MIN_GROUND_COST
end

return PathfindingPolicy
