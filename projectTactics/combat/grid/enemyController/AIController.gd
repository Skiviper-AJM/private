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
	var num_enemies = randi() % max_enemies + 1
	print("Generating ", num_enemies, " enemies.")
	
	for i in range(num_enemies):  # Generates between 1 and max_enemies
		print("Generating enemy ", i + 1)
		var enemy_unit = generate_random_enemy_instance()
		
		var tile = get_random_unoccupied_tile(occupied_tiles)
		if tile:
			occupied_tiles.append(tile)
			print("Placing enemy on tile: ", tile)
			place_enemy_on_tile(enemy_unit, tile)
		else:
			print("No available tile found for enemy ", i + 1)

# Generates a random enemy instance using the unit resource
func generate_random_enemy_instance() -> Node3D:
	print("Creating new enemy unit instance...")
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
	
	print("Enemy unit created and assembled.")
	
	return unit_instance

# Helper function to instantiate the part scene
func instantiate_part(part_type: String) -> Node3D:
	print("Instantiating part: ", part_type)
	var part_index = randi() % unit_part_count + 1
	var part_type_capitalized = part_type.capitalize()
	var part_scene = load("res://combat/parts/%s/unit%02d%s.tscn" % [part_type, part_index, part_type_capitalized])

	var part_instance = part_scene.instantiate()
	print("Part instantiated: ", part_instance)
	return part_instance  # Instantiate the scene

# Finds a random unoccupied tile
func get_random_unoccupied_tile(occupied_tiles: Array) -> Vector2:
	print("Fetching all tiles from grid...")
	var all_tiles = grid_controller.get_all_tiles()  # Assuming this returns an Array of tile nodes
	print("Total available tiles: ", all_tiles.size())

	var unoccupied_tiles = all_tiles.filter(func(tile): return !occupied_tiles.has(Vector2(round(tile.position.x), round(tile.position.z))))

	if unoccupied_tiles.size() > 0:
		var chosen_tile = unoccupied_tiles[randi() % unoccupied_tiles.size()]
		print("Chosen tile for enemy: ", chosen_tile)
		return Vector2(round(chosen_tile.position.x), round(chosen_tile.position.z))  # Convert Vector3 to Vector2 and round to nearest integer
	else:
		print("No unoccupied tiles found!")
	return Vector2.ZERO

# Places the enemy on the chosen tile
func place_enemy_on_tile(enemy_unit: Node3D, tile: Vector2):
	# Use rounded tile coordinates to find the tile in the dictionary
	var rounded_tile = Vector2(round(tile.x), round(tile.y))
	
	if grid_controller.tiles.has(rounded_tile):
		var target_tile = grid_controller.tiles[rounded_tile]
		
		# Scale the enemy unit appropriately
		enemy_unit.scale = grid_controller.unit_scale  # Use the same unit scale as the player's units
		
		# Access the foot nodes or the main geometry to get the bounding box
		var mesh_instance = enemy_unit.get_node_or_null("chestPivot/lLegPos/upperLegPivot/upperLeg/lowerLegPivot/lowerLeg/footPivot/foot")


		if mesh_instance:
			var bbox = mesh_instance.get_aabb()
			enemy_unit.position = target_tile.global_transform.origin - Vector3(0, bbox.position.y, 0)
		else:
			print("MeshInstance3D not found! Please check the path.")
			# Fallback if necessary, perhaps by using some default offset
			enemy_unit.position = target_tile.global_transform.origin
		
		# Add the enemy to the grid
		grid_controller.add_child(enemy_unit)
		
		print("Enemy unit placed on tile at position: ", enemy_unit.position)
	else:
		print("Error: Tile not found in the grid for position: ", rounded_tile)
