extends Node2D

@export var grid_width:int = 10
@export var grid_height:int = 10
@export var hex_radius:float = 50.0

var dragging = false
var drag_start_position = Vector2()

var grid_container: Node2D

func _input(event):
	if Input.is_action_just_pressed("DeleteGrid"):
		changeScene(DataPasser.priorScene)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			dragging = true
			drag_start_position = event.position
		else:
			dragging = false

	if dragging and event is InputEventMouseMotion:
		var offset = event.relative
		grid_container.position += offset

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
	hex_cell.texture = preload("res://combat/grid/gridController/stone_02.png")
	return hex_cell
	
func changeScene(newScene):
	get_tree().change_scene_to_file(newScene)
