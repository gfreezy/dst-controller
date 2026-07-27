local CookingActions = require("dst-controller/actions/cooking")
local hud_opens = 0
local deferred
CookingActions.toggle_cooking_menu({
    GUID = 55,
    DoTaskInTime = function(_, _, fn) deferred = fn end,
    HUD = {
        OpenCookbookScreen = function()
            hud_opens = hud_opens + 1
        end,
    },
})
assert(hud_opens == 1,
    "the configurable action should open the native cookbook")
assert(type(deferred) == "function",
    "opening a modal cookbook should schedule combo-state cleanup")
deferred()
