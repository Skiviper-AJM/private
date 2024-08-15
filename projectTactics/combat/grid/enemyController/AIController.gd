extends Node

# Parameters you can adjust as needed
@export var max_enemies: int = 1
@export var unit_part_count: int = 4  # Number of parts in the unit (assuming it's consistent across all units)
@export var hex_grid: NodePath  # The path to your HexGrid node

@onready var grid_controller = $"../HexGrid"

# Called after the grid is generated
func _on_grid_generated():
	if grid_controller == null:
		print("HexGrid not found!")
		return
	
	var num_enemies = randi() % max_enemies + 1
	print("Generating ", num_enemies, " enemies.")
	
	for i in range(num_enemies):  # Generates between 1 and max_enemies
		print("Generating enemy ", i + 1)
		var enemy_unit = generate_random_enemy_instance()
		
		# Place enemy at fixed position (0,0)
		var tile_position = Vector2.ZERO
		print("Placing enemy at fixed position: ", tile_position)
		place_enemy_on_tile(enemy_unit, tile_position)

# Generates a random enemy instance using the unit resource
func generate_random_enemy_instance() -> Node3D:
	print("Creating new enemy unit instance...")
	
	# Create a new Node3D to act as the root for the unit
	var unit_instance = Node3D.new()
	
	# Apply the UnitAssembler script to this node
	unit_instance.set_script(load("res://combat/resources/unitAssembler.gd"))
	
	# Check if the unit assembler script is applied correctly
	if not unit_instance.has_method("assembleUnit"):
		print("Failed to load UnitAssembler script or assembleUnit method not found.")
		return null

	# Initialize unitParts with a new instance of your custom Unit resource
	unit_instance.unitParts = preload("res://combat/preassembledUnits/starterUnit.tres").duplicate()

	# Assemble the unit with random parts
	unit_instance.assembleUnit()
	
	# Verify that the hierarchy was created correctly
	if unit_instance.get_child_count() == 0:
		print("Error: UnitAssembler did not create any child nodes.")
		return null
	
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
	return part_instance

# Places the enemy on the chosen tile
func place_enemy_on_tile(enemy_unit: Node3D, tile: Vector2):
	# Use fixed position (0,0) for the tile
	var fixed_tile_position = Vector2.ZERO
	
	if grid_controller.tiles.has(fixed_tile_position):
		var target_tile = grid_controller.tiles[fixed_tile_position]
		
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
		print("Error: Tile not found in the grid for position: ", fixed_tile_position)
