-- Enhanced Controller - Global Environment Initialization
-- This module sets up the global environment for all mod files

local Init = {}

-- Initialize global environment access
function Init.SetupGlobalEnv()
    -- Access global environment
    for _, v in ipairs({ "_G", "setmetatable", "rawget" }) do
        env[v] = GLOBAL[v]
    end

    setmetatable(env, {
        __index = function(table, key)
            return rawget(_G, key)
        end
    })
end

return Init
