extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false
var turnCount: int = 1  # Track the current turn count

@onready var player_combat_controller = $"../HexGrid"
@onready var camera = $"../HexGrid/Camera3D"  # Initialize the camera properly
@onready var unit_name_label = $"../CombatGridUI/UnitPlaceUI/UnitName"
@onready var end_turn_button = $"../CombatGridUI/UnitPlaceUI/EndTurn"  # Reference to the end turn button

var block_placement: bool = false
var move_mode_active: bool = false  # New variable to control movement mode

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
]

var highlighted_tiles := []
var selected_unit_instance = null  # Store the instance of the selected unit

# Prevents placing, moving, or interacting if a button is hovered over
func _ready():
	set_process_input(true)
	update_end_turn_label()  # Update the button text at the start

func buttonHover():
	block_placement = true

func _input(event):
	if event.is_action_pressed("interact") and not block_placement:
		handle_unit_selection()

func combatInitiate():
	in_combat = true
	player_combat_controller.block_placement = true  # Disable unit placement from inventory
	print("Combat initiated. Unit selection from inventory disabled.")

func handle_unit_selection():
	if in_combat:
		# Prevent selecting a unit if any unit is currently moving
		if any_unit_moving():
			print("Cannot select any unit while a unit is moving.")
			return

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
		elif selected_unit_instance and move_mode_active:  # Check if move mode is active
			# Only attempt movement if a unit is already selected and move mode is active
			if tile in highlighted_tiles:
				# Tile within range and empty, move the selected unit to this tile
				print("Moving unit to tile:", tile)
				move_unit_to_tile(selected_unit_instance, tile)
				move_mode_active = false  # Reset move mode after moving
			else:
				# Tile outside of range, deselect the unit
				print("Clicked tile is outside of range. Deselecting unit.")
				deselect_unit()
		else:
			# If move mode is not active and the tile is empty, deselect the unit
			print("Empty tile clicked. Deselecting unit.")
			deselect_unit()

func _handle_unit_click(unit_instance):
	if in_combat:
		# Prevent selecting the unit if it is currently moving
		if unit_instance.has_meta("moving") and unit_instance.get_meta("moving"):
			print("Cannot select unit: it is currently moving.")
			return

		# If another unit is selected, deselect it without turning its tile red
		if selected_unit_instance and selected_unit_instance != unit_instance:
			deselect_unit(true)

		clear_highlighted_tiles()

		print("Switching to selected unit instance:", unit_instance)
		# Display the name of the unit
		unit_name_label.text = "Unit: " + unit_instance.unitParts.name

		# Ensure the unit_instance is a Node3D and not a resource reference
		if not unit_instance is Node3D:
			print("Error: The selected unit is not a Node3D instance.")
			return

		# Initialize remaining movement if not set
		if not unit_instance.has_meta("remaining_movement"):
			unit_instance.set_meta("remaining_movement", unit_instance.unitParts.speedRating)

		# Set the instance as selected
		selected_unit_instance = unit_instance
		$"../CombatGridUI/UnitPlaceUI/Move".visible = true
		$"../CombatGridUI/UnitPlaceUI/Shoot".visible = true
		$"../CombatGridUI/UnitPlaceUI/Attack".visible = true
		$"../CombatGridUI/UnitPlaceUI/CenterCam".visible = true
		# Immediately update the current tile reference for this unit
		var selected_tile = null
		for tile in player_combat_controller.units_on_tiles.keys():
			if player_combat_controller.units_on_tiles[tile] == unit_instance:
				selected_tile = tile
				break

		if selected_tile:
			player_combat_controller.currently_selected_tile = selected_tile

			# Only highlight tiles if move mode is active
			if move_mode_active:
				highlight_tiles_around_unit(selected_unit_instance, unit_instance.get_meta("remaining_movement"))

			# Update the selected tile and set the material to green after highlighting
			selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green
		else:
			print("Selected unit instance not found on any tile.")

