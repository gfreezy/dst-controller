-- Enhanced Controller - Manual player position queries and snapshot cache

local G = require("dst-controller/global")
local Protocol = require("dst-controller/locations/protocol")
local ChatTransport = require("dst-controller/locations/chat-transport")
local Scope = require("dst-controller/locations/scope")

local PlayerService = {}

local QUERY_TIMEOUT = 2.5
local RESPONSE_JITTER = 0.8

local state = {
    request_sequence = 0,
    pending = {},
    handled_requests = {},
    positions = {},
    statuses = {},
    listeners = {},
}

local function Now()
    return G.GetStaticTime ~= nil and G.GetStaticTime() or os.time()
end

local function Notify()
    for listener in pairs(state.listeners) do
        listener()
    end
end

local function LocalUserId()
    if G.TheNet ~= nil and G.TheNet.GetUserID ~= nil then
        return tostring(G.TheNet:GetUserID() or "")
    end
    return G.ThePlayer ~= nil and tostring(G.ThePlayer.userid or "") or ""
end

local function GenerateRequestId()
    state.request_sequence = state.request_sequence + 1
    local suffix = LocalUserId():gsub("^.*_", "")
    if suffix == "" then
        suffix = "local"
    end
    local stamp = math.floor(Now() * 1000) % 1000000
    return string.format("%s-%06d-%d", suffix, stamp, state.request_sequence)
end

local function Schedule(delay, callback)
    local player = G.ThePlayer
    if player ~= nil and player.DoTaskInTime ~= nil then
        return player:DoTaskInTime(delay, callback)
    end
    callback()
    return nil
end

local function CaptureLocalPosition()
    local player = G.ThePlayer
    local userid = LocalUserId()
    if userid == "" or player == nil or not player:IsValid() or
        player.Transform == nil then
        return nil
    end
    local x, _, z = player.Transform:GetWorldPosition()
    local client = G.TheNet ~= nil and G.TheNet.GetClientTableForUser ~= nil and
        G.TheNet:GetClientTableForUser(userid) or nil
    local record = {
        userid = userid,
        name = client ~= nil and client.name or player.name or userid,
        prefab = client ~= nil and client.prefab or player.prefab,
        colour = client ~= nil and client.colour or player.playercolour,
        x = x,
        z = z,
        shard_id = Scope.GetShardId(),
        world_type = Scope.GetWorldType(),
        received_at = Now(),
        current_shard = true,
        local_player = true,
    }
    state.positions[userid] = record
    state.statuses[userid] = "located"
    return record
end

local function ClientTable()
    if G.TheNet == nil or G.TheNet.GetClientTable == nil then
        return {}
    end
    return G.TheNet:GetClientTable() or {}
end

local function FinishRequest(request_id)
    local request = state.pending[request_id]
    if request == nil then
        return
    end
    state.pending[request_id] = nil
    if request.kind == "single" then
        if state.statuses[request.target_userid] == "querying" then
            state.statuses[request.target_userid] = "unavailable"
        end
    else
        for _, client in ipairs(ClientTable()) do
            if state.statuses[client.userid] == "querying" then
                state.statuses[client.userid] = "unavailable"
            end
        end
    end
    Notify()
end

local function BeginRequest(request)
    state.pending[request.id] = request
    Schedule(QUERY_TIMEOUT, function()
        FinishRequest(request.id)
    end)
end

local function SendOwnPosition(request_id)
    local player = G.ThePlayer
    if player == nil or not player:IsValid() or player.Transform == nil then
        return
    end
    local x, _, z = player.Transform:GetWorldPosition()
    ChatTransport.Send(Protocol.EncodePosition(
        request_id, Scope.GetShardId(), Scope.GetWorldType(), x, z))
end

function PlayerService.QueryAll()
    local request_id = GenerateRequestId()
    state.positions = {}
    state.statuses = {}
    for _, client in ipairs(ClientTable()) do
        if client.userid ~= nil then
            state.statuses[client.userid] = "querying"
        end
    end
    CaptureLocalPosition()
    BeginRequest({ id = request_id, kind = "all", created_at = Now() })
    ChatTransport.Send(Protocol.EncodeQueryAll(request_id))
    Notify()
    return request_id
end

