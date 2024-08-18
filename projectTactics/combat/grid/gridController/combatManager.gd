extends Node

# A flag to determine whether the player is in combat mode
var in_combat = false
var turnCount: int = 1  # Track the current turn count

@export var playerInfo : PlayerData

@onready var player_combat_controller = $"../HexGrid"
@onready var AI_Controller = $"../aiController"
@onready var camera = $"../HexGrid/Camera3D"  # Initialize the camera properly
@onready var unit_name_label = $"../CombatGridUI/UnitPlaceUI/UnitName"
@onready var end_turn_button = $"../CombatGridUI/UnitPlaceUI/EndTurn"  # Reference to the end turn button
@onready var armor_bar = $"../CombatGridUI/ArmorBar"
@onready var armor_bar_name = $"../CombatGridUI/armorBarName"

var block_placement: bool = false
var move_mode_active: bool = false  # New variable to control movement mode
var attack_mode_active: bool = false  # New variable to control attack mode

# Define the total number of player and enemy units on the field
@onready var total_player_units: int = player_combat_controller.max_squad_size # Adjust this number as needed
@onready var total_enemy_units: int = AI_Controller.max_enemies # Adjust this number as needed

# Track the remaining player and enemy units on the field
@onready var remaining_player_units: int = total_player_units
@onready var remaining_enemy_units: int = total_enemy_units

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")
]

var highlighted_tiles := []
var selected_unit_instance = null  # Store the instance of the selected unit

# Prevents placing, moving, or interacting if a button is hovered over
func _ready():
	playerInfo = FM.playerData
	set_process_input(true)
	update_end_turn_label()  # Update the button text at the start

func buttonHover():
	block_placement = true

func _input(event):
	# Suppress input if the currently selected unit is moving
	if selected_unit_instance and selected_unit_instance.get_meta("moving", false):
		print("Input suppressed: Unit is currently moving.")
		return  # Ignore any input if the unit is moving

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
			var clicked_position_2d = Vector2(clicked_position.x, clicked_position.z)  # Convert to Vector2
			var clicked_tile = player_combat_controller._get_tile_with_tolerance(clicked_position_2d)
			if clicked_tile:
				# Check if there is a unit on the clicked tile
				if player_combat_controller.units_on_tiles.has(clicked_tile):
					var unit_instance = player_combat_controller.units_on_tiles[clicked_tile]
					if unit_instance.is_in_group("player_units"):
						handle_tile_click(clicked_tile)
					elif attack_mode_active and not unit_instance.get_meta("has_attacked", false):
						
						handle_enemy_click(unit_instance, clicked_tile)
					else:
						update_armor_bar(unit_instance, true)
						print("Cannot select this unit: it belongs to the enemy.")
				else:
					# No unit detected on the tile; deselect current unit if selected
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
			end_move_mode()  # End move mode when another unit is selected
		elif selected_unit_instance and move_mode_active:  # Check if move mode is active
			# Only attempt movement if a unit is already selected and move mode is active
			if tile in highlighted_tiles:
				# Tile within range and empty, move the selected unit to this tile
				print("Moving unit to tile:", tile)
				move_unit_to_tile(selected_unit_instance, tile)
				end_move_mode()  # End move mode after moving
			else:
				# Tile outside of range, deselect the unit and end move mode
				print("Clicked tile is outside of range. Deselecting unit.")
				end_move_mode()
				deselect_unit()
		else:
			# If move mode is not active and the tile is empty, deselect the unit
			print("Empty tile clicked. Deselecting unit.")
			end_move_mode()
			deselect_unit()

