extends Node3D

# Enum defining different item types
enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

# Preloaded materials for tile coloring
const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),  # Blue material
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),   # Red material
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/orange.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/white.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres") # Purple material
]

const TILE_HEIGHT := 1.0  # Tile height adjustment
@export var TILE_SIZE := 1.0  # Tile size (scaling factor)
const HEX_TILE = preload("res://combat/grid/gridController/3D Tiles/hex_tile.tscn")
var currently_selected_tile = null  # Reference to the currently selected tile

# Node references
@onready var combat_manager = $"../combatManager"
@onready var ai_controller = $"../aiController"

# Controls for unit scaling and grid size
@export var unit_scale: Vector3 = Vector3(0.15, 0.15, 0.15)
@export_range(2, 35) var grid_size: int = 10  # Controls the 'radius' of the grid generated

@export var max_squad_size: int = 2  # Default maximum squad size

@export var playerInfo : PlayerData  # Player data reference

# Label references for UI elements
@onready var units_label = $"../CombatGridUI/UnitPlaceUI/UnitsLabel" 
@onready var unit_name_label = $"../CombatGridUI/UnitPlaceUI/UnitName"

# Flags for controlling unit placement and tile selection
var block_placement: bool = false
var enemyOccupied: bool = false

# Camera control constants
const PAN_SPEED := 10.0  # Speed for panning the camera with WASD keys
const ZOOM_SPEED := 1.5  # Speed for zooming in/out
const MIN_ZOOM := 20.0   # Minimum FOV value for zoom
const MAX_ZOOM := 90.0   # Maximum FOV value for zoom
const ROTATION_SPEED := 0.5  # Speed of camera rotation
const MAX_ROTATION_X := -60  # Maximum upward rotation angle
const MIN_ROTATION_X := -90.0  # Maximum downward rotation angle

# Variables for camera rotation tracking
var rotation_angle_x := -90.0  # Initial X-axis rotation
var rotation_angle_y := 0.0  # Initial Y-axis rotation
var is_rotating := false  # Flag for detecting rotation

var placing_unit: bool = false  # Flag for unit placement mode
var unit_to_place = null  # Reference to the unit being placed

# Dictionaries for storing tile and unit data
var tiles = {}
var placed_units = {}
var units_on_tiles = {}

# Queue to track the order of placed units
var placed_units_queue := []

# Initialize the grid and set up the camera
func _ready():
	DataPasser.selectedUnit = null
	DataPasser.inActiveCombat = false
	
	_generate_grid()
	_update_units_label()  # Initialize the units label
	var camera = $Camera3D
	
	# Set the initial camera position and rotation
	camera.position.x = 0
	camera.position.z = grid_size
	camera.rotation_degrees.x = rotation_angle_x
	camera.rotation_degrees.y = rotation_angle_y
	
	playerInfo = FM.playerData
	
	# Filter units from player inventory
	var units = playerInfo.inventory.keys().filter(func(item):
		return item.itemType == ItemTypes.UNIT
	)
	
	# Handle the case where no units are available
	if units.size() == 0:
		%noUnits.visible = true
		$"../CombatGridUI/UnitPlaceUI/StartCombat".visible = false

# Block placement when hovering over a button
func buttonHover():
	block_placement = true

# Handle input events for camera control and unit placement
func _input(event):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Ensure the cursor is always visible
	var camera = $Camera3D

	# Handle WASD keys for panning the camera
	var input_vector := Vector3.ZERO
	
	if Input.is_action_pressed("moveLeft"):
		input_vector -= camera.global_transform.basis.x * PAN_SPEED
	if Input.is_action_pressed("moveRight"):
		input_vector += camera.global_transform.basis.x * PAN_SPEED
	
	# Adjust forward/backward movement based on the camera's rotation
	var forward_direction = -Vector3(
		sin(deg_to_rad(rotation_angle_y)),
		0,
		cos(deg_to_rad(rotation_angle_y))
	)
	
	if Input.is_action_pressed("moveUp"):
		input_vector += forward_direction * PAN_SPEED
	if Input.is_action_pressed("moveDown"):
		input_vector -= forward_direction * PAN_SPEED

	if input_vector != Vector3.ZERO:
		input_vector *= get_process_delta_time()
		input_vector.y = 0  # Ensure no vertical movement
		camera.position += input_vector

	# Handle camera rotation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_rotating = event.pressed

	if is_rotating and event is InputEventMouseMotion:
		rotation_angle_x -= event.relative.y * ROTATION_SPEED
		rotation_angle_y -= event.relative.x * ROTATION_SPEED
		rotation_angle_x = clamp(rotation_angle_x, MIN_ROTATION_X, MAX_ROTATION_X)  # Clamp X-axis rotation
		camera.rotation_degrees.x = rotation_angle_x
		camera.rotation_degrees.y = rotation_angle_y

	# Handle camera zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = clamp(camera.fov - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = clamp(camera.fov + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
	
	# Skip input processing for unit placement when in combat mode or placement is blocked
	if combat_manager.in_combat or block_placement:
		return
	
	# Handle tile clicking
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tile_click(event.position)
	
	# Handle unit placement when the interact action is triggered
	if Input.is_action_just_pressed("interact"):
		if DataPasser.selectedUnit != null and not block_placement and not enemyOccupied: 
			unitPlacer()

