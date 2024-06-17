extends Resource
class_name GlobalData
# Pre-existing playerData save files
@export var saveIDs:Array = []
# Graphics
@export var vsyncToggled:bool = true
@export var fullscreenToggled:bool = true
# Volume
@export var musicVolume:int = 5
@export var combatVolume:int = 5
@export var uiVolume:int = 5
@export var ambientVolume:int = 5
# Keybinds
@export var updatedKeybinds : Dictionary = {}