func _handle_unit_click(unit_instance):
	if in_combat:
		# Prevent selecting the unit if it is currently moving
		if unit_instance.has_meta("moving") and unit_instance.get_meta("moving"):
			print("Cannot select unit: it is currently moving.")
			return

		# Check if the unit is a player unit
		if not unit_instance.is_in_group("player_units"):
			print("Cannot select this unit: it belongs to the enemy.")
			return

		# If another unit is selected, deselect it without turning its tile red
		if selected_unit_instance and selected_unit_instance != unit_instance:
			deselect_unit(true)

		clear_highlighted_tiles()

		print("Switching to selected unit instance:", unit_instance)
		# Display the name of the unit
		unit_name_label.text = "Unit: " + unit_instance.unitParts.name

		# Initialize remaining movement if not set
		if not unit_instance.has_meta("remaining_movement"):
			unit_instance.set_meta("remaining_movement", unit_instance.unitParts.speedRating)

		# Set the instance as selected
		selected_unit_instance = unit_instance
		$"../CombatGridUI/UnitPlaceUI/Move".visible = true
		
		# Update the attack button visibility based on the 'has_attacked' property
		if unit_instance.unitParts.has_attacked:
			$"../CombatGridUI/UnitPlaceUI/Attack".visible = false  # Hide the attack button if the unit has already attacked
		else:
			$"../CombatGridUI/UnitPlaceUI/Attack".visible = true  # Show the attack button if the unit has not yet attacked

		$"../CombatGridUI/UnitPlaceUI/CenterCam".visible = true

		# Update and show the armor bar
		update_armor_bar(unit_instance, false)

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
			
			# Deactivate attack mode when selecting a new friendly unit
			if attack_mode_active:
				end_attack_mode()
		else:
			print("Selected unit instance not found on any tile.")

func deselect_unit(force_deselect = false):
	$"../CombatGridUI/UnitPlaceUI/Attack".visible = false
	$"../CombatGridUI/UnitPlaceUI/Move".visible = false
	$"../CombatGridUI/UnitPlaceUI/Shoot".visible = false
	$"../CombatGridUI/UnitPlaceUI/CenterCam".visible = false
	
	# Hide the armor bar
	hide_armor_bar()

	# Clear all highlighted tiles
	clear_highlighted_tiles()

	# Deselect the currently selected unit and reset the tile color
	if selected_unit_instance:
		# Only reset the tile color to red if the unit is not moving or if forced to deselect
		if player_combat_controller.currently_selected_tile and (force_deselect or not selected_unit_instance.get_meta("moving")):
			player_combat_controller.currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red

		selected_unit_instance = null
		player_combat_controller.currently_selected_tile = null
		player_combat_controller.unit_name_label.text = ""
		print("Unit deselected.")
		
		# Deactivate attack mode when deselecting a unit
		if attack_mode_active:
			end_attack_mode()

func move_unit_to_tile(unit_instance: Node3D, target_tile: Node3D):
	# Ensure that unit_instance is a Node3D instance
	if not unit_instance is Node3D:
		print("Error: unit_instance is not a Node3D instance. Cannot move it.")
		return

	# Immediately update the unit's position in the units_on_tiles dictionary
	if player_combat_controller.units_on_tiles.has(target_tile):
		print("Target tile is occupied by another unit. Movement aborted.")
		return
	else:
		# Update the units_on_tiles dictionary to reflect the new position
		player_combat_controller.units_on_tiles.erase(player_combat_controller.currently_selected_tile)
		player_combat_controller.units_on_tiles[target_tile] = unit_instance
		# Set the target tile green immediately upon clicking
		target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green

	# Set the unit as moving
	unit_instance.set_meta("moving", true)

	# Get the tiles along the path
	var path_tiles = get_tiles_along_path(unit_instance.global_transform.origin, target_tile.global_transform.origin)

	# Instantly rotate the unit to face the first tile
	if path_tiles.size() > 0:
		var first_tile = path_tiles[0]
		var first_target_position = first_tile.global_transform.origin
		var direction = (first_target_position - unit_instance.global_transform.origin).normalized()
		unit_instance.look_at(first_target_position, Vector3.UP)
		unit_instance.rotate_y(deg_to_rad(180))  # Rotate 180 degrees to face backward

	# Iterate over each tile in the path and move the unit one tile at a time
	for i in range(path_tiles.size()):
		var tile = path_tiles[i]
		var is_final_tile = (i == path_tiles.size() - 1)
		
		if unit_instance.get_meta("remaining_movement") <= 0:
			break  # Stop if the unit has no remaining movement

		# Move the unit to the current tile
		await move_unit_one_tile(unit_instance, player_combat_controller.currently_selected_tile, tile, i == path_tiles.size())

		# Update the currently selected tile to the new tile
		player_combat_controller.currently_selected_tile = tile

	# Mark the unit as not moving anymore
	unit_instance.set_meta("moving", false)

	# Guarantee that the unit ends up on the target tile
	await move_unit_one_tile(unit_instance, player_combat_controller.currently_selected_tile, target_tile, true)

	print("Unit moved successfully with remaining movement: ", unit_instance.get_meta("remaining_movement"))

