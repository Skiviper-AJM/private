extends Node


@export var unit_part_count: int = 4
@export var hex_grid: NodePath = "../HexGrid"

@onready var grid_controller = $"../HexGrid"
@onready var combat_manager = $"../combatManager"
@onready var root_node = $"../.."  # Get the 3DGrid node (parent of HexGrid)

@export var max_enemies: int = 2

const PURPLE_MATERIAL = preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")

func _on_grid_generated():
	if grid_controller == null:
		print("HexGrid not found!")
		return
	
	var num_enemies = max_enemies #randi() % max_enemies + 1
	print("Generating ", num_enemies, " enemies.")
	
	for i in range(num_enemies):
		print("Generating enemy ", i + 1)
		var enemy_unit = generate_random_enemy_instance()
		
		var tile_position = find_free_tile()
		if tile_position == Vector2(-1, -1):
			print("No suitable tile found for enemy placement.")
		else:
			print("Placing enemy at tile position: ", tile_position)
			grid_controller.enemy_place_unit_on_tile(tile_position, enemy_unit, false) # Passing `false` to indicate it's an enemy unit

func generate_random_enemy_instance() -> Node3D:
	print("Creating new enemy unit instance...")
	var unit_instance = Node3D.new()
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))

	if not unit_instance.has_method("assembleUnit"):
		print("Failed to load UnitAssembler script or assembleUnit method not found.")
		return null

	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()

	unit_instance.unitParts.head = load_random_part("head")
	unit_instance.unitParts.arm = load_random_part("arm")
	unit_instance.unitParts.leg = load_random_part("leg")
	unit_instance.unitParts.chest = load_random_part("chest")
	unit_instance.unitParts.core = load_random_part("core")

	unit_instance.assembleUnit()

	# Check if the unit has been successfully assembled
	if unit_instance.get_child_count() == 0:
		print("Error: UnitAssembler did not create any child nodes.")
		return null

	print("Enemy unit created and assembled with random parts.")
	return unit_instance

func load_random_part(part_name: String) -> Resource:
	var part_variant = randi_range(1, unit_part_count)
	var part_path = "res://combat/parts/%s/unit%02d%s.tres" % [part_name, part_variant, part_name.capitalize()]
	print("Loading part from path: ", part_path)
	return load(part_path)

func find_free_tile() -> Vector2:
	var free_tiles = []
	
	for tile_key in grid_controller.tiles.keys():
		# Check if the tile is within valid grid bounds and not occupied by any unit
		if is_tile_in_bounds(tile_key) and not grid_controller.units_on_tiles.has(tile_key):
			free_tiles.append(tile_key)
	
	if free_tiles.size() == 0:
		return Vector2(-1, -1)
	
	# Randomly select a tile from the free tiles list
	var selected_tile_key = free_tiles[randi_range(0, free_tiles.size() - 1)]
	print("Selected free tile: ", selected_tile_key)
	
	# Directly return the selected tile key without tolerance check
	return selected_tile_key

func is_tile_in_bounds(tile_key: Vector2) -> bool:
	# Ensure the tile is within grid bounds
	return abs(tile_key.x) <= grid_controller.grid_size and abs(tile_key.y) <= grid_controller.grid_size

func find_tiles_within_movement_range(enemy_unit: Node3D) -> Array:
	var reachable_tiles = []
	var speed_rating = enemy_unit.unitParts.speedRating
	print("Finding tiles within movement range: ", speed_rating)

	for tile_key in grid_controller.tiles.keys():
		if not grid_controller.units_on_tiles.has(tile_key):
			var tile_position = grid_controller.tiles[tile_key].global_transform.origin
			var distance_in_tiles = enemy_unit.global_transform.origin.distance_to(tile_position) / grid_controller.TILE_SIZE
			if distance_in_tiles <= speed_rating:
				reachable_tiles.append(tile_key)

	print("Reachable tiles found: ", reachable_tiles.size())
	return reachable_tiles

func find_nearest_tile_to_player(unit_instance: Node3D) -> Array:
	var player_position: Vector3 = Vector3()
	var player_tile: Vector2 = Vector2()
	var player_found = false

	# Find the tile of the nearest non-enemy unit
	for tile_key in grid_controller.units_on_tiles.keys():
		var unit_on_tile = grid_controller.units_on_tiles[tile_key]
		print("Unit on tile: ", unit_on_tile, "Groups: ", unit_on_tile.get_groups())

		# Check if the unit is not in the enemy group
		if not unit_on_tile.is_in_group("enemy_units"):
			player_position = unit_on_tile.global_transform.origin
			if typeof(tile_key) == TYPE_VECTOR2:
				player_tile = tile_key  # Safely assign if tile_key is a Vector2
				player_found = true
				break

	if not player_found:
		print("No non-enemy unit found.")
		return []

	var closest_tiles: Array = []
	var candidate_tiles: Array = []

	# Attempt to move to adjacent tiles around the identified unit
	var adjacent_positions = [
		player_tile + Vector2(-1, 0),
		player_tile + Vector2(1, 0),
		player_tile + Vector2(0, -1),
		player_tile + Vector2(0, 1),
		player_tile + Vector2(-1, -1),
		player_tile + Vector2(1, 1)
	]

	for adj_pos in adjacent_positions:
		if grid_controller.tiles.has(adj_pos) and not grid_controller.units_on_tiles.has(adj_pos):
			candidate_tiles.append(grid_controller.tiles[adj_pos])

	if candidate_tiles.size() > 0:
		closest_tiles.append(candidate_tiles[0])  # Pick the first available tile for now

	return closest_tiles



func take_turn_for_all_enemies():
	for tile_key in grid_controller.units_on_tiles.keys():
		var unit_instance = grid_controller.units_on_tiles[tile_key]
		if unit_instance.is_in_group("enemy_units"):
			var nearest_tiles = find_nearest_tile_to_player(unit_instance)
			
			# Add randomness to the selection of the nearest tile
			if nearest_tiles.size() > 0:
				var target_tile = nearest_tiles[randi() % nearest_tiles.size()]
				if target_tile:
					print("Moving enemy unit to tile: ", target_tile)
					combat_manager.move_unit_to_tile(unit_instance, target_tile)
				else:
					print("No valid tile found for enemy movement.")
			else:
				print("No valid tiles found near a non-enemy unit.")
