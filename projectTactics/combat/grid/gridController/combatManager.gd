extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false

@onready var player_combat_controller = $"../HexGrid"

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
]

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func _handle_unit_click(selected_unit):
	if in_combat:
		# Handle unit selection logic when in combat
		if player_combat_controller.currently_selected_tile:
			# Revert the previously selected tile to red if it's occupied
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		# Update the selection to the new unit
		print("Switching to selected unit:", selected_unit.unitParts.name)
		DataPasser.passUnitInfo(selected_unit.unitParts)
		player_combat_controller.unit_to_place = selected_unit.unitParts
		player_combat_controller.placing_unit = false
		player_combat_controller.unit_name_label.text = "Unit: " + selected_unit.unitParts.name

		# Find the tile that contains this unit
		var selected_tile = null
		for tile in player_combat_controller.units_on_tiles:
			if player_combat_controller.units_on_tiles[tile] == selected_unit:
				selected_tile = tile
				break

		if selected_tile:
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
			player_combat_controller.currently_selected_tile = selected_tile
	else:
		# If not in combat, allow the usual unit selection/placement
		player_combat_controller.unitPlacer()

