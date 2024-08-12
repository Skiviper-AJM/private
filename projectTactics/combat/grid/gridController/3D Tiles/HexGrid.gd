extends Node3D

const TILE_MATERIALS = [
	preload("res://combat/grid/gridController/3D Tiles/materials/blue.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/green.tres"),
	preload("res://combat/grid/gridController/3D Tiles/materials/red.tres"),
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
			_print_tile_coordinates(clicked_position)
		else:
			print("No hit detected.")

			
func _generate_grid():
	var tile_index := 0
	for x in range(grid_size):
		var tile_coordinates := Vector2.ZERO
		tile_coordinates.x = x * TILE_SIZE * cos(deg_to_rad(30))
		tile_coordinates.y = 0 if x % 2 == 0 else TILE_SIZE / 2
		for y in range(grid_size):
			var tile = HEX_TILE.instantiate()
			add_child(tile)
			tile.translate(Vector3(tile_coordinates.x, 0, tile_coordinates.y))
			tiles[Vector2(x, y)] = tile
			tile_coordinates.y += TILE_SIZE
			tile.get_node("CollisionShape3D/unit_hex/mergedBlocks(Clone)").material_override = get_tile_material(tile_index)
			tile_index += 1
			
func _handle_click(screen_position):
	var from = get_viewport().get_camera_3d().project_ray_origin(screen_position)
	var to = from + get_viewport().get_camera_3d().project_ray_normal(screen_position) * 1000
	var space_state = get_world_3d().direct_space_state
	
	# Create a new PhysicsRayQueryParameters3D object
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		var clicked_position = result.collider.global_transform.origin
		_print_tile_coordinates(clicked_position)

func _print_tile_coordinates(position):
	for coord in tiles:
		var tile = tiles[coord]
		if tile.global_transform.origin.distance_to(position) < TILE_SIZE / 2:
			print("Tile Coordinates: ", coord)
			break

func get_tile_material(tile_index: int):
	var index = tile_index % TILE_MATERIALS.size()
	return TILE_MATERIALS[index]
