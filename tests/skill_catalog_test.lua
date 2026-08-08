local SkillCatalog = require("dst-controller/skills/skill-catalog")

local function MakeBook(prefab, items)
    return {
        prefab = prefab,
        components = {
            spellbook = {
                items = items,
                CanBeUsedBy = function() return true end,
            },
        },
        IsValid = function() return true end,
    }
end

local fire = {
    label = "火焰爆发",
    normal = "fire_burst.tex",
    execute = function() end,
}
local shadow = {
    label = "暗影突袭",
    anims = { idle = { anim = "shadow_dash" } },
    execute = function() end,
}
local spacer = {
    label = "",
    normal = "empty.tex",
    execute = function() end,
    spacer = true,
}
local unavailable = MakeBook("unusable_book", {
    { label = "不可用", normal = "unavailable.tex", execute = function() end },
})
unavailable.components.spellbook.CanBeUsedBy = function() return false end

local book = MakeBook("willow_ember", { fire, spacer, shadow })
local duplicate_book = MakeBook("willow_ember", { fire, spacer, shadow })
local player = {
    prefab = "willow",
    replica = {
        inventory = {
            GetItems = function() return { book, duplicate_book, unavailable } end,
            GetEquips = function() return {} end,
            GetOverflowContainer = function() return nil end,
        },
    },
}

local spellbooks = SkillCatalog.CollectSpellBooks(player)
assert(#spellbooks == 2 and spellbooks[1] == book and spellbooks[2] == duplicate_book,
    "only usable owned spellbooks should be collected")

local entries = SkillCatalog.Build({
    player = player,
    spellbooks = spellbooks,
    names = { WILLOW_EMBER = "余烬" },
})
assert(#entries == 2,
    "wheel spacers and duplicate copies of the same spellbook should be excluded")

local fire_matches = SkillCatalog.Search(entries, "火焰")
assert(#fire_matches == 1 and fire_matches[1].skill_key ==
    "willow_ember:fire_burst.tex",
    "localized skill labels should be searchable")
assert(SkillCatalog.Search(entries, "shadow dash")[1].skill_key ==
    "willow_ember:shadow_dash",
    "stable visual identifiers should also be searchable")

local english_fire = {
    label = "Fire Burst",
    normal = "fire_burst.tex",
    execute = function() end,
}
assert(SkillCatalog.GetSkillKey(book, fire, 1, player) ==
       SkillCatalog.GetSkillKey(book, english_fire, 1, player),
    "saved skill identifiers should survive a language change")

local options = SkillCatalog.ToSpinnerOptions(fire_matches)
assert(options[1].data == "willow_ember:fire_burst.tex" and
       string.find(options[1].text, "火焰爆发", 1, true),
    "skill search results should map display labels to stable action parameters")

local all_entries = SkillCatalog.BuildAll({
    player = player,
    spellbooks = spellbooks,
    names = {
        WILLOW = "薇洛",
        WENDY = "温蒂",
        WAXWELL = "麦斯威尔",
        WINONA = "薇诺娜",
        WALTER = "沃尔特",
    },
    strings = {
        PYROMANCY = { FIRE_THROW = "投掷火焰" },
        GHOSTCOMMANDS = { ESCAPE = "灵体逃脱" },
        ACTIONS = {
            COMMUNEWITHSUMMONED = {
                MAKE_AGGRESSIVE = "激怒",
                MAKE_DEFENSIVE = "安抚",
            },
        },
    },
})
assert(#all_entries >= 40,
    "configuration search should include every vanilla character spellbook skill")
assert(SkillCatalog.Search(all_entries, "薇洛 投掷火焰")[1].skill_key ==
       "willow_ember:fire_throw",
    "global skill search should support localized character and skill names")
assert(SkillCatalog.Search(all_entries, "温蒂 灵体逃脱")[1].skill_key ==
       "abigail_flower:teleport",
    "skills belonging to a different character should remain selectable")
assert(SkillCatalog.Find(all_entries, "willow_ember:fire_burst.tex") ~= nil,
    "live or modded spellbook entries should be merged into the global catalog")

local character_options = SkillCatalog.GetCharacterOptions(all_entries)
assert(#character_options == 5,
    "the global vanilla catalog should expose one selector option per character")
assert(SkillCatalog.GetCharacterForSkill(
        all_entries, "waxwelljournal:shadow_worker.tex") == "waxwell",
    "an existing skill selection should resolve back to its character")
local wendy_entries = SkillCatalog.FilterByCharacter(all_entries, "wendy")
assert(#wendy_entries == 6 and
       SkillCatalog.Search(wendy_entries, "投掷火焰")[1] == nil,
    "character filtering should exclude every other character's skills")
local behavior_matches = SkillCatalog.Search(wendy_entries, "激怒 安抚")
assert(#behavior_matches == 1 and behavior_matches[1].skill_key ==
       "abigail_flower:toggle_behavior" and
       SkillCatalog.Find(wendy_entries, "abigail_flower:rile") == nil and
       SkillCatalog.Find(wendy_entries, "abigail_flower:soothe") == nil,
    "Wendy's behavior commands should be exposed as one searchable skill")
assert(SkillCatalog.GetCharacterForSkill(
        all_entries, "abigail_flower:rile") == "wendy",
    "hidden legacy Wendy skill keys should still resolve to their character")
