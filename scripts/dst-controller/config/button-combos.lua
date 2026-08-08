-- Shared button-combination catalog.
-- Keep persistence, runtime dispatch, and the configuration UI on one source
-- of truth so adding a combo cannot silently leave one layer behind.

local ButtonCombos = {}

local DEFINITIONS = {
    { key = "LB_A", modifier = "LB", button = "A", label = "LB + A" },
    { key = "LB_B", modifier = "LB", button = "B", label = "LB + B" },
    { key = "LB_X", modifier = "LB", button = "X", label = "LB + X" },
    { key = "LB_Y", modifier = "LB", button = "Y", label = "LB + Y" },
    { key = "LB_LT", modifier = "LB", button = "LT", label = "LB + LT" },
    { key = "LB_RT", modifier = "LB", button = "RT", label = "LB + RT" },
    { key = "LB_DPAD_UP", modifier = "LB", button = "DPAD_UP", label = "LB + ↑" },
    { key = "LB_DPAD_DOWN", modifier = "LB", button = "DPAD_DOWN", label = "LB + ↓" },
    { key = "LB_DPAD_LEFT", modifier = "LB", button = "DPAD_LEFT", label = "LB + ←" },
    { key = "LB_DPAD_RIGHT", modifier = "LB", button = "DPAD_RIGHT", label = "LB + →" },

    { key = "RB_A", modifier = "RB", button = "A", label = "RB + A" },
    { key = "RB_B", modifier = "RB", button = "B", label = "RB + B" },
    { key = "RB_X", modifier = "RB", button = "X", label = "RB + X" },
    { key = "RB_Y", modifier = "RB", button = "Y", label = "RB + Y" },
    { key = "RB_LT", modifier = "RB", button = "LT", label = "RB + LT" },
    { key = "RB_RT", modifier = "RB", button = "RT", label = "RB + RT" },
    { key = "RB_DPAD_UP", modifier = "RB", button = "DPAD_UP", label = "RB + ↑" },
    { key = "RB_DPAD_DOWN", modifier = "RB", button = "DPAD_DOWN", label = "RB + ↓" },
    { key = "RB_DPAD_LEFT", modifier = "RB", button = "DPAD_LEFT", label = "RB + ←" },
    { key = "RB_DPAD_RIGHT", modifier = "RB", button = "DPAD_RIGHT", label = "RB + →" },
}

local BY_KEY = {}
local KEYS = {}
local BY_MODIFIER = {}
for _, definition in ipairs(DEFINITIONS) do
    BY_KEY[definition.key] = definition
    table.insert(KEYS, definition.key)
    BY_MODIFIER[definition.modifier] = BY_MODIFIER[definition.modifier] or {}
    BY_MODIFIER[definition.modifier][definition.button] = definition.key
end

function ButtonCombos.GetDefinitions()
    return DEFINITIONS
end

function ButtonCombos.GetKeys()
    return KEYS
end

function ButtonCombos.Get(key)
    return BY_KEY[key]
end

function ButtonCombos.GetByModifier()
    return BY_MODIFIER
end

-- LT/RT are mouse buttons while the virtual cursor is active. Their shoulder
-- combinations remain configurable only for the normal gameplay HUD.
function ButtonCombos.IsAvailableInMode(key, mode)
    local definition = BY_KEY[key]
    return definition ~= nil and not (
        mode == "virtual_cursor" and
        (definition.button == "LT" or definition.button == "RT"))
end

return ButtonCombos
