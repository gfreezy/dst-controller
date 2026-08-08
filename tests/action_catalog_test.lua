local Catalog = require("dst-controller/actions/catalog")

local seen = {}
local exposed = {}
for _, definition in ipairs(Catalog.GetDefinitions()) do
    assert(type(definition.id) == "string" and definition.id ~= "", "action ids must be non-empty")
    assert(not seen[definition.id], "action ids must be unique")
    seen[definition.id] = true
    if definition.exposed then
        assert(type(definition.label) == "string", "exposed actions need localization keys")
        exposed[definition.id] = true
    end
end

local options = Catalog.BuildOptions(function(key) return key end)
assert(options[1].data == "", "the no-action option must remain first")
for index = 2, #options do
    local option = options[index]
    assert(exposed[option.data], "only exposed catalog actions may appear in the editor")
    assert(option.has_param == Catalog.NeedsParameter(option.data),
        "editor parameter metadata must come from the catalog")
end

assert(Catalog.NeedsParameter("craft_item"), "craft_item requires a recipe")
assert(Catalog.NeedsParameter("cast_skill"), "cast_skill requires a selected skill")
assert(Catalog.NeedsParameter("delay"), "delay requires a duration")
assert(not Catalog.NeedsParameter("attack"), "attack does not require a parameter")
assert(Catalog.Get("unknown") == nil, "unknown actions must not have metadata")

local registry = Catalog.BuildRegistry()
for _, definition in ipairs(Catalog.GetDefinitions()) do
    if not definition.special then
        assert(type(registry[definition.id]) == "function",
            "every non-special catalog action must have an implementation")
    end
end
