local erased = false
package.loaded["dst-controller/global"] = {
    TheSim = {
        ErasePersistentString = function(_, _, callback)
            erased = true
            callback()
        end,
    },
}
package.loaded["dst-controller/utils/helpers"] = nil
package.loaded["dst-controller/utils/config_manager"] = nil

local Config = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")

local original_print = print
local captured_logs = {}
print = function(message)
    captured_logs[#captured_logs + 1] = tostring(message)
end
Helpers.SetDebugEnabled(false)
Helpers.DebugPrint("hidden diagnostic")
assert(#captured_logs == 0,
    "diagnostic logs should be silent when debug logging is disabled")
Helpers.SetDebugEnabled(true)
Helpers.DebugPrint("visible diagnostic")
assert(captured_logs[1] == "[Enhanced Controller] visible diagnostic",
    "enabled diagnostic logs should use the mod prefix")
Helpers.SetDebugEnabled(false)
print = original_print

local normalized = Config.NormalizeConfig({
    version = "1.0.0",
    tasks = {
        LB_A = {
            on_press = { "attack", {}, { "delay", 0 / 0 }, { "delay", "0.2" } },
            on_release = "invalid",
        },
    },
    settings = {
        attack_angle_mode = "invalid",
        auto_crafting_settings = {
            search_radius = 99,
            search_mode = "invalid",
            max_containers = -4,
        },
        virtual_cursor_settings = {
            cursor_speed = 99,
            magnetism_range = -5,
            toggle_combo = { "LB", "LB" },
            enabled = "yes",
        },
    },
})

assert(normalized ~= nil and normalized.version == "2.3.0",
    "legacy configs should migrate to the current schema")
assert(#normalized.tasks.LB_A.on_press == 2,
    "invalid action definitions should be removed without losing valid actions")
assert(#normalized.tasks.LB_A.on_release == 0,
    "invalid action lists should normalize to an empty list")
assert(normalized.tasks.LB_Y.on_press[1] == "open_skill_panel",
    "new default combos should be merged into older saved configs")
assert(normalized.tasks.LB_X.on_press[1] == "force_attack" and
       normalized.tasks.LB_RT.on_press[1] == "open_skill_wheel",
    "legacy empty preset slots should migrate to the current defaults")
assert(normalized.settings.attack_angle_mode == "forward_only",
    "invalid enums should fall back to defaults")
assert(normalized.settings.virtual_cursor_settings.cursor_speed == 3,
    "numeric cursor settings should be clamped")
assert(normalized.settings.virtual_cursor_settings.magnetism_range == 1,
    "magnetism range should be clamped")
assert(normalized.settings.virtual_cursor_settings.enabled == true,
    "invalid booleans should fall back to defaults")
assert(#normalized.settings.virtual_cursor_settings.toggle_combo == 3,
    "invalid toggle combos should fall back to the default")
assert(normalized.settings.virtual_cursor_settings.actionqueue_integration == true,
    "new settings should be merged into legacy configurations")
assert(normalized.settings.virtual_cursor_settings.modifier_keys.LB == "shift" and
       normalized.settings.virtual_cursor_settings.modifier_keys.RB == "shift",
    "legacy settings should gain the default shoulder modifier mappings")
assert(normalized.tasks.LB_DPAD_UP ~= nil and
       normalized.tasks.LB_DPAD_UP.on_press[1] == "toggle_cooking_menu" and
       normalized.virtual_cursor_tasks.RB_DPAD_RIGHT ~= nil,
    "legacy task sets should gain the default shoulder and D-pad combinations")
assert(#normalized.virtual_cursor_tasks.LB_LT.on_press == 0 and
       #normalized.virtual_cursor_tasks.LB_RT.on_press == 0 and
       #normalized.virtual_cursor_tasks.RB_LT.on_release == 0 and
       #normalized.virtual_cursor_tasks.RB_RT.on_release == 0,
    "virtual cursor trigger combinations must remain reserved for mouse clicks")

local reserved_cursor_triggers = Config.NormalizeConfig({
    tasks = {},
    virtual_cursor_tasks = {
        LB_LT = { on_press = { "attack" }, on_release = { "examine" } },
        RB_RT = { on_press = { "attack" }, on_release = { "examine" } },
    },
})
assert(#reserved_cursor_triggers.virtual_cursor_tasks.LB_LT.on_press == 0 and
       #reserved_cursor_triggers.virtual_cursor_tasks.RB_RT.on_release == 0,
    "saved cursor-mode LT/RT shortcuts should be discarded during normalization")

local upgraded_presets = Config.NormalizeConfig({
    version = "2.2.0",
    tasks = {
        LB_X = { on_press = {}, on_release = {} },
        LB_Y = { on_press = { "examine" }, on_release = {} },
        LB_RT = { on_press = {}, on_release = {} },
    },
})
assert(upgraded_presets.tasks.LB_X.on_press[1] == "force_attack" and
       upgraded_presets.tasks.LB_Y.on_press[1] == "open_skill_panel" and
       upgraded_presets.tasks.LB_RT.on_press[1] == "open_skill_wheel",
    "2.2 configurations should receive the requested default preset upgrade")

local current_empty_preset = Config.NormalizeConfig({
    version = "2.3.0",
    tasks = {
        LB_RT = { on_press = {}, on_release = {} },
    },
})
assert(#current_empty_preset.tasks.LB_RT.on_press == 0,
    "current configurations should preserve an explicitly cleared preset")
assert(normalized.settings.auto_crafting_settings.search_radius == 12 and
       normalized.settings.auto_crafting_settings.search_mode == "smart" and
       normalized.settings.auto_crafting_settings.max_containers == 0,
    "automatic-crafting limits should be normalized and migrated")

local corrupted_nested_settings = Config.NormalizeSettings({
    auto_crafting_settings = "corrupt",
    virtual_cursor_settings = false,
})
assert(corrupted_nested_settings.auto_crafting_settings.search_radius == 6,
    "invalid nested automatic-crafting settings should fall back safely")
assert(corrupted_nested_settings.virtual_cursor_settings.cursor_speed == 1,
    "invalid nested cursor settings should fall back safely")

local normalized_modifiers = Config.NormalizeSettings({
    virtual_cursor_settings = {
        modifier_keys = { LB = "alt", RB = "invalid" },
    },
})
assert(normalized_modifiers.virtual_cursor_settings.modifier_keys.LB == "alt" and
       normalized_modifiers.virtual_cursor_settings.modifier_keys.RB == "shift",
    "shoulder modifier settings should accept only supported semantic keys")

Config.UpdateRuntimeTasks({ LB_A = { on_press = { "examine" }, on_release = {} } })
Config.UpdateRuntimeSettings({ allow_air_attack = false, debug_logging = true })
assert(Helpers.IsDebugEnabled(), "the saved debug setting should control diagnostic logging")
Config.DeleteSavedConfig()
assert(erased, "reset should erase the persisted configuration")
assert(Config.GetRuntimeTasks(false).LB_A.on_press[1] == "attack",
    "reset should clear the normal runtime task cache")
assert(Config.GetRuntimeTasks(false).LB_X.on_press[1] == "force_attack" and
       Config.GetRuntimeTasks(false).LB_RT.on_press[1] == "open_skill_wheel",
    "reset should restore the force-attack and skill-wheel presets")
assert(Config.GetRuntimeVirtualCursorTasks().LB_A.on_press[1] == nil,
    "reset should clear the virtual-cursor runtime task cache")
assert(Config.GetRuntimeSettings().allow_air_attack == true,
    "reset should clear runtime settings")
assert(not Helpers.IsDebugEnabled(), "reset should disable diagnostic logging")
