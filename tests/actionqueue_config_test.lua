local module_names = {
    "dst-controller/global",
    "dst-controller/hooks/input-hook",
    "dst-controller/integrations/actionqueue-config",
}
local saved_modules = {}
for _, name in ipairs(module_names) do
    saved_modules[name] = package.loaded[name]
end

local configured_key = "KEY_LALT"
local index = {
    GetModsToLoad = function()
        return { "workshop-2873533916" }
    end,
    GetModInfo = function()
        return { name = "ActionQueue RB3" }
    end,
}

package.loaded["dst-controller/global"] = {
    KnownModIndex = index,
    KEY_LALT = 101,
    KEY_LSHIFT = 102,
    GetGlobal = function(name)
        if name == "GetModConfigData" then
            return function(option, modname, local_config)
                assert(option == "action_queue_key")
                assert(modname == "workshop-2873533916")
                assert(local_config == true)
                return configured_key
            end
        end
    end,
}
package.loaded["dst-controller/hooks/input-hook"] = {
    GetModifierForKey = function(key)
        return key == 101 and "alt" or key == 102 and "shift" or nil
    end,
}
package.loaded["dst-controller/integrations/actionqueue-config"] = nil

local ActionQueueConfig = require("dst-controller/integrations/actionqueue-config")
assert(ActionQueueConfig.GetModifier() == "alt",
    "ActionQueue integration should follow ActionQueue's own configured modifier")

configured_key = false
assert(ActionQueueConfig.GetModifier() == nil,
    "a disabled ActionQueue key must not fall back to a hard-coded shoulder")

configured_key = "KEY_LSHIFT"
assert(ActionQueueConfig.GetModifier() == "shift",
    "left/right key aliases should normalize to the semantic modifier")

for _, name in ipairs(module_names) do
    package.loaded[name] = saved_modules[name]
end