# Handle logic for tile clicking and unit selection
func _handle_tile_click(mouse_position):
	var camera = $Camera3D
	var from = camera.project_ray_origin(mouse_position)
	var to = from + camera.project_ray_normal(mouse_position) * 50000

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to

	var result = space_state.intersect_ray(query)

	if result:
		print("Raycast hit detected at position: ", result.position)  # Verify the raycast hit

		var clicked_position = result.position
		var clicked_position_2d = Vector2(clicked_position.x, clicked_position.z)  # Convert to 2D coordinates
		var clicked_tile = _get_tile_with_tolerance(clicked_position_2d)

		if clicked_tile:
			print("Clicked tile instance ID: ", clicked_tile.get_instance_id())

			# Find the coordinates corresponding to the clicked tile
			var coord = null
			for key in tiles.keys():
				if tiles[key] == clicked_tile:
					coord = key
					break

			if coord != null:
				print("Tile coordinates detected: ", coord)

				# Check if there is a unit on the tile at these coordinates
				if units_on_tiles.has(tiles[coord]):
					var unit_on_tile = units_on_tiles[tiles[coord]]
					print("Unit detected on tile, unit instance ID: ", unit_on_tile.get_instance_id())
					
					# Handle detection of enemy units to suppress input
					if unit_on_tile.is_in_group("enemy_units"):
						print("Enemy spotted on tile at coordinates: ", coord)
						enemyOccupied = true
						return  # Early return to block further processing

					# Handle selection logic for player units
					if unit_on_tile.is_in_group("player_units"):
						enemyOccupied = false  # Reset flag since player unit is selected
						print("Swapping selection to player unit on tile:", unit_on_tile.name)

						# Deselect the currently selected tile's visual
						if currently_selected_tile != null:
							_deselect_tile(currently_selected_tile)

						# Select the new unit
						DataPasser.passUnitInfo(unit_on_tile.unitParts)
						unit_to_place = unit_on_tile.unitParts
						placing_unit = false
						unit_name_label.text = "Unit: " + unit_on_tile.unitParts.name

						# Update the selected tile's visual to green
						_select_tile(clicked_tile)
						currently_selected_tile = clicked_tile
						return
				else:
					print("No unit detected on tile coordinates: ", coord)
					enemyOccupied = false

					# If placing a unit, place it on the empty tile
					if placing_unit and DataPasser.selectedUnit != null:
						print("Placing unit on empty tile...")

						var unit_instance: Node3D

						if DataPasser.selectedUnit is Resource:
							# Instantiate the unit if it's a resource
							unit_instance = Node3D.new()
							unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))
							unit_instance.unitParts = DataPasser.selectedUnit
							unit_instance.assembleUnit()
						else:
							# Otherwise, it's already a Node3D instance
							unit_instance = DataPasser.selectedUnit

						place_unit_on_tile(clicked_position_2d, unit_instance, true)  # true for player unit
						return
			else:
				print("No matching coordinates found for clicked tile.")
		else:
			print("No valid tile found.")  # If no tile is found
	else:
		print("No raycast hit detected.")  # If raycast doesn't hit anything

# Deselect a tile by resetting its color
func _deselect_tile(tile):
	if units_on_tiles.has(tile) and currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override != TILE_MATERIALS[6]:
		tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
	elif currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override != TILE_MATERIALS[6]:
		tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set to blue

# Select a tile by changing its color to green
func _select_tile(tile):
	tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[1]  # Set to green

