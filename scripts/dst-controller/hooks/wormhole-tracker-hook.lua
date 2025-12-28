-- Wormhole Tracker Hook
-- Installs event listeners to track wormhole usage

local G = require("dst-controller/global")
local WormholeTracker = require("dst-controller/wormhole-tracker/core")

local WormholeTrackerHook = {}

-- Track if we've already installed the hook for this player
local installed_players = {}

-- Install player-specific event listeners
local function InstallPlayerListeners(player)
    if not player or installed_players[player] then
        return
    end

    installed_players[player] = true

    -- Listen for wormholespit event (when player exits a wormhole)
    -- Note: This may not work on pure clients as the event is server-side
    player:ListenForEvent("wormholespit", function()
        print("[WormholeTrackerHook] wormholespit event received!")
        WormholeTracker.OnExitWormhole(player)
    end)

    -- Alternative: Listen for stategraph state change to "jumpout"
    -- This fires when player exits a wormhole
    player:ListenForEvent("newstate", function(inst, data)
        if data and data.statename == "jumpout" then
            print("[WormholeTrackerHook] jumpout state detected!")
            -- Delay slightly to ensure player position is updated
            player:DoTaskInTime(0.5, function()
                WormholeTracker.OnExitWormhole(player)
            end)
        end
    end)

    -- Clean up when player is removed
    player:ListenForEvent("onremove", function()
        installed_players[player] = nil
    end)

    print("[WormholeTrackerHook] Installed listeners for player: " .. tostring(player))
end

-- Hook into ACTIONS.JUMPIN to detect when player enters a wormhole
local function HookJumpInAction()
    -- Hook the action's fn to capture the target wormhole
    local ACTIONS = G.ACTIONS
    if not ACTIONS or not ACTIONS.JUMPIN then
        print("[WormholeTrackerHook] Warning: ACTIONS.JUMPIN not found")
        return
    end

    local original_jumpin_fn = ACTIONS.JUMPIN.fn

    ACTIONS.JUMPIN.fn = function(act)
        -- Record the entry wormhole before the action executes
        if act.target and act.target:HasTag("wormhole") then
            WormholeTracker.OnEnterWormhole(act.target)
        end

        -- Call original function
        if original_jumpin_fn then
            return original_jumpin_fn(act)
        end
    end

    -- Also hook JUMPIN_MAP for map teleportation
    if ACTIONS.JUMPIN_MAP then
        local original_jumpin_map_fn = ACTIONS.JUMPIN_MAP.fn

        ACTIONS.JUMPIN_MAP.fn = function(act)
            if act.target and act.target:HasTag("wormhole") then
                WormholeTracker.OnEnterWormhole(act.target)
            end

            if original_jumpin_map_fn then
                return original_jumpin_map_fn(act)
            end
        end
    end

    print("[WormholeTrackerHook] Hooked JUMPIN action")
end

-- Alternative: Hook PlayerController to detect wormhole interaction
local function HookPlayerController()
    G.AddComponentPostInit("playercontroller", function(self)
        -- Hook DoAction to capture wormhole targets
        local old_DoAction = self.DoAction

        self.DoAction = function(self, bufferedaction)
            -- Check if this is a JUMPIN action on a wormhole
            if bufferedaction and bufferedaction.action then
                local action_id = bufferedaction.action.id
                if (action_id == "JUMPIN" or action_id == "JUMPIN_MAP") and
                   bufferedaction.target and
                   bufferedaction.target:HasTag("wormhole") then
                    WormholeTracker.OnEnterWormhole(bufferedaction.target)
                end
            end

            return old_DoAction(self, bufferedaction)
        end
    end)

    print("[WormholeTrackerHook] Hooked PlayerController:DoAction")
end

function WormholeTrackerHook.Install()
    print("[WormholeTrackerHook] Installing wormhole tracker...")

    -- Load saved data when the hook is installed
    WormholeTracker.Load()

    -- Hook action for detecting wormhole entry
    -- Using PlayerController hook as it's more reliable on client
    HookPlayerController()

    -- Install listeners for the local player
    -- Use AddSimPostInit to ensure ThePlayer is available
    G.AddSimPostInit(function()
        -- Try to install immediately
        if G.ThePlayer then
            InstallPlayerListeners(G.ThePlayer)
        end

        -- Also listen for playeractivated event in case player spawns later
        G.TheWorld:ListenForEvent("playeractivated", function(world, player)
            if player == G.ThePlayer then
                InstallPlayerListeners(player)
            end
        end)
    end)

    print("[WormholeTrackerHook] Wormhole tracker installed")
end

-- Export the tracker for external access
WormholeTrackerHook.Tracker = WormholeTracker

return WormholeTrackerHook
