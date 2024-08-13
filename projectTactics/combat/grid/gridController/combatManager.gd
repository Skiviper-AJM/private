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
var selected_unit_instance = null  # Store the instance of the selected unit

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func _handle_unit_click(unit_instance):
	if in_combat:
		if selected_unit_instance:
			# Reset the previously selected tile color to red
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]

		clear_highlighted_tiles()

		# Debugging
		print("Switching to selected unit instance:", unit_instance)

		# Ensure the unit_instance is a Node3D and not a resource reference
		if not unit_instance is Node3D:
			print("Error: The selected unit is not a Node3D instance.")
			return

		# Set the instance as selected
		selected_unit_instance = unit_instance

		# Debugging to confirm the selection
		print("Selected unit instance:", selected_unit_instance)

		var selected_tile = null
		for tile in player_combat_controller.units_on_tiles.keys():
			if player_combat_controller.units_on_tiles[tile] == unit_instance:
				selected_tile = tile
				break

		if selected_tile:
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
			player_combat_controller.currently_selected_tile = selected_tile

			highlight_tiles_around_unit(selected_unit_instance, selected_unit_instance.unitParts.speedRating)
		else:
			print("Selected unit instance not found on any tile.")

func highlight_tiles_around_unit(selected_unit_instance, range):
	var unit_tile = null
	for tile in player_combat_controller.units_on_tiles.keys():
		if player_combat_controller.units_on_tiles[tile] == selected_unit_instance:
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
		print("Combat Mode Active - Clicked Tile:", tile)
		if tile in highlighted_tiles and selected_unit_instance:
			print("Moving unit to tile:", tile)
			_move_unit_to_tile(selected_unit_instance, tile)
		elif player_combat_controller.units_on_tiles.has(tile):
			# Select the unit instance on the clicked tile
			var unit_instance = player_combat_controller.units_on_tiles[tile]
			print("Tile has unit, selecting:", unit_instance)
			_handle_unit_click(unit_instance)
		else:
			print("Tile clicked is not highlighted for movement.")
	else:
		print("Not in combat, using HexGrid's unitPlacer")
		player_combat_controller.unitPlacer()


func _move_unit_to_tile(selected_unit_instance, target_tile):
	# Ensure that selected_unit_instance is a Node3D instance
	if not selected_unit_instance is Node3D:
		print("Error: selected_unit_instance is not a Node3D instance. Cannot move it.")
		return
	
	# Directly move the specific instance on the map
	print("Moving unit instance:", selected_unit_instance, "to new tile:", target_tile)

	# Set the new unit's position to the target tile
	selected_unit_instance.position = target_tile.global_transform.origin

	# Update the units_on_tiles dictionary to reflect the new tile
	var old_tile = player_combat_controller.currently_selected_tile
	if old_tile:
		player_combat_controller.units_on_tiles.erase(old_tile)
	player_combat_controller.units_on_tiles[target_tile] = selected_unit_instance

	# Update the tile colors
	if old_tile:
		old_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set old tile back to blue
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set new tile to red

	# Update the selected tile reference
	player_combat_controller.currently_selected_tile = target_tile

	# Clear the highlighted tiles
	clear_highlighted_tiles()

	# Deselect the unit after moving
	selected_unit_instance = null
	player_combat_controller.unit_name_label.text = ""
	print("Unit moved to new tile successfully.")