# Find the closest tile to a given position, within a tolerance range
func _get_tile_with_tolerance(position: Vector2, tolerance=0) -> Node3D:
	var closest_tile: Node3D = null
	var min_distance: float = INF
	var closest_tile_coords: Vector2 = Vector2.INF  # Use a clearly out-of-bounds value
	
	for key in tiles.keys():
		var tile = tiles[key]
		var position_3d = Vector3(position.x, 0, position.y)
		var tile_global_position = tile.global_transform.origin
		var distance = tile_global_position.distance_to(position_3d)
		
		if distance < min_distance + tolerance:
			min_distance = distance
			closest_tile = tile
			closest_tile_coords = key  # Update to the closest tile coordinates
	
	if closest_tile and min_distance < TILE_SIZE / 2 + tolerance:
		print("Closest tile coordinates: ", closest_tile_coords)
		return closest_tile
	else:
		print("No valid tile found or out of bounds.")
		return null

# Move a unit to a target tile and update the queue
func move_unit_to_tile(target_tile):
	if currently_selected_tile and target_tile:
		var unit = units_on_tiles.get(currently_selected_tile, null)
		if unit != null:
			# Remove the unit from its current tile and update the placement queue
			print("Moving unit to new tile and updating its position in the queue...")
			_remove_unit_from_queue(unit)

			# Now place the unit on the new tile, treating it as a fresh placement
			place_unit_on_tile(Vector2(target_tile.global_transform.origin.x, target_tile.global_transform.origin.z), unit, true)
		else:
			print("No unit found on the selected tile.")
	else:
		print("No unit selected to move or target tile is null.")

# Remove a unit from the placement queue
func _remove_unit_from_queue(unit):
	# Find and remove the unit from the queue
	if placed_units_queue.has(unit):
		placed_units_queue.erase(unit)

# Generate a grid of hexagonal tiles
func _generate_grid():
	var tile_index := 0
	for x in range(-grid_size, grid_size + 1):
		var tile_coordinates := Vector2.ZERO
		tile_coordinates.x = x * TILE_SIZE * cos(deg_to_rad(30))
		tile_coordinates.y = 0 if x % 2 == 0 else TILE_SIZE / 2
		for y in range(-grid_size, grid_size + 1):
			var tile = HEX_TILE.instantiate()
			add_child(tile)

			# Use a consistent Y for all tiles, which can be adjusted later if needed
			tile.global_transform.origin = Vector3(tile_coordinates.x, 0, tile_coordinates.y)

			tiles[Vector2(x, y)] = tile
			tile_coordinates.y += TILE_SIZE
			# Set the default material to blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]
			tile_index += 1
			print("Generated tile at: ", tile.global_transform.origin)
	ai_controller._on_grid_generated()

# Prepare the selected unit for placement on the grid
func unitPlacer():
	unit_to_place = DataPasser.selectedUnit  # Set the flag and assign the unit to place
	
	if unit_to_place != null:
		placing_unit = true
		print("Ready to place unit:", unit_to_place.name)
		
		unit_name_label.text = "Unit: " + unit_to_place.name
		
		# Check if the unit is already placed on the grid
		var unit_id = unit_to_place.get_instance_id()
		if placed_units.has(unit_id):
			# If the unit is already placed, find the tile it's on
			var tile_with_unit = null
			for tile in units_on_tiles.keys():
				if units_on_tiles[tile] == placed_units[unit_id]:
					tile_with_unit = tile
					break
			
			if tile_with_unit != null:
				# Deselect the previously selected tile, if any
				if currently_selected_tile != null:
					_deselect_tile(currently_selected_tile)

				# Set the new tile color to green
				_select_tile(tile_with_unit)
				
				# Update the currently selected tile reference
				currently_selected_tile = tile_with_unit
		else:
			placing_unit = true
	else:
		placing_unit = false
		
		# Clear the UnitName label if no unit is selected
		unit_name_label.text = ""

# Track the position of an enemy unit on the grid
func add_enemy_to_grid(enemy_unit: Node3D, tile_position: Vector2):
	if not units_on_tiles.has(tile_position):
		units_on_tiles[tile_position] = enemy_unit
		enemy_unit.add_to_group("enemy_units")

# Remove an enemy unit from the grid
func remove_enemy_from_grid(tile_position: Vector2):
	if units_on_tiles.has(tile_position):
		units_on_tiles.erase(tile_position)

