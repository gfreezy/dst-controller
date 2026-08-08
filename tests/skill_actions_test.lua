local debug_calls = {}
local cleared_player = nil

package.loaded["dst-controller/global"] = {
    STRINGS = { NAMES = { WILLOW_EMBER = "余烬" } },
}
package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function(message) debug_calls[#debug_calls + 1] = message end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/executor/button-handler"] = {
    ClearPressedStates = function(player) cleared_player = player end,
}
package.loaded["dst-controller/actions/skills"] = nil

local selected = nil
local executed_with = nil
local opened_with = nil
local closed_execute = nil
local current_book = nil

local skill = {
    label = "火焰爆发",
    normal = "fire_burst.tex",
    execute = function(book) executed_with = book end,
}
local spellbook = {
    items = { skill },
    closeonexecute = true,
    CanBeUsedBy = function() return true end,
    ShouldOpen = function() return true end,
    OpenSpellBook = function(_, player) opened_with = player end,
    SelectSpell = function(_, index)
        selected = index
        return index == 1
    end,
}
local book = {
    prefab = "willow_ember",
    components = { spellbook = spellbook },
    IsValid = function() return true end,
}
local hud = {
    GetCurrentOpenSpellBook = function() return current_book end,
    IsSpellWheelOpen = function() return current_book ~= nil end,
    CloseSpellWheel = function(_, execute) closed_execute = execute end,
}
local player = {
    prefab = "willow",
    HUD = hud,
    replica = {
        inventory = {
            GetItems = function() return { book } end,
            GetEquips = function() return {} end,
            GetOverflowContainer = function() return nil end,
        },
    },
    DoTaskInTime = function(_, _, callback) callback() end,
}

local SkillActions = require("dst-controller/actions/skills")
assert(SkillActions.open_skill_wheel(player) and opened_with == player,
    "open_skill_wheel should use the native spellbook opener")

assert(SkillActions.cast_skill(player, "willow_ember:fire_burst.tex"),
    "an available configured skill should execute")
assert(selected == 1 and executed_with == book,
    "cast_skill should select the spell before invoking its native callback")

current_book = book
assert(SkillActions.cast_skill(player, "willow_ember:fire_burst.tex") and
       closed_execute == true,
    "casting from an open close-on-execute wheel should close it as an execution")

skill.checkenabled = function() return false end
assert(not SkillActions.cast_skill(player, "willow_ember:fire_burst.tex"),
    "disabled skills should not execute")
skill.checkenabled = nil
skill.checkcooldown = function() return 0.5 end
assert(not SkillActions.cast_skill(player, "willow_ember:fire_burst.tex"),
    "skills on cooldown should not execute")
skill.checkcooldown = nil

local panel_opened = false
hud.OpenPlayerInfoScreen = function() panel_opened = true end
assert(SkillActions.open_skill_panel(player) and panel_opened,
    "open_skill_panel should open DST's player skill screen")
assert(cleared_player == player,
    "opening a modal skill panel should clear captured combo state")
