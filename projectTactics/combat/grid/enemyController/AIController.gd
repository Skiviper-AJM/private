extends Node

@export var unit_part_count: int = 4
@export var hex_grid: NodePath = "../HexGrid"

@onready var grid_controller = $"../HexGrid"
@onready var combat_manager = $"../combatManager"
@onready var root_node = $"../.."  # Get the 3DGrid node (parent of HexGrid)

@export var max_enemies: int = 2

const PURPLE_MATERIAL = preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")

@export var enemy_units: Array = []

func _ready():
	# Initialize enemy AI behavior here
	pass

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

	# Place any predefined enemies
	place_enemy_units()

func place_enemy_units():
	for enemy_data in enemy_units:
		var tile_position = enemy_data["tile_position"]
		var enemy_unit = enemy_data["enemy_unit"]

		if grid_controller.tiles.has(tile_position):
			grid_controller.enemy_place_unit_on_tile(tile_position, enemy_unit, false)
			print("Enemy unit placed on tile at: ", tile_position)
		else:
			print("Invalid tile position: ", tile_position, ". Could not place enemy unit.")

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
	var start_tile 
	print("Finding tiles within movement range for unit with speed: ", speed_rating)

	if enemy_unit != null:
		start_tile = _get_tile_with_tolerance(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))

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
	var nearest_player_tile = Vector2(-1, -1)
	var min_distance = INF

	if enemy_unit != null:
		# Find the nearest player unit
		for tile_key in grid_controller.units_on_tiles.keys():
			var unit_on_tile = grid_controller.units_on_tiles[tile_key]
			if unit_on_tile.is_in_group("player_units"):
				var tile_position = Vector2(tile_key.global_transform.origin.x, tile_key.global_transform.origin.z)
				var distance = tile_position.distance_to(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z))
				if distance < min_distance:
					min_distance = distance
					nearest_player_tile = tile_key

	if nearest_player_tile.tiles == Vector2(-1, -1):
		return Vector2(-1, -1) # Return a fallback if no player unit was found

	# Find the nearest tile adjacent to the player unit within movement range
	var reachable_tiles = find_tiles_within_movement_range(enemy_unit)
	var target_tile = Vector2(-1, -1)
	min_distance = INF

	for tile in reachable_tiles:
		var distance = tile.distance_to(nearest_player_tile)
		if distance < min_distance:
			min_distance = distance
			target_tile = tile

	return target_tile




func find_fallback_tile(enemy_unit: Node3D) -> Vector2:
	# Fallback logic when no player units are found
	if enemy_unit != null:
		var random_direction = Vector2(randi_range(-1, 1), randi_range(-1, 1))
		var fallback_tile = _get_tile_with_tolerance(Vector2(enemy_unit.global_transform.origin.x, enemy_unit.global_transform.origin.z) + random_direction)
		
		if grid_controller.tiles.has(fallback_tile) and not grid_controller.units_on_tiles.has(fallback_tile):
			print("Fallback tile chosen: ", fallback_tile)
			return fallback_tile

	print("No valid fallback tile found.")
	return Vector2(-1, -1)


func take_turn_for_all_enemies():
	print("Taking turn for all enemies.")
	for tile_coords in grid_controller.units_on_tiles.keys():
		var unit_instance = grid_controller.units_on_tiles[tile_coords]
		if unit_instance.is_in_group("enemy_units"):
			var nearest_tile = find_nearest_reachable_tile_to_player(unit_instance)
			if nearest_tile != Vector2(-1, -1):
				move_enemy_to_tile(unit_instance, nearest_tile)
				unit_instance.set_meta("moving", false)
	# Ensure player units can be selected after enemies move
	combat_manager.deselect_unit()


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

func move_enemy_to_tile(enemy_unit: Node3D, target_tile_position: Vector2):
	if grid_controller.tiles.has(target_tile_position):
		var target_tile = grid_controller.tiles[target_tile_position]
		
		if grid_controller.units_on_tiles.has(target_tile_position):
			print("Target tile already occupied by another unit.")
			return
		
		# Remove the unit from its current position
		var current_tile_position = grid_controller.units_on_tiles.find(enemy_unit)
		if current_tile_position != null:
			grid_controller.units_on_tiles.erase(current_tile_position)
		
		# Place the unit in the new position
		grid_controller.units_on_tiles[target_tile_position] = enemy_unit
		
		# Move the unit to the new tile
		enemy_unit.global_transform.origin = Vector3(target_tile.global_transform.origin.x, enemy_unit.global_transform.origin.y, target_tile.global_transform.origin.z)
		
		print("Enemy unit moved to new tile at: ", target_tile_position)
	else:
		print("Invalid target tile position: ", target_tile_position, ". Could not move enemy unit.")


func engage_combat():
	# Logic to engage in combat
	print("Engaging in combat with player units...")
	combat_manager.start_combat_with_enemies(enemy_units)
