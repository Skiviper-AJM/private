extends Node

@export var max_enemies: int = 1
@export var unit_part_count: int = 4  # This would be the number of different variants you have for each part
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

	# Create a new unit instance
	var unit_instance = Node3D.new()
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))

	if not unit_instance.has_method("assembleUnit"):
		print("Failed to load UnitAssembler script or assembleUnit method not found.")
		return null

	# Load a blank Unit resource or duplicate the starter unit as a base
	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()

	# Randomize each part of the unit
	unit_instance.unitParts.head = load_random_part("head")
	unit_instance.unitParts.arm = load_random_part("arm")
	unit_instance.unitParts.leg = load_random_part("leg")
	unit_instance.unitParts.chest = load_random_part("chest")
	unit_instance.unitParts.core = load_random_part("core")

	unit_instance.assembleUnit()

	# Add the unit to the 'enemy_units' group
	unit_instance.add_to_group("enemy_units")

	if unit_instance.get_child_count() == 0:
		print("Error: UnitAssembler did not create any child nodes.")
		return null

	print("Enemy unit created and assembled with random parts.")
	return unit_instance


# Helper function to load a random part
func load_random_part(part_name: String) -> Resource:
	var part_variant = randi_range(1, unit_part_count)
	var part_path = "res://combat/parts/%s/unit%02d%s.tres" % [part_name, part_variant, part_name.capitalize()]
	print("Loading part from path: ", part_path)  # Debug print to check the path
	return load(part_path)





# Function to find a random free tile for placing an enemy
func find_free_tile() -> Vector2:
	var free_tiles = []
	
	# Collect all free tiles
	for tile_key in grid_controller.tiles.keys():
		if not grid_controller.units_on_tiles.has(tile_key):
			free_tiles.append(tile_key)
	
	# If there are no free tiles, return a fallback value
	if free_tiles.size() == 0:
		return Vector2(-1, -1)
	
	# Pick a random tile from the list of free tiles
	return free_tiles[randi_range(0, free_tiles.size() - 1)]


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
