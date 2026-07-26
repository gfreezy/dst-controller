package.loaded["dst-controller/crafting/policy"] = nil

local Policy = require("dst-controller/crafting/policy")

local function MakeEntity(prefab, tags)
    local entity = {
        prefab = prefab,
        replica = {},
        components = {},
    }
    function entity:IsValid() return true end
    function entity:HasTag(tag) return tags ~= nil and tags[tag] == true end
    return entity
end

local function MakeContainer(can_open, opened)
    return {
        type = "chest",
        CanBeOpened = function() return can_open end,
        IsOpenedBy = function() return opened end,
        IsReadOnlyContainer = function() return false end,
        GetWidget = function() return {} end,
    }
end

local player = { replica = {} }

local moving_chester = MakeEntity("chester", { chester = true })
moving_chester.replica.container = MakeContainer(false, false)
assert(Policy.IsStorageContainer(moving_chester, player),
    "a moving Chester should remain a storage search candidate")
assert(not Policy.CanOpenStorage(moving_chester),
    "the coordinator should still wait until moving Chester becomes openable")

local unavailable_chest = MakeEntity("treasurechest")
unavailable_chest.replica.container = MakeContainer(false, false)
assert(not Policy.IsStorageContainer(unavailable_chest, player),
    "an unrelated unavailable container should stay excluded")

local shadow_chester = MakeEntity("chester", { chester = true })
local proxy_opened = true
shadow_chester.components.container_proxy = {
    CanBeOpened = function() return true end,
    IsOpenedBy = function() return proxy_opened end,
}

local other_source = MakeEntity("rabbitkinghorn_container")
other_source.replica.container = MakeContainer(true, true)
local shadow_source = MakeEntity("shadow_container")
shadow_source.replica.container = MakeContainer(true, true)
player.replica.inventory = {
    GetOpenContainers = function()
        return { [other_source] = true, [shadow_source] = true }
    end,
}

assert(Policy.IsStorageContainer(shadow_chester, player),
    "Shadow Chester's container proxy should be searchable")
assert(Policy.GetStorageContainer(shadow_chester, player, {
    [other_source] = true,
}) == shadow_source.replica.container,
    "Shadow Chester should resolve to its newly opened shadow container")

proxy_opened = false
assert(Policy.GetStorageContainer(shadow_chester, player) == nil,
    "a closed proxy must not expose stale container slots")
