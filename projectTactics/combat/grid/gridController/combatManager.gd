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
		for tile in player_combat_controller.units_on_tiles.keys():
			if player_combat_controller.units_on_tiles[tile] == selected_unit:
				selected_tile = tile
				break

		if selected_tile:
			# Set the current tile to green
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
			player_combat_controller.currently_selected_tile = selected_tile
			
			# Highlight tiles within the unit's speed range
			highlight_tiles_around_unit(selected_unit, selected_unit.unitParts.speedRating)
	else:
		# If not in combat, allow the usual unit selection/placement
		player_combat_controller.unitPlacer()

# New function to handle clicks on empty tiles
func handle_empty_tile_click():
	if in_combat:
		# Deselect the currently selected unit
		DataPasser.passUnitInfo(null)
		player_combat_controller.unit_name_label.text = "Unit: None"
		
		# Revert the previously selected tile to red if it's occupied
		if player_combat_controller.currently_selected_tile:
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
			player_combat_controller.currently_selected_tile = null

func highlight_tiles_around_unit(selected_unit, range):
	# Get the current position of the selected unit
	var unit_tile = null
	for tile in player_combat_controller.units_on_tiles.keys():
		if player_combat_controller.units_on_tiles[tile] == selected_unit:
			unit_tile = tile
			break
	
	if unit_tile:
		var unit_position = unit_tile.global_transform.origin
		var tile_size = player_combat_controller.TILE_SIZE  # Access TILE_SIZE from HexGrid
		
		# Iterate through all tiles
		for tile_key in player_combat_controller.tiles.keys():
			var tile = player_combat_controller.tiles[tile_key]
			var distance = unit_position.distance_to(tile.global_transform.origin)
			
			if distance <= range * tile_size:
				tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow
