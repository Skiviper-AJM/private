extends Control

signal unitAssemblyComplete

enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

enum PartTypes {
	ARM,
	LEG,
	CHEST,
	CORE,
	HEAD
}

var unitBuilding:Unit = null
var selectingType:PartTypes = PartTypes.ARM

func startBuilding():
	unitBuilding = Unit.new()
	visible = true
	%armItemName.text = "None"
	%headItemName.text = "None"
	%legItemName.text = "None"
	%coreItemName.text = "None"
	%chestItemName.text = "None"
	%unitName.text = ""
	showPartSelection()
	SFX.playCloseMenu()

func showParts(type:PartTypes):
	$partLayout.visible = true
	$partSelectionLayout.visible = false
	selectingType = type
	for child in %partGrid.get_children():
		if not child.is_in_group("defaultChildren"):
			child.queue_free()
	for item in FM.playerData.inventory.keys():
		if item.itemType == ItemTypes.PART and item.type == type:
			var newOption:Button = %partButtonTemplate.duplicate()
			%partGrid.add_child(newOption)
			%partGrid.move_child(newOption, %partBottomSeparator.get_index() - 1)
			newOption.remove_from_group("defaultChildren")
			newOption.text = item.name
			newOption.visible = true
			newOption.button_up.connect(partSelected.bind(item))
	SFX.connectAllButtons()

func nonePressed():
	match selectingType:
		PartTypes.ARM:
			unitBuilding.arm = null
			%armItemName.text = "None"
		PartTypes.HEAD:
			unitBuilding.head = null
			%headItemName.text = "None"
		PartTypes.LEG:
			unitBuilding.leg = null
			%legItemName.text = "None"
		PartTypes.CORE:
			unitBuilding.core = null
			%coreItemName.text = "None"
		PartTypes.CHEST:
			unitBuilding.chest = null
			%chestItemName.text = "None"
	showPartSelection()

func partSelected(part:Part):
	match selectingType:
		PartTypes.ARM:
			unitBuilding.arm = part
			%armItemName.text = part.name
		PartTypes.HEAD:
			unitBuilding.head = part
			%headItemName.text = part.name
		PartTypes.LEG:
			unitBuilding.leg = part
			%legItemName.text = part.name
		PartTypes.CORE:
			unitBuilding.core = part
			%coreItemName.text = part.name
		PartTypes.CHEST:
			unitBuilding.chest = part
			%chestItemName.text = part.name
	showPartSelection()

func showPartSelection():
	$partLayout.visible = false
	$partSelectionLayout.visible = true
	if null in [
		unitBuilding.head, unitBuilding.arm,
		unitBuilding.chest, unitBuilding.core,
		unitBuilding.leg]:
		%unitConfirmButton.disabled = true
		%unitConfirmButton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		%unitConfirmButton.disabled = false
		%unitConfirmButton.mouse_filter = Control.MOUSE_FILTER_STOP

func headPressed(): showParts(PartTypes.HEAD);
func armPressed(): showParts(PartTypes.ARM);
func chestPressed(): showParts(PartTypes.CHEST);
func corePressed(): showParts(PartTypes.CORE);
func legPressed(): showParts(PartTypes.LEG);

func confirmPressed():
	unitBuilding.name = "myMech"
	if %unitName.text != "": unitBuilding.name = %unitName.text;
	
	FM.playerData.addToInventory(unitBuilding)
	FM.playerData.removeFromInventory(unitBuilding.head, 1)
	FM.playerData.removeFromInventory(unitBuilding.arm, 1)
	FM.playerData.removeFromInventory(unitBuilding.chest, 1)
	FM.playerData.removeFromInventory(unitBuilding.core, 1)
	FM.playerData.removeFromInventory(unitBuilding.leg, 1)
	
	visible = false
	emit_signal("unitAssemblyComplete")

func cancelPressed():
	unitBuilding = null
	visible = false
	emit_signal("unitAssemblyComplete")