func deselect_unit(force_deselect = false):
	$"../CombatGridUI/UnitPlaceUI/Attack".visible = false
	$"../CombatGridUI/UnitPlaceUI/Move".visible = false
	$"../CombatGridUI/UnitPlaceUI/Shoot".visible = false
	$"../CombatGridUI/UnitPlaceUI/CenterCam".visible = false
	# Deselect the currently selected unit and reset the tile color
	if selected_unit_instance:
		clear_highlighted_tiles()

		# Only reset the tile color to red if the unit is not moving or if forced to deselect
		if player_combat_controller.currently_selected_tile and (force_deselect or not selected_unit_instance.get_meta("moving")):
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
			var distance = tile.global_transform.origin.distance_to(unit_position) / tile_size
			# Only highlight if the tile is within range and is blue
			if distance <= range + 0.1 and tile.get_node("unit_hex/mergedBlocks(Clone)").material_override == TILE_MATERIALS[0]:  # Adding a small buffer
				tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow
				highlighted_tiles.append(tile)
	else:
		print("No unit tile found to highlight.")



func clear_highlighted_tiles():
	for tile in highlighted_tiles:
		if player_combat_controller.units_on_tiles.has(tile):
			# If the tile is occupied, ensure it stays red
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
		else:
			# Otherwise, reset it to blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
	highlighted_tiles.clear()

func move_unit_to_tile(unit_instance: Node3D, target_tile: Node3D):
	# Ensure that unit_instance is a Node3D instance
	if not unit_instance is Node3D:
		print("Error: unit_instance is not a Node3D instance. Cannot move it.")
		return

	# Calculate the move distance
	var start_position = unit_instance.global_transform.origin
	var target_position = target_tile.global_transform.origin
	var move_distance = start_position.distance_to(target_position) / player_combat_controller.TILE_SIZE

	# Check if the unit has enough remaining movement to make this move
	var remaining_movement = unit_instance.get_meta("remaining_movement")
	if move_distance > remaining_movement + 0.1:  # Adding a small buffer
		print("Not enough movement remaining.")
		return

	# Mark the unit as moving
	unit_instance.set_meta("moving", true)

	# Update the remaining movement after this move
	unit_instance.set_meta("remaining_movement", remaining_movement - move_distance)

	# Get the current and target positions
	target_position.y = start_position.y  # Keep the height constant

	# Instantly update the units_on_tiles dictionary to reflect the new tile
	var old_tile = player_combat_controller.currently_selected_tile
	if old_tile:
		player_combat_controller.units_on_tiles.erase(old_tile)
	player_combat_controller.units_on_tiles[target_tile] = unit_instance

	# Update the tile colors (reset yellow tiles to blue)
	if old_tile and old_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override == TILE_MATERIALS[3]:
		old_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set old tile back to blue
	
	# Set the target tile to red and ensure it stays red during movement
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

	# Clear the highlighted tiles (except for the path tiles)
	clear_highlighted_tiles()

	# Get the tiles along the path
	var path_tiles = get_tiles_along_path(start_position, target_position)
	
	# Highlight the entire path in yellow if the tile is blue
	for tile in path_tiles:
		if tile.get_node("unit_hex/mergedBlocks(Clone)").material_override == TILE_MATERIALS[0]:  # Only highlight if blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[3]  # Set to yellow

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
		var candidate_tiles = get_closest_tiles(interpolated_position)

		# Select one tile randomly if there are multiple candidates
		var current_tile = null
		if candidate_tiles.size() > 0:
			current_tile = candidate_tiles[randi() % candidate_tiles.size()]

		# Proceed only if current_tile is valid
		if current_tile and current_tile != previous_tile:
			# Reset the previous tile color to blue if it's not the target and was yellow
			if previous_tile and previous_tile != target_tile and previous_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override == TILE_MATERIALS[3]:
				previous_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
			previous_tile = current_tile

		# Ensure the target tile remains red during the move
		target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Ensure it stays red

		# Wait for the next frame to continue updating
		await get_tree().create_timer(0.01).timeout

		elapsed += 0.01

	# Ensure the final position and rotation are set
	unit_instance.global_transform.origin = target_position
	unit_instance.look_at(target_position, Vector3.UP)  # Apply final rotation

	# Update the selected tile reference to the new position
	player_combat_controller.currently_selected_tile = target_tile

	# Clear the path tiles after the unit has moved over them
	for tile in path_tiles:
		if tile != target_tile and tile.get_node("unit_hex/mergedBlocks(Clone)").material_override == TILE_MATERIALS[3]:
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue

	# Mark the unit as not moving anymore
	unit_instance.set_meta("moving", false)

	# Turn the target tile green to indicate the unit has arrived
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green

	# The unit will remain selected after its move is completed.
	# Print confirmation of successful move
	print("Unit moved to new tile successfully.")


