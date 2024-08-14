extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false

@onready var player_combat_controller = $"../HexGrid"
@onready var camera = $"../HexGrid/Camera3D"  # Initialize the camera properly
@onready var unit_name_label = $"../CombatGridUI/UnitPlaceUI/UnitName"

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
		# Prevent selecting the unit if it is currently moving
		if unit_instance.has_meta("moving") and unit_instance.get_meta("moving"):
			print("Cannot select unit: it is currently moving.")
			return

		if selected_unit_instance:
			# Reset the previously selected tile color to red
			if player_combat_controller.currently_selected_tile:
				player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		clear_highlighted_tiles()

		print("Switching to selected unit instance:", unit_instance)
		# Display the name of the unit
		unit_name_label.text = "Unit: " + unit_instance.unitParts.name

		# Ensure the unit_instance is a Node3D and not a resource reference
		if not unit_instance is Node3D:
			print("Error: The selected unit is not a Node3D instance.")
			return

		# Set the instance as selected
		selected_unit_instance = unit_instance

		# Immediately update the current tile reference for this unit
		var selected_tile = null
		for tile in player_combat_controller.units_on_tiles.keys():
			if player_combat_controller.units_on_tiles[tile] == unit_instance:
				selected_tile = tile
				break

		if selected_tile:
			player_combat_controller.currently_selected_tile = selected_tile

			# Calculate the max move distance based on the newly selected tile
			highlight_tiles_around_unit(selected_unit_instance, selected_unit_instance.unitParts.speedRating)

			# Update the selected tile and set the material to green after highlighting
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
		else:
			print("Selected unit instance not found on any tile.")

			
func deselect_unit():
	# Deselect the currently selected unit and reset the tile color
	if selected_unit_instance:
		clear_highlighted_tiles()
		if player_combat_controller.currently_selected_tile:
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		selected_unit_instance = null
		player_combat_controller.currently_selected_tile = null
		player_combat_controller.unit_name_label.text = ""
		print("Unit deselected.")

func highlight_tiles_around_unit(selected_unit_instance, range):
	# Fetch the current tile based on the latest position of the unit
	var unit_tile = player_combat_controller.currently_selected_tile
	
	if unit_tile:
		var unit_position = unit_tile.global_transform.origin
		var tile_size = player_combat_controller.TILE_SIZE
		
		# Highlight tiles within range based on the current position
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
	# Clear selected name label
	unit_name_label.text = ""
	
	# Ensure that unit_instance is a Node3D instance
	if not unit_instance is Node3D:
		print("Error: unit_instance is not a Node3D instance. Cannot move it.")
		return

	# Mark the unit as moving
	unit_instance.set_meta("moving", true)

	# Get the current and target positions
	var start_position = unit_instance.global_transform.origin
	var target_position = target_tile.global_transform.origin
	target_position.y = start_position.y  # Keep the height constant

	# Instantly update the units_on_tiles dictionary to reflect the new tile
	var old_tile = player_combat_controller.currently_selected_tile
	if old_tile:
		player_combat_controller.units_on_tiles.erase(old_tile)
	player_combat_controller.units_on_tiles[target_tile] = unit_instance

	# Update the tile colors
	if old_tile:
		old_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set old tile back to blue
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set new tile to red

	# Clear the highlighted tiles
	clear_highlighted_tiles()
	
	# Get the tiles along the path
	var path_tiles = get_tiles_along_path(start_position, target_position)
	
	# Now perform the movement animation
	var duration = 1.0  # seconds
	var elapsed = 0.0
	var previous_tile = null

	while elapsed < duration:
		var t = elapsed / duration
		var interpolated_position = start_position.lerp(target_position, t)
		unit_instance.global_transform.origin = interpolated_position

		# Invert the direction to face the opposite way
		var direction = start_position - target_position
		direction.y = 0  # Keep the height constant for rotation

		# Rotate to face the opposite direction
		unit_instance.look_at(target_position + direction, Vector3.UP)

		# Find the closest tile to the current interpolated position
		var current_tile = get_closest_tile(interpolated_position)
		if current_tile and current_tile != previous_tile:
			# If moving to a new tile, set it to yellow
			current_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow

			# Reset the previous tile color to blue if it's not the target
			if previous_tile and previous_tile != target_tile:
				previous_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
			previous_tile = current_tile

		# Wait for the next frame to continue updating
		await get_tree().create_timer(0.01).timeout

		elapsed += 0.01

	# Ensure the final position and rotation are set
	unit_instance.global_transform.origin = target_position
	unit_instance.look_at(target_position, Vector3.UP)  # Apply final rotation

	# Update the selected tile reference to the new position
	player_combat_controller.currently_selected_tile = target_tile

	# Mark the unit as not moving anymore
	unit_instance.set_meta("moving", false)

	# Deselect the unit after the movement is complete
	deselect_unit()

	# Print confirmation of successful move
	print("Unit moved to new tile successfully.")


# Calculate tiles along the path between two points
func get_tiles_along_path(start_position: Vector3, end_position: Vector3) -> Array:
	var path_tiles = []
	var direction = (end_position - start_position).normalized()
	var distance = start_position.distance_to(end_position)
	var steps = int(distance / player_combat_controller.TILE_SIZE)

	for i in range(steps + 1):
		var current_position = start_position + direction * player_combat_controller.TILE_SIZE * i
		var current_tile = get_closest_tile(current_position)
		if current_tile and current_tile not in path_tiles:
			path_tiles.append(current_tile)

	return path_tiles

# Find the closest tile to a given position
func get_closest_tile(position: Vector3) -> Node:
	var closest_tile = null
	var min_distance = INF

	for tile in player_combat_controller.tiles.values():
		var distance = tile.global_transform.origin.distance_to(position)
		if distance < min_distance:
			min_distance = distance
			closest_tile = tile

	return closest_tile
