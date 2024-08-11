extends Node2D

@export var grid_width:int = 20
@export var grid_height:int = 10
@export var hex_radius:float = 70
@export var zoom_speed:float = 0.1  # Speed of zooming
@export var min_zoom:float = 0.5  # Minimum zoom level
@export var max_zoom:float = 2.0  # Maximum zoom level

var dragging = false
var drag_start_position = Vector2()

var grid_container: Node2D

func _input(event):
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

func _ready():
	grid_container = Node2D.new()
	add_child(grid_container)
	generate_grid()

func generate_grid():
	var hex_width = sqrt(3) * hex_radius
	var hex_height = hex_radius * 2

	# Calculate the total grid size
	var grid_width_px = grid_width * hex_width
	var grid_height_px = grid_height * hex_height * 0.75

	# Center the grid on the screen
	var screen_center = get_viewport().get_visible_rect().size / 2
	var grid_center = Vector2(grid_width_px, grid_height_px) / 2
	var start_position = screen_center - grid_center

	for x in range(grid_width):
		for y in range(grid_height):
			var hex_x = start_position.x + x * hex_width + (y % 2) * (hex_width / 2)
			var hex_y = start_position.y + y * hex_height * 0.75
			
			var hex_cell = create_hex_cell(Vector2(hex_x, hex_y))
			grid_container.add_child(hex_cell)

func create_hex_cell(position: Vector2) -> Sprite2D:
	var hex_cell = Sprite2D.new()
	hex_cell.position = position
	hex_cell.texture = preload("res://combat/grid/gridController/Tiles/stone_03.png")
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

func changeScene(newScene):
	get_tree().change_scene_to_file(newScene)
