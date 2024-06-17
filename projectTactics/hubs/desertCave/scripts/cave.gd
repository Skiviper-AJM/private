extends Node3D

# Variables
var playerInfo:PlayerData

@export var wornUnit:Unit
@export var requiredItems:Array[Part] = []

# Cave scene initialization
func _ready():
	playerInfo = $player.playerInfo
	GS.event.connect(eventTriggered)
	# Update stored player location
	FM.playerData.changeLocation("cave")
	# Adjust music
	Music.playSong("cave")
	FM.audioUpdated.connect(updateSFX)
	updateSFX()

# Dialogue events
func eventTriggered(identifier:String, value):
	# Gives starter units based on amount of parts in inventory
	if identifier == "caveDwellerAssemble":
		# Calculates amount of units to give
		var smallestItemCount:int = 1000000
		for item in requiredItems:
			if item not in playerInfo.inventory.keys():
				GS.emit_signal("triggerDialogue", "caveDwellerFail")
				return
			smallestItemCount = min(smallestItemCount, playerInfo.inventory[item])
		# Adds units to inventory
		for item in requiredItems:
			playerInfo.removeFromInventory(item, smallestItemCount)
		playerInfo.addToInventory(wornUnit, smallestItemCount)
		# Updates dialogue to notify user of new units
		if smallestItemCount == 1:
			$player/UI/dialogueMenu.startCustomDialogue(
				["Perfect! Now just give me a moment...",
				"And hey presto!",
				"1x Well Worn Mech Acquired!"]
			)
		else:
			$player/UI/dialogueMenu.startCustomDialogue(
				["Perfect! Now just give me a moment...",
				"And hey presto!",
				str(smallestItemCount) + "x Well Worn Mechs Acquired!"]
			)

# Update cave ambient SFX volumes
func updateSFX():
	%waterAmbienceSFX.volume_db = 4 * FM.loadedGlobalData.ambientVolume - 30
	%waterfallSFX.volume_db = 4 * FM.loadedGlobalData.ambientVolume - 20
