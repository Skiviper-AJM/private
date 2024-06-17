extends GridContainer

var lockedKeybinds : Array = [
	"pause",
	"quit",
	"interact"
]

@onready var keybindButtons : Dictionary = {
	"moveUp":$forwardButton,
	"moveDown":$backwardButton,
	"moveLeft":$leftButton,
	"moveRight":$rightButton,
	"moveJump":$jumpButton,
	"moveSprint":$sprintButton
}

var keybindSelected : String = ""

func _ready():
	updateAllKeybinds()
	refreshKeybinds()
	FM.globalLoaded.connect(refreshKeybinds)

func refreshKeybinds():
	for keybind in FM.loadedGlobalData.updatedKeybinds.keys():
		InputMap.action_erase_events(keybind)
		InputMap.action_add_event(keybind, FM.loadedGlobalData.updatedKeybinds[keybind])
	updateAllKeybinds()

func _input(event):
	if !visible or !get_parent().get_parent().visible or keybindSelected == "": return;
	if !InputMap.action_has_event(keybindSelected, event):
		for action in keybindButtons.keys() + lockedKeybinds:
			if InputMap.action_has_event(action, event):
				%inUseAnim.play("fade")
				return
	if event is InputEventKey:
		keybindButtons[keybindSelected].text = OS.get_keycode_string(event.keycode)
	elif event is InputEventMouseButton and event.button_index > 5:
		keybindButtons[keybindSelected].text = "Mouse " + str(event.button_index)
	else: return;
	get_viewport().set_input_as_handled()
	InputMap.action_erase_events(keybindSelected)
	InputMap.action_add_event(keybindSelected, event)
	FM.loadedGlobalData.updatedKeybinds[keybindSelected] = event
	FM.saveGlobal()
	keybindSelected = ""
	%clearSelectionButton.grab_focus()

func updateAllKeybinds():
	for button in keybindButtons.keys():
		if InputMap.action_get_events(button)[0] is InputEventKey:
			var event = InputMap.action_get_events(button)[0].as_text()
			event = event.rsplit(" (")[0]
			keybindButtons[button].text = event
		else:
			keybindButtons[button].text = "Mouse " + str(
				InputMap.action_get_events(button)[0].button_index)

func focusKeybind(keybind):
	unfocusKeybind()
	keybindSelected = keybind
	keybindButtons[keybind].text = "[ ]"

func unfocusKeybind():
	if keybindSelected == "": return;
	keybindButtons[keybindSelected].text = InputMap.action_get_events(
		keybindSelected)[0].as_text().rsplit(" (")[0]
	keybindSelected = ""
