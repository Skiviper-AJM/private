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
		# Handle unit selection logic when in combat
		if player_combat_controller.currently_selected_tile:
			# Revert the previously selected tile to red if it's occupied
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		# Clear previous highlights
		clear_highlighted_tiles()

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
			
			if distance <= range * tile_size and not player_combat_controller.units_on_tiles.has(tile):
				tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow
				highlighted_tiles.append(tile)

func clear_highlighted_tiles():
	for tile in highlighted_tiles:
		tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
	highlighted_tiles.clear()

func handle_tile_click(tile):
	if in_combat:
		# Check if the tile is highlighted and unoccupied
		if tile in highlighted_tiles and not player_combat_controller.units_on_tiles.has(tile):
			# Move the selected unit to the clicked tile by removing and re-adding it
			var selected_unit = player_combat_controller.units_on_tiles[player_combat_controller.currently_selected_tile]

			# Remove the current instance of the unit
			player_combat_controller.remove_unit(selected_unit)

			# Instantiate a new unit at the clicked tile
			var new_unit = Node3D.new()
			get_parent().add_child(new_unit)
			new_unit.set_script(load("res://combat/resources/unitAssembler.gd"))
			new_unit.unitParts = selected_unit.unitParts
			new_unit.assembleUnit()

			# Set the new unit's position to the clicked tile
			new_unit.global_transform.origin = tile.global_transform.origin

			# Add the new unit to the tile and update the units_on_tiles dictionary
			player_combat_controller.units_on_tiles[tile] = new_unit

			# Update the tile colors
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set old tile back to blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set new tile to red

			# Update the selected tile reference
			player_combat_controller.currently_selected_tile = tile

			# Clear the highlighted tiles
			clear_highlighted_tiles()

			# Deselect the unit after moving
			DataPasser.passUnitInfo(null)
			player_combat_controller.unit_to_place = null
			player_combat_controller.placing_unit = false
			player_combat_controller.unit_name_label.text = ""
			player_combat_controller.currently_selected_tile = null

		elif tile == player_combat_controller.currently_selected_tile or not tile in highlighted_tiles:
			# If it's a blue or green tile, or if it's not in the highlighted range, deselect the unit
			handle_empty_tile_click()
		else:
			# If the tile is occupied, select the unit on that tile
			var unit_on_tile = player_combat_controller.units_on_tiles[tile]
			_handle_unit_click(unit_on_tile)
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