function PlayerService.QueryPlayer(userid, name)
    userid = tostring(userid or "")
    if userid == "" then
        return nil
    end
    if userid == LocalUserId() then
        CaptureLocalPosition()
        Notify()
        return "local"
    end
    local request_id = GenerateRequestId()
    state.positions[userid] = nil
    state.statuses[userid] = "querying"
    BeginRequest({
        id = request_id,
        kind = "single",
        target_userid = userid,
        created_at = Now(),
    })
    ChatTransport.Send(Protocol.EncodeQueryPlayer(request_id, userid, name))
    Notify()
    return request_id
end

function PlayerService.HandlePacket(packet, sender)
    sender = sender or {}
    local sender_userid = tostring(sender.userid or "")
    if packet.kind == "query_all" or packet.kind == "query_player" then
        if sender_userid == "" or sender_userid == LocalUserId() then
            return true
        end
        if packet.kind == "query_player" and
            packet.target_userid ~= LocalUserId() then
            return true
        end
        local handled_key = sender_userid .. "|" .. packet.request_id
        local cutoff = Now() - 60
        for key, handled_at in pairs(state.handled_requests) do
            if handled_at < cutoff then
                state.handled_requests[key] = nil
            end
        end
        if state.handled_requests[handled_key] then
            return true
        end
        state.handled_requests[handled_key] = Now()
        Schedule(math.random() * RESPONSE_JITTER, function()
            SendOwnPosition(packet.request_id)
        end)
        return true
    elseif packet.kind == "position" then
        local request = state.pending[packet.request_id]
        if request == nil or sender_userid == "" or
            (request.kind == "single" and
                request.target_userid ~= sender_userid) then
            return true
        end
        local current_shard = Scope.IsCurrentShard(packet.shard_id)
        state.positions[sender_userid] = {
            userid = sender_userid,
            name = sender.name or sender_userid,
            prefab = sender.prefab,
            colour = sender.colour,
            x = packet.x,
            z = packet.z,
            shard_id = packet.shard_id,
            world_type = packet.world_type,
            received_at = Now(),
            current_shard = current_shard,
            local_player = false,
        }
        state.statuses[sender_userid] = current_shard and
            "located" or "other_shard"
        if request.kind == "single" then
            state.pending[packet.request_id] = nil
        end
        Notify()
        return true
    end
    return false
end

function PlayerService.GetPlayers()
    local rows = {}
    local seen = {}
    local local_userid = LocalUserId()
    for _, client in ipairs(ClientTable()) do
        if client.userid ~= nil and client.performance == nil then
            local userid = tostring(client.userid)
            seen[userid] = true
            if userid ~= local_userid then
                local position = state.positions[userid]
                if position ~= nil then
                    position.current_shard = Scope.IsCurrentShard(position.shard_id)
                end
                rows[#rows + 1] = {
                    userid = userid,
                    name = client.name or userid,
                    prefab = client.prefab,
                    colour = client.colour,
                    userflags = client.userflags or 0,
                    base_skin = client.base_skin,
                    status = state.statuses[userid] or "not_queried",
                    position = position,
                    local_player = false,
                }
            end
        end
    end
    for userid, position in pairs(state.positions) do
        if not seen[userid] and userid ~= local_userid then
            rows[#rows + 1] = {
                userid = userid,
                name = position.name or userid,
                prefab = position.prefab,
                colour = position.colour,
                userflags = position.userflags or 0,
                base_skin = position.base_skin,
                status = state.statuses[userid] or "located",
                position = position,
                local_player = false,
            }
        end
    end
    table.sort(rows, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
    return rows
end

function PlayerService.GetCurrentShardPositions()
    local result = {}
    for _, record in pairs(state.positions) do
        record.current_shard = Scope.IsCurrentShard(record.shard_id)
        if record.current_shard then
            result[#result + 1] = record
        end
    end
    return result
end

function PlayerService.Subscribe(listener)
    state.listeners[listener] = true
    return function()
        state.listeners[listener] = nil
    end
end

function PlayerService._ResetForTests()
    state.request_sequence = 0
    state.pending = {}
    state.handled_requests = {}
    state.positions = {}
    state.statuses = {}
    state.listeners = {}
end

PlayerService.QUERY_TIMEOUT = QUERY_TIMEOUT

return PlayerService
