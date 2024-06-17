extends Node3D

# Initializes city scene
func _ready():
	Music.playSong("city")
	FM.playerData.changeLocation("city")
	
	if FM.playerData.hasFishingRod: %fishermanInteractable.hasIntroduced = true;
	
	GS.event.connect(eventTriggered)

# Dialogue events
func eventTriggered(identifier:String, value):
	# Unlocks fishing minigame
	if identifier == "giveFishingRod":
		FM.playerData.hasFishingRod = true
		FM.saveGame()
		GS.emit_signal("eventFinished")
