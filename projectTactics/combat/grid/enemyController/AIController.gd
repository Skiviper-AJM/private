extends Node

@export var max_enemies: int = 10
@export var unit_part_count: int = 4
@export var hex_grid: NodePath = "../HexGrid"

@onready var grid_controller = $"../HexGrid"
@onready var root_node = $"../.."  # Get the 3DGrid node (parent of HexGrid)

const PURPLE_MATERIAL = preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")

func _on_grid_generated():
	if grid_controller == null:
		print("HexGrid not found!")
		return
	
	var num_enemies = randi() % max_enemies + 1
	print("Generating ", num_enemies, " enemies.")
	
	for i in range(num_enemies):
		print("Generating enemy ", i + 1)
		var enemy_unit = generate_random_enemy_instance()
		
		var tile_position = find_free_tile()
		if tile_position == Vector2(-1, -1):
			print("No suitable tile found for enemy placement.")
		else:
			print("Placing enemy at tile position: ", tile_position)
			place_enemy_on_tile(enemy_unit, tile_position)

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
		if not grid_controller.units_on_tiles.has(tile_key):
			free_tiles.append(tile_key)
	
	if free_tiles.size() == 0:
		return Vector2(-1, -1)
	
	return free_tiles[randi_range(0, free_tiles.size() - 1)]

func place_enemy_on_tile(enemy_unit: Node3D, tile_position: Vector2):
	if grid_controller.tiles.has(tile_position):
		var target_tile = grid_controller.tiles[tile_position]
		
		# Check if the tile is already occupied by another unit
		if grid_controller.units_on_tiles.has(tile_position):
			print("Tile at position ", tile_position, " is already occupied. Cannot place enemy.")
			return
		
		enemy_unit.scale = grid_controller.unit_scale

		var left_foot_node = enemy_unit.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")
		var right_foot_node = enemy_unit.get_node_or_null("chestPivot/rLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")

		if left_foot_node and right_foot_node:
			var left_foot_bbox = left_foot_node.get_aabb()
			var right_foot_bbox = right_foot_node.get_aabb()
			var lowest_y = min(left_foot_bbox.position.y, right_foot_bbox.position.y)
			enemy_unit.position = target_tile.global_transform.origin - Vector3(0, lowest_y - 1.1, 0)
		else:
			enemy_unit.position = target_tile.global_transform.origin - Vector3(0, 1.1, 0)
		
		# Add the enemy unit as a child of the 3DGrid node
		grid_controller.add_child(enemy_unit)
		
		# Mark the tile as occupied by this enemy
		grid_controller.units_on_tiles[tile_position] = enemy_unit
		
		# Add to enemy units group after adding to the scene tree
		enemy_unit.add_to_group("enemy_units")

		# Verify that the unit was correctly added to the group
		if enemy_unit.is_in_group("enemy_units"):
			print("Enemy unit successfully added to 'enemy_units' group.")
		else:
			print("Failed to add enemy unit to 'enemy_units' group.")

		target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = PURPLE_MATERIAL
		print("Enemy unit placed on tile at position: ", tile_position, " with coordinates: ", target_tile.global_transform.origin)
	else:
		print("Error: Tile not found in the grid for position: ", tile_position)
