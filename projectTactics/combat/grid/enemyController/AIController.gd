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
	
	var num_enemies = max_enemies
	print("Generating ", num_enemies, " enemies.")
	
	for i in range(num_enemies):
		print("Generating enemy ", i + 1)
		var enemy_unit = generate_random_enemy_instance()
		
		var tile_position = find_free_tile()
		if tile_position == Vector2(-1, -1):
			print("No suitable tile found for enemy placement.")
		else:
			print("Placing enemy at tile position: ", tile_position)
			grid_controller.enemy_place_unit_on_tile(tile_position, enemy_unit, false)

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
		if is_tile_in_bounds(tile_key) and not grid_controller.units_on_tiles.has(tile_key):
			free_tiles.append(tile_key)
	
	if free_tiles.size() == 0:
		print("No free tiles available.")
		return Vector2(-1, -1)
	
	var selected_tile_key = free_tiles[randi_range(0, free_tiles.size() - 1)]
	print("Selected free tile: ", selected_tile_key)
	return selected_tile_key

func is_tile_in_bounds(tile_key: Vector2) -> bool:
	print("Checking if tile is in bounds: ", tile_key)
	return abs(tile_key.x) <= grid_controller.grid_size and abs(tile_key.y) <= grid_controller.grid_size

func find_tiles_within_movement_range(enemy_unit: Node3D) -> Array:
	var reachable_tiles = []
	var speed_rating = enemy_unit.unitParts.speedRating
	print("Finding tiles within movement range for unit with speed: ", speed_rating)

	# Convert the Vector3 to Vector2 (x, z) and use it in _get_tile_with_tolerance
	var start_tile = _get_tile_with_tolerance(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))

	if start_tile == Vector2(-1, -1):
		print("Start tile not found.")
		return reachable_tiles

	print("Start tile found: ", start_tile)

	for x in range(-speed_rating, speed_rating + 1):
		for y in range(max(-speed_rating, -x - speed_rating), min(speed_rating, -x + speed_rating) + 1):
			var z = -x - y
			var target_tile_key = start_tile + Vector2(x, y)
			
			if grid_controller.tiles.has(target_tile_key):
				if not grid_controller.units_on_tiles.has(target_tile_key):
					reachable_tiles.append(target_tile_key)

	print("Reachable tiles found: ", reachable_tiles.size(), " for unit at ", start_tile)
	return reachable_tiles

func find_nearest_reachable_tile_to_player(enemy_unit: Node3D) -> Vector2:
	var nearest_player_position: Vector2 = Vector2()
	var nearest_player_tile: Vector2 = Vector2()
	var player_found = false

	print("=== Units on Tiles ===")
	for tile_key in grid_controller.units_on_tiles.keys():
		print("Tile Key: ", tile_key, " - Unit: ", grid_controller.units_on_tiles[tile_key])

	print("=== Tiles ===")
	for tile_key in grid_controller.tiles.keys():
		print("Tile Key: ", tile_key)
		if grid_controller.units_on_tiles.has(tile_key):  # Check if there is a unit on this tile
			var unit_on_tile = grid_controller.units_on_tiles[tile_key]
			print("Unit detected on tile ", tile_key, ": ", unit_on_tile, " (is enemy: ", unit_on_tile.is_in_group("enemy_units"), ")")
			if not unit_on_tile.is_in_group("enemy_units"):  # Ensure it's a player unit
				var player_position = Vector2(unit_on_tile.global_transform.origin.x, unit_on_tile.global_transform.origin.z)
				var distance = player_position.distance_to(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))
				print("Player unit found at ", tile_key, " with distance: ", distance)
				if not player_found or distance < nearest_player_position.distance_to(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z)):
					nearest_player_position = player_position
					nearest_player_tile = tile_key  # This should be a Vector2 tile key
					player_found = true

	if not player_found:
		print("No player unit found.")
		return Vector2(-1, -1)

	print("Nearest player unit found at: ", nearest_player_tile)

	# Find all reachable tiles within the enemy unit's speed range
	var reachable_tiles = find_tiles_within_movement_range(enemy_unit)
	if reachable_tiles.empty():
		print("No tiles within movement range.")
		return Vector2(-1, -1)

	# Find the nearest tile adjacent to the player unit
	var min_distance: float = INF
	var target_tile: Vector2 = Vector2(-1, -1)
	var adjacent_tiles = get_adjacent_tiles(nearest_player_tile)

	print("Finding adjacent tiles to the nearest player unit at: ", nearest_player_tile)

	for tile in adjacent_tiles:
		print("Checking adjacent tile: ", tile)
		if tile in reachable_tiles:
			var distance = tile.distance_to(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))
			print("Distance to adjacent tile ", tile, ": ", distance)
			if distance < min_distance:
				min_distance = distance
				target_tile = tile

	# If no adjacent tile is reachable, move as close as possible
	if target_tile == Vector2(-1, -1):
		for tile in reachable_tiles:
			var distance = tile.distance_to(nearest_player_tile)
			print("Checking tile: ", tile, " with distance to player: ", distance)
			if distance < min_distance:
				min_distance = distance
				target_tile = tile

	print("Target tile for enemy movement: ", target_tile)
	return target_tile

