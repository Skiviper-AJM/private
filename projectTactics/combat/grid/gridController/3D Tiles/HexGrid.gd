extends Node3D

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),   # Blue material
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),    # Red material
	preload("res://combat/grid/gridController/3D Tiles/materials/yellow.tres"),
]

const TILE_SIZE := 1.0
const HEX_TILE = preload("res://combat/grid/gridController/3D Tiles/hex_tile.tscn")

@export_range(2, 35) var grid_size: int = 10

const PAN_SPEED := 10.0  # Speed at which the camera pans with WASD/Arrow keys
const ZOOM_SPEED := 1.5  # Speed at which the camera zooms
const MIN_ZOOM := 10.0   # Minimum FOV value for zoom
const MAX_ZOOM := 80.0   # Maximum FOV value for zoom
const ROTATION_SPEED := 0.050  # Speed of rotation when dragging the mouse
const MAX_ROTATION_ANGLE := 15.0  # Maximum rotation angle in degrees for x-axis

var is_rotating := false  # Whether the user is currently rotating the camera
var rotation_angle_x := -90.0  # Start with -90 degrees on the x-axis
var rotation_angle_y := 0.0  # Start with 0 degrees on the y-axis

# Dictionary to store tile positions with coordinates as keys
var tiles = {}

func _ready():
	_generate_grid()
	var camera = $Camera3D
	# Center it on the x-axis
	camera.position.x = 0
	
	# Calculate the middle of the grid on the z-axis
	var grid_center_z = 0  # or you could calculate it based on grid size
	
	# Center it on the z-axis
	camera.position.z = (grid_center_z + grid_size)
	
	# Set initial rotation
	camera.rotation_degrees.x = rotation_angle_x
	camera.rotation_degrees.y = rotation_angle_y

func _input(event):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera = $Camera3D
	
	# Handle WASD/Arrow keys for panning
	var input_vector := Vector3.ZERO
	
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"):
		input_vector.x -= PAN_SPEED
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"):
		input_vector.x += PAN_SPEED
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"):
		input_vector.z -= PAN_SPEED
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_backward"):
		input_vector.z += PAN_SPEED

	if input_vector != Vector3.ZERO:
		camera.position += camera.basis.xform(input_vector) * get_process_delta_time()

	# Handle mouse button inputs for camera rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_rotating = event.pressed  # Start or stop rotating

		# Handle mouse wheel for zooming
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.fov = clamp(camera.fov - ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.fov = clamp(camera.fov + ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Handle tile clicking
			_handle_tile_click(event.position)

	# Handle mouse motion for camera rotation
	if event is InputEventMouseMotion and is_rotating:
		rotation_angle_x = clamp(rotation_angle_x - event.relative.y * ROTATION_SPEED, -90 - MAX_ROTATION_ANGLE, -90 + MAX_ROTATION_ANGLE)
		rotation_angle_y -= event.relative.x * ROTATION_SPEED
		camera.rotation_degrees.x = rotation_angle_x
		camera.rotation_degrees.y = rotation_angle_y

func _generate_grid():
	var tile_index := 0
	for x in range(-grid_size, grid_size + 1):
		var tile_coordinates := Vector2.ZERO
		tile_coordinates.x = x * TILE_SIZE * cos(deg_to_rad(30))
		tile_coordinates.y = 0 if x % 2 == 0 else TILE_SIZE / 2
		for y in range(-grid_size, grid_size + 1):
			var tile = HEX_TILE.instantiate()
			add_child(tile)
			tile.translate(Vector3(tile_coordinates.x, 0, tile_coordinates.y))
			tiles[Vector2(x, y)] = tile
			tile_coordinates.y += TILE_SIZE
			# Set the default material to blue
			tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = TILE_MATERIALS[0]
			tile_index += 1

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
