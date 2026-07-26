local passable_calls = 0
local barrier_bounds = nil
local road_z = nil
local original_atan2 = math.atan2
local original_global = package.loaded["dst-controller/global"]
local original_helpers = package.loaded["dst-controller/utils/helpers"]
local original_pathfinder = package.loaded["dst-controller/utils/client_pathfinder"]

math.atan2 = math.atan2 or function(y, x)
    return math.atan(y, x)
end

local map = {
    IsPassableAtPoint = function(_, x, _, z)
        passable_calls = passable_calls + 1
        if barrier_bounds ~= nil and
            x >= barrier_bounds.min_x and x <= barrier_bounds.max_x and
            math.abs(z) < barrier_bounds.half_height then
            return false
        end
        return true
    end,
    GetTileAtPoint = function()
        return 1
    end,
}

local world = {
    Map = map,
    prefab = "forest",
    HasTag = function()
        return false
    end,
}

local G = {
    TheWorld = world,
    ThePlayer = nil,
    IsPaused = function() return false end,
    DEGREES = math.pi / 180,
}
G.RoadManager = {
    IsOnRoad = function(_, _, _, z)
        return road_z ~= nil and math.abs(z - road_z) <= 1.75
    end,
}

package.loaded["dst-controller/global"] = G
package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function() end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/utils/client_pathfinder"] = nil

local Pathfinder = require("dst-controller/utils/client_pathfinder")

-- Open terrain still keeps the exact direct waypoint when no faster detour exists.
local path, mode = Pathfinder._Test.FindPathSync(0, 0, 400, 0)
assert(mode == "direct" and #path == 1 and path[1].x == 400,
    "open terrain should retain the direct route when a detour is not faster")

-- A nearby road is longer in distance but faster in estimated travel time.
road_z = 6
path, mode = Pathfinder._Test.FindPathSync(0, 0, 80, 0)
local uses_road = false
for _, point in ipairs(path or {}) do
    uses_road = uses_road or math.abs(point.z - road_z) <= 1.75
end
assert(mode == "fine" and uses_road,
    "a passable direct line should yield to a meaningfully faster road route")

-- Mounted/client locomotors that receive no road bonus should not detour.
G.ThePlayer = {
    components = {
        playercontroller = {
            locomotor = {
                FasterOnRoad = function() return false end,
            },
        },
    },
}
path, mode = Pathfinder._Test.FindPathSync(0, 0, 80, 0)
assert(mode == "direct",
    "road detours should respect the current locomotor's road-speed capability")
G.ThePlayer = nil
road_z = nil

-- A blocked direct line should route around the obstacle with the fine grid.
barrier_bounds = {min_x = 18, max_x = 22, half_height = 14}
passable_calls = 0
path, mode = Pathfinder._Test.FindPathSync(0, 0, 40, 0)
assert(mode == "fine" and path ~= nil and #path >= 2,
    "weighted A* should find a local detour when the direct line is blocked")

-- A long blocked route should use the much smaller coarse-grid search.
barrier_bounds = {min_x = 190, max_x = 210, half_height = 40}
passable_calls = 0
path, mode = Pathfinder._Test.FindPathSync(0, 0, 400, 0)
assert(mode == "coarse" and path ~= nil and #path >= 2,
    "long detours should use the validated coarse-grid route")

-- Start must yield after one client-side query budget instead of blocking the frame.
barrier_bounds = nil
passable_calls = 0
local movement_tick
local callback_success = nil
local movement_calls = 0
local cancelled_tasks = 0

local function NewTask()
    return {
        Cancel = function()
            cancelled_tasks = cancelled_tasks + 1
        end,
    }
end

local controller = {
    locomotor = {
        SetBufferedAction = function() end,
        RunInDirection = function()
            movement_calls = movement_calls + 1
        end,
        Stop = function() end,
    },
    CanLocomote = function() return true end,
}

G.ThePlayer = {
    components = {playercontroller = controller},
    IsValid = function() return true end,
    GetPosition = function() return {x = 0, y = 0, z = 0} end,
    ClearBufferedAction = function() end,
    HasTag = function() return false end,
    DoPeriodicTask = function(_, interval, fn)
        if interval ~= 0 then
            movement_tick = fn
        end
        return NewTask()
    end,
}

local started = Pathfinder.Start(400, 0, function(success)
    callback_success = success
end)
assert(started and callback_success == nil,
    "a long search should yield after the first client frame")
assert(passable_calls <= Pathfinder._Test.CONFIG.SEARCH_QUERIES_PER_TICK,
    "the first frame must respect the map-query budget")

-- Front-end updates continue while a single-player map screen pauses simulation.
G.IsPaused = function() return true end
for _ = 1, 120 do
    if callback_success ~= nil then
        break
    end
    Pathfinder.UpdateSearch()
end
assert(callback_success == true and movement_tick ~= nil,
    "front-end ticks should finish a search while simulation is paused")
assert(movement_calls == 1,
    "movement should start only after the client path is ready")

Pathfinder.Stop()
assert(cancelled_tasks >= 1, "stopping should cancel the movement task")

math.atan2 = original_atan2
package.loaded["dst-controller/global"] = original_global
package.loaded["dst-controller/utils/helpers"] = original_helpers
package.loaded["dst-controller/utils/client_pathfinder"] = original_pathfinder
