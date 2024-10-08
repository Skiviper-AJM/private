extends CanvasLayer

@export var grid_width:int = 1500
@export var grid_height:int = 1500
@export var hex_radius:float = 70
@export var zoom_speed:float = 0.1  # Speed of zooming
@export var min_zoom:float = 0.5  # Minimum zoom level
@export var max_zoom:float = 2.0  # Maximum zoom level

var dragging = false
var drag_start_position = Vector2()
var placing_unit = false  # Flag to indicate unit placement mode
var unit_to_place = null  # Reference to the unit to be placed

var grid_container: Node2D
var grid_tiles = {}  # Track the extra tiles added by the user

func _input(event):
	if Input.is_action_just_pressed("pause"): 
		if DataPasser.selectedUnit != null: 
			unitPlacer()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Handle middle-click drag
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				dragging = true
				drag_start_position = event.position
			else:
				dragging = false

	if dragging and event is InputEventMouseMotion:
		var offset = event.relative
		grid_container.position += offset

	# Handle zoom with scroll wheel only
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out(event.position)

	# Handle tile click (left-click for adding tiles or placing units)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placing_unit and unit_to_place:
			place_unit_on_tile(event.position)
		else:
			handle_tile_click(event.position, "add")
	
	# Handle right-click for removing tiles
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		handle_tile_click(event.position, "remove")

func _ready():
	set_physics_process(false)

	grid_container = Node2D.new()
	grid_container.z_index = -1  # Set the z_index to ensure it renders behind everything else
	add_child(grid_container)

	# Center the grid container
	var viewport_size = get_viewport().get_visible_rect().size
	var center_offset = viewport_size / 2
	grid_container.position = center_offset
	
	generate_grid()

func generate_grid():
	var hex_width = sqrt(3) * hex_radius
	var hex_height = hex_radius * 2

	# Generate tiles evenly in all directions
	for x in range(-grid_width / 2, grid_width / 2 + 1):
		for y in range(-grid_height / 2, grid_height / 2 + 1):
			var hex_x = x * hex_width + (y % 2) * (hex_width / 2)
			var hex_y = y * hex_height * 0.75
			
			var hex_position = Vector2(hex_x, hex_y)
			var hex_cell = create_hex_cell(hex_position)
			grid_container.add_child(hex_cell)

			# Initialize grid_tiles with empty lists for each position
			grid_tiles[hex_position] = []

func create_hex_cell(position: Vector2) -> Sprite2D:
	var hex_cell = Sprite2D.new()
	hex_cell.position = position
	hex_cell.texture = preload("res://combat/grid/gridController/Tiles/stone_03.png")
	hex_cell.z_index = -1  # Set z_index for each hex cell to ensure it's behind other objects
	return hex_cell

func zoom_in(mouse_position: Vector2):
	if grid_container.scale.x < max_zoom:
		adjust_zoom(zoom_speed, mouse_position)

func zoom_out(mouse_position: Vector2):
	if grid_container.scale.x > min_zoom:
		adjust_zoom(-zoom_speed, mouse_position)

func adjust_zoom(zoom_amount: float, mouse_position: Vector2):
	var old_scale = grid_container.scale
	grid_container.scale += Vector2(zoom_amount, zoom_amount)
	var zoom_factor = grid_container.scale.x / old_scale.x

	# Adjust position to keep the zoom centered on the middle
	var container_to_mouse = mouse_position - grid_container.position
	var adjusted_position = grid_container.position - container_to_mouse * (zoom_factor - 1)
	grid_container.position = adjusted_position

func handle_tile_click(mouse_position: Vector2, action: String):
	var local_position = grid_container.to_local(mouse_position)
	
	# Find the closest tile by distance 
	var closest_tile_position: Vector2 = Vector2(INF, INF)
	var min_distance = INF

	for position in grid_tiles.keys():
		var distance = position.distance_to(local_position)
		if distance < min_distance:
			min_distance = distance
			closest_tile_position = position

	if closest_tile_position != Vector2(INF, INF):
		if action == "add":
			add_tile_on_top(closest_tile_position)
		elif action == "remove":
			remove_tile(closest_tile_position)

func add_tile_on_top(position: Vector2):
	# Create a new tile at the position if none exists there
	if grid_tiles[position].size() == 0:
		var new_tile = Sprite2D.new()
		new_tile.position = position
		new_tile.texture = preload("res://combat/grid/gridController/Tiles/stone_04.png")  # Change texture for the new tile
		new_tile.z_index = -1  # Ensure new tiles are behind other objects

		# Add the new tile to the container and store it in the grid_tiles dictionary
		grid_container.add_child(new_tile)
		grid_tiles[position].append(new_tile)

		# Print the grid position of the new tile
		print_grid_position(position, "Added at ")

func remove_tile(position: Vector2):
	if grid_tiles[position].size() > 0:
		# Remove the topmost tile from the grid
		var tile_to_remove = grid_tiles[position].pop_back()
		grid_container.remove_child(tile_to_remove)
		tile_to_remove.queue_free()

		# Print the grid position of the removed tile
		print_grid_position(position, "Deleted at ")

func print_grid_position(position: Vector2, action: String):
	# Convert the pixel position back to grid coordinates
	var hex_width = sqrt(3) * hex_radius
	var hex_height = hex_radius * 2
	var grid_x = floor(round_to_nearest_half(position.x / hex_width))
	var grid_y = (round_to_nearest_half(position.y / (hex_height * 0.75)))
	print(action, "Grid Position: (", grid_x, ",", grid_y, ")")

func round_to_nearest_half(value: float) -> float:
	return round(value * 2) / 2.0

func unitPlacer():
	# Set the flag and assign the unit to place
	unit_to_place = DataPasser.selectedUnit
	if unit_to_place:
		placing_unit = true
		#print("Ready to place unit:", unit_to_place.name)

func place_unit_on_tile(mouse_position: Vector2):
	var local_position = grid_container.to_local(mouse_position)
	
	# Find the closest tile by distance
	var closest_tile_position: Vector2 = Vector2(INF, INF)
	var min_distance = INF

	for position in grid_tiles.keys():
		var distance = position.distance_to(local_position)
		if distance < min_distance:
			min_distance = distance
			closest_tile_position = position

	if closest_tile_position != Vector2(INF, INF) and unit_to_place:
		# Create and place the 3D model at the tile position
		print(str(get_parent()))
		
		var newModel = Node3D.new()
		get_parent().add_child(newModel)
		newModel.set_script(load("res://combat/resources/unitAssembler.gd"))
		newModel.unitParts = unit_to_place
		newModel.assembleUnit()

		# Position the 3D model at the center of the selected tile
		newModel.position = Vector3(closest_tile_position.x, 1, closest_tile_position.y)

		# Stop unit placement mode after placing the unit
		placing_unit = false
		unit_to_place = null

		# Print the grid position where the unit was placed
		print_grid_position(closest_tile_position, "Unit placed at ")

