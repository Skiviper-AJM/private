extends Node

@export var max_enemies: int = 1
@export var unit_part_count: int = 4
@export var hex_grid: NodePath = "../HexGrid"  # Path to HexGrid node

@onready var grid_controller = get_node(hex_grid)

# Purple material for tiles occupied by enemies
const PURPLE_MATERIAL = preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")

# Called after the grid is generated
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

# Generates a random enemy instance using the unit resource
func generate_random_enemy_instance() -> Node3D:
	print("Creating new enemy unit instance...")
	
	var unit_instance = Node3D.new()
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))
	
	if not unit_instance.has_method("assembleUnit"):
		print("Failed to load UnitAssembler script or assembleUnit method not found.")
		return null

	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()
	unit_instance.assembleUnit()
	
	if unit_instance.get_child_count() == 0:
		print("Error: UnitAssembler did not create any child nodes.")
		return null
	
	print("Enemy unit created and assembled.")
	return unit_instance

# Function to find a free tile for placing an enemy
func find_free_tile() -> Vector2:
	for tile_key in grid_controller.tiles.keys():
		if not grid_controller.units_on_tiles.has(tile_key):
			return tile_key
	return Vector2(-1, -1)  # Fallback value if no free tile is found

# Places the enemy on the chosen tile
func place_enemy_on_tile(enemy_unit: Node3D, tile: Vector2):
	if grid_controller.tiles.has(tile):
		var target_tile = grid_controller.tiles[tile]
		
		enemy_unit.scale = grid_controller.unit_scale  # Use the same unit scale as the player's units

		# Access the foot nodes or the main geometry to get the bounding box
		var left_foot_node = enemy_unit.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")
		var right_foot_node = enemy_unit.get_node_or_null("chestPivot/rLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")

		if left_foot_node and right_foot_node:
			var left_foot_bbox = left_foot_node.get_aabb()
			var right_foot_bbox = right_foot_node.get_aabb()
			var lowest_y = min(left_foot_bbox.position.y, right_foot_bbox.position.y)
			enemy_unit.position = target_tile.global_transform.origin - Vector3(0, lowest_y - 1.1, 0)
		else:
			print("Foot nodes not found! Adjusting using a default offset.")
			enemy_unit.position = target_tile.global_transform.origin - Vector3(0, 1.1, 0)  # Fallback position adjustment
		
		grid_controller.add_child(enemy_unit)
		
		target_tile.get_node("unit_hex/mergedBlocks(Clone)").material_override = PURPLE_MATERIAL
		
		grid_controller.units_on_tiles[tile] = enemy_unit
		
		print("Enemy unit placed on tile at position: ", enemy_unit.position)
	else:
		print("Error: Tile not found in the grid for position: ", tile)

# Override input handling to prevent player interaction with tiles occupied by enemies
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_position = event.position
		var clicked_tile = grid_controller._get_tile_with_tolerance(mouse_position)

		if clicked_tile and grid_controller.units_on_tiles.has(clicked_tile):
			var unit_on_tile = grid_controller.units_on_tiles[clicked_tile]
			
			if unit_on_tile != null and unit_on_tile.get_script().get_path() == "res://combat/resources/unitAssembler.gd":
				print("Tile with an enemy unit clicked. Blocking interaction.")
				return