func move_unit_one_tile(unit_instance: Node3D, start_tile: Node3D, target_tile: Node3D, is_final_tile: bool = false):
	# Get the current and target positions
	var start_position = start_tile.global_transform.origin
	var target_position = target_tile.global_transform.origin

	# Calculate the distance to move
	var distance_to_move = start_position.distance_to(target_position) / player_combat_controller.TILE_SIZE

	# Check if the unit has enough remaining movement, allowing for a small precision buffer
	var remaining_movement = unit_instance.get_meta("remaining_movement")
	var precision_buffer = 0.001  # Small buffer to account for floating-point precision issues
	if remaining_movement + precision_buffer < distance_to_move:
		print("Unit does not have enough remaining movement to move to the target tile.")
		return

	# Preserve the Y position from the start
	var initial_y = unit_instance.global_transform.origin.y
	target_position.y = initial_y  # Ensure the Y-axis remains unchanged

	# Calculate the direction to the target
	var direction = (target_position - start_position).normalized()

	# Rotate the unit only if it's not the final tile
	if not is_final_tile:
		unit_instance.look_at(target_position, Vector3.UP)
		unit_instance.rotate_y(deg_to_rad(180))  # Rotate 180 degrees to face backward

	# Now perform the movement animation
	var duration = 0.5  # seconds per tile
	var elapsed = 0.0

	while elapsed < duration:
		var t = elapsed / duration
		var interpolated_position = start_position.lerp(target_position, t)
		interpolated_position.y = initial_y  # Keep Y constant during interpolation
		unit_instance.global_transform.origin = interpolated_position

		await get_tree().create_timer(0.01).timeout
		elapsed += 0.01

	# Ensure the final position is set
	unit_instance.global_transform.origin = target_position

	# Clear the start tile if it's not the final tile
	if not is_final_tile:
		start_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set to blue

	# If this is the final tile, set it to purple (or green if it's selected)
	var final_tile_material = TILE_MATERIALS[4] if is_final_tile else TILE_MATERIALS[1]
	target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = final_tile_material

	# Decrement the remaining movement by the distance moved, considering the buffer
	unit_instance.set_meta("remaining_movement", max(0, remaining_movement - distance_to_move))

	print("Unit moved to tile: ", target_tile.global_transform.origin, " Remaining movement: ", unit_instance.get_meta("remaining_movement"))

	# Mark the unit as not moving if it's on the final tile
	if is_final_tile:
		unit_instance.set_meta("moving", false)

		# Ensure the unit ends up on the target tile and is correctly displayed
		unit_instance.global_transform.origin = target_position

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
	if selected_unit_instance and selected_unit_instance.get_meta("moving", false):
		print("Input suppressed: Unit is currently moving.")
		return  # Ignore any input if the unit is moving

	clear_highlighted_tiles()  # Clear any existing highlights
	
	if attack_mode_active:
		end_attack_mode()  # Deactivate attack mode if it is active

	if move_mode_active:
		end_move_mode()  # If move mode is active, deactivate it
	else:
		print("Move mode activated for selected unit.")
		move_mode_active = true  # Activate move mode

		# Highlight the movement range when move mode is activated
		highlight_tiles_around_unit(selected_unit_instance, selected_unit_instance.get_meta("remaining_movement"))

func shootButton():
	if selected_unit_instance and selected_unit_instance.get_meta("moving", false):
		print("Input suppressed: Unit is currently moving.")
		return  # Ignore any input if the unit is moving
	clear_highlighted_tiles()  # Clear any existing highlights
	print("Shoot action selected.")
	end_move_mode()  # End move mode when shooting
	# Implement shooting logic here
	
	# Deactivate attack mode if it is active
	if attack_mode_active:
		end_attack_mode()

func attackButton():
	if selected_unit_instance and selected_unit_instance.get_meta("moving", false):
		print("Input suppressed: Unit is currently moving.")
		return  # Ignore any input if the unit is moving

	clear_highlighted_tiles()  # Clear any existing highlights
	
	if move_mode_active:
		end_move_mode()  # Deactivate move mode if it is active

	if attack_mode_active:
		end_attack_mode()  # Deactivate attack mode if it's already active
	else:
		print("Attack mode activated.")
		attack_mode_active = true  # Activate attack mode

		# Calculate and highlight the attack range
		if selected_unit_instance:
			highlight_attack_range(selected_unit_instance)
		else:
			print("No unit selected for attack.")

func end_attack_mode():
	attack_mode_active = false  # Deactivate attack mode
	
	if selected_unit_instance:
		# Reset the attack flag on the selected unit
		selected_unit_instance.set_meta("has_attacked", false)
	
	clear_highlighted_tiles()  # Clear highlighted attack tiles
	print("Attack mode deactivated.")

