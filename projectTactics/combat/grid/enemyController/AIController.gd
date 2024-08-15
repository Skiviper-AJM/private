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
		var enemy_unit = generate_random_enemy_instance()
		
		var tile = get_random_unoccupied_tile(occupied_tiles)
		if tile:
			occupied_tiles.append(tile)
			place_enemy_on_tile(enemy_unit, tile)

# Generates a random enemy instance using the unit resource
func generate_random_enemy_instance() -> Node3D:
	# Create a new Node3D to act as the root for the unit
	var unit_instance = Node3D.new()
	
	# Apply the unitAssembler script to this node
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))
	
	# Initialize unitParts with a new instance of your custom Unit resource
	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()

	# Set up random parts for the unit, assuming unitParts expects Node3D instances
	unit_instance.unitParts.head = instantiate_part("head")
	unit_instance.unitParts.chest = instantiate_part("chest")
	unit_instance.unitParts.arm = instantiate_part("arm")
	unit_instance.unitParts.leg = instantiate_part("leg")
	unit_instance.unitParts.core = instantiate_part("core")
	
	# Assemble the unit with random parts
	unit_instance.assembleUnit()
	
	return unit_instance

# Helper function to instantiate the part scene
func instantiate_part(part_type: String) -> Node3D:
	var part_index = randi() % unit_part_count + 1
	var part_type_capitalized = part_type.capitalize()
	var part_scene = load("res://combat/parts/%s/unit%02d%s.tscn" % [part_type, part_index, part_type_capitalized])

	return part_scene.instantiate()  # Instantiate the scene


# Finds a random unoccupied tile
func get_random_unoccupied_tile(occupied_tiles: Array) -> Vector2:
	var all_tiles = grid_controller.get_all_tiles()  # Assuming this returns an Array of tile nodes
	var unoccupied_tiles = all_tiles.filter(func(tile): return !occupied_tiles.has(Vector2(tile.position.x, tile.position.z)))

	if unoccupied_tiles.size() > 0:
		var chosen_tile = unoccupied_tiles[randi() % unoccupied_tiles.size()]
		return Vector2(chosen_tile.position.x, chosen_tile.position.z)  # Convert Vector3 to Vector2
	return Vector2.ZERO




func place_enemy_on_tile(enemy_unit: Node3D, tile: Vector2):
	if grid_controller.tiles.has(tile):
		var target_tile = grid_controller.tiles[tile]
		enemy_unit.position = target_tile.global_transform.origin  # Directly use the tile's position
		grid_controller.add_child(enemy_unit)  # Adds the enemy to the HexGrid scene
	else:
		print("Error: Tile not found in the grid!")
