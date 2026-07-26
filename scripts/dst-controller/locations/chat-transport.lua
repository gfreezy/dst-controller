-- Enhanced Controller - Player location messages over ordinary world chat

local G = require("dst-controller/global")
local Protocol = require("dst-controller/locations/protocol")

local ChatTransport = {}

local installed = false

function ChatTransport.Install(handler)
    if installed then
        return true
    end
    local old_networking_say = G.GetGlobal("Networking_Say")
    if type(old_networking_say) ~= "function" then
        return false
    end

    G.SetGlobal("Networking_Say", function(
        guid, userid, name, prefab, message, colour, whisper, isemote,
        user_vanity)
        local packet = not isemote and Protocol.Decode(message) or nil
        if packet ~= nil then
            handler(packet, {
                guid = guid,
                userid = userid,
                name = name,
                prefab = prefab,
                colour = colour,
            })
            return
        end
        return old_networking_say(
            guid, userid, name, prefab, message, colour, whisper, isemote,
            user_vanity)
    end)
    installed = true
    return true
end

function ChatTransport.Send(message)
    if type(message) ~= "string" or message == "" or G.TheNet == nil or
        G.TheNet.Say == nil then
        return false
    end
    G.TheNet:Say(message, false)
    return true
end

function ChatTransport._ResetForTests()
    installed = false
end

return ChatTransport
