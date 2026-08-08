-- Searchable catalog of the skills exposed by DST spellbook wheels.

local SearchCatalog = require("dst-controller/crafting/recipe-catalog")
local AllSkillDefinitions = require("dst-controller/skills/all-skill-definitions")

local SkillCatalog = {}

local function AddUniqueEntity(entities, seen, entity)
    if entity == nil or seen[entity] then
        return
    end
    seen[entity] = true
    table.insert(entities, entity)
end

local function AddItems(entities, seen, items)
    for _, item in pairs(items or {}) do
        AddUniqueEntity(entities, seen, item)
    end
end

local function AddInventorySpellBooks(entities, seen, player)
    local inventory = player and player.replica and player.replica.inventory or nil
    if inventory == nil then
        return
    end

    AddItems(entities, seen, inventory.GetItems and inventory:GetItems() or nil)
    AddItems(entities, seen, inventory.GetEquips and inventory:GetEquips() or nil)

    local overflow = inventory.GetOverflowContainer and
        inventory:GetOverflowContainer() or nil
    if overflow ~= nil then
        local items = overflow.GetItems and overflow:GetItems() or nil
        if (items == nil or next(items) == nil) and
            overflow.classified ~= nil and overflow.classified.GetItems ~= nil then
            items = overflow.classified:GetItems()
        end
        AddItems(entities, seen, items)
    end
end

local function IsUsableSpellBook(entity, player)
    if entity == nil or entity.components == nil then
        return false
    end
    if entity.IsValid ~= nil and not entity:IsValid() then
        return false
    end

    local spellbook = entity.components.spellbook
    if spellbook == nil or type(spellbook.items) ~= "table" or #spellbook.items == 0 then
        return false
    end
    if spellbook.CanBeUsedBy ~= nil then
        local ok, usable = pcall(spellbook.CanBeUsedBy, spellbook, player)
        if not ok or not usable then
            return false
        end
    end
    return true
end

---Collect currently reachable spellbook entities in deterministic priority order.
---The player-owned wheel is preferred, followed by inventory spellbooks, the
---current mount, and Walter's linked Woby.
---@param player table
---@return table
function SkillCatalog.CollectSpellBooks(player)
    local candidates = {}
    local seen = {}

    AddUniqueEntity(candidates, seen, player)
    AddInventorySpellBooks(candidates, seen, player)

    local rider = player and player.replica and player.replica.rider or nil
    AddUniqueEntity(candidates, seen,
        rider and rider.GetMount and rider:GetMount() or nil)

    local woby_classified = player and player.woby_commands_classified or nil
    AddUniqueEntity(candidates, seen,
        woby_classified and woby_classified.GetWoby and
            woby_classified:GetWoby() or nil)

    local hud = player and player.HUD or nil
    AddUniqueEntity(candidates, seen,
        hud and hud.GetCurrentOpenSpellBook and
            hud:GetCurrentOpenSpellBook() or nil)

    local spellbooks = {}
    for _, entity in ipairs(candidates) do
        if IsUsableSpellBook(entity, player) then
            table.insert(spellbooks, entity)
        end
    end
    return spellbooks
end

local function GetIdleAnim(item)
    local idle = item and item.anims and item.anims.idle or nil
    if type(idle) == "table" then
        return idle.anim
    end
    return type(idle) == "string" and idle or nil
end

local function SanitizeKeyPart(value)
    return tostring(value or "")
        :gsub("[%c%s]+", "_")
        :gsub(":", "_")
        :gsub("^_+", "")
        :gsub("_+$", "")
end

