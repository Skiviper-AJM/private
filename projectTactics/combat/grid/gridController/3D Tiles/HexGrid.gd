extends Node3D

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),   # Blue material
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),    # Red material
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
]

const TILE_HEIGHT := 1.0  # Set this to the actual height of your tile
const TILE_SIZE := 1.0
const HEX_TILE = preload("res://combat/grid/gridController/3D Tiles/hex_tile.tscn")

@export var unit_scale: Vector3 = Vector3(0.2, 0.2, 0.2)  # New export variable for unit scale
@export_range(2, 35) var grid_size: int = 10

const PAN_SPEED := 10.0  # Speed at which the camera pans with WASD keys
const ZOOM_SPEED := 1.5  # Speed at which the camera zooms
const MIN_ZOOM := 20.0   # Minimum FOV value for zoom
const MAX_ZOOM := 90.0   # Maximum FOV value for zoom
const ROTATION_SPEED := 0.5  # Speed of rotation when dragging the mouse
const MAX_ROTATION_X := 0 # Maximum rotation angle on the x-axis (camera looks down slightly)
const MIN_ROTATION_X := -90.0  # Minimum rotation angle on the x-axis (camera looks straight down)

var rotation_angle_x := -90.0  # Start with -90 degrees on the x-axis
var rotation_angle_y := 0.0  # Start with 0 degrees on the y-axis
var is_rotating := false  # Track whether the camera is being rotated

var placing_unit: bool = false
var unit_to_place = null

# Dictionary to store tile positions with coordinates as keys
var tiles = {}

func _ready():
	_generate_grid()
	var camera = $Camera3D
	# Initialize the camera's position and rotation
	camera.position.x = 0
	camera.position.z = grid_size
	camera.rotation_degrees.x = rotation_angle_x
	camera.rotation_degrees.y = rotation_angle_y

func _input(event):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Ensure the cursor is always visible
	var camera = $Camera3D
	if Input.is_action_just_pressed("interact"): 
		if DataPasser.selectedUnit != null: 
			unitPlacer()
			
	# Handle WASD keys for panning based on camera's facing direction
	var input_vector := Vector3.ZERO
	
	if Input.is_action_pressed("moveLeft"):
		input_vector -= camera.global_transform.basis.x * PAN_SPEED
	if Input.is_action_pressed("moveRight"):
		input_vector += camera.global_transform.basis.x * PAN_SPEED
	
	# Adjust the forward and backward movement based on the camera's Y-axis rotation
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

	# Handle rotation
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_rotating = event.pressed

	if is_rotating and event is InputEventMouseMotion:
		rotation_angle_x -= event.relative.y * ROTATION_SPEED
		rotation_angle_y -= event.relative.x * ROTATION_SPEED
		rotation_angle_x = clamp(rotation_angle_x, MIN_ROTATION_X, MAX_ROTATION_X)  # Clamping x rotation
		camera.rotation_degrees.x = rotation_angle_x
		camera.rotation_degrees.y = rotation_angle_y

	# Handle zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = clamp(camera.fov - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = clamp(camera.fov + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)

	# Handle tile clicking
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tile_click(event.position)

func _handle_tile_click(mouse_position):
	if placing_unit:
		print("Placing unit on tile...")
		place_unit_on_tile(mouse_position)
	else:
		var camera = $Camera3D
		var from = camera.project_ray_origin(mouse_position)
		var to = from + camera.project_ray_normal(mouse_position) * 50000

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = from
		query.to = to

		var result = space_state.intersect_ray(query)

		if result:
			var clicked_position = result.position
			var clicked_tile = _get_tile_with_tolerance(clicked_position)
			if clicked_tile:
				# Print the coordinates of the clicked tile to the console
				for coord in tiles.keys():
					var tile = tiles[coord]
					if tile == clicked_tile:
						print("Clicked tile coordinates: ", coord)
						break
				var current_material = clicked_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override
				if current_material == TILE_MATERIALS[0]:  # If currently blue
					clicked_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[2]  # Set to red
				else:
					clicked_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]  # Set back to blue

func _get_tile_with_tolerance(position, tolerance=0):
	var closest_tile = null
	var min_distance = INF
	for key in tiles.keys():
		var tile = tiles[key]
		var distance = tile.global_transform.origin.distance_to(position)
		if distance < min_distance + tolerance:
			min_distance = distance
			closest_tile = tile
	return closest_tile if min_distance < TILE_SIZE / 2 + tolerance else null

func _generate_grid():
	var tile_index := 0
	for x in range(-grid_size, grid_size + 1):
		var tile_coordinates := Vector2.ZERO
		tile_coordinates.x = x * TILE_SIZE * cos(deg_to_rad(30))
		tile_coordinates.y = 0 if x % 2 == 0 else TILE_SIZE / 2
		for y in range(-grid_size, grid_size + 1):
			var tile = HEX_TILE.instantiate()
			add_child(tile)

			# Adjust the tile's position so the top of the tile is at z=0
			tile.translate(Vector3(tile_coordinates.x, -TILE_HEIGHT, tile_coordinates.y))

			tiles[Vector2(x, y)] = tile
			tile_coordinates.y += TILE_SIZE
			# Set the default material to blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]
			tile_index += 1

func unitPlacer():
	# Set the flag and assign the unit to place
	unit_to_place = DataPasser.selectedUnit
	if unit_to_place:
		placing_unit = true
		print("Ready to place unit:", unit_to_place.name)

func place_unit_on_tile(mouse_position: Vector2):
	if placing_unit and unit_to_place:
		print("Placing unit...")
		var camera = $Camera3D
		var from = camera.project_ray_origin(mouse_position)
		var to = from + camera.project_ray_normal(mouse_position) * 50000

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = from
		query.to = to

		var result = space_state.intersect_ray(query)

		if result:
			var clicked_position = result.position
			var closest_tile = _get_tile_with_tolerance(clicked_position)
			if closest_tile:
				# Create and place the 3D model at the tile position
				print("Creating new unit model...")
				var new_model = Node3D.new()
				get_parent().add_child(new_model)
				new_model.set_script(load("res://combat/resources/unitAssembler.gd"))
				new_model.unitParts = unit_to_place
				new_model.assembleUnit()

				# Set the scale of the 3D model
				new_model.scale = unit_scale  # Apply the unit scale

				# Access the foot nodes using the full path
				var left_foot_node = new_model.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")
				var right_foot_node = new_model.get_node_or_null("chestPivot/rLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")

				if left_foot_node and right_foot_node:
					var left_foot_bbox = left_foot_node.get_aabb()
					var right_foot_bbox = right_foot_node.get_aabb()

					var lowest_y = min(left_foot_bbox.position.y, right_foot_bbox.position.y)

					new_model.position = closest_tile.global_transform.origin - Vector3(0, lowest_y - 1.45, 0)
				else:
					print("Foot nodes not found! Adjusting using the main bounding box.")
					# Fallback to use the main bounding box
					var bbox = new_model.get_aabb()
					new_model.position = closest_tile.global_transform.origin - Vector3(0, bbox.position.y, 0)
			else:
				print("No valid tile found for placement.")
		else:
			print("No raycast hit detected.")
	else:
		print("No unit to place or placing_unit flag is false.")
