local current_session = "save-a"
local current_shard = "Master"

package.loaded["dst-controller/global"] = {
    TheNet = { GetSessionIdentifier = function() return current_session end },
    TheShard = { GetShardId = function() return current_shard end },
}
package.loaded["dst-controller/crafting/container-cache"] = nil

local Cache = require("dst-controller/crafting/container-cache")
Cache._ResetForTests()

local item = {
    prefab = "log",
    replica = { stackable = { StackSize = function() return 7 end } },
    IsValid = function() return true end,
    HasTag = function() return false end,
}

local function MakeContainer(guid)
    local entity = {
        GUID = guid,
        prefab = "treasurechest",
        replica = {},
        Transform = { GetWorldPosition = function() return 10, 0, 20 end },
        IsValid = function() return true end,
        HasTag = function() return false end,
    }
    entity.replica.container = {
        type = "chest",
        CanBeOpened = function() return true end,
        IsReadOnlyContainer = function() return false end,
        IsOpenedBy = function() return true end,
        GetWidget = function() return {} end,
        GetItems = function() return { item } end,
    }
    return entity
end

local player = { replica = {} }
local surface_chest = MakeContainer(101)
assert(Cache.Snapshot(surface_chest, player), "first surface snapshot should change the cache")
assert(Cache.Get(surface_chest).items.log == 7, "surface snapshot should retain item counts")

current_shard = "Caves"
assert(Cache.Get(surface_chest) == nil, "cave cache must not see surface records")
local cave_chest = MakeContainer(202)
assert(Cache.Snapshot(cave_chest, player), "cave snapshot should use its own scope")

current_shard = "Master"
assert(Cache.Get(surface_chest) ~= nil, "returning to surface should restore the surface scope")
assert(Cache.Get(MakeContainer(999)) == nil, "a different entity GUID must not reuse a stale snapshot")

local refreshed = MakeContainer(303)
assert(Cache.Snapshot(refreshed, player), "a replacement chest should create a fresh snapshot")
local stale_record = Cache.Get(refreshed)
stale_record.updated_at = 0
assert(Cache.Get(refreshed) == nil, "expired container snapshots should be pruned on access")

current_session = "save-b"
assert(Cache.Get(surface_chest) == nil, "different world sessions must not share cache")