# Place a unit on a specified tile and handle placement logic
func enemy_place_unit_on_tile(tile_position: Vector2, unit_to_place: Node3D, is_player: bool = true):
	print("Placing unit at tile position: ", tile_position)
	
	# Directly retrieve the tile using the position from the tiles dictionary
	var target_tile = tiles.get(tile_position, null)

	if target_tile:
		print("Target tile found: ", target_tile.get_instance_id())
		
		# Check if the tile already has a unit
		if units_on_tiles.has(target_tile):
			var existing_unit = units_on_tiles[target_tile]
			print("Existing unit instance ID: ", existing_unit.get_instance_id())

			# Block placement if the tile is occupied by another unit of the same type
			if (is_player and existing_unit.is_in_group("player_units")) or (not is_player and existing_unit.is_in_group("enemy_units")):
				print("Cannot place unit on a tile occupied by another unit of the same type.")
				return

			# Remove the existing unit if the placement is allowed
			print("Removing existing unit to place a new one...")
			remove_unit(existing_unit)

		# Create and place the 3D model at the tile position
		print("Creating new unit model...")
		unit_to_place.scale = unit_scale  # Apply the unit scale

		# Set the unit position based on the tile position
		var left_foot_node = unit_to_place.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")
		var right_foot_node = unit_to_place.get_node_or_null("chestPivot/rLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")

		if left_foot_node and right_foot_node:
			var left_foot_bbox = left_foot_node.get_aabb()
			var right_foot_bbox = right_foot_node.get_aabb()

			var lowest_y = min(left_foot_bbox.position.y, right_foot_bbox.position.y)

			unit_to_place.position = target_tile.global_transform.origin - Vector3(0, lowest_y - 1.1, 0)
		else:
			print("Foot nodes not found! Adjusting using the main bounding box.")
			# Fallback to use the main bounding box
			var bbox = unit_to_place.get_aabb()
			unit_to_place.position = target_tile.global_transform.origin - Vector3(0, bbox.position.y, 0)

		# Store the unit in the correct dictionary and assign the correct group
		units_on_tiles[target_tile] = unit_to_place
		if is_player:
			# Add the unit to the queue (remove first if it's already there to avoid duplicates)
			_remove_unit_from_queue(unit_to_place)
			placed_units_queue.push_back(unit_to_place)
			placed_units[unit_to_place.unitParts] = unit_to_place
			unit_to_place.add_to_group("player_units")
		else:
			unit_to_place.add_to_group("enemy_units")

		# Set the tile color accordingly
		if is_player:
			target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red for player
		else:
			target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[6]  # Set to purple for enemy

		# Add the unit to the scene tree if it wasn't already
		if not is_instance_valid(unit_to_place.get_parent()):
			add_child(unit_to_place)

		# Update the label text if placing a player unit
		if is_player:
			_update_units_label()

		# Update the currently selected tile reference if needed
		if is_player and currently_selected_tile and currently_selected_tile != target_tile:
			_deselect_tile(currently_selected_tile)
		currently_selected_tile = target_tile

		# Deselect the unit after placement
		DataPasser.selectedUnit = null
		placing_unit = false
		unit_name_label.text = ""
	else:
		print("No valid tile found at position: ", tile_position)

