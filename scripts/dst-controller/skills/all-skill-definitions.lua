-- Search metadata for every vanilla character spellbook entry. These are
-- configuration-time records only; execution still resolves the selected key
-- against the current player's live spellbook so unavailable skills are safe.

return {
    -- Willow
    { key = "willow_ember:fire_throw", character = "willow", label = { "PYROMANCY", "FIRE_THROW" } },
    { key = "willow_ember:fire_burst", character = "willow", label = { "PYROMANCY", "FIRE_BURST" } },
    { key = "willow_ember:fire_ball", character = "willow", label = { "PYROMANCY", "FIRE_BALL" } },
    { key = "willow_ember:fire_frenzy", character = "willow", label = { "PYROMANCY", "FIRE_FRENZY" } },
    { key = "willow_ember:lunar_fire", character = "willow", label = { "PYROMANCY", "LUNAR_FIRE" } },
    { key = "willow_ember:shadow_fire", character = "willow", label = { "PYROMANCY", "SHADOW_FIRE" } },

    -- Winona
    { key = "winona_remote:icon_target", character = "winona", label = { "ENGINEER_REMOTE", "VOLLEY" } },
    { key = "winona_remote:icon_boost", character = "winona", label = { "ENGINEER_REMOTE", "BOOST" } },
    { key = "winona_remote:icon_wake", character = "winona", label = { "ENGINEER_REMOTE", "WAKEUP" } },
    { key = "winona_remote:slot_4", character = "winona", label = { "ENGINEER_REMOTE", "ELEMENTAL_VOLLEY" } },

    -- Maxwell
    { key = "waxwelljournal:shadow_worker.tex", character = "waxwell", label = { "SPELLS", "SHADOW_WORKER" } },
    { key = "waxwelljournal:shadow_protector.tex", character = "waxwell", label = { "SPELLS", "SHADOW_PROTECTOR" } },
    { key = "waxwelljournal:shadow_trap.tex", character = "waxwell", label = { "SPELLS", "SHADOW_TRAP" } },
    { key = "waxwelljournal:shadow_pillars.tex", character = "waxwell", label = { "SPELLS", "SHADOW_PILLARS" } },

    -- Wendy
    { key = "abigail_flower:unsummon", character = "wendy", label = { "GHOSTCOMMANDS", "UNSUMMON" } },
    { key = "abigail_flower:rile", character = "wendy", label = { "ACTIONS", "COMMUNEWITHSUMMONED", "MAKE_AGGRESSIVE" } },
    { key = "abigail_flower:soothe", character = "wendy", label = { "ACTIONS", "COMMUNEWITHSUMMONED", "MAKE_DEFENSIVE" } },
    { key = "abigail_flower:teleport", character = "wendy", label = { "GHOSTCOMMANDS", "ESCAPE" } },
    { key = "abigail_flower:attack_at", character = "wendy", label = { "GHOSTCOMMANDS", "ATTACK_AT" } },
    { key = "abigail_flower:scare", character = "wendy", label = { "GHOSTCOMMANDS", "SCARE" } },
    { key = "abigail_flower:haunt", character = "wendy", label = { "GHOSTCOMMANDS", "HAUNT_AT" } },

    -- Walter while mounted
    { key = "walter:dismount", character = "walter", label = { "ACTIONS", "DISMOUNT" } },
    { key = "walter:opencontainer", character = "walter", label = { "ACTIONS", "RUMMAGE", "GENERIC" } },
    { key = "walter:forcetransform", character = "walter", label = { "WOBY_COMMANDS", "SHRINK" } },
    { key = "walter:walter_woby_sprint", character = "walter", label = { "WOBY_COMMANDS", "SPRINTING" } },
    { key = "walter:walter_woby_shadow", character = "walter", label = { "WOBY_COMMANDS", "SHADOWDASH" } },

    -- Walter's linked Woby. Both forms are listed because their runtime
    -- spellbook keys differ even when the visible command is the same.
    { key = "wobybig:mount", character = "walter", label = { "ACTIONS", "MOUNT" } },
    { key = "wobybig:forcetransform", character = "walter", label = { "WOBY_COMMANDS", "SHRINK" } },
    { key = "wobybig:sit", character = "walter", label = { "WOBY_COMMANDS", "SIT" } },
    { key = "wobybig:walter_woby_itemfetcher", character = "walter", label = { "WOBY_COMMANDS", "PICKUP" } },
    { key = "wobybig:walter_woby_foraging", character = "walter", label = { "WOBY_COMMANDS", "FORAGING" } },
    { key = "wobybig:walter_woby_taskaid", character = "walter", label = { "WOBY_COMMANDS", "WORKING" } },
    { key = "wobybig:walter_camp_wobycourier", character = "walter", label = { "WOBY_COMMANDS", "COURIER" } },
    { key = "wobybig:walter_camp_wobycourier#2", character = "walter", label = { "WOBY_COMMANDS", "REMEMBERCHEST" } },

    { key = "wobysmall:pet", character = "walter", label = { "ACTIONS", "PET" } },
    { key = "wobysmall:sit_small", character = "walter", label = { "WOBY_COMMANDS", "SIT" } },
    { key = "wobysmall:walter_woby_itemfetcher", character = "walter", label = { "WOBY_COMMANDS", "PICKUP" } },
    { key = "wobysmall:walter_woby_foraging", character = "walter", label = { "WOBY_COMMANDS", "FORAGING" } },
    { key = "wobysmall:walter_woby_taskaid", character = "walter", label = { "WOBY_COMMANDS", "WORKING" } },
    { key = "wobysmall:walter_camp_wobycourier", character = "walter", label = { "WOBY_COMMANDS", "COURIER" } },
    { key = "wobysmall:walter_camp_wobycourier#2", character = "walter", label = { "WOBY_COMMANDS", "REMEMBERCHEST" } },
}
