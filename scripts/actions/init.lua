-- Enhanced Controller - Actions Module Entry Point
-- Aggregates all action modules into a single ACTIONS table

-- Load all action modules
local Combat = require("actions/combat")
local Inspection = require("actions/inspection")
local Equipment = require("actions/equipment")
local Items = require("actions/items")
local Crafting = require("actions/crafting")
local Character = require("actions/character")
local Utility = require("actions/utility")

-- Create the aggregated ACTIONS table
local ACTIONS = {}

-- ============================================================================
-- Combat Actions
-- ============================================================================
ACTIONS.attack = Combat.attack
ACTIONS.force_attack = Combat.force_attack

-- ============================================================================
-- Inspection Actions
-- ============================================================================
ACTIONS.examine = Inspection.examine
ACTIONS.inspect_self = Inspection.inspect_self

-- ============================================================================
-- Equipment Actions
-- ============================================================================
ACTIONS.equip_item = Equipment.equip_item
ACTIONS.cycle_hand = Equipment.cycle_hand
ACTIONS.cycle_hand_prev = Equipment.cycle_hand_prev
ACTIONS.cycle_head = Equipment.cycle_head
ACTIONS.cycle_head_prev = Equipment.cycle_head_prev
ACTIONS.cycle_body = Equipment.cycle_body
ACTIONS.cycle_body_prev = Equipment.cycle_body_prev
ACTIONS.swap_hand_last = Equipment.swap_hand_last
ACTIONS.swap_head_last = Equipment.swap_head_last
ACTIONS.swap_body_last = Equipment.swap_body_last
ACTIONS.save_hand_item = Equipment.save_hand_item
ACTIONS.restore_hand_item = Equipment.restore_hand_item
ACTIONS.save_head_item = Equipment.save_head_item
ACTIONS.restore_head_item = Equipment.restore_head_item
ACTIONS.save_body_item = Equipment.save_body_item
ACTIONS.restore_body_item = Equipment.restore_body_item

-- ============================================================================
-- Item Usage Actions
-- ============================================================================
ACTIONS.use_item = Items.use_item
ACTIONS.use_item_on_self = Items.use_item_on_self

-- ============================================================================
-- Crafting Actions
-- ============================================================================
ACTIONS.craft_item = Crafting.craft_item

-- ============================================================================
-- Character-Specific Actions
-- ============================================================================
ACTIONS.willow_cast_spell = Character.willow_cast_spell
ACTIONS.start_channeling = Character.start_channeling
ACTIONS.stop_channeling = Character.stop_channeling

-- ============================================================================
-- Utility Actions
-- ============================================================================
ACTIONS.none = Utility.none

-- ============================================================================
-- Special Exports
-- ============================================================================
-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
ACTIONS.InitEquipmentTracking = Equipment.InitEquipmentTracking

return ACTIONS