func highlight_attack_range(unit_instance):
	# Initialize variables to store the highest range
	var max_range = 0

	# Manually retrieve the parts from the unitParts
	var parts = [unit_instance.unitParts.head, unit_instance.unitParts.arm, unit_instance.unitParts.leg, unit_instance.unitParts.core, unit_instance.unitParts.chest]

	for part in parts:
		if part.name != "head":
			max_range = max(max_range, part.range)

	print("Calculated max range:", max_range)

	# Fetch the current tile based on the latest position of the unit
	var unit_tile = player_combat_controller.currently_selected_tile

	if unit_tile:
		var unit_position = unit_tile.global_transform.origin
		var tile_size = player_combat_controller.TILE_SIZE

		# Highlight tiles within range based on the current position
		for tile_key in player_combat_controller.tiles.keys():
			var tile = player_combat_controller.tiles[tile_key]
			var distance = tile.global_transform.origin.distance_to(unit_position) / tile_size

			if tile == unit_tile:
				continue  # Skip the tile the unit is standing on to keep it green

			var material_override = tile.get_node("unit_hex/mergedBlocks(Clone)").material_override

			if material_override == TILE_MATERIALS[0]:  # Check if the tile is currently blue
				if max_range == 1 and distance <= max_range:
					# Highlight all adjacent tiles (melee attack)
					tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
					highlighted_tiles.append(tile)
				elif max_range > 1 and distance <= max_range and distance > 1:
					# Highlight tiles outside the immediate surrounding area (ranged attack)
					tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
					highlighted_tiles.append(tile)
	else:
		print("No unit tile found to highlight attack range.")

func handle_enemy_click(enemy_unit_instance, clicked_tile):
	
	if selected_unit_instance and attack_mode_active:
		var max_range = selected_unit_instance.unitParts.range
		var distance = clicked_tile.global_transform.origin.distance_to(player_combat_controller.currently_selected_tile.global_transform.origin) / player_combat_controller.TILE_SIZE

		if max_range > 1 and distance <= 1:
			print("Cannot attack enemy: Out of melee range for ranged unit.")
			return

		if distance <= max_range and not selected_unit_instance.unitParts.has_attacked:
			# Apply damage to the enemy unit
			enemy_unit_instance.unitParts.armorRating -= selected_unit_instance.unitParts.damage
			print("Enemy unit took damage! Remaining armor:", enemy_unit_instance.unitParts.armorRating)

			if enemy_unit_instance.unitParts.armorRating <= 0:
				print("Enemy unit destroyed!")
				remove_unit_from_map(enemy_unit_instance, clicked_tile)
				

			# Mark that the unit has attacked
			selected_unit_instance.unitParts.has_attacked = true
			$"../CombatGridUI/UnitPlaceUI/Attack".visible = false  # Hide the attack button after attacking
			
			end_attack_mode()
		else:
			print("Enemy unit is out of range.")
	else:
		print("No selected unit to attack with.")

func remove_unit_from_map(unit_instance, tile):
	# Determine if the unit is a player or enemy unit
	var is_player_unit = unit_instance.is_in_group("player_units")

	# Remove the unit from the map and erase its node reference
	player_combat_controller.units_on_tiles.erase(tile)
	unit_instance.queue_free()

	# Reset the tile color to blue after the unit is removed
	tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]

	# Update the remaining unit count based on the unit type
	if is_player_unit:
		remaining_player_units -= 1
		if remaining_player_units <= 0:
			all_players_died()
	else:
		remaining_enemy_units -= 1
		if remaining_enemy_units <= 0:
			all_enemies_dead()

	print("Unit removed from map.")
	print("Remaining player units:", remaining_player_units)
	print("Remaining enemy units:", remaining_enemy_units)

func all_players_died():
	print("All player units have died.")
	# Add additional logic here to handle the game over condition for the player.
	player_combat_controller.fleeCombat()

func all_enemies_dead():
	print("All enemy units have been defeated.")
	
	# Give the player a random amount of coins between 1 and 100 for each enemy they beat
	playerInfo.balance += total_enemy_units * (randi() % 100)+1
	# Add additional logic here to handle the victory condition.
	player_combat_controller.fleeCombat()

