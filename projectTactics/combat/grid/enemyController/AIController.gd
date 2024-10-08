extends Node

# Number of different parts available for each unit
@export var unit_part_count: int = 4
# Path to the HexGrid node in the scene
@export var hex_grid: NodePath = "../HexGrid"

# References to the HexGrid and 3DGrid nodes
@onready var grid_controller = $"../HexGrid"
@onready var root_node = $"../.."  # Reference to the 3DGrid node (parent of HexGrid)

# Maximum number of enemy units to generate
@export var max_enemies: int = 2

# Preload a material resource for use in the grid
const PURPLE_MATERIAL = preload("res://combat/grid/gridController/3D Tiles/materials/purple.tres")

# Called when the grid is generated, responsible for enemy unit placement
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

# Generate and assemble a random enemy unit
func generate_random_enemy_instance() -> Node3D:
	print("Creating new enemy unit instance...")
	var unit_instance = Node3D.new()
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))

	# Check if the unit instance has the necessary method for assembly
	if not unit_instance.has_method("assembleUnit"):
		print("Failed to load UnitAssembler script or assembleUnit method not found.")
		return null

	# Duplicate a preassembled unit and assign random parts
	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()

	unit_instance.unitParts.head = load_random_part("head")
	unit_instance.unitParts.arm = load_random_part("arm")
	unit_instance.unitParts.leg = load_random_part("leg")
	unit_instance.unitParts.chest = load_random_part("chest")
	unit_instance.unitParts.core = load_random_part("core")

	unit_instance.assembleUnit()

	# Verify that the unit was successfully assembled
	if unit_instance.get_child_count() == 0:
		print("Error: UnitAssembler did not create any child nodes.")
		return null

	print("Enemy unit created and assembled with random parts.")
	return unit_instance

# Load a random part for the unit based on the part name
func load_random_part(part_name: String) -> Resource:
	var part_variant = randi_range(1, unit_part_count)
	var part_path = "res://combat/parts/%s/unit%02d%s.tres" % [part_name, part_variant, part_name.capitalize()]
	print("Loading part from path: ", part_path)
	return load(part_path)

# Find a free tile on the grid where an enemy unit can be placed
func find_free_tile() -> Vector2:
	var free_tiles = []
	
	for tile_key in grid_controller.tiles.keys():
		# Add tile to list if it is within bounds and not occupied
		if is_tile_in_bounds(tile_key) and not grid_controller.units_on_tiles.has(tile_key):
			free_tiles.append(tile_key)
	
	# If no free tiles are found, return an invalid position
	if free_tiles.size() == 0:
		return Vector2(-1, -1)
	
	# Randomly select a free tile from the list
	var selected_tile_key = free_tiles[randi_range(0, free_tiles.size() - 1)]
	print("Selected free tile: ", selected_tile_key)
	
	return selected_tile_key

# Check if the specified tile is within the grid's boundaries
func is_tile_in_bounds(tile_key: Vector2) -> bool:
	return abs(tile_key.x) <= grid_controller.grid_size and abs(tile_key.y) <= grid_controller.grid_size
