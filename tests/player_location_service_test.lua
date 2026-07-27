local now = 10
local scheduled = {}
local sent = {}
local clients = {
    { userid = "KU_local", name = "本地玩家", prefab = "wilson", colour = { 1, 1, 1, 1 } },
    {
        userid = "KU_remote",
        name = "远端;玩家=一",
        prefab = "willow",
        colour = { 1, 0, 0, 1 },
        userflags = 4,
        base_skin = "willow_none",
    },
}

package.loaded["dst-controller/global"] = {
    GetStaticTime = function() return now end,
    TheNet = {
        GetUserID = function() return "KU_local" end,
        GetClientTable = function() return clients end,
        GetClientTableForUser = function(_, userid)
            for _, client in ipairs(clients) do
                if client.userid == userid then return client end
            end
        end,
    },
    TheShard = { GetShardId = function() return "Master" end },
    TheWorld = { HasTag = function() return false end },
    ThePlayer = {
        userid = "KU_local",
        name = "Wilson",
        prefab = "wilson",
        IsValid = function() return true end,
        Transform = { GetWorldPosition = function() return 5, 0, 6 end },
        DoTaskInTime = function(_, delay, callback)
            scheduled[#scheduled + 1] = { delay = delay, callback = callback }
        end,
    },
}
package.loaded["dst-controller/locations/chat-transport"] = {
    Send = function(message)
        sent[#sent + 1] = message
        return true
    end,
}
package.loaded["dst-controller/locations/protocol"] = nil
package.loaded["dst-controller/locations/scope"] = nil
package.loaded["dst-controller/locations/player-service"] = nil

local Protocol = require("dst-controller/locations/protocol")
local Service = require("dst-controller/locations/player-service")
Service._ResetForTests()

local request_id = Service.QueryAll()
local query = assert(Protocol.Decode(sent[#sent]))
assert(query.kind == "query_all" and query.request_id == request_id)

local rows = Service.GetPlayers()
assert(#rows == 1, "player list should omit the local player")
assert(rows[1].userid == "KU_remote" and rows[1].status == "querying")
assert(rows[1].userflags == 4 and rows[1].base_skin == "willow_none",
    "player rows should include native badge appearance data")

Service.HandlePacket({
    kind = "position",
    request_id = request_id,
    shard_id = "Master",
    world_type = "地表",
    x = 20,
    z = 30,
}, {
    userid = "KU_remote",
    name = "远端;玩家=一",
    prefab = "willow",
    colour = { 1, 0, 0, 1 },
})
assert(#Service.GetCurrentShardPositions() == 2)

Service.QueryPlayer("KU_remote", "远端;玩家=一")
local targeted = assert(Protocol.Decode(sent[#sent]))
assert(targeted.kind == "query_player")
assert(targeted.target_name == "远端;玩家=一")

Service.HandlePacket({
    kind = "query_all",
    request_id = "REMOTE-1",
}, { userid = "KU_remote", name = "远端玩家" })
local response_task
for _, task in ipairs(scheduled) do
    if task.delay <= 0.8 then response_task = task end
end
assert(response_task ~= nil, "incoming requests should schedule one jittered response")
response_task.callback()
local response = assert(Protocol.Decode(sent[#sent]))
assert(response.kind == "position")
assert(response.request_id == "REMOTE-1")
assert(response.x == 5 and response.z == 6)
