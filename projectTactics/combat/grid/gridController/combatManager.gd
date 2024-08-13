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

		print("Switching to selected unit:", selected_unit.unitParts.name)
		DataPasser.passUnitInfo(selected_unit.unitParts)
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
			player_combat_controller.move_unit_to_tile(tile)
		elif player_combat_controller.units_on_tiles.has(tile):
			_handle_unit_click(player_combat_controller.units_on_tiles[tile])
		else:
			print("Clicked tile is not highlighted for movement.")
	else:
		# Handle as necessary when not in combat
		player_combat_controller.unitPlacer()




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
