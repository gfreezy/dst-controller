-- Enhanced Controller - Global chat hook for player location messages

local G = require("dst-controller/global")
local ChatTransport = require("dst-controller/locations/chat-transport")
local PlayerService = require("dst-controller/locations/player-service")
local FavoritesStore = require("dst-controller/locations/favorites-store")
local ControlMode = require("dst-controller/utils/control-mode")

local NetworkingHook = {}

local function InstallChatTransport()
    return ChatTransport.Install(function(packet, sender)
        if ControlMode.IsControllerActive() then
            PlayerService.HandlePacket(packet, sender)
        end
    end)
end

function NetworkingHook.Install()
    if not InstallChatTransport() then
        G.AddSimPostInit(function()
            InstallChatTransport()
        end)
    end
    G.AddSimPostInit(function()
        FavoritesStore.Load()
    end)
end

return NetworkingHook
