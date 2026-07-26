-- Enhanced Controller - Current world and shard identity helpers

local G = require("dst-controller/global")

local Scope = {}

function Scope.GetSessionId()
    if G.TheNet ~= nil and G.TheNet.GetSessionIdentifier ~= nil then
        local session_id = G.TheNet:GetSessionIdentifier()
        if session_id ~= nil and session_id ~= "" then
            return tostring(session_id)
        end
    end
    if G.TheWorld ~= nil and G.TheWorld.meta ~= nil and
        G.TheWorld.meta.session_identifier ~= nil then
        return tostring(G.TheWorld.meta.session_identifier)
    end
    return "unknown-session"
end

function Scope.GetShardId()
    if G.TheShard ~= nil and G.TheShard.GetShardId ~= nil then
        local shard_id = G.TheShard:GetShardId()
        if shard_id ~= nil and shard_id ~= "" then
            return tostring(shard_id)
        end
    end
    return "unknown-shard"
end

function Scope.GetWorldType()
    return G.TheWorld ~= nil and G.TheWorld.HasTag ~= nil and
        G.TheWorld:HasTag("cave") and "洞穴" or "地表"
end

function Scope.IsCurrentShard(shard_id)
    return tostring(shard_id or "") == Scope.GetShardId()
end

return Scope
