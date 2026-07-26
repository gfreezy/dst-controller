-- Declarative action catalog shared by the executor registry and config UI.
-- Adding an action here is enough to register it; exposed actions also appear
-- in the editor with the correct parameter requirements.

local ActionCatalog = {}

local DEFINITIONS = {
    { id = "attack", module = "combat", label = "ACTION_ATTACK", exposed = true },
    { id = "examine", module = "inspection", label = "ACTION_EXAMINE", exposed = true },
    { id = "inspect_self", module = "inspection", label = "ACTION_INSPECT_SELF", exposed = true },

    { id = "equip_item", module = "equipment", label = "ACTION_EQUIP_ITEM", exposed = true, has_param = true },
    { id = "unequip_item", module = "equipment", label = "ACTION_UNEQUIP_ITEM", exposed = true, has_param = true },
    { id = "use_equip", module = "equipment", label = "ACTION_USE_EQUIP", exposed = true, has_param = true },
    { id = "cycle_hand", module = "equipment", label = "ACTION_CYCLE_HAND", exposed = true },
    { id = "cycle_hand_prev", module = "equipment" },
    { id = "cycle_head", module = "equipment", label = "ACTION_CYCLE_HEAD", exposed = true },
    { id = "cycle_head_prev", module = "equipment" },
    { id = "cycle_body", module = "equipment", label = "ACTION_CYCLE_BODY", exposed = true },
    { id = "cycle_body_prev", module = "equipment" },
    { id = "swap_hand_last", module = "equipment" },
    { id = "swap_head_last", module = "equipment" },
    { id = "swap_body_last", module = "equipment" },
    { id = "save_hand_item", module = "equipment", label = "ACTION_SAVE_HAND_ITEM", exposed = true },
    { id = "restore_hand_item", module = "equipment", label = "ACTION_RESTORE_HAND_ITEM", exposed = true },
    { id = "save_head_item", module = "equipment" },
    { id = "restore_head_item", module = "equipment" },
    { id = "save_body_item", module = "equipment" },
    { id = "restore_body_item", module = "equipment" },

    { id = "use_item_on_self", module = "items", label = "ACTION_USE_ITEM_ON_SELF", exposed = true, has_param = true },
    { id = "use_item_on_scene", module = "items", label = "ACTION_USE_ITEM_ON_SCENE", exposed = true, has_param = true },
    { id = "use_active_item_on_self", module = "items", label = "ACTION_USE_ACTIVE_ITEM_ON_SELF", exposed = true },
    { id = "use_active_item_on_scene", module = "items", label = "ACTION_USE_ACTIVE_ITEM_ON_SCENE", exposed = true },

    { id = "craft_item", module = "crafting", label = "ACTION_CRAFT_ITEM", exposed = true, has_param = true },
    { id = "willow_cast_spell", module = "character" },
    { id = "trigger_key", module = "keyboard", label = "ACTION_TRIGGER_KEY", exposed = true, has_param = true },
    { id = "enable_virtual_cursor", module = "system", label = "ACTION_ENABLE_VIRTUAL_CURSOR", exposed = true },
    { id = "disable_virtual_cursor", module = "system", label = "ACTION_DISABLE_VIRTUAL_CURSOR", exposed = true },

    -- Delay is interpreted directly by ActionExecutor and has no action module.
    { id = "delay", label = "ACTION_DELAY", exposed = true, has_param = true, special = true },
}

local BY_ID = {}
for _, definition in ipairs(DEFINITIONS) do
    assert(BY_ID[definition.id] == nil, "duplicate action id: " .. definition.id)
    BY_ID[definition.id] = definition
end

function ActionCatalog.GetDefinitions()
    return DEFINITIONS
end

function ActionCatalog.Get(action_id)
    return BY_ID[action_id]
end

function ActionCatalog.NeedsParameter(action_id)
    local definition = BY_ID[action_id]
    return definition ~= nil and definition.has_param == true
end

function ActionCatalog.BuildOptions(localize)
    local options = {
        { data = "", text = localize("ACTION_NONE"), has_param = false },
    }
    for _, definition in ipairs(DEFINITIONS) do
        if definition.exposed then
            table.insert(options, {
                data = definition.id,
                text = localize(definition.label),
                has_param = definition.has_param == true,
            })
        end
    end
    return options
end

function ActionCatalog.BuildRegistry()
    local registry = {}
    local modules = {}
    for _, definition in ipairs(DEFINITIONS) do
        if not definition.special then
            local module = modules[definition.module]
            if module == nil then
                module = require("dst-controller/actions/" .. definition.module)
                modules[definition.module] = module
            end
            local action = module[definition.id]
            assert(type(action) == "function", "missing action implementation: " .. definition.id)
            registry[definition.id] = action
        end
    end
    return registry
end

return ActionCatalog
