package.loaded["dst-controller/actions/combat"] = nil

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
assert(not Combat.attack({}), "attack should fail safely without a player controller")
