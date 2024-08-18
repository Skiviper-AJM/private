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

func take_enemy_turns():
	var player_units = grid_controller.placed_units_queue  # Queue of player units
	
	for tile_key in grid_controller.units_on_tiles.keys():
		if grid_controller.units_on_tiles.has(tile_key):
			var enemy_unit = grid_controller.units_on_tiles[tile_key]
			if enemy_unit.is_in_group("enemy_units"):
				move_and_attack_nearest_player(enemy_unit, player_units)
		else:
			print("Invalid tile key or tile not found in units_on_tiles:", tile_key)



func move_and_attack_nearest_player(enemy_unit: Node3D, player_units):
	var nearest_player_unit = find_nearest_player_unit(enemy_unit, player_units)
	if nearest_player_unit == null:
		return  # No player units found

	var target_tile_position = find_closest_unoccupied_tile(enemy_unit, nearest_player_unit)
	if target_tile_position != null:
		move_enemy_unit_to_tile(enemy_unit, target_tile_position)
		
		# Check if the enemy is within range to attack the player unit
		if is_within_attack_range(enemy_unit, nearest_player_unit):
			attack_player_unit(enemy_unit, nearest_player_unit)
	else:
		print("No valid tile to move to for enemy:", enemy_unit.name)



func find_nearest_player_unit(enemy_unit: Node3D, player_units) -> Node3D:
	var min_distance = INF
	var nearest_unit = null
	
	# Check if there are any player units on the map
	if grid_controller.placed_units_queue.is_empty():
		print("No player units on the map. No valid target.")
		return null

	for player_unit in player_units:
		if not is_instance_valid(player_unit):
			continue  # Skip this unit if it is no longer valid (i.e., has been freed)

		var distance = enemy_unit.global_transform.origin.distance_to(player_unit.global_transform.origin)
		if distance < min_distance:
			min_distance = distance
			nearest_unit = player_unit
			
	return nearest_unit


func find_closest_unoccupied_tile(enemy_unit: Node3D, target_unit: Node3D) -> Vector2:
	var min_distance = INF
	var target_tile = null
	
	# Check if there are any player units on the map
	if grid_controller.placed_units_queue.is_empty():
		print("No player units on the map. No valid target tile.")
		return Vector2(-1, -1)


	# Get the coordinates of the player unit
	print(grid_controller._get_tile_with_tolerance(Vector2(target_unit.global_transform.origin.x, target_unit.global_transform.origin.z)))
	var player_tile = grid_controller.out_coords

	# Calculate the six adjacent tiles around the player
	var adjacent_tiles = [
		Vector2(player_tile.x + 1, player_tile.y),
		Vector2(player_tile.x + 1, player_tile.y - 1),
		Vector2(player_tile.x, player_tile.y - 1),
		Vector2(player_tile.x - 1, player_tile.y),
		Vector2(player_tile.x - 1, player_tile.y + 1),
		Vector2(player_tile.x, player_tile.y + 1)
	]

	print("Checking adjacent tiles for enemy:", enemy_unit.name, "with target:", target_unit.name)

	# Check for the closest unoccupied adjacent tile
	for tile_key in adjacent_tiles:
		if is_tile_in_bounds(tile_key) and not grid_controller.units_on_tiles.has(tile_key):
			var tile_position = grid_controller.tiles[tile_key].global_transform.origin
			var distance = enemy_unit.global_transform.origin.distance_to(tile_position)
			print("Checking tile at position:", tile_position, " Distance:", distance)
			if distance < min_distance:
				min_distance = distance
				target_tile = tile_key
		else:
			print("Tile at position:", tile_key, "is occupied or out of bounds.")

	if target_tile == null:
		print("No valid tile found for enemy:", enemy_unit.name)
	else:
		print("Found valid tile for enemy:", enemy_unit.name, " at position:", target_tile)
	
	return target_tile

func is_within_attack_range(attacker: Node3D, target: Node3D) -> bool:
	var distance = attacker.global_transform.origin.distance_to(target.global_transform.origin) / grid_controller.TILE_SIZE
	return distance <= attacker.unitParts.range

func attack_player_unit(attacker: Node3D, target: Node3D):
	target.unitParts.armorRating -= attacker.unitParts.damage
	print("Player unit took damage! Remaining armor:", target.unitParts.armorRating)
	if target.unitParts.armorRating <= 0:
		print("Player unit destroyed!")
		combat_manager.remove_unit_from_map(target, grid_controller._get_tile_with_tolerance(Vector2(target.global_transform.origin.x, target.global_transform.origin.z)))
		
func get_adjacent_tiles(unit: Node3D) -> Array:
	var adjacent_tiles = []

	# Convert the unit's position to a Vector2
	var unit_tile = grid_controller._get_tile_with_tolerance(Vector2(unit.global_transform.origin.x, unit.global_transform.origin.z))
	
	if unit_tile != null:
		var directions = [
			Vector2(1, 0), Vector2(-1, 0),
			Vector2(0.5, -1), Vector2(-0.5, 1),
			Vector2(-0.5, -1), Vector2(0.5, 1)
		]

		for direction in directions:
			# Convert the unit_tile's global_transform.origin to a Vector2
			var unit_tile_position = Vector2(unit_tile.global_transform.origin.x, unit_tile.global_transform.origin.z)
			
			# Calculate the adjacent tile's position as a Vector2
			var adjacent_tile_position = unit_tile_position + direction * grid_controller.TILE_SIZE
			
			# Find the adjacent tile using the calculated position
			var adjacent_tile = grid_controller._get_tile_with_tolerance(adjacent_tile_position)
			
			if adjacent_tile != null:
				adjacent_tiles.append(adjacent_tile)
	
	return adjacent_tiles

func move_enemy_unit_to_tile(enemy_unit: Node3D, target_tile_position: Vector2):
	if not enemy_unit is Node3D:
		print("Error: enemy_unit is not a Node3D instance. Cannot move it.")
		return

	# Find the Node3D instance for the target tile using the position
	var target_tile = grid_controller.tiles.get(target_tile_position)
	
	if not target_tile:
		print("Error: Target tile at position ", target_tile_position, " not found.")
		return

	# Use the existing move_unit_to_tile logic
	combat_manager.move_unit_to_tile(enemy_unit, target_tile)
