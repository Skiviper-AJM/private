extends Node

# Parameters you can adjust as needed
@export var max_enemies: int = 5
@export var unit_part_count: int = 4  # Number of parts in the unit (assuming it's consistent across all units)
@export var hex_grid: NodePath  # The path to your HexGrid node

@onready var grid_controller = $"../HexGrid"

# Called after the grid is generated
func _on_grid_generated():
	if grid_controller == null:
		print("HexGrid not found!")
		return
	
	var occupied_tiles = []

	for i in range(randi() % max_enemies + 1):  # Generates between 1 and max_enemies
		var enemy_unit = generate_random_enemy()
		
		var tile = get_random_unoccupied_tile(occupied_tiles)
		if tile:
			occupied_tiles.append(tile)
			place_enemy_on_tile(enemy_unit, tile)

# Generates a random enemy using the unitAssembler
func generate_random_enemy() -> Node:
	var unit_assembler = load("res://combat/resources/unitAssembler.gd").new()

	# Initialize unitParts with a new instance of your custom Unit resource
	unit_assembler.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()  # Replace with actual path to Unit.tres

	# Set up random parts for the unit
	unit_assembler.unitParts.head = load_part("head")
	unit_assembler.unitParts.body = load_part("chest")  # 'body' seems to be represented by 'chest' in your structure
	unit_assembler.unitParts.arm = load_part("arm")
	unit_assembler.unitParts.leg = load_part("leg")
	unit_assembler.unitParts.core = load_part("core")
	
	unit_assembler.assembleUnit()  # Assemble the unit
	return unit_assembler

# Helper function to instantiate the part scene
func load_part(part_type: String) -> Node:
	var part_index = randi() % unit_part_count + 1
	var part_type_capitalized = part_type.capitalize()  # Capitalize the first letter
	var part_resource = load("res://combat/parts/%s/unit%02d%s.tscn" % [part_type, part_index, part_type_capitalized])

	return part_resource.instantiate()  # Instantiate the scene


# Finds a random unoccupied tile
func get_random_unoccupied_tile(occupied_tiles: Array) -> Vector2:
	var all_tiles = grid_controller.get_all_tiles()  # Ensure this function exists in HexGrid.gd
	var unoccupied_tiles = all_tiles.filter(func(tile): return !occupied_tiles.has(tile))
	
	if unoccupied_tiles.size() > 0:
		return unoccupied_tiles[randi() % unoccupied_tiles.size()]
	return Vector2.ZERO

# Places the enemy on the chosen tile
func place_enemy_on_tile(enemy_unit: Node, tile: Vector2):
	enemy_unit.position = grid_controller.get_tile_position(tile)  # Ensure this function exists in HexGrid.gd
	grid_controller.add_child(enemy_unit)  # Adds the enemy to the HexGrid scene
