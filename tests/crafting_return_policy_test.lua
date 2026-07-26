package.loaded["dst-controller/crafting/policy"] = nil

local Policy = require("dst-controller/crafting/policy")

assert(Policy.ShouldReturnExternalRemainder({}, "log"),
    "an externally acquired prefab absent at task start should be returned")
assert(Policy.ShouldReturnExternalRemainder({ log = 0 }, "log"),
    "a zero initial count should be treated as absent")
assert(not Policy.ShouldReturnExternalRemainder({ log = 1 }, "log"),
    "an externally acquired prefab already owned at task start must not be returned")
