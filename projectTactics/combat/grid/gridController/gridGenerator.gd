extends Node2D

@export var grid_width:int = 10
@export var grid_height:int = 10
@export var hex_radius:float = 50.0

func _input(event):
	if Input.is_action_just_pressed("DeleteGrid"): changeScene(DataPasser.priorScene);

func _ready():
	generate_grid()

func generate_grid():
	var hex_width = sqrt(3) * hex_radius
	var hex_height = hex_radius * 2

	for x in range(grid_width):
		for y in range(grid_height):
			var hex_x = x * hex_width + (y % 2) * (hex_width / 2)
			var hex_y = y * hex_height * 0.75
			
			var hex_cell = create_hex_cell(Vector2(hex_x, hex_y))
			add_child(hex_cell)

func create_hex_cell(position: Vector2) -> Sprite2D:
	var hex_cell = Sprite2D.new()
	hex_cell.position = position
	hex_cell.texture = preload("res://combat/grid/gridController/stone_02.png")  # Replace with your actual hex texture path
	return hex_cell
	
	




func changeScene(newScene):
	get_tree().change_scene_to_file(newScene)
