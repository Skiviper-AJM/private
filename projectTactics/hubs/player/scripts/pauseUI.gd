extends Control

enum ItemTypes {
	ALL,
	PART,
	UNIT,
	FISH
}

enum Rarities {
	COMMON,
	UNCOMMON,
	RARE,
	EXOTIC,
	LEGENDARY,
	MYTHIC
}

var inCombat = false


var selectedItem
var selectedItemType:ItemTypes = ItemTypes.ALL

var spawnedItems:Array[Button] = []

@export var playerInfo : PlayerData

func _ready():
	playerInfo = FM.playerData
	
	%allFilter.button_up.connect(setItemType.bind(ItemTypes.ALL))
	%partsFilter.button_up.connect(setItemType.bind(ItemTypes.PART))
	%unitsFilter.button_up.connect(setItemType.bind(ItemTypes.UNIT))
	%fishFilter.button_up.connect(setItemType.bind(ItemTypes.FISH))

func _input(event):
	if Input.is_action_just_pressed("pause"): unpause();

func combatMode():

	$options/fleeCombat.visible = true
	$inventoryMenu/filterMenu.visible = false
	var units = playerInfo.inventory.keys().filter(func(item):
		return item.itemType == ItemTypes.UNIT
	)
	
	if units.size() > 0:
		inCombat = true
		var first_unit = units[0]
	

func unpause():
	clearDisplayedItem()
	get_tree().paused = false
	SFX.playCloseMenu()
	await get_tree().process_frame
	self.visible = false
	%inventoryMenu.visible = false
	if !%dialogueMenu.visible and !%sellMenu.visible and !%unitAssembler.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func openInventory():
	FM.saveGame()
	%pauseMenuBalance.set_text("[center][color=#f8f644]" + str(playerInfo.balance
		) + " [img=12]placeholder/goldIcon.png[/img]")
	clearDisplayedItem()
	if DataPasser.inActiveCombat == false:
		%inventoryMenu.visible = true
	else:
		%inventoryMenu.visible = false
	%saveMenu.visible = false
	%settingsMenu.visible = false
	refreshItems()

func refreshItems():
	for item in spawnedItems: item.queue_free();
	spawnedItems.clear()
	
	var allItems:Array = playerInfo.inventory.keys()
	var filteredItems:Array = []
	if inCombat == true:
		selectedItemType = ItemTypes.UNIT
		
	if selectedItemType == ItemTypes.ALL: filteredItems = allItems;
	else:
		for item in allItems:
			if item.itemType == selectedItemType:
				filteredItems.append(item)
	if not selectedItem in filteredItems:
		clearDisplayedItem()
		selectedItem = null
	for item in filteredItems:
		var newItem:Button = %itemTemplate.duplicate()
		%itemGrid.add_child(newItem)
		newItem.text = item.name
		if playerInfo.inventory[item] > 1:
			newItem.text += " (" + str(playerInfo.inventory[item]) + ")"
		newItem.visible = true
		newItem.button_up.connect(inventoryItemSelected.bind(item))
		spawnedItems.append(newItem)
	SFX.connectAllButtons()

func clearDisplayedItem():
	selectedItem = null
	%inventoryItemName.text = ""
	%inventoryItemData.text = " "
	%inventoryItemDescription.text = ""
	%inventoryItemModel.visible = false
	%inventoryItemMesh.mesh = null
	for child in %inventoryItemModel.get_children():
		if child != %inventoryItemMesh:
			child.queue_free()
	%inventoryDamageIcon.visible = false
	%inventoryArmorIcon.visible = false
	%inventorySpeedIcon.visible = false
	%inventoryRangeIcon.visible = false
	%inventorySplashIcon.visible = false
	%itemTrashSpacer.visible = false
	%deleteButton.visible = false

func openSettings():
	%inventoryMenu.visible = false
	%inventoryItemModel.visible = false
	%saveMenu.visible = false
	%settingsMenu.visible = true
	%settingsMenu.audioPressed()
	
func openQuit():
	%inventoryMenu.visible = false
	%inventoryItemModel.visible = false
	%saveMenu.visible = true
	%settingsMenu.visible = false
	
func leaveCombat():
	DataPasser.selectedUnit = null
	DataPasser.inActiveCombat = false
	$inventoryMenu/filterMenu.visible = true
	$options/fleeCombat.visible = false
	unpause()
	get_tree().change_scene_to_file(DataPasser.priorScene)
	