func get_tiles_along_path(start_position: Vector3, end_position: Vector3) -> Array:
	var path_tiles = []
	var direction = (end_position - start_position).normalized()
	var distance = start_position.distance_to(end_position)
	var steps = int(distance / player_combat_controller.TILE_SIZE) * 2  # Increase resolution by multiplying steps

	for i in range(steps + 1):
		var current_position = start_position + direction * (distance / steps) * i
		
		# Get the closest tile and add randomness to choose between equally distant tiles
		var candidate_tiles = get_closest_tiles(current_position)
		if candidate_tiles.size() > 0:
			var chosen_tile = candidate_tiles[randi() % candidate_tiles.size()]
			if chosen_tile not in path_tiles:
				path_tiles.append(chosen_tile)

	return path_tiles


# Modified function to get closest tiles, with randomness to break ties
func get_closest_tiles(position: Vector3) -> Array:
	var closest_tiles = []
	var min_distance = INF

	for tile in player_combat_controller.tiles.values():
		var distance = tile.global_transform.origin.distance_to(position)
		if distance < min_distance:
			min_distance = distance
			closest_tiles.clear()
			closest_tiles.append(tile)
		elif distance == min_distance:
			closest_tiles.append(tile)

	# Return all closest tiles for randomness in selection
	return closest_tiles


func any_unit_moving() -> bool:
	for tile in player_combat_controller.units_on_tiles.keys():
		var unit_instance = player_combat_controller.units_on_tiles[tile]
		if unit_instance.has_meta("moving") and unit_instance.get_meta("moving"):
			return true
	return false

func moveButton():
	if selected_unit_instance:
		print("Move mode activated for selected unit.")
		move_mode_active = true  # Activate move mode

		# Highlight the movement range when move mode is activated
		highlight_tiles_around_unit(selected_unit_instance, selected_unit_instance.get_meta("remaining_movement"))
	else:
		print("No unit selected to move.")

func endTurn():
	# Increment the turn count
	turnCount += 1

	# Reset the remaining movement for all units
	reset_all_units_movement()

	# Update the end turn button text
	update_end_turn_label()

	print("Turn ended. Turn count is now ", turnCount)

func reset_all_units_movement():
	# Iterate through all units and reset their remaining movement to their full speed
	for tile in player_combat_controller.units_on_tiles.keys():
		var unit_instance = player_combat_controller.units_on_tiles[tile]
		unit_instance.set_meta("remaining_movement", unit_instance.unitParts.speedRating)
	print("All units' movement reset for the new turn.")

func update_end_turn_label():
	$"../CombatGridUI/UnitPlaceUI2/TurnCounter".text = "End Turn: " + str(turnCount)

func buttonLeft():
	block_placement = false

func centerCamera():
	if selected_unit_instance:
		# Get the current position of the selected unit
		var unit_position = selected_unit_instance.global_transform.origin

		# Set the camera's position, keeping the current Y position
		var camera_position = camera.global_transform.origin
		camera_position.x = unit_position.x
		camera_position.z = unit_position.z

		# Apply the new camera position
		camera.global_transform.origin = camera_position

		# Reset the camera's X-axis rotation to -90, keeping the current Y and Z rotations
		var current_rotation = camera.rotation_degrees
		camera.rotation_degrees = Vector3(-90, current_rotation.y, current_rotation.z)

		print("Camera centered on selected unit at position: ", unit_position, " with X-axis rotation set to -90.")
	else:
		print("No unit selected to center camera.")