func clear_highlighted_tiles():
	for tile in highlighted_tiles:
		var material_override = tile.get_node("unit_hex/mergedBlocks(Clone)").material_override
		# Reset to blue if it was originally blue or if it's currently yellow or red
		if material_override == TILE_MATERIALS[2] or material_override == TILE_MATERIALS[3]:
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue
	highlighted_tiles.clear()

func end_move_mode():
	move_mode_active = false  # Deactivate move mode
	clear_highlighted_tiles()  # Clear highlighted tiles
	print("Move mode deactivated.")
	
	# Deactivate attack mode if it is active
	if attack_mode_active:
		end_attack_mode()

func endTurn():
	if selected_unit_instance and selected_unit_instance.get_meta("moving", false):
		print("Input suppressed: Unit is currently moving.")
		return  # Ignore any input if the unit is moving
	
	# Increment the turn count
	turnCount += 1
	deselect_unit()
	end_move_mode()  # End move mode at the end of a turn
	
	# Reset the remaining movement and attack flag for all units
	reset_all_units_status()

	# Update the end turn button text
	update_end_turn_label()

	print("Turn ended. Turn count is now ", turnCount)
	# Trigger enemy turn after player ends their turn
	AI_Controller.take_enemy_turns()


func reset_all_units_status():
	for tile in player_combat_controller.units_on_tiles.keys():
		var unit_instance = player_combat_controller.units_on_tiles[tile]
		unit_instance.set_meta("remaining_movement", unit_instance.unitParts.speedRating)
		unit_instance.unitParts.has_attacked = false  # Reset attack flag
		print("Reset unit's movement and attack status.")

		if unit_instance == selected_unit_instance:
			$"../CombatGridUI/UnitPlaceUI/Attack".visible = true

func update_end_turn_label():
	$"../CombatGridUI/UnitPlaceUI2/TurnCounter".text = "End Turn: " + str(turnCount)

func buttonLeft():
	block_placement = false

func centerCamera():
	if selected_unit_instance:
		print("Centering camera on selected unit.")

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

func highlight_tiles_around_unit(unit_instance, range):
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

# New functions for handling the armor bar
func update_armor_bar(unit_instance, is_enemy):
	armor_bar.max_value = unit_instance.unitParts.maxArmor
	armor_bar.value = unit_instance.unitParts.armorRating
	if !is_enemy:
		armor_bar_name.text = "Unit armor: " + str(unit_instance.unitParts.armorRating) + " / " + str(unit_instance.unitParts.maxArmor)
	else:
		armor_bar_name.text = "Enemy armor: " + str(unit_instance.unitParts.armorRating) + " / " + str(unit_instance.unitParts.maxArmor)
	armor_bar.visible = true
	armor_bar_name.visible = true

func hide_armor_bar():
	armor_bar.visible = false
	armor_bar_name.visible = false


func move_enemy_unit_to_tile(enemy_unit: Node3D, target_tile: Vector2):
	if not enemy_unit is Node3D:
		print("Error: enemy_unit is not a Node3D instance. Cannot move it.")
		return

	# Check if the target tile is already occupied
	if player_combat_controller.units_on_tiles.has(target_tile):
		print("Target tile is occupied by another unit. Movement aborted.")
		return
	else:
		# Update the units_on_tiles dictionary
		var current_tile = player_combat_controller._get_tile_with_tolerance(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))
		player_combat_controller.units_on_tiles.erase(current_tile)
		player_combat_controller.units_on_tiles[target_tile] = enemy_unit

	# Set the unit as moving
	enemy_unit.set_meta("moving", true)

	# Move the unit to the target tile
	var target_position = player_combat_controller.tiles[target_tile].global_transform.origin
	var initial_y = enemy_unit.global_transform.origin.y
	target_position.y = initial_y  # Ensure the Y-axis remains unchanged

	enemy_unit.look_at(target_position, Vector3.UP)
	enemy_unit.rotate_y(deg_to_rad(180))  # Rotate 180 degrees to face backward

	var duration = 0.5
	var elapsed = 0.0

	while elapsed < duration:
		var t = elapsed / duration
		var interpolated_position = enemy_unit.global_transform.origin.lerp(target_position, t)
		interpolated_position.y = initial_y  # Keep Y constant during interpolation
		enemy_unit.global_transform.origin = interpolated_position

		await get_tree().create_timer(0.01).timeout
		elapsed += 0.01

	enemy_unit.global_transform.origin = target_position
	enemy_unit.set_meta("moving", false)
	print("Enemy unit moved to tile: ", target_tile)
