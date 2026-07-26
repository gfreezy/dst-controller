local current_session = "world-a"
local current_shard = "Master"
local saved_count = 0

package.loaded["dst-controller/global"] = {
    TheNet = {
        GetSessionIdentifier = function() return current_session end,
    },
    TheShard = {
        GetShardId = function() return current_shard end,
    },
    TheWorld = {
        HasTag = function(_, tag)
            return current_shard == "Caves" and tag == "cave"
        end,
    },
    ThePlayer = {
        IsValid = function() return true end,
        Transform = {
            GetWorldPosition = function() return 12.25, 0, -34.75 end,
        },
    },
    TheSim = {
        GetPersistentString = function(_, _, callback)
            callback(false, nil)
        end,
        SetPersistentString = function(_, _, _, _, callback)
            saved_count = saved_count + 1
            callback()
        end,
    },
    json = {
        encode = function() return "encoded" end,
        decode = function() return {} end,
    },
}
package.loaded["dst-controller/locations/scope"] = nil
package.loaded["dst-controller/locations/favorites-store"] = nil

local Favorites = require("dst-controller/locations/favorites-store")
Favorites._ResetForTests()
Favorites.Load()
assert(Favorites.IsLoaded())

local surface = assert(Favorites.AddCurrent("基地;东门=入口"))
assert(surface.name == "基地;东门=入口", "JSON storage should preserve protocol delimiters")
assert(#Favorites.GetCurrentShard() == 1)

current_shard = "Caves"
local cave = assert(Favorites.AddCurrent("洞穴营地"))
assert(#Favorites.GetCurrentShard() == 1, "favorites should be separated by shard")
assert(#Favorites.GetCurrentWorld() == 2, "current world should expose all shard favorites")

assert(Favorites.Rename(surface.id, "地表基地"), "other-shard favorites should be renameable")
assert(Favorites.Remove(surface.id), "other-shard favorites should be removable")
assert(#Favorites.GetCurrentWorld() == 1)
assert(Favorites.GetCurrentWorld()[1].id == cave.id)

current_session = "world-b"
assert(#Favorites.GetCurrentWorld() == 0, "different worlds must not share favorites")
assert(saved_count >= 4, "every mutation should be persisted")
