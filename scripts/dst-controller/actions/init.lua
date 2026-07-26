-- Enhanced Controller - Actions Module Entry Point
-- Aggregates all action modules into a single ACTIONS table

local Catalog = require("dst-controller/actions/catalog")
local Equipment = require("dst-controller/actions/equipment")

-- All executable actions are registered from the catalog, so the editor and
-- executor cannot silently drift apart as new actions are added.
local ACTIONS = Catalog.BuildRegistry()

-- ============================================================================
-- Special Exports
-- ============================================================================
-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
ACTIONS.InitEquipmentTracking = Equipment.InitEquipmentTracking

return ACTIONS
