extends Node2D
# Button sprites
@onready var completePointHoverStyle:StyleBoxTexture = preload("res://combat/maps/resources/completePointHoverStyle.tres")
@onready var completePointStyle:StyleBoxTexture = preload("res://combat/maps/resources/completePointStyle.tres")

@onready var currentPointHoverStyle:StyleBoxTexture = preload("res://combat/maps/resources/currentPointHoverStyle.tres")
@onready var currentPointStyle:StyleBoxTexture = preload("res://combat/maps/resources/currentPointStyle.tres")

@onready var lockedPointHoverStyle:StyleBoxTexture = preload("res://combat/maps/resources/lockedHoverStyle.tres")
@onready var lockedPointStyle:StyleBoxTexture = preload("res://combat/maps/resources/lockedStyle.tres")

@onready var unlockedPointHoverStyle:StyleBoxTexture = preload("res://combat/maps/resources/unlockedPointHoverStyle.tres")
@onready var unlockedPointStyle:StyleBoxTexture = preload("res://combat/maps/resources/unlockedPointStyle.tres")

@onready var emptyStyle = preload("res://combat/maps/resources/emptyStyle.tres")
# Line sprites
@onready var solidLine:Texture2D = preload("res://combat/maps/assets/solidLine.png")
@onready var darkDottedLine:Texture2D = preload("res://combat/maps/assets/darkDottedLine.png")
@onready var dottedLine:Texture2D = preload("res://combat/maps/assets/dottedLine.png")
# Stores which location to unlock next
# Location: [Newly unlocked locations], [New connection lines], [Established lines]
@onready var locationConnections:Dictionary = {
	$location1:[[$location2], [$line1, $line2], []],
	$location2:[[$location3, $location4], [$line3, $line4, $line5], [$line1, $line2]],
	$location3:[[], [], [$line3, $line4]],
	$location4:[[$location5], [$line6], [$line3, $line5]],
	$location5:[[], [], [$line6]]
}
# Variables
@onready var completeLocations:Array[Button] = []
@onready var startingLocation:Button = $location1
@onready var allLocations:Array[Button] = [$location1, $location2, $location3, $location4, $location5]
@onready var allLines:Array[Line2D] = [$line1, $line2, $line3, $line4, $line5, $line6]

@onready var activeLocations:Array[Button] = [startingLocation]

# Initializes map scene
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Connects buttons to locationPressed function
	for location in allLocations: location.button_up.connect(locationPressed.bind(location));
	updateLocations()

# Updates map based on what has been unlocked
func updateLocations():
	# Updates lines
	for line in allLines: line.texture = darkDottedLine;
	# Sets all buttons to default locked state
	for location in allLocations:
		location.add_theme_stylebox_override("normal", lockedPointStyle)
		location.add_theme_stylebox_override("hover", lockedPointHoverStyle)
		location.add_theme_stylebox_override("pressed", lockedPointHoverStyle)
		location.focus_mode = Control.FOCUS_NONE
	# Updates starting button state
	startingLocation.add_theme_stylebox_override("normal", unlockedPointStyle)
	startingLocation.add_theme_stylebox_override("hover", unlockedPointHoverStyle)
	startingLocation.add_theme_stylebox_override("pressed", unlockedPointHoverStyle)
	startingLocation.focus_mode = Control.FOCUS_ALL
	
	# Updates relevent button states based on whether button has been unlocked
	var establishedLines:Array[Line2D] = []
	
	for location in completeLocations:
		var locationData:Array = locationConnections[location]
		for newLocation in locationData[0]:
			newLocation.add_theme_stylebox_override("normal", unlockedPointStyle)
			newLocation.add_theme_stylebox_override("hover", unlockedPointHoverStyle)
			newLocation.add_theme_stylebox_override("pressed", unlockedPointHoverStyle)
			newLocation.focus_mode = Control.FOCUS_ALL
			activeLocations.append(newLocation)
		for newLine in locationData[1]: newLine.texture = dottedLine;
		establishedLines.append_array(locationData[2])
	
	for location in completeLocations:
		location.add_theme_stylebox_override("normal", completePointStyle)
		location.add_theme_stylebox_override("hover", completePointHoverStyle)
		location.add_theme_stylebox_override("pressed", completePointHoverStyle)
		location.focus_mode = Control.FOCUS_NONE
		if location in activeLocations: activeLocations.erase(location);
	# Updates lines to show unlocked connections
	for line in establishedLines: line.texture = solidLine;

# Button pressed event
func locationPressed(location:Button):
	if location not in activeLocations: return;
	# Unlock new hub area
	if location == $location5:
		GS.entranceName = "caveTop"
		get_tree().change_scene_to_file("res://hubs/desertCave/cave.tscn")
	# Unlock next button/s
	completeLocations.append(location)
	updateLocations()

# Return player to pre-map hub
func _on_quit_button_button_up():
	get_tree().change_scene_to_file("res://hubs/desertCave/cave.tscn")
