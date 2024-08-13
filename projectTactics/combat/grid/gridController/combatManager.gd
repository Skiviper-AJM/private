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

var highlighted_tiles := []

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func _handle_unit_click(selected_unit):
	if in_combat:
		if player_combat_controller.currently_selected_tile:
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		clear_highlighted_tiles()

		# Debug: What is selected_unit?
		print("Selected unit type:", typeof(selected_unit), ", name:", selected_unit.name)

		# Pass the correct instance
		DataPasser.passUnitInfo(selected_unit)
		player_combat_controller.unit_to_place = selected_unit.unitParts
		player_combat_controller.placing_unit = false
		player_combat_controller.unit_name_label.text = "Unit: " + selected_unit.unitParts.name

		var selected_tile = null
		for tile in player_combat_controller.units_on_tiles.keys():
			if player_combat_controller.units_on_tiles[tile] == selected_unit:
				selected_tile = tile
				break

		if selected_tile:
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
			player_combat_controller.currently_selected_tile = selected_tile

			highlight_tiles_around_unit(selected_unit, selected_unit.unitParts.speedRating)
	else:
		player_combat_controller.unitPlacer()

func highlight_tiles_around_unit(selected_unit, range):
	var unit_tile = null
	for tile in player_combat_controller.units_on_tiles.keys():
		if player_combat_controller.units_on_tiles[tile] == selected_unit:
			unit_tile = tile
			break
	
	if unit_tile:
		var unit_position = unit_tile.global_transform.origin
		var tile_size = player_combat_controller.TILE_SIZE
		
		# Highlight tiles within range
		for tile_key in player_combat_controller.tiles.keys():
			var tile = player_combat_controller.tiles[tile_key]
			var distance = tile.global_transform.origin.distance_to(unit_position)
			if distance <= range * tile_size:
				tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow
				highlighted_tiles.append(tile)
	else:
		print("No unit tile found to highlight.")

func clear_highlighted_tiles():
	for tile in highlighted_tiles:
		tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
	highlighted_tiles.clear()
	
func handle_tile_click(tile):
	if in_combat:
		if tile in highlighted_tiles and player_combat_controller.units_on_tiles.has(player_combat_controller.currently_selected_tile):
			# Get the unit on the currently selected tile
			var selected_unit = player_combat_controller.units_on_tiles[player_combat_controller.currently_selected_tile]

			if selected_unit:
				# Move the selected unit to the new tile
				_move_unit_to_tile(selected_unit, tile)
			else:
				print("No unit found on the currently selected tile to move.")
		elif player_combat_controller.units_on_tiles.has(tile):
			# Select the unit on the clicked tile
			var unit_on_tile = player_combat_controller.units_on_tiles[tile]
			_handle_unit_click(unit_on_tile)
			# Set the selected unit through DataPasser
			DataPasser.passUnitInfo(unit_on_tile.unitParts)
		else:
			print("Clicked tile is not highlighted for movement.")
	else:
		# Handle as necessary when not in combat
		player_combat_controller.unitPlacer()

func _move_unit_to_tile(selected_unit, target_tile):
	# Ensure that selected_unit is a Node3D instance
	if not selected_unit is Node3D:
		print("Error: selected_unit is not a Node3D instance. Cannot move it.")
		return
	
	# Directly move the specific instance on the map
	print("Moving unit instance:", selected_unit, "to new tile:", target_tile)

	# Set the new unit's position to the target tile
	selected_unit.position = target_tile.global_transform.origin

	# Update the units_on_tiles dictionary to reflect the new tile
	var old_tile = player_combat_controller.currently_selected_tile
	if old_tile:
		player_combat_controller.units_on_tiles.erase(old_tile)
	player_combat_controller.units_on_tiles[target_tile] = selected_unit

	# Update the tile colors
	if old_tile:
		old_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set old tile back to blue
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set new tile to red

	# Update the selected tile reference
	player_combat_controller.currently_selected_tile = target_tile

	# Clear the highlighted tiles
	clear_highlighted_tiles()

	# Deselect the unit after moving
	DataPasser.passUnitInfo(null)
	player_combat_controller.unit_to_place = null
	player_combat_controller.placing_unit = false
	player_combat_controller.unit_name_label.text = ""
	print("Unit moved to new tile successfully.")


func handle_empty_tile_click():
	# Clear the current selection and reset the label
	DataPasser.passUnitInfo(null)
	player_combat_controller.unit_to_place = null
	player_combat_controller.placing_unit = false
	player_combat_controller.unit_name_label.text = ""
	
	# Clear the currently selected tile reference and reset its color
	if player_combat_controller.currently_selected_tile:
		player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set to blue
		player_combat_controller.currently_selected_tile = null

	# Clear all highlighted tiles (yellow tiles)
	clear_highlighted_tiles()