func inventoryItemSelected(item):
	if item == selectedItem: return;
	clearDisplayedItem()
	%inventoryItemModel.visible = true
	%inventoryItemModel.scale = Vector3(1.0, 1.0, 1.0)
	%itemRotatorAnim.pause()
	%inventoryItemModel.rotation.y = 0.0
	var aabbSize:Vector3
	match item.itemType:
		ItemTypes.PART:
			var newModel = item.model.instantiate()
			%inventoryItemModel.add_child(newModel)
			if newModel.get_node_or_null("inverted") != null:
				newModel.get_child(1).free()
			newModel.position = Vector3(0.0, -(newModel.getAABB().position + newModel.getAABB().size / 2.0).y, 0.0)
			if newModel.has_node("pivotCenter"):
				newModel.position.z = -newModel.get_node("pivotCenter").position.z - newModel.position.z
			aabbSize = newModel.getAABB().size
			var divideAmt : float = max(aabbSize.x, aabbSize.y, aabbSize.z)
			%inventoryItemModel.scale = Vector3(0.8, 0.8, 0.8) / divideAmt * newModel.scaleModifier
		ItemTypes.UNIT:
			var newModel = Node3D.new()
			%inventoryItemModel.add_child(newModel)
			newModel.set_script(load("res://combat/resources/unitAssembler.gd"))
			newModel.unitParts = item
			newModel.assembleUnit()
			newModel.position = Vector3(0.0, -(newModel.getAABB().position + newModel.getAABB().size / 2.0).y, 0.0)
			aabbSize = newModel.getAABB().size
			var divideAmt : float = max(aabbSize.x, aabbSize.y, aabbSize.z)
			%inventoryItemModel.scale = Vector3(0.8, 0.8, 0.8) / divideAmt
			#combat use of inventory here
			if inCombat && item.itemType == ItemTypes.UNIT: 
				DataPasser.passUnitInfo(item)
		ItemTypes.FISH:
			%inventoryItemMesh.mesh = item.model
			aabbSize = item.model.get_aabb().size
			var divideAmt : float = max(aabbSize.x, aabbSize.y, aabbSize.z)
			%inventoryItemModel.scale = Vector3(0.8, 0.8, 0.8) / divideAmt
	%itemRotatorAnim.play()
	%inventoryItemName.text = item.name
	if playerInfo.inventory[item] > 1:
		%inventoryItemName.text += " (" + str(playerInfo.inventory[item]) + ")"
		
	%inventoryItemDescription.text = "[center][i] " + item.description
	if item.itemType in [ItemTypes.PART, ItemTypes.UNIT]:
		if item.itemType == ItemTypes.PART:
			%inventoryItemData.text = "[center][color=red]%s [color=white]-[color=blue] %s/%s[color=white] - %s [img=12]placeholder/goldIcon.png[/img]" % [
				item.strType[item.type],
				str(item.currentDurability), 
				str(item.maxDurability),
				str(int(item.cost / 2.0))
			]
		%inventoryDamageIcon.visible = true
		%inventoryDamage.text = str(item.damage)
		%inventoryArmorIcon.visible = true
		%inventoryArmor.text = str(item.armorRating)
		%inventorySpeedIcon.visible = true
		%inventorySpeed.text = str(item.speedRating)
		%inventoryRangeIcon.visible = true
		%inventoryRange.text = str(item.range)
		%inventorySplashIcon.visible = item.splash > 0
		%inventorySplash.text = str(item.splash)
		%itemTrashSpacer.visible = true
	elif item.itemType == ItemTypes.FISH:
		var rarityText:String = ""
		match item.rarity:
			Rarities.COMMON:
				rarityText = "Common"
			Rarities.UNCOMMON:
				rarityText = "[color=turquoise]Uncommon"
			Rarities.RARE:
				rarityText = "[color=tomato]Rare"
			Rarities.EXOTIC:
				rarityText = "[color=hotpink]Exotic"
			Rarities.LEGENDARY:
				rarityText = "[color=gold]Legendary"
			Rarities.MYTHIC:
				rarityText = "[color=purple]Mythic"
		%inventoryItemData.text = "[center] %s [color=white] - %s [img=12]placeholder/goldIcon.png[/img]" % [
			rarityText,
			str(int(item.cost))
		]
			
	%deleteButton.visible = true
	selectedItem = item

func saveGamePressed():
	FM.saveGame()
	%saveGameButton.text = "Saved!"
	%saveGameButton.disabled = true
	await get_tree().create_timer(1.0).timeout
	%saveGameButton.text = "Manual Save"
	%saveGameButton.disabled = false

func mainMenuPressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://general/UI/mainMenu.tscn")

func desktopPressed():
	get_tree().quit()

func deleteItemPressed():
	playerInfo.inventory.erase(selectedItem)
	clearDisplayedItem()
	refreshItems()
	FM.saveGame()

func setItemType(type:ItemTypes):
	selectedItemType = type
	refreshItems()



