extends Control

# EVENT = Trigger Event
# DIALG = Add new dialogue to queue
# FQUIT = End Dialogue
# GSELL = Open Generic Sell Menu

signal dialogueEnded

# Stored dialogue sequences
var dialogue:Dictionary = {
	"caveDwellerIntro":
		["Ah, you must be new around these parts.",
		"If you're in need of supplies, there should be some worn down parts scattered throughout this cave.",
		"Once you've found enough parts to build a mech, come talk to me and I'll see if I can put something together for you."],
	"caveDwellerCheck":
		["Let me have a look at what you've got.../EVENTcaveDwellerAssemble"],
	"caveDwellerFail":
		["Hmmm, you seem to be missing a few parts.",
		"Find me 1x Corroded Head, 1x Corroded Chest Plating, 1x Corroded Sword, 1x Corroded Fire Core, and 1x Corroded Leg.",
		"Then I should be able to put something together for you."],
	"unitAssemblerIntro":
		["The mech assembly system. You can build or deconstruct mechs here./DIALGunitAssembler"],
	"unitAssembler":
		["The mech assembly system./EVENTbuildUnit/Build Unit/EVENTdeconstructUnit/Deconstruct Unit/FQUIT/Leave"],
	"fishermanIntro":
		["You look like you have potential.",
		"Here, take my old fishing rod, may it serve you well./EVENTgiveFishingRod",
		"Fishing Rod Acquired! Press left click when looking at water to begin fishing."],
	"fisherman":
		["If you're looking for places to fish, I believe the cave system beneath the city is as good a place as any."],
	"cityBuyerIntro":
		["Well hello down there!",
		"If you're looking to sell goods, you've come to the right place./GSELLcityBuyer/Sell/FQUIT/Nevermind"],
	"cityBuyer":
		["Looking to sell?/GSELLcityBuyer/Sell/FQUIT/Nevermind"],
	"cityBuyerDenied":
		["Come back anytime!"],
	"cityBuyerSold":
		["Pleasure doing business."]
}

# Dialogue state variables
var queuedDialogue:Array[String] = []
var queuedActions:Array[String] = []
var canSkip:bool = false

@onready var responseBoxes:Array[Button] = [%response1, %response2, %response3, %response4]

# Connects global events to functions
func _ready():
	GS.eventFinished.connect(nextLine)
	GS.triggerDialogue.connect(appendDialogue)

# Checks whether dialogue should be progressed
func _process(delta):
	if Input.is_action_just_pressed("interact") and !responseBoxes[0].visible and canSkip:
		if len(queuedActions) > 0: executeAction(queuedActions[0]);
		else: nextLine();

# Initiate dialogue
func startDialogue(identifier:String):
	visible = true
	SFX.playCloseMenu()
	appendDialogue(identifier)

# Play next queued dialogue line
func nextLine():
	# Clears previous dialogue state
	visible = true
	if len(queuedDialogue) == 0:
		endDialogue()
		return
	queuedActions.clear()
	canSkip = false
	# Scans for any dialogue responses
	for responseBox in responseBoxes: responseBox.visible = false;
	var rawLine:String = queuedDialogue.pop_front() + "/"
	var curString:String = ""
	var idxNum:int = 0
	# Display possible responses
	for char:String in rawLine:
		if char == "/":
			if idxNum == 0: %dialogueText.text = curString;
			elif idxNum % 2 == 0:
				responseBoxes[idxNum / 2 - 1].text = curString
				responseBoxes[idxNum / 2 - 1].visible = true
			else: queuedActions.append(curString);
			idxNum += 1
			curString = ""
			continue
		curString += char
	# Display line
	if idxNum < 3: %dialogueText.text += " [wave]▼";
	# Prevent player from accidentally skipping dialogue
	await get_tree().create_timer(0.1).timeout
	canSkip = true

# Dialogue actions
func executeAction(action:String):
	match action.substr(0, 5): 
		"EVENT": # Trigger external event
			canSkip = false
			visible = false
			GS.emit_signal("event", action.substr(5, -1), "")
		"DIALG": # Append new dialogue
			appendDialogue(action.substr(5, -1))
		"FQUIT": # Force quit dialogue
			endDialogue()
		"GSELL": # Display npc sell menu
			visible = false
			%sellMenu.enable(action.substr(5, -1))

# Clears all dialogue and resets system
func endDialogue():
	visible = false
	SFX.playCloseMenu()
	queuedActions.clear()
	queuedDialogue.clear()
	for responseBox in responseBoxes: responseBox.visible = false;
	# Reactivates player movement
	emit_signal("dialogueEnded")
	process_mode = Node.PROCESS_MODE_DISABLED

# Add new dialogue lines to queue
func appendDialogue(identifier:String):
	for line:String in dialogue[identifier]:
		queuedDialogue.append(line)
	nextLine()

# Add custom dialogue to queue
func startCustomDialogue(customDialogue:Array):
	for line:String in customDialogue:
		queuedDialogue.append(line)
	nextLine()

# Trigger response actions
func response1Pressed(): executeAction(queuedActions[0]);
func response2Pressed(): executeAction(queuedActions[1]);
func response3Pressed(): executeAction(queuedActions[2]);
func response4Pressed(): executeAction(queuedActions[3]);
