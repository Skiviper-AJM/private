extends Node

# Global signals
signal gameSaved
signal globalLoaded
signal audioUpdated

# Enumerators
enum Locations {
	CAVE,
	CITY,
	WORKSHOP
}

# Global variables
var saveFilePath : String = "user://saves/"
var saveListFilePath : String = "user://saves/saveList.tres"

var activeSaveID : String = "0"
var lastSaveTime : int

# Savable resources
var loadedGlobalData : GlobalData
var playerData : PlayerData = PlayerData.new()

# Retrieve previous session globalData resource
func _ready():
	DirAccess.make_dir_absolute(saveFilePath)
	if ResourceLoader.exists(saveListFilePath):
		loadedGlobalData = ResourceLoader.load(saveListFilePath).duplicate(true)
	else:
		loadedGlobalData = GlobalData.new()
		ResourceSaver.save(loadedGlobalData, saveListFilePath)

# Overrides saved globalData
func saveGlobal():
	ResourceSaver.save(loadedGlobalData, saveListFilePath)
	emit_signal("audioUpdated")

# Load existing globalData
func loadGlobal():
	if ResourceLoader.exists(saveListFilePath):
		loadedGlobalData = ResourceLoader.load(saveListFilePath).duplicate(true)
	else:
		loadedGlobalData = GlobalData.new()
		ResourceSaver.save(loadedGlobalData, saveListFilePath)
	emit_signal("globalLoaded")

# Create new playerData save file
func createGame(newGameName):
	activeSaveID = newGameName
	loadedGlobalData.saveIDs.append(activeSaveID)
	saveGlobal()
	loadAndEnterGame(activeSaveID)

# Overrides saved playerData resource with current version
func saveGame():
	var currentTime : int = Time.get_unix_time_from_system()
	playerData.playTime += currentTime - lastSaveTime
	lastSaveTime = currentTime
	ResourceSaver.save(playerData, saveFilePath + activeSaveID + ".tres")
	emit_signal("gameSaved")

# Loads existing playerData resource
func loadGame():
	var newPlayerData : PlayerData = getGame(activeSaveID)
	playerData.constructor(newPlayerData)
	lastSaveTime = Time.get_unix_time_from_system()

# Returns given playerData resource
func getGame(saveID):
	if ResourceLoader.exists(saveFilePath + saveID + ".tres"):
		return ResourceLoader.load(saveFilePath + saveID + ".tres").duplicate(true)
	return PlayerData.new()

# Loads given playerData resource and enters game
func loadAndEnterGame(saveID):
	# Loads playerData
	activeSaveID = saveID
	loadGame()
	saveGame()
	# Enters stored scene
	match playerData.currentLocation:
		Locations.CAVE:
			get_tree().change_scene_to_file("res://hubs/desertCave/cave.tscn")
		Locations.CITY:
			get_tree().change_scene_to_file("res://hubs/city/city.tscn")
		Locations.WORKSHOP:
			get_tree().change_scene_to_file("res://hubs/city/subscenes/workshop.tscn")

# Deletes given playerData resource
func deleteSave(saveID):
	DirAccess.remove_absolute(saveFilePath + saveID + ".tres")
	loadedGlobalData.saveIDs.erase(saveID)
