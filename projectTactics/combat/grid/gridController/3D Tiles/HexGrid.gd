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

# Dictionary to store tile positions with coordinates as keys
var tiles = {}

func _ready():
	_generate_grid()

func _input(event):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera = get_viewport().get_camera_3d()
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 50000

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = from
		query.to = to

		var result = space_state.intersect_ray(query)

		if result:
			var clicked_position = result.position
			_handle_tile_click(clicked_position)

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


func _handle_tile_click(clicked_position):
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
