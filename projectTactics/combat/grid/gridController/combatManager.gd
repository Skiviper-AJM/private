extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false

@onready var player_combat_controller = $"../HexGrid"
@onready var camera = $"../HexGrid/Camera3D"  # Initialize the camera properly

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
]

var highlighted_tiles := []
var selected_unit_instance = null  # Store the instance of the selected unit

func _ready():
	set_process_input(true)

func _input(event):
	if event.is_action_pressed("interact"):
		handle_unit_selection()

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func handle_unit_selection():
	if in_combat:
		# Raycast to find the tile and the unit instance on it
		var from = camera.project_ray_origin(get_viewport().get_mouse_position())
		var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * 50000

		var space_state = camera.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = from
		query.to = to

		var result = space_state.intersect_ray(query)

		if result:
			var clicked_position = result.position
			var clicked_tile = player_combat_controller._get_tile_with_tolerance(clicked_position)
			if clicked_tile:
				handle_tile_click(clicked_tile)
			else:
				print("No valid tile found.")
		else:
			print("No raycast hit detected.")

func handle_tile_click(tile):
	if in_combat:
		if player_combat_controller.units_on_tiles.has(tile):
			# Always prioritize selecting a unit on the clicked tile
			var unit_instance = player_combat_controller.units_on_tiles[tile]
			_handle_unit_click(unit_instance)
		elif selected_unit_instance:
			# Only attempt movement if a unit is already selected
			if tile in highlighted_tiles:
				# Tile within range and empty, move the selected unit to this tile
				print("Moving unit to tile:", tile)
				move_unit_to_tile(selected_unit_instance, tile)
			else:
				# Tile outside of range, deselect the unit
				print("Clicked tile is outside of range. Deselecting unit.")
				deselect_unit()
		else:
			print("No unit selected and clicked tile is empty.")

func _handle_unit_click(unit_instance):
	if in_combat:
		if selected_unit_instance:
			# Reset the previously selected tile color to red
			if player_combat_controller.currently_selected_tile:
				player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]

		clear_highlighted_tiles()

		print("Switching to selected unit instance:", unit_instance)

		# Ensure the unit_instance is a Node3D and not a resource reference
		if not unit_instance is Node3D:
			print("Error: The selected unit is not a Node3D instance.")
			return

		# Set the instance as selected
		selected_unit_instance = unit_instance

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

func deselect_unit():
	# Deselect the currently selected unit and reset the tile color
	if selected_unit_instance:
		clear_highlighted_tiles()
		if player_combat_controller.currently_selected_tile:
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set to blue

		selected_unit_instance = null
		player_combat_controller.currently_selected_tile = null
		player_combat_controller.unit_name_label.text = ""
		print("Unit deselected.")

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

func move_unit_to_tile(unit_instance: Node3D, target_tile: Node3D):
	# Ensure that unit_instance is a Node3D instance
	if not unit_instance is Node3D:
		print("Error: unit_instance is not a Node3D instance. Cannot move it.")
		return

	# Get the current and target positions
	var start_position = unit_instance.global_transform.origin
	var target_position = target_tile.global_transform.origin
	target_position.y = start_position.y  # Keep the height constant

	# Duration of movement
	var duration = 1.0  # seconds
	var elapsed = 0.0

	while elapsed < duration:
		var t = elapsed / duration
		var interpolated_position = start_position.lerp(target_position, t)
		unit_instance.global_transform.origin = interpolated_position

		# Calculate the direction to face
		var direction = interpolated_position - target_position
		direction.y = 0  # Keep the height constant for rotation

		# Rotate to face the direction (reverse the direction vector)
		unit_instance.look_at(interpolated_position + direction, Vector3.UP)

		# Wait for the next frame to continue updating
		await get_tree().create_timer(0.01).timeout
		
		elapsed += 0.01

	# Ensure the final position and rotation are set
	unit_instance.global_transform.origin = target_position
	unit_instance.look_at(target_position, Vector3.UP)  # Apply final rotation

	# Update the units_on_tiles dictionary to reflect the new tile
	var old_tile = player_combat_controller.currently_selected_tile
	if old_tile:
		player_combat_controller.units_on_tiles.erase(old_tile)
	player_combat_controller.units_on_tiles[target_tile] = unit_instance

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
