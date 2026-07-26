local current_networking_say
local ordinary_calls = 0
local sent_message

current_networking_say = function()
    ordinary_calls = ordinary_calls + 1
    return "ordinary"
end

package.loaded["dst-controller/global"] = {
    GetGlobal = function(name)
        return name == "Networking_Say" and current_networking_say or nil
    end,
    SetGlobal = function(name, value)
        if name == "Networking_Say" then current_networking_say = value end
    end,
    TheNet = {
        Say = function(_, message) sent_message = message end,
    },
}
package.loaded["dst-controller/locations/protocol"] = nil
package.loaded["dst-controller/locations/chat-transport"] = nil

local Protocol = require("dst-controller/locations/protocol")
local Transport = require("dst-controller/locations/chat-transport")
local received
assert(Transport.Install(function(packet, sender)
    received = { packet = packet, sender = sender }
end))

assert(current_networking_say(1, "KU_a", "A", "wilson", "你好") == "ordinary")
assert(ordinary_calls == 1, "ordinary chat should continue through the native handler")

current_networking_say(2, "KU_b", "B", "willow",
    Protocol.EncodeQueryAll("Q1"), { 1, 0, 0, 1 }, false, false)
assert(received ~= nil and received.packet.kind == "query_all")
assert(received.sender.userid == "KU_b")
assert(ordinary_calls == 1, "valid protocol messages should be hidden from chat")

assert(Transport.Send(Protocol.EncodeQueryAll("Q2")))
assert(Protocol.Decode(sent_message).request_id == "Q2")
