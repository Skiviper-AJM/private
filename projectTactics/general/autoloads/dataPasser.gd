extends Node

#stores the name of the scene before going into combat so the exit scene is correct
@export var priorScene: String = ""

#the currently selected unit (player unit specifically
var selectedUnit: Object

#tracks the consecutive fights in the cave scene between fights 
var fights: int = 0

#tells the UI if its in combat mode
var inActiveCombat: bool

#function another script can call to get the information of the currently selected unit
func passUnitInfo(item):
	selectedUnit = item