# Place a unit on the grid and handle related logic
func place_unit_on_tile(position: Vector2, unit_to_place: Node3D, is_player: bool = true, use_direct_placement: bool = false):
	print("Placing unit at position: ", position)

	var target_tile: Node3D = null

	# If direct placement is used, skip raycasting and tolerance checks
	if use_direct_placement:
		target_tile = tiles.get(position, null)
	else:
		target_tile = _get_tile_with_tolerance(position)

	if target_tile:
		print("Target tile found: ", target_tile.get_instance_id())

		# Check if a unit with the same unitParts is already placed
		if placed_units.has(unit_to_place.unitParts):
			var existing_unit = placed_units[unit_to_place.unitParts]
			print("A unit with the same parts is already placed. Removing the existing unit.")
			remove_unit(existing_unit)

		# Enforce max_squad_size before adding the new unit
		if is_player and placed_units_queue.size() >= max_squad_size:
			print("Max squad size exceeded, removing the oldest unit.")
			remove_unit(placed_units_queue.front())  # Remove the oldest unit (first in the queue)

		# Check if the tile already has a unit
		if units_on_tiles.has(target_tile):
			var existing_unit_on_tile = units_on_tiles[target_tile]
			print("Existing unit instance ID on tile: ", existing_unit_on_tile.get_instance_id())

			# Block placement if the tile is occupied by another unit of the same type
			if (is_player and existing_unit_on_tile.is_in_group("player_units")) or (not is_player and existing_unit_on_tile.is_in_group("enemy_units")):
				print("Cannot place unit on a tile occupied by another unit of the same type.")
				return

			# Remove the existing unit if the placement is allowed
			print("Removing existing unit on the tile to place a new one...")
			remove_unit(existing_unit_on_tile)

		# Create and place the 3D model at the tile position
		print("Creating new unit model...")
		unit_to_place.scale = unit_scale  # Apply the unit scale

		# Set the unit position based on the tile position
		var left_foot_node = unit_to_place.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")
		var right_foot_node = unit_to_place.get_node_or_null("chestPivot/rLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")

		if left_foot_node and right_foot_node:
			var left_foot_bbox = left_foot_node.get_aabb()
			var right_foot_bbox = right_foot_node.get_aabb()

			var lowest_y = min(left_foot_bbox.position.y, right_foot_bbox.position.y)

			unit_to_place.position = target_tile.global_transform.origin - Vector3(0, lowest_y - 1.1, 0)
		else:
			print("Foot nodes not found! Adjusting using the main bounding box.")
			# Fallback to use the main bounding box
			var bbox = unit_to_place.get_aabb()
			unit_to_place.position = target_tile.global_transform.origin - Vector3(0, bbox.position.y, 0)

		# Store the unit in the correct dictionary and assign the correct group
		units_on_tiles[target_tile] = unit_to_place
		if is_player:
			# Add the unit to the queue (remove first if it's already there to avoid duplicates)
			_remove_unit_from_queue(unit_to_place)
			placed_units_queue.push_back(unit_to_place)
			placed_units[unit_to_place.unitParts] = unit_to_place
			unit_to_place.add_to_group("player_units")
		else:
			unit_to_place.add_to_group("enemy_units")

		# Set the tile color accordingly
		if is_player:
			target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red for player
		else:
			target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[6]  # Set to purple for enemy

		# Add the unit to the scene tree if it wasn't already
		if not is_instance_valid(unit_to_place.get_parent()):
			add_child(unit_to_place)

		# Update the label text if placing a player unit
		if is_player:
			_update_units_label()

		# Update the currently selected tile reference if needed
		if is_player and currently_selected_tile and currently_selected_tile != target_tile:
			_deselect_tile(currently_selected_tile)
		currently_selected_tile = target_tile

		# Deselect the unit after placement
		DataPasser.selectedUnit = null
		placing_unit = false
		unit_name_label.text = ""
	else:
		print("No valid tile found at position: ", position)

# Remove a unit from the grid and clean up references
func remove_unit(unit):
	# Check if the unit still exists in the scene
	if unit and is_instance_valid(unit):
		# Find and remove the unit from the tiles dictionary
		for tile in units_on_tiles.keys():
			if units_on_tiles[tile] == unit:
				# Change the tile color back to blue
				print("Reverting tile to blue after removing unit.")
				tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set to blue
				
				units_on_tiles.erase(tile)
				break

		# Remove the unit from the placed_units dictionary and queue
		var unit_resource = unit.unitParts
		placed_units.erase(unit_resource)
		placed_units_queue.erase(unit)

		# Update the label text
		_update_units_label()

		unit.queue_free()  # This will remove the unit from the scene
	else:
		print("Warning: Tried to remove a unit that is no longer valid or doesn't exist.")

# Update the units label with the current count
func _update_units_label():
	var current_units := placed_units_queue.size()
	units_label.text = "Select Units: %d / %d" % [current_units, max_squad_size]

# Re-enable placement after leaving a button
func buttonLeft():
	block_placement = false;

# Initiate combat mode after unit placement
func combatInitiate():
	# Prevent initiation of combat without selecting at least one unit
	
	if placed_units_queue.size() < 1:
		return
	
	DataPasser.inActiveCombat = true
	
	# Deselect current unit and set its tile to red
	if currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override != TILE_MATERIALS[6]:
		currently_selected_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]
	DataPasser.selectedUnit = null
	unit_name_label.text = ""
	
	$"../CombatGridUI/UnitPlaceUI/UnitsLabel".visible = false
	$"../CombatGridUI/UnitPlaceUI/StartCombat".visible = false
	$"../CombatGridUI/UnitPlaceUI2".visible = true
	combat_manager.combatInitiate()
	print("fite tiem")

# Handle fleeing from combat and resetting the scene
func fleeCombat():
	DataPasser.inActiveCombat = false
	DataPasser.selectedUnit = null
	%noUnits.visible = false
	get_tree().change_scene_to_file(DataPasser.priorScene)
