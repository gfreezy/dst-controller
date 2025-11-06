-- Enhanced Controller - Actions Module Entry Point
-- Aggregates all action modules into a single ACTIONS table

-- Load all action modules
local Inspection = require("dst-controller/actions/inspection")
local Equipment = require("dst-controller/actions/equipment")
local Items = require("dst-controller/actions/items")
local Crafting = require("dst-controller/actions/crafting")
local Character = require("dst-controller/actions/character")
local Keyboard = require("dst-controller/actions/keyboard")

-- Create the aggregated ACTIONS table
local ACTIONS = {}

-- ============================================================================
-- Inspection Actions
-- ============================================================================
ACTIONS.examine = Inspection.examine
ACTIONS.inspect_self = Inspection.inspect_self

-- ============================================================================
-- Equipment Actions
-- ============================================================================
ACTIONS.equip_item = Equipment.equip_item
ACTIONS.unequip_item = Equipment.unequip_item
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
ACTIONS.use_item_on_self = Items.use_item_on_self
ACTIONS.use_item_on_scene = Items.use_item_on_scene
ACTIONS.use_active_item_on_self = Items.use_active_item_on_self
ACTIONS.use_active_item_on_scene = Items.use_active_item_on_scene

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
-- Keyboard Actions
-- ============================================================================
ACTIONS.trigger_key = Keyboard.trigger_key

-- ============================================================================
-- Special Exports
-- ============================================================================
-- Export the InitEquipmentTracking function so modmain.lua can call it during player initialization
ACTIONS.InitEquipmentTracking = Equipment.InitEquipmentTracking

return ACTIONS