local function FirstString(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
end

local function GetSourceName(book, player)
    return (book and book.prefab) or (book == player and player and player.prefab) or
        "player"
end

---Return a stable, human-readable identifier for a wheel entry. Visual asset
---names are used before the localized label so saved shortcuts survive a
---language change.
function SkillCatalog.GetSkillKey(book, item, index, player)
    local source = SanitizeKeyPart(GetSourceName(book, player))
    local identity = item and FirstString(
        item.skill, item.id, item.name, item.spell, item.normal,
        GetIdleAnim(item)) or nil
    identity = SanitizeKeyPart(identity)
    if identity == "" then
        identity = "slot_" .. tostring(index)
    end
    return source .. ":" .. identity
end

local function GetDisplayLabel(book, item, player, names, multiple_books)
    local source = GetSourceName(book, player)
    local label = item.label
    if type(label) ~= "string" or label == "" then
        label = FirstString(item.skill, item.name, item.normal, GetIdleAnim(item)) or source
    end
    if multiple_books then
        local source_label = names[string.upper(source)] or source
        return string.format("%s (%s)", label, source_label)
    end
    return tostring(label)
end

---Build the searchable list of executable skills available to the player.
---@param options table|nil { player, spellbooks, names }
---@return table
function SkillCatalog.Build(options)
    options = options or {}
    local player = options.player
    local spellbooks = options.spellbooks or SkillCatalog.CollectSpellBooks(player)
    local names = options.names or {}
    local raw_entries = {}
    local localized_names = {}
    local runtime_entries = {}
    local key_counts = {}

    for _, book in ipairs(spellbooks) do
        local spellbook = book.components and book.components.spellbook or nil
        for index, item in ipairs(spellbook and spellbook.items or {}) do
            if type(item) == "table" and type(item.execute) == "function" and
                not item.spacer and not item.noselect then
                local base_key = SkillCatalog.GetSkillKey(book, item, index, player)
                local skill_key = base_key
                local existing = runtime_entries[base_key]
                if existing ~= nil and existing.book == book then
                    key_counts[base_key] = (key_counts[base_key] or 1) + 1
                    skill_key = base_key .. "#" .. tostring(key_counts[base_key])
                end

                -- When two identical spellbook items are carried, the first
                -- copy wins because either copy performs the configured skill.
                if raw_entries[skill_key] == nil then
                    raw_entries[skill_key] = {
                        name = skill_key,
                        product = skill_key,
                    }
                    localized_names[string.upper(skill_key)] =
                        GetDisplayLabel(book, item, player, names, #spellbooks > 1)
                    runtime_entries[skill_key] = {
                        skill_key = skill_key,
                        book = book,
                        spellbook = spellbook,
                        item = item,
                        index = index,
                    }
                end
            end
        end
    end

    local entries = SearchCatalog.Build(raw_entries, localized_names, {})
    for _, entry in ipairs(entries) do
        local runtime = runtime_entries[entry.recipe_name]
        entry.skill_key = entry.recipe_name
        entry.book = runtime.book
        entry.spellbook = runtime.spellbook
        entry.item = runtime.item
        entry.index = runtime.index
        -- RecipeCatalog normally appends the internal identifier. Skill keys
        -- are intentionally hidden here; the visible source name is enough.
        entry.display_text = entry.localized_name
    end
    return entries
end

local function ResolveStringPath(strings, path)
    local value = strings
    for _, key in ipairs(path or {}) do
        value = type(value) == "table" and value[key] or nil
        if value == nil then
            return nil
        end
    end
    return type(value) == "string" and value ~= "" and value or nil
end

local function GetDefinitionFallbackLabel(definition)
    local identity = definition.key:match(":(.+)$") or definition.key
    return identity:gsub("#%d+$", ""):gsub("%.tex$", ""):gsub("_", " ")
end

local function GetDefinitionLabel(definition, strings)
    if definition.labels ~= nil then
        local labels = {}
        for _, path in ipairs(definition.labels) do
            local label = ResolveStringPath(strings, path)
            if label ~= nil then
                table.insert(labels, label)
            end
        end
        if #labels > 0 then
            return table.concat(labels, " / ")
        end
    end
    return ResolveStringPath(strings, definition.label) or
        GetDefinitionFallbackLabel(definition)
end

---Build the configuration-time catalog for every vanilla character skill,
---then merge live entries so modded spellbooks remain searchable as well.
---@param options table|nil { player, spellbooks, names, strings }
---@return table
function SkillCatalog.BuildAll(options)
    options = options or {}
    local names = options.names or {}
    local strings = options.strings or {}
    local raw_entries = {}
    local localized_names = {}
    local runtime_by_key = {}
    local metadata_by_key = {}

    for _, definition in ipairs(AllSkillDefinitions) do
        local skill_key = definition.key
        local label = GetDefinitionLabel(definition, strings)
        local character = names[string.upper(definition.character)] or
            definition.character
        metadata_by_key[skill_key] = {
            character = definition.character,
            character_label = character,
            hidden = definition.hidden == true,
        }
        if not definition.hidden then
            raw_entries[skill_key] = { name = skill_key, product = skill_key }
            localized_names[string.upper(skill_key)] =
                string.format("%s (%s)", label, character)
        end
    end

    for _, entry in ipairs(SkillCatalog.Build(options)) do
        local skill_key = entry.skill_key
        local metadata = metadata_by_key[skill_key]
        if metadata == nil or not metadata.hidden then
            runtime_by_key[skill_key] = entry
        end
        if metadata == nil then
            local character = options.player and options.player.prefab or
                (entry.book and entry.book.prefab) or "other"
            raw_entries[skill_key] = { name = skill_key, product = skill_key }
            localized_names[string.upper(skill_key)] = entry.display_text
            metadata_by_key[skill_key] = {
                character = character,
                character_label = names[string.upper(character)] or character,
            }
        end
    end

    local entries = SearchCatalog.Build(raw_entries, localized_names, {})
    for _, entry in ipairs(entries) do
        local runtime = runtime_by_key[entry.recipe_name]
        local metadata = metadata_by_key[entry.recipe_name] or {}
        entry.skill_key = entry.recipe_name
        entry.display_text = entry.localized_name
        entry.character = metadata.character
        entry.character_label = metadata.character_label
        if runtime ~= nil then
            entry.book = runtime.book
            entry.spellbook = runtime.spellbook
            entry.item = runtime.item
            entry.index = runtime.index
        end
    end
    return entries
end

function SkillCatalog.GetAllDefinitions()
    return AllSkillDefinitions
end

local function GetDefinition(skill_key)
    for _, definition in ipairs(AllSkillDefinitions) do
        if definition.key == skill_key then
            return definition
        end
    end
end

---Return runtime wheel keys in state-aware priority order. Ordinary skills
---resolve to themselves; virtual skills may resolve to one of several native
---wheel entries.
function SkillCatalog.GetRuntimeSkillKeys(skill_key, player)
    local definition = GetDefinition(skill_key)
    if definition == nil or definition.runtime_keys == nil then
        return { skill_key }
    end

    local keys = {}
    local seen = {}
    local function AddKey(key)
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end

    local tagged = definition.state_tag ~= nil and player ~= nil and
        player.HasTag ~= nil and player:HasTag(definition.state_tag)
    AddKey(tagged and definition.tagged_key or definition.untagged_key)
    for _, key in ipairs(definition.runtime_keys) do
        AddKey(key)
    end
    return keys
end

function SkillCatalog.GetCharacterOptions(entries)
    local by_character = {}
    for _, entry in ipairs(entries or {}) do
        if entry.character ~= nil and by_character[entry.character] == nil then
            by_character[entry.character] = entry.character_label or entry.character
        end
    end

    local options = {}
    for character, label in pairs(by_character) do
        table.insert(options, { data = character, text = label })
    end
    table.sort(options, function(a, b)
        if a.text == b.text then
            return a.data < b.data
        end
        return a.text < b.text
    end)
    return options
end

function SkillCatalog.FilterByCharacter(entries, character)
    local filtered = {}
    for _, entry in ipairs(entries or {}) do
        if entry.character == character then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

function SkillCatalog.GetCharacterForSkill(entries, skill_key)
    local entry = SkillCatalog.Find(entries, skill_key)
    if entry ~= nil then
        return entry.character
    end
    local definition = GetDefinition(skill_key)
    return definition and definition.character or nil
end

function SkillCatalog.Search(entries, query, limit)
    return SearchCatalog.Search(entries, query, limit)
end

function SkillCatalog.Find(entries, skill_key)
    return SearchCatalog.Find(entries, skill_key)
end

function SkillCatalog.ToSpinnerOptions(entries)
    return SearchCatalog.ToSpinnerOptions(entries)
end

return SkillCatalog
