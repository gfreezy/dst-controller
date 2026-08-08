-- Actions backed by DST's native spellbook wheel and player skill tree UI.

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ButtonHandler = require("dst-controller/executor/button-handler")
local SkillCatalog = require("dst-controller/skills/skill-catalog")

local SkillActions = {}

local function BuildCatalog(player)
    return SkillCatalog.Build({
        player = player,
        names = (G.STRINGS and G.STRINGS.NAMES) or {},
    })
end

local function ClearComboStateAfterOpeningScreen(player)
    if player and player.DoTaskInTime ~= nil then
        player:DoTaskInTime(0, function()
            ButtonHandler.ClearPressedStates(player)
        end)
    end
end

function SkillActions.open_skill_wheel(player)
    local hud = player and player.HUD or nil
    if hud == nil then
        return false
    end

    local spellbooks = SkillCatalog.CollectSpellBooks(player)
    local book = spellbooks[1]
    local spellbook = book and book.components and book.components.spellbook or nil
    if spellbook == nil or spellbook.OpenSpellBook == nil then
        Helpers.DebugPrint("No usable skill wheel is available")
        return false
    end
    if spellbook.ShouldOpen ~= nil and not spellbook:ShouldOpen(player) then
        Helpers.DebugPrint("The current skill wheel is temporarily unavailable")
        return false
    end
    if hud.GetCurrentOpenSpellBook ~= nil and
        hud:GetCurrentOpenSpellBook() == book and
        hud.IsSpellWheelOpen ~= nil and hud:IsSpellWheelOpen() then
        return true
    end

    spellbook:OpenSpellBook(player)
    Helpers.DebugPrintf("Action: Open Skill Wheel (%s)", tostring(book.prefab))
    return true
end

function SkillActions.cast_skill(player, skill_key)
    if type(skill_key) ~= "string" or skill_key == "" then
        Helpers.DebugPrint("cast_skill requires a skill")
        return false
    end

    local skill = SkillCatalog.Find(BuildCatalog(player), skill_key)
    if skill == nil then
        Helpers.DebugPrintf("Skill '%s' is not currently available", skill_key)
        return false
    end

    local item = skill.item
    if item.checkenabled ~= nil and not item.checkenabled(player) then
        Helpers.DebugPrintf("Skill '%s' is currently disabled", skill_key)
        return false
    end
    if item.checkcooldown ~= nil and item.checkcooldown(player) then
        Helpers.DebugPrintf("Skill '%s' is on cooldown", skill_key)
        return false
    end
    if not skill.spellbook:SelectSpell(skill.index) then
        Helpers.DebugPrintf("Skill '%s' could not be selected", skill_key)
        return false
    end

    local hud = player and player.HUD or nil
    local was_open = hud ~= nil and hud.GetCurrentOpenSpellBook ~= nil and
        hud:GetCurrentOpenSpellBook() == skill.book
    item.execute(skill.book)
    if was_open and skill.spellbook.closeonexecute ~= false and
        hud.CloseSpellWheel ~= nil then
        hud:CloseSpellWheel(true)
    end
    Helpers.DebugPrintf("Action: Cast Skill (%s)", skill_key)
    return true
end

function SkillActions.open_skill_panel(player)
    local hud = player and player.HUD or nil
    if hud == nil then
        return false
    end

    local screen = hud.playerinfoscreen
    if screen ~= nil and screen.inst ~= nil and screen.inst:IsValid() then
        if screen.skilltree == nil and screen.root ~= nil and
            screen.root.tabs ~= nil and screen.MakeSkillTree ~= nil then
            screen:MakeSkillTree()
        elseif screen.skilltree == nil then
            Helpers.DebugPrint("The current character has no skill panel")
            return false
        end
    elseif hud.OpenPlayerInfoScreen ~= nil then
        hud:OpenPlayerInfoScreen()
    else
        Helpers.DebugPrint("Skill panel is not available")
        return false
    end

    ClearComboStateAfterOpeningScreen(player)
    Helpers.DebugPrint("Action: Open Skill Panel")
    return true
end

return SkillActions
