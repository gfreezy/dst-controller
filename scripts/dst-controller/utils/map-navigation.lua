-- Enhanced Controller - Shared entry point for map and saved-location navigation

local G = require("dst-controller/global")
local MapPathDrawer = require("dst-controller/utils/map_path_drawer")
local ClientPathfinder = require("dst-controller/utils/client_pathfinder")
local WormholeMapVisualizer = require("dst-controller/wormhole-tracker/map_visualizer")
local Helpers = require("dst-controller/utils/helpers")

local MapNavigation = {}

function MapNavigation.Start(x, z)
    if type(x) ~= "number" or type(z) ~= "number" or G.ThePlayer == nil then
        return false
    end
    Helpers.DebugPrintf("Path target: (%.1f, %.1f)", x, z)
    return ClientPathfinder.Start(x, z, function(path_ready, path)
        if not path_ready or path == nil or G.ThePlayer == nil then
            return
        end
        local path_points = {}
        for _, waypoint in ipairs(path) do
            path_points[#path_points + 1] =
                G.Vector3(waypoint.x, 0, waypoint.z)
        end
        MapPathDrawer.DrawPathPoints(path_points, G.ThePlayer:GetPosition())
        MapPathDrawer.UpdateDecorations()
        WormholeMapVisualizer.UpdateDecorations()
    end)
end

return MapNavigation
