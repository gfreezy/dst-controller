package.loaded["dst-controller/actions/combat"] = nil

local force_refreshes = 0
package.loaded["dst-controller/target-selection/core"] = {
    RefreshControllerAttackTarget = function(controller, force)
        assert(controller ~= nil and force == true,
            "force attack should request an immediate forced target refresh")
        force_refreshes = force_refreshes + 1
    end,
}

local called = 0
local player = {
    components = {
        playercontroller = {
            DoControllerAttackButton = function()
                called = called + 1
            end,
        },
    },
}

local Combat = require("dst-controller/actions/combat")
assert(Combat.attack(player), "attack should report that the native controller action ran")
assert(called == 1, "attack should use DST's controller attack path")
assert(Combat.force_attack(player), "force attack should use the controller attack path")
assert(called == 2 and force_refreshes == 1,
    "force attack should refresh an unrestricted target before attacking")
assert(not Combat.attack({}), "attack should fail safely without a player controller")
assert(not Combat.force_attack({}), "force attack should fail safely without a controller")
