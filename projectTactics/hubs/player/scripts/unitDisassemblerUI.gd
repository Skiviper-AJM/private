extends Control

signal unitDisassemblyComplete

enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

func openDisassembler():
	visible = true
	SFX.playCloseMenu()
	updateUnitList()

func updateUnitList():
	for child in %disassemblerGrid.get_children():
		if not child.is_in_group("defaultChildren"):
			child.queue_free()
	for item in FM.playerData.inventory.keys():
		if item.itemType == ItemTypes.UNIT:
			var newOption:Button = %disassemblerButtonTemplate.duplicate()
			%disassemblerGrid.add_child(newOption)
			%disassemblerGrid.move_child(newOption, %disassemblerTopSeparator.get_index() + 1)
			newOption.remove_from_group("defaultChildren")
			newOption.text = item.name
			if FM.playerData.inventory[item] > 1:
				newOption.text += "(" + str(FM.playerData.inventory[item]) + ")"
			newOption.visible = true
			newOption.button_up.connect(removeUnit.bind(item))
	SFX.connectAllButtons()

func removeUnit(selectedUnit:Unit):
	FM.playerData.addToInventory(selectedUnit.head)
	FM.playerData.addToInventory(selectedUnit.arm)
	FM.playerData.addToInventory(selectedUnit.chest)
	FM.playerData.addToInventory(selectedUnit.core)
	FM.playerData.addToInventory(selectedUnit.leg)
	FM.playerData.removeFromInventory(selectedUnit, 1)
	updateUnitList()

func exitPressed():
	visible = false
	SFX.playCloseMenu()
	emit_signal("unitDisassemblyComplete")