func take_turn_for_all_enemies():
	print("Taking turn for all enemies.")
	for tile_key in grid_controller.units_on_tiles.keys():
		var unit_instance = grid_controller.units_on_tiles[tile_key]
		print("Processing unit at tile: ", tile_key, " - Unit: ", unit_instance)
		if unit_instance.is_in_group("enemy_units"):
			var nearest_tile = find_nearest_reachable_tile_to_player(unit_instance)
			if nearest_tile != Vector2(-1, -1):
				print("Moving enemy unit to tile: ", nearest_tile)
				combat_manager.move_unit_to_tile(unit_instance, grid_controller.tiles[nearest_tile])
			else:
				print("No valid tile found for enemy movement.")
		else:
			print("Skipping non-enemy unit at tile: ", tile_key)

func on_end_turn():
	print("Ending turn, processing AI moves.")
	take_turn_for_all_enemies()

func get_adjacent_tiles(tile_key: Vector2) -> Array:
	print("Getting adjacent tiles for: ", tile_key)
	var adjacent_tiles = []
	var directions = [
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(1, -1),
		Vector2(-1, 1)
	]
	
	for direction in directions:
		var adjacent_tile_key = tile_key + direction
		print("Checking direction: ", direction, " - Resulting adjacent tile: ", adjacent_tile_key)
		if grid_controller.tiles.has(adjacent_tile_key):
			adjacent_tiles.append(adjacent_tile_key)

	print("Adjacent tiles found: ", adjacent_tiles)
	return adjacent_tiles

func _get_tile_with_tolerance(position: Vector2, tolerance=0) -> Vector2:
	print("Finding closest tile to position: ", position, " with tolerance: ", tolerance)
	var closest_tile: Node3D = null
	var min_distance: float = INF
	var closest_tile_coords: Vector2 = Vector2(-1, -1)  # Use a clearly out-of-bounds value
	
	for key in grid_controller.tiles.keys():
		var tile = grid_controller.tiles[key]
		var position_3d = Vector3(position.x, 0, position.y)
		var tile_global_position = tile.global_transform.origin
		var distance = tile_global_position.distance_to(position_3d)
		print("Checking tile at key: ", key, " - Distance: ", distance)
		
		if distance < min_distance + tolerance:
			min_distance = distance
			closest_tile = tile
			closest_tile_coords = key  # Update to the closest tile coordinates
	
	if closest_tile and min_distance < grid_controller.TILE_SIZE / 2 + tolerance:
		print("Closest tile coordinates found: ", closest_tile_coords)
		return closest_tile_coords
	else:
		print("No valid tile found or out of bounds for position: ", position)
		return Vector2(-1, -1)
